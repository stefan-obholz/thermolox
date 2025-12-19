import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/project_models.dart';
import '../models/projects_model.dart';
import '../theme/app_theme.dart';

class ProjectDetailPage extends StatelessWidget {
  final String projectId;

  const ProjectDetailPage({super.key, required this.projectId});

  Project _find(BuildContext context) =>
      context.read<ProjectsModel>().projects.firstWhere((p) => p.id == projectId);

  Future<void> _renameProject(BuildContext context, Project project) async {
    final ctrl = TextEditingController(text: project.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Projekt umbenennen'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Neuer Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await context.read<ProjectsModel>().renameProject(project.id, ctrl.text.trim());
    }
  }

  Future<void> _addUpload(BuildContext context, Project project) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Dokument auswählen'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Bild aus Galerie'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    String? path;
    String name = 'Upload';
    String type = 'file';

    if (choice == 'file') {
      final res = await FilePicker.platform.pickFiles();
      if (res == null || res.files.isEmpty) return;
      final picked = res.files.single;
      path = picked.path;
      name = picked.name;
      type = 'file';
    } else if (choice == 'image') {
      final picker = ImagePicker();
      final img = await picker.pickImage(source: ImageSource.gallery);
      if (img == null) return;
      path = img.path;
      name = img.name;
      type = 'image';
    } else if (choice == 'camera') {
      final picker = ImagePicker();
      final img = await picker.pickImage(source: ImageSource.camera);
      if (img == null) return;
      path = img.path;
      name = img.name;
      type = 'image';
    }

    await context.read<ProjectsModel>().addItem(
          projectId: project.id,
          name: name,
          type: type,
          path: path,
        );
  }

  Future<void> _renameItem(BuildContext context, ProjectItem item) async {
    final ctrl = TextEditingController(text: item.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Umbenennen'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Neuer Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await context.read<ProjectsModel>().renameItem(item.id, ctrl.text.trim());
    }
  }

  Future<void> _moveItem(BuildContext context, ProjectItem item) async {
    final model = context.read<ProjectsModel>();
    final targetId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Verschieben nach...')),
            ...model.projects.map(
              (p) => ListTile(
                title: Text(p.name),
                onTap: () => Navigator.pop(ctx, p.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (targetId != null && targetId.isNotEmpty) {
      await model.moveItem(itemId: item.id, targetProjectId: targetId);
    }
  }

  Future<void> _openPreview(BuildContext context, ProjectItem item) async {
    if (item.type != 'image') return;
    final tokens = context.thermoloxTokens;
    final Widget? image = item.path != null
        ? Image.file(File(item.path!), fit: BoxFit.contain)
        : (item.url != null
            ? Image.network(item.url!, fit: BoxFit.contain)
            : null);
    if (image == null) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.85)),
              ),
              Center(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusSm),
                            child: image,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color? _colorFromHex(String hex) {
      var h = hex.trim();
      if (h.startsWith('#')) h = h.substring(1);
      if (h.length == 3) {
        h = h.split('').map((c) => '$c$c').join();
      }
      if (h.length < 6) h = h.padRight(6, '0');
      final val = int.tryParse(h.substring(0, 6), radix: 16);
      if (val == null) return null;
      return Color(0xFF000000 | val);
    }

    final tokens = context.thermoloxTokens;
    return Consumer<ProjectsModel>(
      builder: (context, model, _) {
        final project = model.projects.firstWhere((p) => p.id == projectId);
        final items = project.items;
        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _renameProject(context, project),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addUpload(context, project),
            icon: const Icon(Icons.upload),
            label: const Text('Upload'),
          ),
          body: items.isEmpty
              ? const Center(child: Text('Noch keine Uploads in diesem Projekt.'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final hasImage = item.type == 'image' && (item.path != null || item.url != null);
                    final isColor = item.type == 'color';
                    final color = isColor ? _colorFromHex(item.url ?? item.name) : null;
                    return GestureDetector(
                      onTap: hasImage ? () => _openPreview(context, item) : null,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              color: Colors.grey.shade200,
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (hasImage)
                                    item.path != null
                                        ? Image.file(File(item.path!), fit: BoxFit.cover)
                                        : Image.network(item.url!, fit: BoxFit.cover)
                                  else if (isColor && color != null)
                                    Container(color: color)
                                  else
                                    const Center(
                                      child: Icon(Icons.insert_drive_file, size: 36),
                                    ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      color: Colors.black.withOpacity(0.35),
                                      padding: const EdgeInsets.all(6),
                                      child: Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'rename') {
                                  await _renameItem(context, item);
                                } else if (value == 'delete') {
                                  await model.deleteItem(item.id);
                                } else if (value == 'move') {
                                  await _moveItem(context, item);
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
                                PopupMenuItem(value: 'move', child: Text('Verschieben')),
                                PopupMenuItem(value: 'delete', child: Text('Löschen')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
