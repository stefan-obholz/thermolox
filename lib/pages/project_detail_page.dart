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
import '../services/credit_service.dart';
import '../services/image_edit_service.dart';
import '../theme/app_theme.dart';
import '../utils/color_utils.dart';
import '../utils/thermolox_overlay.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/color_palette_sheet.dart';
import '../widgets/mask_editor_page.dart';

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

  Future<void> _openBeforeAfter(
    BuildContext context,
    ProjectItem beforeItem,
    ProjectItem afterItem,
  ) async {
    final before = _imageWidget(beforeItem, fit: BoxFit.contain);
    final after = _imageWidget(afterItem, fit: BoxFit.contain);
    if (before == null || after == null) return;
    await showBeforeAfterDialog(
      context: context,
      before: before,
      after: after,
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
        final renderItem = _findByType('render');
        final fileItem = _findByType('file');
        final mediaItem = imageItem ?? fileItem;
        final colorItem = _findByType('color');
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
                'Foto',
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
              _VirtualRoomSection(
                project: project,
                imageItem: imageItem,
                colorItem: colorItem,
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
  final VoidCallback? onOpenBeforeAfter;
  final VoidCallback onPick;

  const _ProjectImageCard({
    required this.item,
    this.renderItem,
    this.onTap,
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

class _VirtualRoomSection extends StatefulWidget {
  final Project project;
  final ProjectItem? imageItem;
  final ProjectItem? colorItem;
  final Future<void> Function()? onOpenProPaywall;
  final Future<void> Function()? onOpenCreditsPaywall;

  const _VirtualRoomSection({
    required this.project,
    required this.imageItem,
    required this.colorItem,
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
  Uint8List? _pendingImageBytes;
  Uint8List? _pendingMaskBytes;
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
  }

  void _resetPending() {
    _creditsConsumed = false;
    _pendingImageBytes = null;
    _pendingMaskBytes = null;
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
            'Bitte zuerst ein Foto hinzufuegen.',
            isError: true,
          );
          return;
        }
        final colorHex = colorItem?.url ?? colorItem?.name;
        if (colorHex == null || colorHex.trim().isEmpty) {
          ThermoloxOverlay.showSnack(
            context,
            'Bitte zuerst eine Farbe auswaehlen.',
            isError: true,
          );
          return;
        }

        final imageBytes = await _loadImageBytes(imageItem);
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

      if (!_creditsConsumed) {
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
      }

      final imageBytes = _pendingImageBytes;
      if (imageBytes == null) {
        _showRetrySnack();
        return;
      }

      final editedBytes = await _imageEditService.editImage(
        imageUrl: _pendingImageUrl,
        imageBytes: _pendingImageUrl == null
            ? await _ensurePng(imageBytes)
            : null,
        maskPng: _pendingMaskBytes!,
        prompt: _pendingPrompt!,
      );

      final path = await _writeTempFile(editedBytes);
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
      'Credits-Shop ist noch nicht verfügbar.',
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
          title: const Text('Credits aufgebraucht'),
          content: const Text('Pro aktiv / Credits 0'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Später'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('10 Credits nachkaufen'),
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
    final actionLabel = !hasPro
        ? 'Pro freischalten'
        : credits <= 0
            ? 'Credits kaufen'
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
                  child: Center(
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
                                  'Credits: $credits',
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
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: theme.colorScheme.surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(999),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _isBusy ? null : () => _startRender(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
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
        ),
      ],
    );
  }
}
