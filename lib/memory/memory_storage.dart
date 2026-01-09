import 'package:shared_preferences/shared_preferences.dart';

class MemoryStorage {
  const MemoryStorage._();

  static const String storageKey = 'memory_v1';

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  static Future<void> write(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
