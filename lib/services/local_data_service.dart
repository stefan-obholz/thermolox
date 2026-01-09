import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../memory/memory_storage.dart';

class LocalDataService {
  const LocalDataService._();

  static const _projectsCachePrefix = 'projects_cache_v1_';
  static const _projectsLegacyKey = 'projects_v1';
  static const _projectsMigratedKey = 'projects_migrated_v1';

  static Future<void> clearAll() async {
    await _clearPreferences();
    await _clearUploadsDirectory();
  }

  static Future<void> _clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final removals = <String>[];

    for (final key in keys) {
      if (key == MemoryStorage.storageKey ||
          key == _projectsLegacyKey ||
          key == _projectsMigratedKey ||
          key.startsWith(_projectsCachePrefix)) {
        removals.add(key);
      }
    }

    for (final key in removals) {
      await prefs.remove(key);
    }
  }

  static Future<void> _clearUploadsDirectory() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final uploadsDir = Directory(
        '${docsDir.path}${Platform.pathSeparator}uploads',
      );
      if (await uploadsDir.exists()) {
        await uploadsDir.delete(recursive: true);
      }
    } catch (_) {
      // ignore local cleanup errors
    }
  }
}
