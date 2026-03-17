import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_models.dart';
import '../services/projects_repository.dart';
import '../services/supabase_service.dart';

class ProjectsModel extends ChangeNotifier {
  final ProjectsRepository _repo;
  bool _loaded = false;
  bool _loadedFromCache = false;
  int _initGeneration = 0;
  List<Project> _projects = [];
  StreamSubscription<AuthState>? _authSub;

  bool get isLoaded => _loaded;
  bool get loadedFromCache => _loadedFromCache;
  List<Project> get projects => List.unmodifiable(_projects);
  bool existsName(String name) =>
      _projects.any((p) => p.name.toLowerCase() == name.toLowerCase());

  ProjectsModel({ProjectsRepository? repo}) : _repo = repo ?? ProjectsRepository() {
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut) {
        reload();
      }
    });
    _init();
  }

  Future<void> _init() async {
    final generation = ++_initGeneration;
    try {
      await _repo.migrateLocalProjectsIfNeeded();
      if (generation != _initGeneration) return;
      _projects = await _repo.loadProjects();
      if (generation != _initGeneration) return;
      _loadedFromCache = _repo.lastLoadUsedCache;
    } catch (_) {
      if (generation != _initGeneration) return;
      _projects = [];
      _loadedFromCache = true;
    } finally {
      if (generation == _initGeneration) {
        _loaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> reload() async {
    _loaded = false;
    notifyListeners();
    await _init();
  }

  Future<void> _cacheProjects() async {
    await _repo.cacheProjects(_projects);
  }

  String _fileNameFromPath(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : path;
  }

  Future<String?> _persistLocalFile(String? path) async {
    if (path == null || path.isEmpty) return path;
    try {
      final file = File(path);
      if (!await file.exists()) return path;

      final docsDir = await getApplicationDocumentsDirectory();
      final uploadsDir = Directory('${docsDir.path}${Platform.pathSeparator}uploads');
      if (!await uploadsDir.exists()) {
        await uploadsDir.create(recursive: true);
      }

      if (path.startsWith(uploadsDir.path)) return path;

      final fileName = _fileNameFromPath(path);
      final stampedName =
          '${DateTime.now().microsecondsSinceEpoch}_$fileName';
      final target = File(
        '${uploadsDir.path}${Platform.pathSeparator}$stampedName',
      );
      final copied = await file.copy(target.path);
      return copied.path;
    } catch (_) {
      return path;
    }
  }

  Future<Project> addProject(String name) async {
    final existing = _projects.firstWhere(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
      orElse: () => Project(id: '', name: '', items: []),
    );
    if (existing.id.isNotEmpty) {
      return existing;
    }
    final project = await _repo.createProject(name: name, title: name);
    _projects.add(project);
    await _cacheProjects();
    notifyListeners();
    return project;
  }

  Future<void> renameProject(String id, String newName) async {
    final idx = _projects.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _projects[idx].name = newName;
    _projects[idx].title = newName;
    await _repo.updateProjectName(id: id, newName: newName);
    await _cacheProjects();
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    await _repo.deleteProject(id);
    _projects.removeWhere((e) => e.id == id);
    await _cacheProjects();
    notifyListeners();
  }

  Future<void> addItem({
    required String projectId,
    required String name,
    required String type,
    String? path,
    String? url,
  }) async {
    final pIdx = _projects.indexWhere((e) => e.id == projectId);
    if (pIdx == -1) return;
    final project = _projects[pIdx];
    if (type == 'image') {
      project.items.removeWhere((item) => item.type == 'image');
    } else if (type == 'file') {
      project.items.removeWhere((item) => item.type == 'file');
    } else if (type == 'color') {
      project.items.removeWhere((item) => item.type == 'color');
    }
    final persistedPath = await _persistLocalFile(path);
    final localPath = persistedPath ?? path;
    final item = await _repo.addItem(
      projectId: projectId,
      name: name,
      type: type,
      localPath: localPath,
      remoteUrl: url,
    );
    project.items.add(
      ProjectItem(
        id: item.id,
        name: item.name,
        type: item.type,
        path: persistedPath,
        url: item.url ?? url,
        storagePath: item.storagePath,
      ),
    );
    await _cacheProjects();
    notifyListeners();
  }

  Future<void> renameItem(String itemId, String newName) async {
    for (final p in _projects) {
      final idx = p.items.indexWhere((e) => e.id == itemId);
      if (idx != -1) {
        p.items[idx].name = newName;
        await _repo.renameItem(itemId, newName);
        await _cacheProjects();
        notifyListeners();
        return;
      }
    }
  }

  Future<void> deleteItem(String itemId) async {
    await _repo.deleteItem(itemId);
    for (final p in _projects) {
      p.items.removeWhere((e) => e.id == itemId);
    }
    await _cacheProjects();
    notifyListeners();
  }

  Future<void> moveItem({
    required String itemId,
    required String targetProjectId,
  }) async {
    ProjectItem? item;
    for (final p in _projects) {
      final idx = p.items.indexWhere((e) => e.id == itemId);
      if (idx != -1) {
        item = p.items.removeAt(idx);
        break;
      }
    }
    if (item == null) return;
    final tIdx = _projects.indexWhere((e) => e.id == targetProjectId);
    if (tIdx == -1) return;
    final target = _projects[tIdx];
    target.items.add(item);
    await _repo.moveItem(itemId: itemId, targetProjectId: targetProjectId);
    await _cacheProjects();
    notifyListeners();
  }

  String _normalizeHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length < 6) {
      h = h.padRight(6, '0');
    }
    return '#${h.substring(0, 6)}'.toUpperCase();
  }

  Future<void> addColorSwatch({
    required String projectId,
    required String hex,
  }) async {
    final csIdx = _projects.indexWhere((e) => e.id == projectId);
    if (csIdx == -1) return;
    final project = _projects[csIdx];
    final normalized = _normalizeHex(hex);
    project.items.removeWhere((item) => item.type == 'color');
    final item = await _repo.addItem(
      projectId: projectId,
      name: normalized,
      type: 'color',
      colorHex: normalized,
    );
    project.items.add(item);
    await _cacheProjects();
    notifyListeners();
  }

  Future<void> addRender({
    required String projectId,
    required String name,
    String? path,
    String? url,
  }) async {
    await addItem(
      projectId: projectId,
      name: name,
      type: 'render',
      path: path,
      url: url,
    );
    final rIdx = _projects.indexWhere((e) => e.id == projectId);
    if (rIdx == -1) return;
    final project = _projects[rIdx];
    final renders = project.items.where((i) => i.type == 'render').toList();
    if (renders.length <= 10) return;

    final overflow = renders.length - 10;
    final toRemove = renders.take(overflow).toList();
    for (final item in toRemove) {
      await _repo.deleteItem(item.id);
      project.items.removeWhere((i) => i.id == item.id);
    }
    await _cacheProjects();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
