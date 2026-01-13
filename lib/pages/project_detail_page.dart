import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../controllers/plan_controller.dart';
import '../controllers/virtual_room_credit_manager.dart';
import '../models/project_models.dart';
import '../models/projects_model.dart';
import '../pages/auth_page.dart';
import '../services/consent_service.dart';
import '../services/credit_service.dart';
import '../services/image_edit_service.dart';
import '../theme/app_theme.dart';
import '../utils/color_utils.dart';
import '../utils/thermolox_overlay.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/color_palette_sheet.dart';
import '../widgets/image_preview_page.dart';
import '../widgets/mask_editor_page.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projectId;

  const ProjectDetailPage({super.key, required this.projectId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  String? _selectedRenderId;

  Project _find(BuildContext context) =>
      context.read<ProjectsModel>().projects.firstWhere(
            (p) => p.id == widget.projectId,
          );

  Future<void> _renameProject(BuildContext context, Project project) async {
    final newName = await ThermoloxOverlay.promptText(
      context: context,
      title: 'Projekt umbenennen',
      hintText: 'Neuer Name',
      initialValue: project.name,
      confirmLabel: 'Speichern',
    );
    if (newName != null) {
      try {
        await context.read<ProjectsModel>().renameProject(project.id, newName);
      } catch (_) {
        ThermoloxOverlay.showSnack(
          context,
          'Bitte anmelden, um Projekte zu speichern.',
        );
      }
    }
  }

  Future<void> _addUpload(BuildContext context, Project project) async {
    final picked = await pickThermoloxAttachment(context);
    if (picked == null) return;
    try {
      await context.read<ProjectsModel>().addItem(
            projectId: project.id,
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

  Future<void> _openPreview(BuildContext context, ProjectItem item) async {
    if (item.type != 'image' && item.type != 'render') return;
    final pathOrUrl = _resolveItemPreviewPath(item);
    if (pathOrUrl == null) return;
    await openImagePreview(
      context,
      pathOrUrl: pathOrUrl,
      title: 'Bild',
    );
  }

  String? _resolveItemPreviewPath(ProjectItem item) {
    final localPath = item.path;
    if (localPath != null && File(localPath).existsSync()) {
      return localPath;
    }
    final url = item.url;
    if (url != null && url.isNotEmpty) return url;
    return null;
  }

  Widget? _imageWidget(ProjectItem item, {BoxFit fit = BoxFit.cover}) {
    final localPath = item.path;
    final localExists =
        localPath != null && File(localPath).existsSync();
    if (localExists) {
      return Image.file(File(localPath!), fit: fit);
    }
    if (item.url != null) {
      return Image.network(item.url!, fit: fit);
    }
    return null;
  }

  Future<Uint8List> _loadItemBytes(ProjectItem item) async {
    final localPath = item.path;
    if (localPath != null && File(localPath).existsSync()) {
      return File(localPath).readAsBytes();
    }
    final url = item.url;
    if (url == null || url.isEmpty) {
      throw StateError('Missing image source');
    }
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw StateError('Image download failed');
    }
    return res.bodyBytes;
  }

  Future<double?> _loadItemAspectRatio(ProjectItem item) async {
    try {
      final bytes = await _loadItemBytes(item);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (image.height == 0) return null;
      return image.width / image.height;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openBeforeAfter(
    BuildContext context,
    ProjectItem beforeItem,
    ProjectItem afterItem,
  ) async {
    final before = _imageWidget(beforeItem, fit: BoxFit.contain);
    final after = _imageWidget(afterItem, fit: BoxFit.contain);
    if (before == null || after == null) return;
    double? aspectRatio;
    aspectRatio = await _loadItemAspectRatio(beforeItem);
    aspectRatio ??= await _loadItemAspectRatio(afterItem);
    if (!mounted) return;
    await showBeforeAfterDialog(
      context: context,
      before: before,
      after: after,
      aspectRatio: aspectRatio,
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
    try {
      await context.read<ProjectsModel>().addColorSwatch(
            projectId: project.id,
            hex: selectedHex,
          );
    } catch (_) {
      ThermoloxOverlay.showSnack(
        context,
        'Bitte anmelden, um Farben zu speichern.',
      );
    }
  }

  Future<void> _addNoteLine(
    BuildContext context,
    Project project,
    String note,
  ) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return;
    try {
      await context.read<ProjectsModel>().addItem(
            projectId: project.id,
            name: trimmed,
            type: 'note',
          );
    } catch (_) {
      ThermoloxOverlay.showSnack(
        context,
        'Bitte anmelden, um Notizen zu speichern.',
      );
    }
  }

  Future<void> _renameNoteLine(
    BuildContext context,
    ProjectItem note,
    String newName,
  ) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == note.name.trim()) return;
    try {
      await context.read<ProjectsModel>().renameItem(note.id, trimmed);
    } catch (_) {
      ThermoloxOverlay.showSnack(
        context,
        'Bitte anmelden, um Notizen zu speichern.',
      );
    }
  }

  Future<void> _deleteNoteLine(
    BuildContext context,
    ProjectItem note,
  ) async {
    try {
      await context.read<ProjectsModel>().deleteItem(note.id);
    } catch (_) {
      ThermoloxOverlay.showSnack(
        context,
        'Bitte anmelden, um Notizen zu löschen.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.thermoloxTokens;
    return Consumer<ProjectsModel>(
      builder: (context, model, _) {
        final project =
            model.projects.firstWhere((p) => p.id == widget.projectId);
        final items = project.items;
        final renderItems =
            items.where((item) => item.type == 'render').toList();
        ProjectItem? _findByType(String type) {
          for (var i = items.length - 1; i >= 0; i--) {
            final item = items[i];
            if (item.type == type) return item;
          }
          return null;
        }

        final imageItem = _findByType('image');
        final hasSelectedRender = _selectedRenderId != null &&
            renderItems.any((item) => item.id == _selectedRenderId);
        final selectedRender = renderItems.isEmpty
            ? null
            : (hasSelectedRender
                ? renderItems.firstWhere(
                    (item) => item.id == _selectedRenderId,
                  )
                : renderItems.last);
        final selectedRenderId = selectedRender?.id;
        if (!hasSelectedRender && selectedRenderId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_selectedRenderId != selectedRenderId) {
              setState(() => _selectedRenderId = selectedRenderId);
            }
          });
        }
        final renderItem = selectedRender;
        final fileItem = _findByType('file');
        final mediaItem = imageItem ?? fileItem;
        final colorItem = _findByType('color');
        final noteItems = items
            .where((item) => item.type == 'note' && item.name.trim().isNotEmpty)
            .toList()
            .reversed
            .toList();
        return ThermoloxScaffold(
          appBar: AppBar(
            title: Text(
              (project.title != null && project.title!.trim().isNotEmpty)
                  ? project.title!
                  : project.name,
            ),
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
                'Dein Projekt',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: tokens.gapSm),
              _ProjectCard(
                child: _ProjectImageCard(
                  item: mediaItem,
                  renderItem: renderItem,
                  onTap: mediaItem == null || mediaItem.type != 'image'
                      ? null
                      : () => _openPreview(context, mediaItem),
                  onOpenFullScreen: imageItem == null
                      ? null
                      : () {
                          if (renderItem != null) {
                            _openBeforeAfter(
                              context,
                              imageItem,
                              renderItem,
                            );
                          } else {
                            _openPreview(context, imageItem);
                          }
                        },
                  onOpenBeforeAfter: imageItem != null && renderItem != null
                      ? () => _openBeforeAfter(
                            context,
                            imageItem,
                            renderItem,
                          )
                      : null,
                  onPick: () => _addUpload(context, project),
                ),
              ),
              SizedBox(height: tokens.gapLg),
              _VirtualRoomSection(
                project: project,
                imageItem: imageItem,
                colorItem: colorItem,
                renderItems: renderItems,
                selectedRenderId: selectedRenderId,
                onRenderSelected: (renderId) {
                  if (_selectedRenderId == renderId) return;
                  setState(() => _selectedRenderId = renderId);
                },
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
              SizedBox(height: tokens.gapLg),
              Text(
                'Notizen',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: tokens.gapSm),
              _ProjectNotesCard(
                notes: noteItems,
                onAddNote: (note) => _addNoteLine(context, project, note),
                onDeleteNote: (note) => _deleteNoteLine(context, note),
                onRenameNote: (note, name) =>
                    _renameNoteLine(context, note, name),
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
  final ProjectItem? renderItem;
  final VoidCallback? onTap;
  final VoidCallback? onOpenFullScreen;
  final VoidCallback? onOpenBeforeAfter;
  final VoidCallback onPick;

  const _ProjectImageCard({
    required this.item,
    this.renderItem,
    this.onTap,
    this.onOpenFullScreen,
    this.onOpenBeforeAfter,
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
    final renderPath = renderItem?.path;
    final renderLocalExists =
        renderPath != null && File(renderPath).existsSync();
    final renderUrl = renderItem?.url;
    final hasRender = hasImage &&
        renderItem != null &&
        (renderLocalExists || renderUrl != null);
    final isFile = item != null && item!.type == 'file';
    final beforeWidget = hasImage
        ? (localExists
            ? Image.file(File(localPath!), fit: BoxFit.cover)
            : Image.network(remoteUrl!, fit: BoxFit.cover))
        : null;
    final afterWidget = hasRender
        ? (renderLocalExists
            ? Image.file(File(renderPath!), fit: BoxFit.cover)
            : Image.network(renderUrl!, fit: BoxFit.cover))
        : null;
    final tapHandler = hasRender && onOpenBeforeAfter != null
        ? onOpenBeforeAfter
        : (hasImage ? onTap : null);
    return InkWell(
      onTap: tapHandler,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: theme.colorScheme.surface,
              child: hasRender && beforeWidget != null && afterWidget != null
                  ? BeforeAfterSlider(
                      before: beforeWidget!,
                      after: afterWidget!,
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                    )
                  : hasImage
                      ? beforeWidget!
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
          if (hasImage && onOpenFullScreen != null)
            Positioned(
              top: 8,
              left: 8,
              child: _ActionPill(
                icon: Icons.fullscreen,
                onTap: onOpenFullScreen,
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: _ActionPill(
              icon: Icons.photo_camera_outlined,
              label: 'Bild ändern',
              onTap: onPick,
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

class _ProjectNotesCard extends StatefulWidget {
  final List<ProjectItem> notes;
  final Future<void> Function(String note) onAddNote;
  final Future<void> Function(ProjectItem note) onDeleteNote;
  final Future<void> Function(ProjectItem note, String name) onRenameNote;

  const _ProjectNotesCard({
    required this.notes,
    required this.onAddNote,
    required this.onDeleteNote,
    required this.onRenameNote,
  });

  @override
  State<_ProjectNotesCard> createState() => _ProjectNotesCardState();
}

class _ProjectNotesCardState extends State<_ProjectNotesCard> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Set<String> _busyIds = {};
  final TextEditingController _draftController = TextEditingController();
  final FocusNode _draftFocus = FocusNode();
  bool _showDraft = false;
  bool _draftSubmitting = false;

  @override
  void initState() {
    super.initState();
    _syncControllers();
    _draftFocus.addListener(_handleDraftFocusChange);
  }

  @override
  void didUpdateWidget(covariant _ProjectNotesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    final noteIds = widget.notes.map((note) => note.id).toSet();
    for (final id in _controllers.keys.toList()) {
      if (!noteIds.contains(id)) {
        _controllers[id]?.dispose();
        _controllers.remove(id);
        _focusNodes[id]?.dispose();
        _focusNodes.remove(id);
        _busyIds.remove(id);
      }
    }
    for (final note in widget.notes) {
      _controllers.putIfAbsent(
        note.id,
        () => TextEditingController(text: note.name),
      );
      _focusNodes.putIfAbsent(
        note.id,
        () {
          final node = FocusNode();
          node.addListener(() => _handleNoteFocusChange(note.id));
          return node;
        },
      );
      final controller = _controllers[note.id]!;
      final focusNode = _focusNodes[note.id]!;
      if (!focusNode.hasFocus && controller.text != note.name) {
        controller.text = note.name;
      }
    }
  }

  ProjectItem? _findNote(String id) {
    for (final note in widget.notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  void _handleNoteFocusChange(String noteId) {
    final node = _focusNodes[noteId];
    if (node == null || node.hasFocus) return;
    final note = _findNote(noteId);
    if (note == null) return;
    _commitNote(note);
  }

  Future<void> _commitNote(ProjectItem note) async {
    if (_busyIds.contains(note.id)) return;
    final controller = _controllers[note.id];
    if (controller == null) return;
    final text = controller.text.trim();
    if (text.isEmpty) {
      await _deleteNote(note);
      return;
    }
    if (text == note.name.trim()) return;
    setState(() => _busyIds.add(note.id));
    await widget.onRenameNote(note, text);
    if (!mounted) return;
    setState(() => _busyIds.remove(note.id));
  }

  Future<void> _deleteNote(ProjectItem note) async {
    if (_busyIds.contains(note.id)) return;
    setState(() => _busyIds.add(note.id));
    await widget.onDeleteNote(note);
    if (!mounted) return;
    setState(() => _busyIds.remove(note.id));
  }

  void _handleDraftFocusChange() {
    if (_draftFocus.hasFocus || _draftSubmitting) return;
    _submitDraft();
  }

  Future<void> _submitDraft({bool keepOpen = false}) async {
    if (_draftSubmitting) return;
    _draftSubmitting = true;
    final text = _draftController.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        setState(() => _showDraft = false);
      }
      _draftController.clear();
      _draftSubmitting = false;
      return;
    }
    await widget.onAddNote(text);
    if (!mounted) {
      _draftSubmitting = false;
      return;
    }
    _draftController.clear();
    if (keepOpen) {
      setState(() => _showDraft = true);
      FocusScope.of(context).requestFocus(_draftFocus);
    } else {
      setState(() => _showDraft = false);
    }
    _draftSubmitting = false;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _draftController.dispose();
    _draftFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    return Container(
      padding: EdgeInsets.all(tokens.gapMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.notes.isEmpty && !_showDraft)
            Text(
              'Noch keine Notizen',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            )
          else
            ...widget.notes.map(
              (note) => Padding(
                padding: EdgeInsets.only(bottom: tokens.gapSm),
                child: TextField(
                  controller: _controllers[note.id],
                  focusNode: _focusNodes[note.id],
                  textInputAction: TextInputAction.done,
                  maxLines: 1,
                  onSubmitted: (_) => _commitNote(note),
                  decoration: InputDecoration(
                    prefixText: '- ',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: tokens.gapSm,
                      vertical: tokens.gapSm,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _busyIds.contains(note.id)
                          ? null
                          : () => _deleteNote(note),
                    ),
                  ),
                ),
              ),
            ),
          if (_showDraft) ...[
            SizedBox(height: tokens.gapSm),
            TextField(
              controller: _draftController,
              focusNode: _draftFocus,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              onSubmitted: (_) => _submitDraft(keepOpen: true),
              decoration: InputDecoration(
                prefixText: '- ',
                hintText: 'Stichpunkt hinzufügen',
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: tokens.gapSm,
                  vertical: tokens.gapSm,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _draftSubmitting
                      ? null
                      : () {
                          _draftController.clear();
                          setState(() => _showDraft = false);
                        },
                ),
              ),
            ),
          ] else ...[
            SizedBox(height: tokens.gapSm),
            TextButton.icon(
              onPressed: () {
                setState(() => _showDraft = true);
                FocusScope.of(context).requestFocus(_draftFocus);
              },
              icon: const Icon(Icons.add),
              label: const Text('Stichpunkt hinzufügen'),
            ),
          ],
        ],
      ),
    );
  }
}

class _VirtualRoomSection extends StatefulWidget {
  final Project project;
  final ProjectItem? imageItem;
  final ProjectItem? colorItem;
  final List<ProjectItem> renderItems;
  final String? selectedRenderId;
  final ValueChanged<String>? onRenderSelected;
  final Future<void> Function()? onOpenProPaywall;
  final Future<void> Function()? onOpenCreditsPaywall;

  const _VirtualRoomSection({
    required this.project,
    required this.imageItem,
    required this.colorItem,
    required this.renderItems,
    this.selectedRenderId,
    this.onRenderSelected,
    this.onOpenProPaywall,
    this.onOpenCreditsPaywall,
  });

  @override
  State<_VirtualRoomSection> createState() => _VirtualRoomSectionState();
}

class _VirtualRoomSectionState extends State<_VirtualRoomSection> {
  late final VirtualRoomCreditManager _creditManager;
  final ImageEditService _imageEditService = const ImageEditService();
  bool _isBusy = false;
  bool _creditsConsumed = false;
  PageController? _renderController;
  int _currentIndex = 0;
  Uint8List? _pendingImageBytes;
  Uint8List? _pendingMaskBytes;
  ui.Size? _pendingImageSize;
  String? _pendingPrompt;
  String? _pendingImageUrl;

  @override
  void initState() {
    super.initState();
    _creditManager = VirtualRoomCreditManager(
      consume: ({required int amount, required String requestId}) {
        return context.read<CreditService>().consumeCredit(
              amount: amount,
              requestId: requestId,
        );
      },
    );
    _currentIndex = _resolveSelectedIndex();
    _renderController = PageController(initialPage: _currentIndex);
  }

  int _resolveSelectedIndex() {
    if (widget.renderItems.isEmpty) return 0;
    if (widget.selectedRenderId == null) {
      return widget.renderItems.length - 1;
    }
    final idx = widget.renderItems.indexWhere(
      (item) => item.id == widget.selectedRenderId,
    );
    return idx == -1 ? widget.renderItems.length - 1 : idx;
  }

  @override
  void didUpdateWidget(covariant _VirtualRoomSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _resolveSelectedIndex();
    if (widget.renderItems.isEmpty) {
      _currentIndex = 0;
      return;
    }
    if (nextIndex != _currentIndex) {
      _currentIndex = nextIndex;
      if (_renderController?.hasClients ?? false) {
        _renderController?.jumpToPage(nextIndex);
      } else {
        _renderController = PageController(initialPage: nextIndex);
      }
    }
  }

  @override
  void dispose() {
    _renderController?.dispose();
    super.dispose();
  }

  void _resetPending() {
    _creditsConsumed = false;
    _pendingImageBytes = null;
    _pendingMaskBytes = null;
    _pendingImageSize = null;
    _pendingPrompt = null;
    _pendingImageUrl = null;
  }

  Future<Uint8List> _loadImageBytes(ProjectItem item) async {
    final localPath = item.path;
    if (localPath != null && File(localPath).existsSync()) {
      return File(localPath).readAsBytes();
    }
    final url = item.url;
    if (url == null || url.isEmpty) {
      throw StateError('Missing image source');
    }
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw StateError('Image download failed');
    }
    return res.bodyBytes;
  }

  Widget? _renderImage(ProjectItem item) {
    final localPath = item.path;
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(File(localPath), fit: BoxFit.cover);
    }
    final url = item.url;
    if (url != null && url.isNotEmpty) {
      return Image.network(url, fit: BoxFit.cover);
    }
    return null;
  }

  String? _resolvePreviewPath(ProjectItem item) {
    final localPath = item.path;
    if (localPath != null && File(localPath).existsSync()) {
      return localPath;
    }
    final url = item.url;
    if (url != null && url.isNotEmpty) return url;
    return null;
  }

  Future<Uint8List> _ensurePng(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data?.buffer.asUint8List() ?? bytes;
    } catch (_) {
      return bytes;
    }
  }

  Future<ui.Size> _readImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return ui.Size(image.width.toDouble(), image.height.toDouble());
  }

  Future<Uint8List> _resizeToMatch(Uint8List bytes, ui.Size target) async {
    try {
      if (target.width <= 0 || target.height <= 0) return bytes;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = Paint();
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final dst = Rect.fromLTWH(0, 0, target.width, target.height);
      canvas.drawImageRect(image, src, dst, paint);
      final picture = recorder.endRecording();
      final outImage = await picture.toImage(
        target.width.round(),
        target.height.round(),
      );
      final data = await outImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data?.buffer.asUint8List() ?? bytes;
    } catch (_) {
      return bytes;
    }
  }

  Future<String> _writeTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final file = File('${dir.path}/render_$stamp.png');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _buildPrompt(String hex) {
    return 'Edit only the masked wall. Paint it with color $hex. '
        'Preserve texture, lighting, and perspective. '
        'Do not change other areas.';
  }

  Future<void> _startRender({bool isRetry = false}) async {
    if (!context.read<ConsentService>().aiAllowed) {
      ThermoloxOverlay.showSnack(
        context,
        'Bitte Einwilligung für KI-Funktionen aktivieren '
        '(Einstellungen > Rechtliches > Datenschutz).',
        isError: true,
      );
      return;
    }
    final planController = context.read<PlanController>();
    final hasPro = planController.isPro;
    final credits = planController.virtualRoomCredits;

    if (!hasPro) {
      await _showProPaywall();
      return;
    }
    if (credits <= 0 && !_creditsConsumed) {
      await _showCreditsPaywall();
      return;
    }
    if (_isBusy || _creditManager.isBusy) return;

    setState(() => _isBusy = true);
    try {
      if (!isRetry) {
        _resetPending();
        final imageItem = widget.imageItem;
        final colorItem = widget.colorItem;
        if (imageItem == null || imageItem.type != 'image') {
          ThermoloxOverlay.showSnack(
            context,
            'Bitte zuerst ein Foto hinzufügen.',
            isError: true,
          );
          return;
        }
        final colorHex = colorItem?.url ?? colorItem?.name;
        if (colorHex == null || colorHex.trim().isEmpty) {
          ThermoloxOverlay.showSnack(
            context,
            'Bitte zuerst eine Farbe auswählen.',
            isError: true,
          );
          return;
        }

        final imageBytes = await _loadImageBytes(imageItem);
        try {
          _pendingImageSize = await _readImageSize(imageBytes);
        } catch (_) {
          _pendingImageSize = null;
        }
        final maskBytes = await MaskEditorPage.open(
          context: context,
          imageBytes: imageBytes,
        );
        if (maskBytes == null) return;

        _pendingImageBytes = imageBytes;
        _pendingMaskBytes = maskBytes;
        _pendingImageUrl = imageItem.url;
        _pendingPrompt = _buildPrompt(normalizeHex(colorHex));
      }

      if (_pendingMaskBytes == null || _pendingPrompt == null) {
        return;
      }

      if (!planController.isGodMode && !_creditsConsumed) {
        final result = await _creditManager.consume(isRetry: isRetry);
        if (result.message == 'busy') {
          return;
        }
        if (result.isOk) {
          _creditsConsumed = true;
          planController.updateCreditsBalance(result.balance);
        } else if (result.isNotEnoughCredits) {
          _resetPending();
          await _showCreditsPaywall();
          return;
        } else if (result.isProRequired) {
          _resetPending();
          await _showProPaywall();
          return;
        } else {
          _showRetrySnack();
          return;
        }
      } else if (planController.isGodMode) {
        _creditsConsumed = true;
      }

      final imageBytes = _pendingImageBytes;
      if (imageBytes == null) {
        _showRetrySnack();
        return;
      }

      final editedBytes = await _imageEditService.editImage(
        imageUrl: null,
        imageBytes: await _ensurePng(imageBytes),
        maskPng: _pendingMaskBytes!,
        prompt: _pendingPrompt!,
      );

      var outputBytes = editedBytes;
      if (_pendingImageSize != null) {
        outputBytes = await _resizeToMatch(editedBytes, _pendingImageSize!);
      }
      final path = await _writeTempFile(outputBytes);
      await context.read<ProjectsModel>().addRender(
            projectId: widget.project.id,
            name: 'Render',
            path: path,
          );

      _resetPending();
      ThermoloxOverlay.showSnack(
        context,
        'Render gespeichert.',
      );
    } catch (_) {
      _showRetrySnack();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showRetrySnack() {
    ThermoloxOverlay.showSnack(
      context,
      'Fehler beim Starten. Bitte erneut versuchen.',
      isError: true,
      action: SnackBarAction(
        label: 'Erneut versuchen',
        onPressed: () => _startRender(isRetry: true),
      ),
    );
  }

  Future<void> openProPaywall() async {
    if (widget.onOpenProPaywall != null) {
      await widget.onOpenProPaywall!();
      return;
    }
    ThermoloxOverlay.showSnack(
      context,
      'Pro Lifetime ist noch nicht verfügbar.',
    );
  }

  Future<void> openCreditsPaywall() async {
    if (widget.onOpenCreditsPaywall != null) {
      await widget.onOpenCreditsPaywall!();
      return;
    }
    ThermoloxOverlay.showSnack(
      context,
      'Nachkauf ist noch nicht verfügbar.',
    );
  }

  Future<void> _showProPaywall() async {
    final shouldOpen = await ThermoloxOverlay.showAppDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Pro erforderlich'),
          content:
              const Text('Dieses Feature ist nur mit Pro Lifetime verfügbar.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pro Lifetime freischalten'),
            ),
          ],
        );
      },
    );

    if (shouldOpen != true) return;

    final planController = context.read<PlanController>();
    if (!planController.isLoggedIn) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AuthPage(initialTabIndex: 1),
        ),
      );
      await planController.load(force: true);
      if (!planController.isLoggedIn) return;
    }

    await openProPaywall();
  }

  Future<void> _showCreditsPaywall() async {
    final shouldOpen = await ThermoloxOverlay.showAppDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Visualisierungen aufgebraucht'),
          content: const Text('Pro aktiv / 0 Visualisierungen verfügbar'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Später'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('10 Visualisierungen kaufen'),
            ),
          ],
        );
      },
    );

    if (shouldOpen == true) {
      await openCreditsPaywall();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final planController = context.watch<PlanController>();
    final hasPro = planController.isPro;
    final credits = planController.virtualRoomCredits;
    final hasRenders = widget.renderItems.isNotEmpty;
    final safeIndex = hasRenders
        ? _currentIndex.clamp(0, widget.renderItems.length - 1)
        : 0;
    final currentRender =
        hasRenders ? widget.renderItems[safeIndex] : null;
    final currentPreviewPath =
        currentRender == null ? null : _resolvePreviewPath(currentRender);
    final actionLabel = !hasPro
        ? 'Pro freischalten'
        : credits <= 0
            ? 'Visualisierungen kaufen'
            : 'Raum gestalten';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Virtuelle Raumgestaltung',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tokens.gapSm),
        _ProjectCard(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: theme.colorScheme.surface,
                  child: hasRenders
                      ? PageView.builder(
                          controller: _renderController,
                          itemCount: widget.renderItems.length,
                          onPageChanged: (index) {
                            _currentIndex = index;
                            final item = widget.renderItems[index];
                            widget.onRenderSelected?.call(item.id);
                          },
                          itemBuilder: (context, index) {
                            final image = _renderImage(
                              widget.renderItems[index],
                            );
                            if (image != null) return image;
                            return Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                                size: 36,
                              ),
                            );
                          },
                        )
                      : Center(
                          child: _isBusy
                              ? const CircularProgressIndicator()
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 34,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Bereit zum Rendern',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                    if (hasPro) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Visualisierungen: $credits',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                ),
              ),
              if (currentPreviewPath != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _ActionPill(
                    icon: Icons.fullscreen,
                    onTap: () => openImagePreview(
                      context,
                      pathOrUrl: currentPreviewPath,
                      title: 'Bild',
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: _ActionPill(
                  icon: Icons.auto_awesome,
                  label: actionLabel,
                  onTap: _isBusy ? null : () => _startRender(),
                ),
              ),
              if (_isBusy && hasRenders)
                Positioned.fill(
                  child: Container(
                    color: theme.colorScheme.surface.withOpacity(0.65),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.icon,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final hasLabel = label != null && label!.trim().isNotEmpty;
    final padding = hasLabel
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.all(8);

    return Material(
      color: theme.colorScheme.surface.withOpacity(0.92),
      borderRadius: BorderRadius.circular(999),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: theme.colorScheme.onSurface,
              ),
              if (hasLabel) ...[
                SizedBox(width: tokens.gapXs),
                Text(
                  label!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
