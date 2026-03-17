import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/project_measurement.dart';
import 'consent_service.dart';
import 'thermolox_api.dart';
import '../utils/safe_json.dart';

class LidarMeasurementResult {
  final double? lengthM;
  final double? widthM;
  final double? heightM;
  final List<RoomOpening> openings;
  final double? confidence;

  const LidarMeasurementResult({
    required this.lengthM,
    required this.widthM,
    required this.heightM,
    required this.openings,
    required this.confidence,
  });

  factory LidarMeasurementResult.fromJson(Map<String, dynamic> json) {
    final rawOpenings = json['openings'];
    final openings = <RoomOpening>[];
    if (rawOpenings is List) {
      for (final entry in rawOpenings) {
        if (entry is Map<String, dynamic>) {
          openings.add(RoomOpening.fromJson(entry));
        } else if (entry is Map) {
          openings.add(RoomOpening.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }
    return LidarMeasurementResult(
      lengthM: (json['length_m'] as num?)?.toDouble(),
      widthM: (json['width_m'] as num?)?.toDouble(),
      heightM: (json['height_m'] as num?)?.toDouble(),
      openings: openings,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

class LidarMeasurementService {
  const LidarMeasurementService();

  Future<LidarMeasurementResult> estimateFromRoomPlanJson(
    String roomJson,
  ) async {
    if (!ConsentService.instance.aiAllowed) {
      throw StateError('AI consent required');
    }
    if (roomJson.trim().isEmpty) {
      throw StateError('RoomPlan JSON missing');
    }

    final payload = {
      'room_json': roomJson,
    };

    final res = await http.post(
      Uri.parse('$kThermoloxApiBase/measure/lidar'),
      headers: buildWorkerHeaders(contentType: 'application/json'),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('LiDAR measurement failed: ${res.statusCode} ${res.body}');
    }

    final decoded = SafeJson.decodeMap(res.body);
    if (decoded == null) {
      throw Exception('LiDAR measurement response missing payload');
    }
    return LidarMeasurementResult.fromJson(
      decoded,
    );
  }
}
