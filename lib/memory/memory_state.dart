import 'dart:convert';

class MemoryNote {
  final String id;
  final String text;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime lastUsed;
  final double score;

  const MemoryNote({
    required this.id,
    required this.text,
    required this.tags,
    required this.createdAt,
    required this.lastUsed,
    required this.score,
  });

  MemoryNote copyWith({
    String? id,
    String? text,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? lastUsed,
    double? score,
  }) {
    return MemoryNote(
      id: id ?? this.id,
      text: text ?? this.text,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'tags': tags,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'lastUsed': lastUsed.millisecondsSinceEpoch,
        'score': score,
      };

  factory MemoryNote.fromMap(Map<String, dynamic> map) {
    return MemoryNote(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      tags: (map['tags'] as List<dynamic>? ?? const []).cast<String>(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      lastUsed: DateTime.fromMillisecondsSinceEpoch(
          (map['lastUsed'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      score: (map['score'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class MemoryState {
  final String runningSummary;
  final List<MemoryNote> highlights;
  final DateTime updatedAt;

  const MemoryState({
    required this.runningSummary,
    required this.highlights,
    required this.updatedAt,
  });

  factory MemoryState.initial() => MemoryState(
        runningSummary: '',
        highlights: const [],
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  MemoryState copyWith({
    String? runningSummary,
    List<MemoryNote>? highlights,
    DateTime? updatedAt,
  }) {
    return MemoryState(
      runningSummary: runningSummary ?? this.runningSummary,
      highlights: highlights ?? this.highlights,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'runningSummary': runningSummary,
        'highlights': highlights.map((e) => e.toMap()).toList(),
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory MemoryState.fromMap(Map<String, dynamic> map) {
    final rawHighlights = map['highlights'] as List<dynamic>? ?? const [];
    return MemoryState(
      runningSummary: map['runningSummary'] as String? ?? '',
      highlights: rawHighlights
          .map((e) => MemoryNote.fromMap(e as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MemoryState.fromJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return MemoryState.fromMap(decoded);
    } catch (_) {
      return MemoryState.initial();
    }
  }
}
