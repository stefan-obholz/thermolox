import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/thermolox_overlay.dart';

class AttachmentPick {
  final String path;
  final bool isImage;
  final String? name;

  const AttachmentPick({
    required this.path,
    required this.isImage,
    this.name,
  });
}

Future<AttachmentPick?> pickThermoloxAttachment(
  BuildContext context, {
  bool allowFiles = true,
}) async {
  final result = await ThermoloxOverlay.showSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (dialogCtx) {
      return SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Bild aus Galerie'),
              onTap: () => Navigator.of(dialogCtx).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.of(dialogCtx).pop('camera'),
            ),
            if (allowFiles)
              ListTile(
                leading: const Icon(Icons.insert_drive_file_rounded),
                title: const Text('Datei auswählen'),
                onTap: () => Navigator.of(dialogCtx).pop('file'),
              ),
          ],
        ),
      );
    },
  );

  if (result == null) return null;

  if (result == 'file') {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.first;
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return AttachmentPick(path: path, isImage: false, name: file.name);
  }

  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: result == 'camera' ? ImageSource.camera : ImageSource.gallery,
  );
  if (image == null) return null;
  return AttachmentPick(path: image.path, isImage: true, name: image.name);
}
