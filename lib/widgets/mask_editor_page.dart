import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/thermolox_overlay.dart';

class MaskEditorPage extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;

  const MaskEditorPage({
    super.key,
    required this.imageBytes,
    this.title = 'Maske erstellen',
  });

  static Future<Uint8List?> open({
    required BuildContext context,
    required Uint8List imageBytes,
    String title = 'Maske erstellen',
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => MaskEditorPage(
          imageBytes: imageBytes,
          title: title,
        ),
      ),
    );
  }

  @override
  State<MaskEditorPage> createState() => _MaskEditorPageState();
}

class _MaskEditorPageState extends State<MaskEditorPage> {
  final List<_MaskStroke> _strokes = [];
  final List<Offset> _currentPoints = [];
  double _currentWidthFactor = 0.0;

  ui.Image? _image;
  Size _canvasSize = Size.zero;
  double _brushSize = 26;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _image = frame.image;
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MaskEditor decode failed: $e');
      }
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _startStroke(Offset local) {
    if (_canvasSize == Size.zero) return;
    final point = _normalize(local, _canvasSize);
    _currentWidthFactor = _brushSize / _minSide(_canvasSize);
    _currentPoints
      ..clear()
      ..add(point);
  }

  void _updateStroke(Offset local) {
    if (_canvasSize == Size.zero) return;
    final point = _normalize(local, _canvasSize);
    _currentPoints.add(point);
    setState(() {});
  }

  void _endStroke() {
    if (_currentPoints.length < 2 || _canvasSize == Size.zero) {
      _currentPoints.clear();
      return;
    }
    final stroke = _MaskStroke(
      points: List<Offset>.from(_currentPoints),
      widthFactor: _brushSize / _minSide(_canvasSize),
    );
    _strokes.add(stroke);
    _currentPoints.clear();
    setState(() {});
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.clear());
  }

  Future<void> _finish() async {
    if (_image == null || _strokes.isEmpty) {
      ThermoloxOverlay.showSnack(
        context,
        'Bitte maskiere mindestens eine Fläche.',
        isError: true,
      );
      return;
    }
    final bytes = await _exportMask();
    if (!mounted) return;
    if (bytes == null) {
      ThermoloxOverlay.showSnack(
        context,
        'Maske konnte nicht erstellt werden.',
        isError: true,
      );
      return;
    }
    Navigator.of(context).pop(bytes);
  }

  Future<Uint8List?> _exportMask() async {
    final image = _image;
    if (image == null) return null;
    final width = image.width.toDouble();
    final height = image.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), backgroundPaint);

    for (final stroke in _strokes) {
      final paint = Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.widthFactor * _minSide(Size(width, height));
      _drawStroke(canvas, stroke, Size(width, height), paint);
    }

    final picture = recorder.endRecording();
    final imageResult = await picture.toImage(width.toInt(), height.toInt());
    final data = await imageResult.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.thermoloxTokens;
    final theme = Theme.of(context);
    final image = _image;
    final aspect = image == null ? 4 / 3 : image.width / image.height;

    return ThermoloxScaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Schließen',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      centerBody: false,
      padding: EdgeInsets.fromLTRB(
        tokens.screenPadding,
        tokens.gapSm,
        tokens.screenPadding,
        tokens.gapLg,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Male die Wand, die du einfärben möchtest.',
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: tokens.gapSm),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: AspectRatio(
                      aspectRatio: aspect,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _canvasSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          return GestureDetector(
                            onPanStart: (details) =>
                                _startStroke(details.localPosition),
                            onPanUpdate: (details) =>
                                _updateStroke(details.localPosition),
                            onPanEnd: (_) => _endStroke(),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(tokens.radiusMd),
                                    child: Image.memory(
                                      widget.imageBytes,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _MaskPainter(
                                        strokes: _strokes,
                                        currentPoints: _currentPoints,
                                        currentWidthFactor: _currentWidthFactor,
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.45),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
          SizedBox(height: tokens.gapSm),
          Row(
            children: [
              Icon(
                Icons.brush,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              Expanded(
                child: Slider(
                  value: _brushSize,
                  min: 8,
                  max: 48,
                  onChanged: (value) => setState(() => _brushSize = value),
                ),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _strokes.isEmpty ? null : _undo,
                            icon: const Icon(Icons.undo),
                            label: const Text('Undo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _strokes.isEmpty ? null : _clear,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Alles löschen'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.gapSm),
                    FilledButton(
                      onPressed: _loading ? null : _finish,
                      child: const Text('Maske anwenden'),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _strokes.isEmpty ? null : _undo,
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _strokes.isEmpty ? null : _clear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Alles löschen'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _loading ? null : _finish,
                    child: const Text('Maske anwenden'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Offset _normalize(Offset point, Size size) {
    final dx = (point.dx / size.width).clamp(0.0, 1.0);
    final dy = (point.dy / size.height).clamp(0.0, 1.0);
    return Offset(dx, dy);
  }

  double _minSide(Size size) => math.min(size.width, size.height);

  void _drawStroke(
    Canvas canvas,
    _MaskStroke stroke,
    Size size,
    Paint paint,
  ) {
    final points = stroke.points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      final p = _denormalize(points.first, size);
      canvas.drawCircle(p, paint.strokeWidth / 2, paint);
      return;
    }
    final path = Path();
    final first = _denormalize(points.first, size);
    path.moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final p = _denormalize(point, size);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  Offset _denormalize(Offset point, Size size) {
    return Offset(point.dx * size.width, point.dy * size.height);
  }
}

class _MaskStroke {
  final List<Offset> points;
  final double widthFactor;

  _MaskStroke({
    required this.points,
    required this.widthFactor,
  });
}

class _MaskPainter extends CustomPainter {
  final List<_MaskStroke> strokes;
  final List<Offset> currentPoints;
  final double currentWidthFactor;
  final Color color;

  _MaskPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentWidthFactor,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      paint.strokeWidth = stroke.widthFactor *
          math.min(size.width, size.height);
      _paintStroke(canvas, stroke.points, size, paint);
    }

    if (currentPoints.isNotEmpty) {
      paint.strokeWidth = currentWidthFactor *
          math.min(size.width, size.height);
      _paintStroke(canvas, currentPoints, size, paint);
    }
  }

  void _paintStroke(
    Canvas canvas,
    List<Offset> points,
    Size size,
    Paint paint,
  ) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      final p = _denormalize(points.first, size);
      canvas.drawCircle(p, paint.strokeWidth / 2, paint);
      return;
    }
    final path = Path();
    final first = _denormalize(points.first, size);
    path.moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final p = _denormalize(point, size);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  Offset _denormalize(Offset point, Size size) {
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  @override
  bool shouldRepaint(covariant _MaskPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentPoints != currentPoints ||
        oldDelegate.currentWidthFactor != currentWidthFactor ||
        oldDelegate.color != color;
  }
}
