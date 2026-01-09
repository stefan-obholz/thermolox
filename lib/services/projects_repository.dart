import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_models.dart';
import 'supabase_service.dart';

class ProjectsRepository {
  static const _bucket = 'project_uploads';
  static const _legacyKey = 'projects_v1';
  static const _migratedKey = 'projects_migrated_v1';
  static const _cachePrefix = 'projects_cache_v1_';

  ProjectsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;
  bool lastLoadUsedCache = false;

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }
    return user;
  }

  Future<void> migrateLocalProjectsIfNeeded() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) {
      await prefs.setBool(_migratedKey, true);
      return;
    }

    List<Project> legacyProjects;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      legacyProjects = decoded
          .map((e) => Project.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Legacy projects parse failed: $e');
      }
      return;
    }

    if (legacyProjects.isEmpty) {
      await prefs.setBool(_migratedKey, true);
      await prefs.remove(_legacyKey);
      return;
    }

    try {
      final existingRows = await _client
          .from('projects')
          .select('id,name')
          .eq('user_id', user.id);
      final nameToId = <String, String>{};
      for (final row in existingRows) {
        final data = row as Map<String, dynamic>;
        final id = data['id']?.toString();
        final name = data['name']?.toString();
        if (id == null || name == null) continue;
        nameToId[name.toLowerCase()] = id;
      }

      for (final project in legacyProjects) {
        final name = project.name.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        var projectId = nameToId[key];
        if (projectId == null) {
          final created = await createProject(
            name: name,
            title: project.title ?? name,
          );
          projectId = created.id;
          if (projectId.isNotEmpty) {
            nameToId[key] = projectId;
          }
        }

        if (projectId == null || projectId.isEmpty) continue;

        for (final item in project.items) {
          final type = item.type.toLowerCase();
          if (type == 'color') {
            final hex = item.url ?? item.name;
            if (hex == null || hex.trim().isEmpty) continue;
            await addItem(
              projectId: projectId,
              name: hex,
              type: 'color',
              colorHex: hex,
            );
            continue;
          }
          if (type == 'image' || type == 'file') {
            final path = item.path;
            final hasLocal = path != null && File(path).existsSync();
            final remoteUrl = item.url;
            if (!hasLocal && (remoteUrl == null || remoteUrl.isEmpty)) {
              continue;
            }
            final fileName =
                item.name.isNotEmpty ? item.name : (path != null ? p.basename(path) : 'Upload');
            await addItem(
              projectId: projectId,
              name: fileName,
              type: type,
              localPath: hasLocal ? path : null,
              remoteUrl: remoteUrl,
            );
          }
        }
      }

      await prefs.setBool(_migratedKey, true);
      await prefs.remove(_legacyKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Legacy projects migration failed: $e');
      }
    }
  }

  Future<List<Project>> _readCachedProjects(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$userId');
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final projects = <Project>[];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          projects.add(Project.fromJson(entry));
        } else if (entry is Map) {
          projects.add(Project.fromJson(entry.cast<String, dynamic>()));
        }
      }
      return projects;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Projects cache read failed: $e');
      }
      return [];
    }
  }

  Future<void> cacheProjects(List<Project> projects) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(projects.map((p) => p.toJson()).toList());
      await prefs.setString('$_cachePrefix${user.id}', payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Projects cache write failed: $e');
      }
    }
  }

  Future<List<Project>> loadProjects() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    lastLoadUsedCache = false;
    try {
      final projectRows = await _client
          .from('projects')
          .select('id,name,title')
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final projects = <Project>[];
      final projectIds = <String>[];
      for (final row in projectRows) {
        final data = row as Map<String, dynamic>;
        final id = data['id']?.toString();
        if (id == null || id.isEmpty) continue;
        projectIds.add(id);
        projects.add(
          Project(
            id: id,
            name: data['name']?.toString() ?? '',
            title: data['title']?.toString(),
            items: [],
          ),
        );
      }

      if (projectIds.isNotEmpty) {
        final itemRows = await _client
            .from('project_items')
            .select('id,project_id,type,name,storage_path,url,color_hex')
            .eq('user_id', user.id)
            .inFilter('project_id', projectIds);

        final itemsByProject = <String, List<ProjectItem>>{};
        for (final row in itemRows) {
          final data = row as Map<String, dynamic>;
          final projectId = data['project_id']?.toString();
          if (projectId == null || projectId.isEmpty) continue;
          final item = await _mapItemRow(data);
          if (item == null) continue;
          itemsByProject.putIfAbsent(projectId, () => []).add(item);
        }

        for (final project in projects) {
          project.items.addAll(itemsByProject[project.id] ?? []);
        }
      }

      await cacheProjects(projects);
      lastLoadUsedCache = false;
      return projects;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Projects load failed, using cache: $e');
      }
      lastLoadUsedCache = true;
      return _readCachedProjects(user.id);
    }
  }

  Future<Project> createProject({
    required String name,
    String? title,
  }) async {
    final user = _requireUser();
    final row = await _client
        .from('projects')
        .insert({
          'user_id': user.id,
          'name': name,
          'title': title,
        })
        .select('id,name,title')
        .single();

    return Project(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? name,
      title: row['title']?.toString(),
      items: [],
    );
  }

  Future<void> updateProjectName({
    required String id,
    required String newName,
  }) async {
    final user = _requireUser();
    await _client
        .from('projects')
        .update({
          'name': newName,
          'title': newName,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<void> deleteProject(String id) async {
    final user = _requireUser();
    final items = await _client
        .from('project_items')
        .select('storage_path')
        .eq('project_id', id)
        .eq('user_id', user.id);
    for (final row in items) {
      final storagePath = (row as Map<String, dynamic>)['storage_path'];
      if (storagePath is String && storagePath.isNotEmpty) {
        await _deleteStorageObject(storagePath);
      }
    }
    await _client
        .from('projects')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<ProjectItem> addItem({
    required String projectId,
    required String name,
    required String type,
    String? localPath,
    String? colorHex,
    String? remoteUrl,
  }) async {
    final user = _requireUser();
    final normalizedType = type.toLowerCase();
    final removeTypes = normalizedType == 'color'
        ? ['color']
        : normalizedType == 'render'
            ? ['render']
            : normalizedType == 'image'
                ? ['image']
                : normalizedType == 'file'
                    ? ['file']
                    : [normalizedType];

    await _removeExistingByTypes(
      userId: user.id,
      projectId: projectId,
      types: removeTypes,
    );

    if (normalizedType == 'color') {
      final hex = colorHex ?? name;
      final row = await _client
          .from('project_items')
          .insert({
            'project_id': projectId,
            'user_id': user.id,
            'type': 'color',
            'name': hex,
            'color_hex': hex,
          })
          .select('id,name,type,color_hex')
          .single();

      final label = row['color_hex']?.toString() ?? row['name']?.toString() ?? hex;
      return ProjectItem(
        id: row['id']?.toString() ?? '',
        name: label,
        type: 'color',
        url: label,
      );
    }

    if ((localPath == null || localPath.isEmpty) &&
        (remoteUrl == null || remoteUrl.isEmpty)) {
      throw StateError('Missing file path');
    }

    String? storagePath;
    String? url = remoteUrl;
    if (localPath != null && localPath.isNotEmpty) {
      storagePath = _buildStoragePath(user.id, projectId, localPath);
      final bytes = await File(localPath).readAsBytes();
      final contentType = _contentTypeForPath(localPath);

      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      url = await _signedUrl(storagePath);
    }
    final row = await _client
        .from('project_items')
        .insert({
          'project_id': projectId,
          'user_id': user.id,
          'type': normalizedType,
          'name': name,
          'storage_path': storagePath,
          'url': url,
        })
        .select('id,name,type,storage_path,url')
        .single();

    return ProjectItem(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? name,
      type: row['type']?.toString() ?? normalizedType,
      path: localPath,
      url: row['url']?.toString() ?? url,
      storagePath: row['storage_path']?.toString() ?? storagePath,
    );
  }

  Future<void> renameItem(String itemId, String newName) async {
    final user = _requireUser();
    await _client
        .from('project_items')
        .update({'name': newName})
        .eq('id', itemId)
        .eq('user_id', user.id);
  }

  Future<void> deleteItem(String itemId) async {
    final user = _requireUser();
    final row = await _client
        .from('project_items')
        .select('storage_path')
        .eq('id', itemId)
        .eq('user_id', user.id)
        .maybeSingle();
    final storagePath = row?['storage_path']?.toString();
    if (storagePath != null && storagePath.isNotEmpty) {
      await _deleteStorageObject(storagePath);
    }
    await _client
        .from('project_items')
        .delete()
        .eq('id', itemId)
        .eq('user_id', user.id);
  }

  Future<void> moveItem({
    required String itemId,
    required String targetProjectId,
  }) async {
    final user = _requireUser();
    await _client
        .from('project_items')
        .update({'project_id': targetProjectId})
        .eq('id', itemId)
        .eq('user_id', user.id);
  }

  Future<ProjectItem?> _mapItemRow(Map<String, dynamic> data) async {
    final id = data['id']?.toString();
    final type = data['type']?.toString();
    if (id == null || type == null) return null;

    final storagePath = data['storage_path']?.toString();
    var url = data['url']?.toString();
    final colorHex = data['color_hex']?.toString();

    if (type == 'color') {
      final label = colorHex ?? data['name']?.toString() ?? '#000000';
      return ProjectItem(id: id, name: label, type: 'color', url: label);
    }

    if (storagePath != null && storagePath.isNotEmpty) {
      final refreshedUrl = await _signedUrl(storagePath);
      if (refreshedUrl != null && refreshedUrl.isNotEmpty) {
        url = refreshedUrl;
      }
    }

    return ProjectItem(
      id: id,
      name: data['name']?.toString() ?? '',
      type: type,
      url: url,
      storagePath: storagePath,
    );
  }

  Future<void> _removeExistingByTypes({
    required String userId,
    required String projectId,
    required List<String> types,
  }) async {
    final rows = await _client
        .from('project_items')
        .select('id,type,storage_path')
        .eq('user_id', userId)
        .eq('project_id', projectId)
        .inFilter('type', types);

    for (final row in rows) {
      final data = row as Map<String, dynamic>;
      final storagePath = data['storage_path']?.toString();
      if (storagePath != null && storagePath.isNotEmpty) {
        await _deleteStorageObject(storagePath);
      }
    }

    await _client
        .from('project_items')
        .delete()
        .eq('user_id', userId)
        .eq('project_id', projectId)
        .inFilter('type', types);
  }

  Future<void> _deleteStorageObject(String storagePath) async {
    try {
      await _client.storage.from(_bucket).remove([storagePath]);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Storage delete failed: $e');
      }
    }
  }

  Future<String?> _signedUrl(String storagePath) async {
    try {
      return await _client.storage
          .from(_bucket)
          .createSignedUrl(storagePath, 60 * 60);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Signed URL failed: $e');
      }
      return null;
    }
  }

  String _buildStoragePath(String userId, String projectId, String localPath) {
    final fileName = p.basename(localPath);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return '$userId/$projectId/${stamp}_$fileName';
  }

  String? _contentTypeForPath(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.pdf':
        return 'application/pdf';
      default:
        return null;
    }
  }
}
