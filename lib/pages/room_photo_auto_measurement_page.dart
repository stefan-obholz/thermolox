import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/feature_guard.dart';

import '../models/project_measurement.dart';
import '../services/photo_measurement_service.dart';
import '../services/supabase_service.dart';
import '../widgets/attachment_sheet.dart';
import 'room_measurement_page.dart';

class RoomPhotoAutoMeasurementPage extends StatefulWidget {
  final String projectId;
  final ProjectMeasurement? initialMeasurement;
  final List<String> initialImagePaths;
  final int minPhotos;

  const RoomPhotoAutoMeasurementPage({
    super.key,
    required this.projectId,
    this.initialMeasurement,
    this.initialImagePaths = const [],
    this.minPhotos = 4,
  });

  @override
  State<RoomPhotoAutoMeasurementPage> createState() =>
      _RoomPhotoAutoMeasurementPageState();
}

class _RoomPhotoAutoMeasurementPageState
    extends State<RoomPhotoAutoMeasurementPage> {
  final List<String> _photos = [];
  final PhotoMeasurementService _service = const PhotoMeasurementService();
  bool _calculating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _photos.addAll(widget.initialImagePaths);
  }

  bool get _readyToCalculate => _photos.length >= widget.minPhotos;

  Future<void> _addPhoto() async {
    final pick = await pickEverloxxAttachment(
      context,
      allowFiles: false,
    );
    if (!mounted || pick == null || !pick.isImage) return;
    setState(() {
      _photos.add(pick.path);
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _calculate() async {
    if (!_readyToCalculate || _calculating) return;
    setState(() {
      _calculating = true;
      _errorMessage = null;
    });

    try {
      final results = await _service
          .estimateFromPhotos(_photos)
          .timeout(const Duration(seconds: 40));
      final valid = results
          .where((r) =>
              (r.wallWidthM ?? 0) > 0 &&
              (r.wallHeightM ?? 0) > 0)
          .toList();

      if (valid.length < 2) {
        const message =
            'Ich konnte die Maße nicht sicher erkennen. '
            'Bitte prüfe, ob der Meterstab auf allen Fotos gut sichtbar ist.';
        setState(() {
          _errorMessage = message;
        });
        _showSnack(message, isError: true);
        return;
      }

      final widths = valid.map((r) => r.wallWidthM!).toList()..sort();
      final heights = valid.map((r) => r.wallHeightM!).toList();
      final half = math.max(1, widths.length ~/ 2);
      final small = widths.take(half).toList();
      final large = widths.skip(widths.length - half).toList();
      final widthM = _average(small);
      final lengthM = _average(large);
      final heightM = _average(heights);
      if (widthM <= 0 || lengthM <= 0 || heightM <= 0) {
        const message =
            'Ich konnte die Maße nicht zuverlässig bestimmen. '
            'Bitte prüfe die Fotos oder gib die Maße manuell ein.';
        setState(() {
          _errorMessage = message;
        });
        _showSnack(message, isError: true);
        return;
      }

      final confidence = _average(
        valid
            .map((r) => r.confidence ?? 0.4)
            .toList(),
      ).clamp(0.2, 0.9);

      final userId = SupabaseService.client.auth.currentUser?.id ?? '';
      final measurement = ProjectMeasurement(
        id: widget.initialMeasurement?.id ?? '',
        projectId: widget.projectId,
        userId: userId,
        method: 'photo_auto',
        lengthM: lengthM,
        widthM: widthM,
        heightM: heightM,
        openings: widget.initialMeasurement?.openings ?? const [],
        confidence: confidence,
        createdAt: widget.initialMeasurement?.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(measurement);
    } on TimeoutException {
      const message =
          'Die Messung hat zu lange gedauert. '
          'Bitte versuche es erneut oder gib die Maße manuell ein.';
      if (mounted) {
        setState(() {
          _errorMessage = message;
        });
        _showSnack(message, isError: true);
      }
    } catch (error) {
      const message =
          'Messung fehlgeschlagen. Bitte versuche es erneut '
          'oder gib die Maße manuell ein.';
      if (mounted) {
        setState(() {
          _errorMessage = message;
        });
        _showSnack(message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _calculating = false;
        });
      }
    }
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : null,
      ),
    );
  }

  Future<void> _openManualMeasurement() async {
    final measurement = await Navigator.of(context).push<ProjectMeasurement>(
      MaterialPageRoute(
        builder: (_) => RoomMeasurementPage(
          projectId: widget.projectId,
          initialMeasurement: widget.initialMeasurement,
        ),
      ),
    );
    if (!mounted || measurement == null) return;
    Navigator.of(context).pop(measurement);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos messen'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
      body: SafeArea(
        child: FeatureGuard(
          message:
              'Die automatische Messung ist gerade nicht verfügbar. Bitte erneut versuchen.',
          builder: () => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                'Für die automatische Messung brauche ich mindestens '
                '${widget.minPhotos} Fotos von den Wänden.',
                style: tokens.textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Wichtig: Auf jedem Foto muss ein Meterstab sichtbar sein '
                'und an der Wand liegen. Mehr Fotos verbessern das Ergebnis.',
                style: tokens.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: tokens.textTheme.bodyMedium?.copyWith(
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Text(
                    '${_photos.length}/${widget.minPhotos} Fotos',
                    style: tokens.textTheme.titleMedium,
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _calculating ? null : _addPhoto,
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: const Text('Foto hinzufügen'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_photos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DEE4).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_camera_back_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Füge deine ersten Fotos hinzu, um zu starten.',
                          style: tokens.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (_, index) {
                    final path = _photos[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.white,
                            onPressed: _calculating
                                ? null
                                : () => _removePhoto(index),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _readyToCalculate && !_calculating
                      ? _calculate
                      : null,
                  child: _calculating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Berechnung starten'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _calculating ? null : _openManualMeasurement,
                  child: const Text('Manuell eingeben'),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
