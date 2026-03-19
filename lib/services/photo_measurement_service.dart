import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'consent_service.dart';
import 'everloxx_api.dart';
import '../utils/safe_json.dart';

class PhotoMeasurementResult {
  final double? wallWidthM;
  final double? wallHeightM;
  final double? confidence;

  const PhotoMeasurementResult({
    required this.wallWidthM,
    required this.wallHeightM,
    required this.confidence,
  });

  factory PhotoMeasurementResult.fromJson(Map<String, dynamic> json) {
    return PhotoMeasurementResult(
      wallWidthM: (json['wall_width_m'] as num?)?.toDouble(),
      wallHeightM: (json['wall_height_m'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

class PhotoMeasurementService {
  const PhotoMeasurementService();

  Future<List<PhotoMeasurementResult>> estimateFromPhotos(
    List<String> paths,
  ) async {
    if (!ConsentService.instance.aiAllowed) {
      throw StateError('AI consent required');
    }
    if (paths.isEmpty) {
      throw StateError('No photos provided');
    }

    final images = <String>[];
    for (final path in paths) {
      final bytes = await File(path).readAsBytes();
      images.add(_toDataUrl(bytes, path));
    }

    final payload = {
      'images': images,
    };

    final res = await http.post(
      Uri.parse('$kEverloxxApiBase/measure/photos'),
      headers: buildWorkerHeaders(contentType: 'application/json'),
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('Photo measurement failed: ${res.statusCode} ${res.body}');
    }

    final decoded = SafeJson.decodeMap(res.body);
    final rawResults = decoded?['results'];
    if (rawResults is! List) {
      throw Exception('Photo measurement response missing results');
    }

    return rawResults
        .whereType<Map>()
        .map((item) => PhotoMeasurementResult.fromJson(
              item.cast<String, dynamic>(),
            ))
        .toList();
  }

  String _toDataUrl(Uint8List bytes, String path) {
    final encoded = base64Encode(bytes);
    final mime = _guessMimeType(path);
    return 'data:$mime;base64,$encoded';
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
