import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/project_models.dart';
import '../services/projects_repository.dart';

class ProjectsModel extends ChangeNotifier {
  final ProjectsRepository _repo;
  bool _loaded = false;
  List<Project> _projects = [];

  bool get isLoaded => _loaded;
  List<Project> get projects => List.unmodifiable(_projects);
  bool existsName(String name) =>
      _projects.any((p) => p.name.toLowerCase() == name.toLowerCase());

  ProjectsModel({ProjectsRepository? repo}) : _repo = repo ?? ProjectsRepository() {
    _init();
  }

  Future<void> _init() async {
    _projects = await _repo.loadProjects();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _repo.saveProjects(_projects);
    notifyListeners();
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

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString() + Random().nextInt(9999).toString();

  Future<Project> addProject(String name) async {
    final existing = _projects.firstWhere(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
      orElse: () => Project(id: '', name: '', items: []),
    );
    if (existing.id.isNotEmpty) {
      return existing;
    }
    final project = Project(id: _newId(), name: name, items: []);
    _projects.add(project);
    await _persist();
    return project;
  }

  Future<void> renameProject(String id, String newName) async {
    final p = _projects.firstWhere((e) => e.id == id);
    p.name = newName;
    await _persist();
  }

  Future<void> deleteProject(String id) async {
    _projects.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> addItem({
    required String projectId,
    required String name,
    required String type,
    String? path,
    String? url,
  }) async {
    final project = _projects.firstWhere((e) => e.id == projectId);
    if (type == 'image' || type == 'file') {
      project.items.removeWhere(
        (item) => item.type == 'image' || item.type == 'file',
      );
    } else if (type == 'color') {
      project.items.removeWhere((item) => item.type == 'color');
    }
    final persistedPath = await _persistLocalFile(path);
    project.items.add(
      ProjectItem(
        id: _newId(),
        name: name,
        type: type,
        path: persistedPath,
        url: url,
      ),
    );
    await _persist();
  }

  Future<void> renameItem(String itemId, String newName) async {
    for (final p in _projects) {
      final idx = p.items.indexWhere((e) => e.id == itemId);
      if (idx != -1) {
        p.items[idx].name = newName;
        await _persist();
        return;
      }
    }
  }

  Future<void> deleteItem(String itemId) async {
    for (final p in _projects) {
      p.items.removeWhere((e) => e.id == itemId);
    }
    await _persist();
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
    final target = _projects.firstWhere((e) => e.id == targetProjectId);
    target.items.add(item);
    await _persist();
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
    final project = _projects.firstWhere((e) => e.id == projectId);
    final normalized = _normalizeHex(hex);
    project.items.removeWhere((item) => item.type == 'color');
    project.items.add(
      ProjectItem(
        id: _newId(),
        name: normalized,
        type: 'color',
        url: normalized,
      ),
    );
    await _persist();
  }
}
