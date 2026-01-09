import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/plan_controller.dart';
import '../models/project_models.dart';
import '../models/projects_model.dart';
import '../theme/app_theme.dart';
import '../utils/color_utils.dart';
import '../utils/thermolox_overlay.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/cart_icon_button.dart';
import 'project_detail_page.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  Future<void> _createProject(BuildContext context) async {
    final name = await ThermoloxOverlay.promptText(
      context: context,
      title: 'Neues Projekt',
      hintText: 'Projektname',
      confirmLabel: 'Anlegen',
    );
    if (name == null) return;

    final model = context.read<ProjectsModel>();
    if (model.existsName(name)) {
      ThermoloxOverlay.showSnack(context, 'Projekt existiert bereits.');
      return;
    }
    try {
      final project = await model.addProject(name);
      await _promptFirstUpload(context, project.id);
    } catch (_) {
      ThermoloxOverlay.showSnack(
        context,
        'Bitte anmelden, um Projekte zu speichern.',
      );
    }
  }

  Future<void> _promptFirstUpload(BuildContext context, String projectId) async {
    final picked = await pickThermoloxAttachment(context);
    if (picked == null) return;
    try {
      await context.read<ProjectsModel>().addItem(
            projectId: projectId,
            name: picked.name ?? 'Upload',
            type: picked.isImage ? 'image' : 'file',
            path: picked.path,
          );
    } catch (_) {
      ThermoloxOverlay.showSnack(
        context,
        'Bitte anmelden, um Uploads zu speichern.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final canAccessProjects =
        context.watch<PlanController>().hasProjectsAccess;

    return ThermoloxScaffold(
      safeArea: true,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Projekte & Uploads',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.0,
          ),
        ),
        actions: const [CartIconButton()],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canAccessProjects ? () => _createProject(context) : null,
        icon: const Icon(Icons.add),
        label: const Text('Projekt'),
      ),
      body: Consumer<ProjectsModel>(
        builder: (context, model, _) {
          if (!model.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final projects = model.projects;
          if (projects.isEmpty) {
            return Center(
              child: Opacity(
                opacity: canAccessProjects ? 1 : 0.45,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Noch keine Projekte'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: canAccessProjects
                          ? () => _createProject(context)
                          : null,
                      child: const Text('Neues Projekt anlegen'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Opacity(
            opacity: canAccessProjects ? 1 : 0.45,
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                0,
                tokens.screenPadding,
                0,
                100,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final p = projects[index];
              ProjectItem? _findByType(String type) {
                for (var i = p.items.length - 1; i >= 0; i--) {
                  final item = p.items[i];
                  if (item.type == type) return item;
                }
                return null;
              }

              final imageItem = _findByType('image');
              final fileItem = _findByType('file');
              final colorItem = _findByType('color');
              final mediaItem = imageItem ?? fileItem;
              final thumb = mediaItem ?? colorItem;
              final localPath = thumb?.path;
              final localExists =
                  localPath != null && File(localPath).existsSync();
              final remoteUrl = thumb?.url;
              final hasImageThumb = thumb != null &&
                  thumb.type == 'image' &&
                  (localExists || remoteUrl != null);
              final isFileThumb = thumb != null && thumb.type == 'file';
              final isColorThumb = thumb != null && thumb.type == 'color';
              return GestureDetector(
                onTap: canAccessProjects
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProjectDetailPage(projectId: p.id),
                          ),
                        )
                    : null,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                        color: theme.colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasImageThumb)
                              localExists
                                  ? Image.file(
                                      File(localPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      remoteUrl!,
                                      fit: BoxFit.cover,
                                    )
                            else if (isFileThumb)
                              Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.insert_drive_file,
                                  size: 42,
                                  color: Colors.black54,
                                ),
                              )
                            else if (isColorThumb)
                              Container(
                                color: colorFromHex(
                                      thumb?.url ?? thumb?.name ?? '#777777',
                                    ) ??
                                    const Color(0xFF777777),
                              )
                            else
                              Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.folder, size: 42),
                              ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.black.withOpacity(0.35),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (p.title != null &&
                                              p.title!.trim().isNotEmpty)
                                          ? p.title!
                                          : p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: canAccessProjects
                          ? PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'rename') {
                                  final newName =
                                      await ThermoloxOverlay.promptText(
                                    context: context,
                                    title: 'Projekt umbenennen',
                                    hintText: 'Neuer Name',
                                    initialValue: p.name,
                                    confirmLabel: 'Speichern',
                                  );
                                  if (newName != null) {
                                    await context
                                        .read<ProjectsModel>()
                                        .renameProject(p.id, newName);
                                  }
                                } else if (value == 'delete') {
                                  final ok = await ThermoloxOverlay.confirm(
                                    context: context,
                                    title: 'Projekt löschen?',
                                    message:
                                        'Das Projekt und alle zugehörigen Einträge werden entfernt.',
                                    confirmLabel: 'Löschen',
                                  );
                                  if (ok) {
                                    await context
                                        .read<ProjectsModel>()
                                        .deleteProject(p.id);
                                  }
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Umbenennen'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Löschen'),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
            ),
          );
        },
      ),
    );
  }
}
