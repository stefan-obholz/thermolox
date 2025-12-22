import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_models.dart';
import '../models/projects_model.dart';
import '../theme/app_theme.dart';
import '../utils/color_utils.dart';
import '../utils/thermolox_overlay.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/color_palette_sheet.dart';

class ProjectDetailPage extends StatelessWidget {
  final String projectId;

  const ProjectDetailPage({super.key, required this.projectId});

  Project _find(BuildContext context) =>
      context.read<ProjectsModel>().projects.firstWhere((p) => p.id == projectId);

  Future<void> _renameProject(BuildContext context, Project project) async {
    final newName = await ThermoloxOverlay.promptText(
      context: context,
      title: 'Projekt umbenennen',
      hintText: 'Neuer Name',
      initialValue: project.name,
      confirmLabel: 'Speichern',
    );
    if (newName != null) {
      await context.read<ProjectsModel>().renameProject(project.id, newName);
    }
  }

  Future<void> _addUpload(BuildContext context, Project project) async {
    final picked = await pickThermoloxAttachment(context);
    if (picked == null) return;
    await context.read<ProjectsModel>().addItem(
          projectId: project.id,
          name: picked.name ?? 'Upload',
          type: picked.isImage ? 'image' : 'file',
          path: picked.path,
        );
  }

  Future<void> _openPreview(BuildContext context, ProjectItem item) async {
    if (item.type != 'image') return;
    final tokens = context.thermoloxTokens;
    final localPath = item.path;
    final localExists =
        localPath != null && File(localPath).existsSync();
    final Widget? image = localExists
        ? Image.file(File(localPath!), fit: BoxFit.contain)
        : (item.url != null
            ? Image.network(item.url!, fit: BoxFit.contain)
            : null);
    if (image == null) return;
    await ThermoloxOverlay.showAppDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.85)),
              ),
              Center(
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(tokens.screenPadding),
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                            child: image,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openColorPreview(
    BuildContext context,
    Color color,
    String label,
  ) async {
    final onColor = ThemeData.estimateBrightnessForColor(color) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
    await ThermoloxOverlay.showAppDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(
            color: color,
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: Icon(Icons.close, color: onColor),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  Center(
                    child: Text(
                      label,
                      style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                            color: onColor,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    Project project, {
    String? initialHex,
  }) async {
    final selectedHex = await showColorPaletteSheet(
      context,
      initialHex: initialHex,
    );
    if (selectedHex == null) return;
    await context.read<ProjectsModel>().addColorSwatch(
          projectId: project.id,
          hex: selectedHex,
        );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.thermoloxTokens;
    return Consumer<ProjectsModel>(
      builder: (context, model, _) {
        final project = model.projects.firstWhere((p) => p.id == projectId);
        final items = project.items;
        ProjectItem? _findByType(String type) {
          for (var i = items.length - 1; i >= 0; i--) {
            final item = items[i];
            if (item.type == type) return item;
          }
          return null;
        }

        final imageItem = _findByType('image');
        final fileItem = _findByType('file');
        final mediaItem = imageItem ?? fileItem;
        final colorItem = _findByType('color');
        return ThermoloxScaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _renameProject(context, project),
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              0,
              tokens.screenPadding,
              0,
              100,
            ),
            children: [
              Text(
                'Foto',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: tokens.gapSm),
              _ProjectCard(
                child: _ProjectImageCard(
                  item: mediaItem,
                  onTap: mediaItem == null || mediaItem.type != 'image'
                      ? null
                      : () => _openPreview(context, mediaItem),
                  onPick: () => _addUpload(context, project),
                ),
              ),
              SizedBox(height: tokens.gapLg),
              Text(
                'Farbe',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: tokens.gapSm),
              _ProjectCard(
                child: _ProjectColorCard(
                  item: colorItem,
                  colorFromHex: colorFromHex,
                  onPreview: colorItem == null
                      ? null
                      : () {
                          final hex = colorItem.url ?? colorItem.name;
                          final color = colorFromHex(hex);
                          if (color == null) return;
                          _openColorPreview(context, color, hex);
                        },
                  onPick: () => _pickColor(
                    context,
                    project,
                    initialHex: colorItem?.url ?? colorItem?.name,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Widget child;

  const _ProjectCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.thermoloxTokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: child,
      ),
    );
  }
}

class _ProjectImageCard extends StatelessWidget {
  final ProjectItem? item;
  final VoidCallback? onTap;
  final VoidCallback onPick;

  const _ProjectImageCard({
    required this.item,
    this.onTap,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final localPath = item?.path;
    final localExists =
        localPath != null && File(localPath).existsSync();
    final remoteUrl = item?.url;
    final hasImage = item != null &&
        item!.type == 'image' &&
        (localExists || remoteUrl != null);
    final isFile = item != null && item!.type == 'file';
    return InkWell(
      onTap: hasImage ? onTap : null,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: theme.colorScheme.surface,
              child: hasImage
                  ? (localExists
                      ? Image.file(
                          File(localPath!),
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          remoteUrl!,
                          fit: BoxFit.cover,
                        ))
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFile
                                ? Icons.insert_drive_file_outlined
                                : Icons.photo_outlined,
                            size: 36,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isFile ? (item?.name ?? 'Datei') : 'Noch kein Foto',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: theme.colorScheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(999),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                      SizedBox(width: tokens.gapXs),
                      Text(
                        'Bild ändern',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectColorCard extends StatelessWidget {
  final ProjectItem? item;
  final Color? Function(String hex) colorFromHex;
  final VoidCallback onPick;
  final VoidCallback? onPreview;

  const _ProjectColorCard({
    required this.item,
    required this.colorFromHex,
    required this.onPick,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final color = item == null
        ? null
        : colorFromHex(item?.url ?? item?.name ?? '');
    final actionLabel = color == null ? 'Farbe auswählen' : 'Farbe ändern';
    return InkWell(
      onTap: color != null ? onPreview : onPick,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: color ?? theme.colorScheme.surface,
              child: color == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.color_lens_outlined,
                            size: 32,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Noch keine Farbe',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Farbe auswählen',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: theme.colorScheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(999),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                      SizedBox(width: tokens.gapXs),
                      Text(
                        actionLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
