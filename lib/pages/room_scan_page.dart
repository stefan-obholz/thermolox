import 'package:flutter/material.dart';

import '../models/project_measurement.dart';

class RoomScanResult {
  final ProjectMeasurement? measurement;
  final bool openManual;

  const RoomScanResult._({this.measurement, required this.openManual});

  factory RoomScanResult.measurement(ProjectMeasurement measurement) {
    return RoomScanResult._(measurement: measurement, openManual: false);
  }

  factory RoomScanResult.manualFallback() {
    return const RoomScanResult._(openManual: true);
  }

  factory RoomScanResult.cancelled() {
    return const RoomScanResult._(openManual: false);
  }
}

/// Placeholder page — the old ar_flutter_plugin based room scan has been
/// removed.  Native LiDAR / RoomPlan scanning is handled via
/// [ARWallPaintView] and [ar_wall_paint_page.dart].
class RoomScanPage extends StatelessWidget {
  final String projectId;
  final ProjectMeasurement? initialMeasurement;
  final bool skipPermissionGate;

  const RoomScanPage({
    super.key,
    required this.projectId,
    this.initialMeasurement,
    this.skipPermissionGate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raum scannen'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(RoomScanResult.cancelled()),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.construction_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Raum-Scan wird aktualisiert',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bitte nutze in der Zwischenzeit die manuelle Eingabe.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .pop(RoomScanResult.manualFallback()),
                  child: const Text('Manuell eingeben'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
