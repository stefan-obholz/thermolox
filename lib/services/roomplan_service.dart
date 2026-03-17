import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RoomPlanService {
  static const MethodChannel _channel = MethodChannel('thermolox/roomplan');

  static Future<bool> isSupported() async {
    if (kIsWeb) return false;
    if (!Platform.isIOS) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> startScan() async {
    if (kIsWeb) return null;
    if (!Platform.isIOS) return null;
    try {
      final result = await _channel.invokeMethod('startScan');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
