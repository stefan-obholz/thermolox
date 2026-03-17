import 'package:flutter/material.dart';

import '../widgets/feature_guard.dart';
import '../models/project_measurement.dart';
import '../services/supabase_service.dart';

class RoomMeasurementPage extends StatefulWidget {
  final String projectId;
  final ProjectMeasurement? initialMeasurement;

  const RoomMeasurementPage({
    super.key,
    required this.projectId,
    this.initialMeasurement,
  });

  @override
  State<RoomMeasurementPage> createState() => _RoomMeasurementPageState();
}

class _RoomMeasurementPageState extends State<RoomMeasurementPage> {
  late final TextEditingController _lengthController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  final List<RoomOpening> _openings = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMeasurement;
    _lengthController = TextEditingController(
      text: _formatDouble(initial?.lengthM),
    );
    _widthController = TextEditingController(
      text: _formatDouble(initial?.widthM),
    );
    _heightController = TextEditingController(
      text: _formatDouble(initial?.heightM),
    );
    if (initial != null) {
      _openings.addAll(initial.openings);
    }
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String _formatDouble(double? value) {
    if (value == null || value == 0) return '';
    final text = value.toStringAsFixed(2);
    return text.replaceAll('.', ',');
  }

  double? _parseMeters(String input) {
    final cleaned = input.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _addOpening() async {
    String type = 'window';
    final widthController = TextEditingController();
    final heightController = TextEditingController();
    final countController = TextEditingController(text: '1');

    final result = await showDialog<RoomOpening>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Öffnung hinzufügen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Typ'),
                  items: const [
                    DropdownMenuItem(
                      value: 'window',
                      child: Text('Fenster'),
                    ),
                    DropdownMenuItem(
                      value: 'door',
                      child: Text('Tür'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Sonstiges'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    type = value;
                  },
                ),
                TextField(
                  controller: widthController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Breite (m)'),
                ),
                TextField(
                  controller: heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Höhe (m)'),
                ),
                TextField(
                  controller: countController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  decoration: const InputDecoration(labelText: 'Anzahl'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                final width = _parseMeters(widthController.text);
                final height = _parseMeters(heightController.text);
                final count = int.tryParse(countController.text.trim()) ?? 1;
                if (width == null || width <= 0 || height == null || height <= 0) {
                  _showSnack('Bitte gültige Maße eingeben.');
                  return;
                }
                final opening = RoomOpening(
                  type: type,
                  widthM: width,
                  heightM: height,
                  count: count <= 0 ? 1 : count,
                );
                Navigator.of(dialogContext).pop(opening);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _openings.add(result);
      });
    }
  }

  String _openingLabel(RoomOpening opening) {
    final typeLabel = switch (opening.type) {
      'door' => 'Tür',
      'other' => 'Sonstiges',
      _ => 'Fenster',
    };
    final size =
        '${opening.widthM.toStringAsFixed(2).replaceAll('.', ',')} m × '
        '${opening.heightM.toStringAsFixed(2).replaceAll('.', ',')} m';
    final count = opening.count > 1 ? ' × ${opening.count}' : '';
    return '$typeLabel: $size$count';
  }

  void _save() {
    final userId = SupabaseService.client.auth.currentUser?.id ?? '';

    final length = _parseMeters(_lengthController.text);
    final width = _parseMeters(_widthController.text);
    final height = _parseMeters(_heightController.text);
    if (length == null || length <= 0 ||
        width == null || width <= 0 ||
        height == null || height <= 0) {
      _showSnack('Bitte Länge, Breite und Höhe angeben.');
      return;
    }

    final measurement = ProjectMeasurement(
      id: widget.initialMeasurement?.id ?? '',
      projectId: widget.projectId,
      userId: userId,
      method: 'manual',
      lengthM: length,
      widthM: width,
      heightM: height,
      openings: List<RoomOpening>.from(_openings),
      confidence: null,
      createdAt: widget.initialMeasurement?.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    Navigator.of(context).pop(measurement);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raum messen'),
      ),
      body: SafeArea(
        child: FeatureGuard(
          message:
              'Die Messung ist gerade nicht verfügbar. Bitte erneut versuchen.',
          builder: () => ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            children: [
              const Text(
                'Gib die Maße des Raumes in Metern an. Optional kannst du '
                'Fenster/Türen ergänzen.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lengthController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Länge (m)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _widthController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Breite (m)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _heightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Höhe (m)'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Öffnungen',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextButton.icon(
                    onPressed: _addOpening,
                    icon: const Icon(Icons.add),
                    label: const Text('Hinzufügen'),
                  ),
                ],
              ),
              if (_openings.isEmpty)
                const Text('Noch keine Öffnungen erfasst.'),
              for (var i = 0; i < _openings.length; i += 1)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_openingLabel(_openings[i])),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        _openings.removeAt(i);
                      });
                    },
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Messung speichern'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
