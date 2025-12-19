import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_models.dart';
import '../models/projects_model.dart';
import '../theme/app_theme.dart';
import '../utils/thermolox_overlay.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/cart_icon_button.dart';
import 'project_detail_page.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  Color _colorFromHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length < 6) h = h.padRight(6, '0');
    final val = int.tryParse(h.substring(0, 6), radix: 16) ?? 0x777777;
    return Color(0xFF000000 | val);
  }

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
    final project = await model.addProject(name);
    await _promptFirstUpload(context, project.id);
  }

  Future<void> _promptFirstUpload(BuildContext context, String projectId) async {
    final picked = await pickThermoloxAttachment(context);
    if (picked == null) return;
    await context.read<ProjectsModel>().addItem(
          projectId: projectId,
          name: picked.name ?? 'Upload',
          type: picked.isImage ? 'image' : 'file',
          path: picked.path,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;

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
        onPressed: () => _createProject(context),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Noch keine Projekte'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _createProject(context),
                    child: const Text('Neues Projekt anlegen'),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
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
              final thumb = p.items.firstWhere(
                (e) => e.type == 'image',
                orElse: () => p.items.firstWhere(
                  (e) => e.type == 'color',
                  orElse: () => p.items.isNotEmpty
                      ? p.items.first
                      : ProjectItem(
                          id: '',
                          name: '',
                          type: 'file',
                          url: null,
                          path: null,
                        ),
                ),
              );
              final hasImageThumb = thumb.id.isNotEmpty &&
                  thumb.type == 'image' &&
                  (thumb.path != null || thumb.url != null);
              final isColorThumb = thumb.id.isNotEmpty && thumb.type == 'color';
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailPage(projectId: p.id),
                  ),
                ),
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
                              thumb.path != null
                                  ? Image.file(
                                      File(thumb.path!),
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      thumb.url!,
                                      fit: BoxFit.cover,
                                    )
                            else if (isColorThumb)
                              Container(
                                color: _colorFromHex(thumb.url ?? thumb.name),
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
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${p.items.length} Upload${p.items.length == 1 ? '' : 's'}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white70,
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
                      child: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'rename') {
                            final newName = await ThermoloxOverlay.promptText(
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
                          PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
                          PopupMenuItem(value: 'delete', child: Text('Löschen')),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
