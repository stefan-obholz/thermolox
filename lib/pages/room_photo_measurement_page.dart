import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/project_measurement.dart';
import '../services/supabase_service.dart';
import '../widgets/attachment_sheet.dart';

class RoomPhotoMeasurementPage extends StatefulWidget {
  final String projectId;
  final ProjectMeasurement? initialMeasurement;
  final List<String> initialImagePaths;

  const RoomPhotoMeasurementPage({
    super.key,
    required this.projectId,
    this.initialMeasurement,
    this.initialImagePaths = const [],
  });

  @override
  State<RoomPhotoMeasurementPage> createState() =>
      _RoomPhotoMeasurementPageState();
}

class _PhotoWallMeasurement {
  final String path;
  double meterLengthM;
  List<Offset> meterPoints;
  List<Offset> wallPoints;

  _PhotoWallMeasurement({
    required this.path,
    this.meterLengthM = 1.0,
    this.meterPoints = const [],
    this.wallPoints = const [],
  });

  bool get meterReady => meterPoints.length == 2 && meterLengthM > 0;
  bool get wallReady => wallPoints.length == 4;

  double? _meterPixelLength(Size size) {
    if (!meterReady) return null;
    final a = Offset(meterPoints[0].dx * size.width,
        meterPoints[0].dy * size.height);
    final b = Offset(meterPoints[1].dx * size.width,
        meterPoints[1].dy * size.height);
    return (a - b).distance;
  }

  double? wallWidthM(Size size) {
    if (!meterReady || !wallReady) return null;
    final meterPx = _meterPixelLength(size);
    if (meterPx == null || meterPx == 0) return null;
    final topLeft = Offset(wallPoints[0].dx * size.width,
        wallPoints[0].dy * size.height);
    final topRight = Offset(wallPoints[1].dx * size.width,
        wallPoints[1].dy * size.height);
    final widthPx = (topLeft - topRight).distance;
    return widthPx * (meterLengthM / meterPx);
  }

  double? wallHeightM(Size size) {
    if (!meterReady || !wallReady) return null;
    final meterPx = _meterPixelLength(size);
    if (meterPx == null || meterPx == 0) return null;
    final topLeft = Offset(wallPoints[0].dx * size.width,
        wallPoints[0].dy * size.height);
    final bottomLeft = Offset(wallPoints[3].dx * size.width,
        wallPoints[3].dy * size.height);
    final heightPx = (topLeft - bottomLeft).distance;
    return heightPx * (meterLengthM / meterPx);
  }
}

class _RoomPhotoMeasurementPageState extends State<RoomPhotoMeasurementPage> {
  final List<_PhotoWallMeasurement> _photos = [];
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    for (final path in widget.initialImagePaths) {
      _photos.add(_PhotoWallMeasurement(path: path));
    }
  }

  Future<void> _addPhoto() async {
    final pick = await pickEverloxxAttachment(
      context,
      allowFiles: false,
    );
    if (!mounted) return;
    if (pick == null || !pick.isImage) return;
    setState(() {
      _photos.add(_PhotoWallMeasurement(path: pick.path));
    });
  }

  Future<void> _editMeter(_PhotoWallMeasurement item) async {
    final points = await Navigator.of(context).push<List<Offset>>(
      MaterialPageRoute(
        builder: (_) => _PhotoPointEditorPage(
          title: 'Meterstab setzen',
          hint:
              'Tippe die beiden Enden des Meterstabs im Foto an.\nDer Meterstab muss an der Wand liegen.',
          imagePath: item.path,
          maxPoints: 2,
          initialPoints: item.meterPoints,
        ),
      ),
    );
    if (!mounted || points == null) return;
    final meterLength = await _askMeterLength(item.meterLengthM);
    if (!mounted) return;
    if (meterLength == null || meterLength <= 0) return;
    setState(() {
      item.meterPoints = points;
      item.meterLengthM = meterLength;
    });
  }

  Future<void> _editWall(_PhotoWallMeasurement item) async {
    final points = await Navigator.of(context).push<List<Offset>>(
      MaterialPageRoute(
        builder: (_) => _PhotoPointEditorPage(
          title: 'Wand markieren',
          hint:
              'Tippe die vier Ecken der Wand im Uhrzeigersinn an:\noben links → oben rechts → unten rechts → unten links.',
          imagePath: item.path,
          maxPoints: 4,
          initialPoints: item.wallPoints,
        ),
      ),
    );
    if (!mounted || points == null) return;
    setState(() {
      item.wallPoints = points;
    });
  }

  Future<double?> _askMeterLength(double current) async {
    final controller = TextEditingController(
      text: current.toStringAsFixed(2).replaceAll('.', ','),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Meterstab-Länge'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Länge (m)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    return result;
  }

  bool get _readyToCalculate {
    if (_photos.length < 4) return false;
    for (final item in _photos) {
      if (!item.meterReady || !item.wallReady) return false;
    }
    return true;
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _calculate() async {
    if (!_readyToCalculate) return;
    setState(() {
      _calculating = true;
    });

    final widthSamples = <double>[];
    final heightSamples = <double>[];

    for (final item in _photos) {
      final size = await _loadImageSize(item.path);
      final width = item.wallWidthM(size);
      final height = item.wallHeightM(size);
      if (width != null && height != null) {
        widthSamples.add(width);
        heightSamples.add(height);
      }
    }

    if (widthSamples.length < 4 || heightSamples.isEmpty) {
      setState(() {
        _calculating = false;
      });
      _showSnack('Bitte alle Fotos vollständig markieren.');
      return;
    }

    widthSamples.sort();
    final half = math.max(1, widthSamples.length ~/ 2);
    final small = widthSamples.take(half).toList();
    final large = widthSamples.skip(widthSamples.length - half).toList();
    final widthM = _average(small);
    final lengthM = _average(large);
    final heightM = _average(heightSamples);

    final userId = SupabaseService.client.auth.currentUser?.id ?? '';
    final confidence = math.min(0.85, 0.45 + 0.05 * (_photos.length - 4));

    final measurement = ProjectMeasurement(
      id: widget.initialMeasurement?.id ?? '',
      projectId: widget.projectId,
      userId: userId,
      method: 'photo',
      lengthM: lengthM,
      widthM: widthM,
      heightM: heightM,
      openings: widget.initialMeasurement?.openings ?? const [],
      confidence: confidence,
      createdAt: widget.initialMeasurement?.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    if (!mounted) return;
    setState(() {
      _calculating = false;
    });
    Navigator.of(context).pop(measurement);
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Future<Size> _loadImageSize(String path) async {
    final image = FileImage(File(path));
    final completer = Completer<ui.Image>();
    final stream = image.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (!completer.isCompleted) {
        completer.complete(info.image);
      }
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    final uiImage = await completer.future;
    return Size(uiImage.width.toDouble(), uiImage.height.toDouble());
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raum messen (Fotos)'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          children: [
            const Text(
              'Nimm mindestens 4 Fotos (pro Wand eins).\n'
              'Auf jedem Foto muss ein Meterstab an der Wand liegen.\n'
              'Markiere danach den Meterstab und die Wand.',
            ),
            const SizedBox(height: 16),
            Text(
              'Fotos: ${_photos.length} (mindestens 4, gern mehr)',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ..._photos.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final meterStatus = item.meterReady ? 'gesetzt' : 'fehlt';
              final wallStatus = item.wallReady ? 'markiert' : 'fehlt';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Foto ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(item.path),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Meterstab: $meterStatus'),
                      Text('Wand: $wallStatus'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _editMeter(item),
                            child: const Text('Meterstab setzen'),
                          ),
                          OutlinedButton(
                            onPressed: item.meterReady
                                ? () => _editWall(item)
                                : null,
                            child: const Text('Wand markieren'),
                          ),
                          TextButton(
                            onPressed: () => _removePhoto(index),
                            child: const Text('Entfernen'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addPhoto,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Foto hinzufügen'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _readyToCalculate && !_calculating ? _calculate : null,
              child: _calculating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Berechnung starten'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPointEditorPage extends StatefulWidget {
  final String title;
  final String hint;
  final String imagePath;
  final int maxPoints;
  final List<Offset> initialPoints;

  const _PhotoPointEditorPage({
    required this.title,
    required this.hint,
    required this.imagePath,
    required this.maxPoints,
    this.initialPoints = const [],
  });

  @override
  State<_PhotoPointEditorPage> createState() => _PhotoPointEditorPageState();
}

class _PhotoPointEditorPageState extends State<_PhotoPointEditorPage> {
  late final List<Offset> _points;

  @override
  void initState() {
    super.initState();
    _points = List<Offset>.from(widget.initialPoints);
  }

  void _addPoint(Offset local, Size size) {
    if (_points.length >= widget.maxPoints) return;
    final normalized = Offset(
      (local.dx / size.width).clamp(0, 1),
      (local.dy / size.height).clamp(0, 1),
    );
    setState(() {
      _points.add(normalized);
    });
  }

  void _reset() {
    setState(() {
      _points.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _points.length == widget.maxPoints
                ? () => Navigator.of(context).pop(_points)
                : null,
            child: const Text('Fertig'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.hint),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  return GestureDetector(
                    onTapUp: (details) => _addPoint(details.localPosition, size),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PointPainter(
                              points: _points,
                              maxPoints: widget.maxPoints,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Neu setzen'),
                  ),
                  const Spacer(),
                  Text(
                    '${_points.length}/${widget.maxPoints}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointPainter extends CustomPainter {
  final List<Offset> points;
  final int maxPoints;

  _PointPainter({
    required this.points,
    required this.maxPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < points.length; i += 1) {
      final point = Offset(points[i].dx * size.width,
          points[i].dy * size.height);
      canvas.drawCircle(point, 6, Paint()..color = Colors.deepPurple);
      if (i > 0) {
        final prev = Offset(points[i - 1].dx * size.width,
            points[i - 1].dy * size.height);
        canvas.drawLine(prev, point, paint);
      }
    }

    if (points.length == maxPoints && maxPoints > 2) {
      final first = Offset(points.first.dx * size.width,
          points.first.dy * size.height);
      final last = Offset(points.last.dx * size.width,
          points.last.dy * size.height);
      canvas.drawLine(last, first, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PointPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxPoints != maxPoints;
  }
}
