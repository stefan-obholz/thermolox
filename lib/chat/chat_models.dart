import 'dart:typed_data';

/// =======================
///  MODEL-KLASSEN
/// =======================

class ChatMessage {
  final String role; // "user" oder "assistant"
  final String text;
  final List<QuickReplyButton>? buttons;
  final bool excludeFromApi;

  /// Optional: Original-Inhalt für die API (Text oder Text+Bild-Content)
  final dynamic content;

  /// Lokale Bildpfade, nur für die Vorschau in der Bubble
  final List<String>? localImagePaths;

  const ChatMessage({
    required this.role,
    required this.text,
    this.buttons,
    this.content,
    this.localImagePaths,
    this.excludeFromApi = false,
  });

  ChatMessage copyWith({
    String? role,
    String? text,
    List<QuickReplyButton>? buttons,
    dynamic content,
    List<String>? localImagePaths,
    bool? excludeFromApi,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      buttons: buttons ?? this.buttons,
      content: content ?? this.content,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      excludeFromApi: excludeFromApi ?? this.excludeFromApi,
    );
  }
}

class QuickReplyButton {
  final String label;
  final String value;
  final bool preferred;
  final QuickReplyAction action;

  const QuickReplyButton({
    required this.label,
    required this.value,
    this.preferred = false,
    this.action = QuickReplyAction.send,
  });

  QuickReplyButton copyWith({
    String? label,
    String? value,
    bool? preferred,
    QuickReplyAction? action,
  }) {
    return QuickReplyButton(
      label: label ?? this.label,
      value: value ?? this.value,
      preferred: preferred ?? this.preferred,
      action: action ?? this.action,
    );
  }
}

enum QuickReplyAction {
  send,
  uploadAttachment,
  goToCart,
  acceptAllConsents,
  openSettings,
  declineConsents,
  scanColor,
  startRender,
  arWallPaint,
}

enum ProjectDecision {
  unknown,
  withProject,
  withoutProject,
}

class FallbackButtons {
  final List<QuickReplyButton> buttons;
  final String key;

  const FallbackButtons({required this.buttons, required this.key});
}

class Attachment {
  final String path;
  final bool isImage;
  final String? name;

  const Attachment({required this.path, required this.isImage, this.name});
}

class SentUpload {
  final String id;
  final String name;
  final bool isImage;
  final String? localPath;
  final String? remoteUrl;

  const SentUpload({
    required this.id,
    required this.name,
    required this.isImage,
    this.localPath,
    this.remoteUrl,
  });

  SentUpload copyWith({String? remoteUrl}) {
    return SentUpload(
      id: id,
      name: name,
      isImage: isImage,
      localPath: localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
    );
  }
}

class CompressedUpload {
  final Uint8List bytes;
  final String mime;
  final bool compressed;

  const CompressedUpload({
    required this.bytes,
    required this.mime,
    required this.compressed,
  });
}

class RoomMention {
  final String base;
  final String token;
  final int? ordinal;
  final bool wantsAnother;
  final bool wantsExisting;
  final String? customLabel;

  const RoomMention({
    required this.base,
    required this.token,
    required this.ordinal,
    required this.wantsAnother,
    required this.wantsExisting,
    required this.customLabel,
  });
}

class RoomFlowChecklist {
  final bool hasProject;
  final bool hasImage;
  final String? room;
  final String? colorHex;

  const RoomFlowChecklist({
    required this.hasProject,
    required this.hasImage,
    required this.room,
    required this.colorHex,
  });

  bool get hasRoom => room != null && room!.trim().isNotEmpty;
  bool get hasColor => colorHex != null && colorHex!.trim().isNotEmpty;
}

class MeasurementCartData {
  final int paintBuckets;
  final int thermoSealPacks;

  const MeasurementCartData({
    required this.paintBuckets,
    required this.thermoSealPacks,
  });

  bool get hasItems => paintBuckets > 0 || thermoSealPacks > 0;
}
