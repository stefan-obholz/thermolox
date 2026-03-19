import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LidarService {
  static const MethodChannel _channel = MethodChannel('everloxx/lidar');

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (!Platform.isIOS) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isLidarSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }
}
