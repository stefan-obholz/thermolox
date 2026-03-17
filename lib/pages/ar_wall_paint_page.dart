import '../theme/app_theme.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/palette_color.dart';
import '../services/ar_wall_paint_service.dart';
import '../services/lidar_service.dart';
import '../services/palette_service.dart';
import '../utils/thermolox_overlay.dart';
import '../widgets/color_palette_sheet.dart';

/// Result returned when leaving the AR wall paint page.
class ARWallPaintResult {
  /// Path to a saved screenshot, or null if none taken.
  final String? screenshotPath;

  /// The hex color that was last applied, if any.
  final String? lastColorHex;

  const ARWallPaintResult({this.screenshotPath, this.lastColorHex});
}

class ARWallPaintPage extends StatefulWidget {
  final String projectId;

  const ARWallPaintPage({super.key, required this.projectId});

  @override
  State<ARWallPaintPage> createState() => _ARWallPaintPageState();
}

class _ARWallPaintPageState extends State<ARWallPaintPage>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('thermolox/ar_wall_paint');

  String? _selectedColorHex;
  final Map<String, String> _wallColors = {};
  String _trackingState = 'initializing';
  int _wallCount = 0;
  bool _showInstruction = true;
  bool _cameraReady = false;
  bool _hasLidar = false;
  List<PaletteColor> _recentColors = [];
  List<PaletteColor> _allColors = [];
  String? _savedScreenshotPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCamera();
    _loadPalette();
    _checkLidar();
    _setupNativeCallbacks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ARWallPaintService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCamera();
    }
  }

  Future<void> _checkCamera() async {
    if (kIsWeb) return;
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (mounted) {
      setState(() => _cameraReady = status.isGranted || status.isLimited);
    }
  }

  Future<void> _checkLidar() async {
    final available = await LidarService.isAvailable();
    if (mounted) setState(() => _hasLidar = available);
  }

  Future<void> _loadPalette() async {
    final colors = await PaletteService.fetchColors();
    if (!mounted) return;
    setState(() {
      _allColors = colors;
      // Show first 8 colors as "recent" initially
      _recentColors = colors.take(8).toList();
    });
  }

  void _setupNativeCallbacks() {
    _channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'onWallTapped':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final anchorId = args['anchorId'] as String;
          _onWallTapped(anchorId);
          break;
        case 'onTrackingStateChanged':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          setState(() => _trackingState = args['state'] as String? ?? 'unknown');
          break;
        case 'onWallsDetected':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          setState(() => _wallCount = args['count'] as int? ?? 0);
          break;
      }
    });
  }

  void _onWallTapped(String anchorId) {
    if (_selectedColorHex == null) {
      ThermoloxOverlay.showSnack(
        context,
        'Wähle zuerst eine Farbe aus.',
      );
      return;
    }

    setState(() {
      _wallColors[anchorId] = _selectedColorHex!;
      _showInstruction = false;
    });

    ARWallPaintService.setWallColor(anchorId, _selectedColorHex!);
  }

  void _selectColor(String hex) {
    setState(() => _selectedColorHex = hex);

    // Move to front of recent colors
    final paletteColor = _allColors
        .where((c) => c.hex.toUpperCase() == hex.toUpperCase())
        .firstOrNull;
    if (paletteColor != null) {
      setState(() {
        _recentColors.removeWhere(
            (c) => c.hex.toUpperCase() == hex.toUpperCase());
        _recentColors.insert(0, paletteColor);
        if (_recentColors.length > 10) {
          _recentColors = _recentColors.sublist(0, 10);
        }
      });
    }
  }

  Future<void> _openPalette() async {
    final hex = await showColorPaletteSheet(
      context,
      initialHex: _selectedColorHex,
    );
    if (hex != null && mounted) {
      _selectColor(hex);
    }
  }

  Future<void> _takeScreenshot() async {
    final bytes = await ARWallPaintService.takeScreenshot();
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ThermoloxOverlay.showSnack(
          context,
          'Screenshot konnte nicht erstellt werden.',
          isError: true,
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/ar_wallpaint_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);

    if (mounted) {
      setState(() => _savedScreenshotPath = file.path);
      ThermoloxOverlay.showSnack(context, 'Screenshot gespeichert');
    }
  }

  Future<void> _clearAll() async {
    await ARWallPaintService.clearAllColors();
    if (mounted) {
      setState(() {
        _wallColors.clear();
      });
    }
  }

  String _trackingLabel() {
    return switch (_trackingState) {
      'normal' => 'Tracking aktiv',
      'initializing' => 'Initialisiere…',
      'excessiveMotion' => 'Zu schnelle Bewegung',
      'insufficientFeatures' => 'Mehr Oberflächen nötig',
      'relocalizing' => 'Relokaliserung…',
      'notAvailable' => 'AR nicht verfügbar',
      _ => 'Suche Wände…',
    };
  }

  IconData _trackingIcon() {
    return switch (_trackingState) {
      'normal' => Icons.check_circle_outline,
      'excessiveMotion' => Icons.speed,
      'insufficientFeatures' => Icons.blur_on,
      'notAvailable' => Icons.error_outline,
      _ => Icons.hourglass_top,
    };
  }

  @override
  Widget build(BuildContext context) {
    // LiDAR required gate
    if (!_hasLidar && _trackingState != 'initializing') {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sensors_off, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'LiDAR-Sensor erforderlich',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Die AR-Wandfarbe benötigt ein iPhone Pro oder iPad Pro mit LiDAR-Sensor. '
                    'Nutze stattdessen die virtuelle Raumgestaltung — die funktioniert auf allen Geräten!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Zurück'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // AR View
          if (_cameraReady && !kIsWeb)
            Positioned.fill(
              child: Platform.isIOS
                  ? UiKitView(
                      viewType: 'thermolox/ar_wall_paint',
                      creationParamsCodec: const StandardMessageCodec(),
                    )
                  : AndroidView(
                      viewType: 'thermolox/ar_wall_paint',
                      creationParamsCodec: const StandardMessageCodec(),
                    ),
            )
          else
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Kamera-Zugriff erforderlich',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Für die AR-Wandfarbe braucht CLIMALOX Zugriff auf deine Kamera. Bitte erlaube den Zugriff in den Einstellungen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => openAppSettings(),
                      icon: const Icon(Icons.settings),
                      label: const Text('Einstellungen öffnen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                8,
                MediaQuery.of(context).padding.top + 8,
                8,
                12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        ARWallPaintResult(
                          screenshotPath: _savedScreenshotPath,
                          lastColorHex: _selectedColorHex,
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  // Tracking status
                  Icon(
                    _trackingIcon(),
                    color: _trackingState == 'normal'
                        ? Colors.greenAccent
                        : Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _trackingLabel(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_hasLidar)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LiDAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Wall count
                  if (_wallCount > 0)
                    Text(
                      '$_wallCount ${_wallCount == 1 ? 'Wand' : 'Wände'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Screenshot button
                  IconButton(
                    onPressed: _takeScreenshot,
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                  ),
                  // Clear all
                  if (_wallColors.isNotEmpty)
                    IconButton(
                      onPressed: _clearAll,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),

          // Instruction overlay
          if (_showInstruction && _cameraReady)
            Positioned(
              left: 40,
              right: 40,
              top: MediaQuery.of(context).size.height * 0.4,
              child: GestureDetector(
                onTap: () => setState(() => _showInstruction = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, color: Colors.white, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Wähle eine Farbe und\ntippe auf eine Wand',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom color bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selected color info
                  if (_selectedColorHex != null) ...[
                    _buildSelectedColorInfo(),
                    const SizedBox(height: 8),
                  ],
                  // Color row
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        // Palette button
                        GestureDetector(
                          onTap: _openPalette,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.palette,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Scrollable color circles
                        Expanded(
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recentColors.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final pc = _recentColors[index];
                              final isSelected = _selectedColorHex != null &&
                                  pc.hex.toUpperCase() ==
                                      _selectedColorHex!.toUpperCase();
                              return _buildColorCircle(pc, isSelected);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedColorInfo() {
    final pc = _allColors
        .where(
            (c) => c.hex.toUpperCase() == _selectedColorHex!.toUpperCase())
        .firstOrNull;
    final name = pc?.name ?? _selectedColorHex!;
    final group = pc?.groupName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _colorFromHex(_selectedColorHex!),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              group != null ? '$name · $group' : name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle(PaletteColor pc, bool isSelected) {
    final color = pc.color;
    return GestureDetector(
      onTap: () => _selectColor(pc.hex),
      child: Tooltip(
        message: pc.name,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 48 : 44,
          height: isSelected ? 48 : 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Color _colorFromHex(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length != 6) return Colors.white;
    final value = int.tryParse(clean, radix: 16) ?? 0xFFFFFF;
    return Color(0xFF000000 | value);
  }
}
