import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'consent_service.dart';
import 'thermolox_api.dart';

class ImageEditService {
  const ImageEditService();

  Future<Uint8List> editImage({
    String? imageUrl,
    Uint8List? imageBytes,
    required Uint8List maskPng,
    required String prompt,
  }) async {
    if (!ConsentService.instance.aiAllowed) {
      throw StateError('AI consent required');
    }
    if ((imageUrl == null || imageUrl.isEmpty) &&
        (imageBytes == null || imageBytes.isEmpty)) {
      throw StateError('Missing image input');
    }

    final payload = <String, dynamic>{
      'prompt': prompt,
      'maskBase64': _toDataUrl(maskPng),
    };

    if (imageUrl != null && imageUrl.isNotEmpty) {
      payload['imageUrl'] = imageUrl;
    }
    if (imageBytes != null && imageBytes.isNotEmpty) {
      payload['imageBase64'] = _toDataUrl(imageBytes);
    }

    final res = await http.post(
      Uri.parse('$kThermoloxApiBase/image-edit'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('Image edit failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    return await _extractBytes(decoded);
  }

  Future<Uint8List> _extractBytes(dynamic decoded) async {
    if (decoded is Map) {
      return await _bytesFromMap(decoded);
    }
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return await _bytesFromMap(decoded.first as Map);
    }
    throw Exception('Unknown image edit response');
  }

  Future<Uint8List> _bytesFromMap(Map decoded) async {
    final base64 = decoded['imageBase64'] ??
        decoded['base64'] ??
        decoded['image'] ??
        decoded['image_base64'];
    if (base64 is String && base64.isNotEmpty) {
      return _decodeBase64(base64);
    }
    final url = decoded['imageUrl'] ?? decoded['url'];
    if (url is String && url.isNotEmpty) {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) return res.bodyBytes;
    }
    throw Exception('Image bytes missing in response');
  }

  String _toDataUrl(Uint8List bytes) {
    final encoded = base64Encode(bytes);
    return 'data:image/png;base64,$encoded';
  }

  Uint8List _decodeBase64(String value) {
    final clean = value.contains(',')
        ? value.substring(value.indexOf(',') + 1)
        : value;
    return base64Decode(clean.trim());
  }
}
