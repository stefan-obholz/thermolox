import 'dart:io';

import 'package:flutter/material.dart';

class ImagePreviewPage extends StatelessWidget {
  final String pathOrUrl;
  final String? title;

  const ImagePreviewPage({
    super.key,
    required this.pathOrUrl,
    this.title,
  });

  bool _isRemotePath(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isRemote = _isRemotePath(pathOrUrl);
    final image = isRemote
        ? Image.network(
            pathOrUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image_outlined),
            ),
          )
        : Image.file(
            File(pathOrUrl),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.broken_image_outlined),
            ),
          );

    return Scaffold(
      appBar: isLandscape
          ? null
          : AppBar(
              title: Text(title ?? 'Bild'),
              backgroundColor: theme.colorScheme.surface,
            ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: image,
        ),
      ),
    );
  }
}

Future<void> openImagePreview(
  BuildContext context, {
  required String pathOrUrl,
  String? title,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ImagePreviewPage(
        pathOrUrl: pathOrUrl,
        title: title,
      ),
    ),
  );
}
