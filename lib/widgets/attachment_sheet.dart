import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../utils/thermolox_overlay.dart';

class AttachmentPick {
  final String path;
  final bool isImage;
  final String? name;

  const AttachmentPick({
    required this.path,
    required this.isImage,
    this.name,
  });
}

Future<AttachmentPick?> pickThermoloxAttachment(BuildContext context) async {
  final result = await ThermoloxOverlay.showGlassDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Anhänge',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    builder: (dialogCtx) {
      final theme = Theme.of(dialogCtx);
      return SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(color: Colors.black.withOpacity(0.25)),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Zeige uns dein Projekt',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 96,
                      child: Image.asset(
                        'assets/logos/THERMOLOX_SYSTEMS_WHITE.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AttachmentActionCircle(
                          icon: Icons.camera_alt_rounded,
                          label: 'Kamera',
                          onTap: () => Navigator.of(dialogCtx).pop('camera'),
                        ),
                        const SizedBox(width: 24),
                        _AttachmentActionCircle(
                          icon: Icons.photo_library_rounded,
                          label: 'Galerie',
                          onTap: () => Navigator.of(dialogCtx).pop('gallery'),
                        ),
                        const SizedBox(width: 24),
                        _AttachmentActionCircle(
                          icon: Icons.insert_drive_file_rounded,
                          label: 'Datei',
                          onTap: () => Navigator.of(dialogCtx).pop('file')),
                      ],
                    ),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: () => Navigator.of(dialogCtx).pop(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.redAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.5),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Abbrechen',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (result == null) return null;

  if (result == 'file') {
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.single;
    final path = file.path;
    if (path == null) return null;
    return AttachmentPick(path: path, isImage: _looksLikeImage(path), name: file.name);
  }

  final picker = ImagePicker();
  XFile? image;
  if (result == 'camera') {
    image = await picker.pickImage(source: ImageSource.camera);
  } else if (result == 'gallery') {
    image = await picker.pickImage(source: ImageSource.gallery);
  }
  if (image == null) return null;
  return AttachmentPick(path: image.path, isImage: true, name: image.name);
}

bool _looksLikeImage(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.webp');
}

class _AttachmentActionCircle extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentActionCircle({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_AttachmentActionCircle> createState() =>
      _AttachmentActionCircleState();
}

class _AttachmentActionCircleState extends State<_AttachmentActionCircle>
    with TickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    final tokens = ThermoloxTokens.light;
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringRotationDuration,
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringPulseDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.04).animate(
            CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.65),
                    blurRadius: 26,
                    spreadRadius: 3,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _rotationCtrl,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: tokens.rainbowRingGradient,
                        boxShadow: [
                          BoxShadow(
                            color: tokens.rainbowRingHaloColor,
                            blurRadius: tokens.rainbowRingHaloBlur,
                            spreadRadius: tokens.rainbowRingHaloSpread,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                  Icon(widget.icon, size: 32, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
