import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ARWallPaintService {
  static const MethodChannel _channel =
      MethodChannel('everloxx/ar_wall_paint');

  /// Whether the device supports AR wall painting.
  /// iOS 13.4+ with ARKit, Android with ARCore.
  static Future<bool> isSupported() async {
    if (kIsWeb) return false;
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    // ARKit is available on iOS 13.4+, ARCore on compatible Android devices.
    // The platform view itself handles the availability check.
    return true;
  }

  /// Apply a color to a detected wall.
  static Future<void> setWallColor(String anchorId, String hexColor) async {
    await _channel.invokeMethod('setWallColor', {
      'anchorId': anchorId,
      'hexColor': hexColor,
    });
  }

  /// Remove color from a specific wall.
  static Future<void> clearWallColor(String anchorId) async {
    await _channel.invokeMethod('clearWallColor', {
      'anchorId': anchorId,
    });
  }

  /// Remove all wall colors.
  static Future<void> clearAllColors() async {
    await _channel.invokeMethod('clearAllColors');
  }

  /// Take a screenshot of the current AR view (PNG bytes).
  static Future<Uint8List?> takeScreenshot() async {
    try {
      final result = await _channel.invokeMethod('takeScreenshot');
      if (result is Uint8List) return result;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Dispose the AR session.
  static Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {}
  }
}
