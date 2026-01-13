import 'dart:convert';

import 'package:http/http.dart' as http;
import 'memory_state.dart';
import '../services/consent_service.dart';
import '../services/thermolox_api.dart';
import 'memory_storage.dart';

class MemoryRepository {
  Future<MemoryState> load() async {
    final raw = await MemoryStorage.read();
    if (raw == null || raw.isEmpty) return MemoryState.initial();
    return MemoryState.fromJson(raw);
  }

  Future<void> save(MemoryState state) async {
    await MemoryStorage.write(state.toJson());
  }

  Future<void> clear() async {
    await MemoryStorage.clear();
  }
}

class _ScoredNote {
  final MemoryNote note;
  final double score;

  _ScoredNote({required this.note, required this.score});
}

class MemoryManager {
  final MemoryRepository _repo;
  final String apiBase;
  MemoryState _state = MemoryState.initial();
  bool _loaded = false;

  MemoryManager({MemoryRepository? repository})
      : _repo = repository ?? MemoryRepository(),
        apiBase = '';

  MemoryManager.withApiBase({
    required this.apiBase,
    MemoryRepository? repository,
  }) : _repo = repository ?? MemoryRepository();

  MemoryState get state => _state;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _state = await _repo.load();
    _loaded = true;
  }

  List<MemoryNote> relevantNotes(String query, {int max = 6}) {
    if (query.isEmpty || _state.highlights.isEmpty) return const [];

    final words = query
        .toLowerCase()
        .split(RegExp(r'[^a-zA-Z0-9äöüÄÖÜß]+'))
        .where((w) => w.length > 2)
        .toSet();

    int overlap(MemoryNote note) {
      final textWords = note.text
          .toLowerCase()
          .split(RegExp(r'[^a-zA-Z0-9äöüÄÖÜß]+'))
          .where((w) => w.length > 2)
          .toSet();
      return words.intersection(textWords).length;
    }

    final now = DateTime.now();
    final scored = _state.highlights.map((note) {
      final recencyDays =
          now.difference(note.lastUsed).inDays.clamp(0, 30).toDouble();
      final recencyBoost = (30 - recencyDays) / 30.0; // 0..1
      final overlapScore = overlap(note).toDouble();
      final base = note.score;
      final total = base + overlapScore + recencyBoost;
      return _ScoredNote(note: note, score: total);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(max).map((e) => e.note).toList();
  }

  Future<void> updateWithTurn({
    required String userText,
    required String assistantText,
  }) async {
    if (!ConsentService.instance.aiAllowed) return;
    if (userText.trim().isEmpty && assistantText.trim().isEmpty) return;

    final updated = await _summarizeWithModel(
      userText: userText,
      assistantText: assistantText,
    );

    if (updated != null) {
      _state = updated.copyWith(updatedAt: DateTime.now());
      await _repo.save(_state);
    }
  }

  Future<void> clearLocal() async {
    _state = MemoryState.initial();
    _loaded = true;
    await _repo.clear();
  }

  Future<MemoryState?> _summarizeWithModel({
    required String userText,
    required String assistantText,
  }) async {
    final base = apiBase.isEmpty ? '' : apiBase;
    if (base.isEmpty) return null;
    final uri = Uri.parse('$base/chat');

    final systemPrompt = '''
Du bist der Memory-Summarizer für den THERMOLOX Chat. Halte Tokens klein.
Gib ausschließlich JSON im Format:
{"runningSummary":"...","highlights":[{"id":"...","text":"...","tags":["a"],"score":1.0}]}
Vorgaben:
- runningSummary max 400 Zeichen, ersetze oder ergänze das bestehende.
- highlights max 12, jeder text max 200 Zeichen.
- Verwende bestehende highlight-IDs, wenn weiter relevant, sonst neue.
- score zwischen 0.5 und 3.0 (höher = wichtiger).
Kein Fließtext, keine Erklärungen, nur das JSON.
''';

    final inputPayload = {
      'previousSummary': _state.runningSummary,
      'previousHighlights': _state.highlights.map((e) => e.toMap()).toList(),
      'user': userText,
      'assistant': assistantText,
    };

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': 0.2,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': jsonEncode(inputPayload)},
      ],
    });

    try {
      final res = await http.post(
        uri,
        headers: buildWorkerHeaders(contentType: 'application/json'),
        body: body,
      );

      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final content =
          choices.first['message']?['content'] as String? ?? '';
      if (content.isEmpty) return null;

      final jsonContent = jsonDecode(content) as Map<String, dynamic>;
      final summary = jsonContent['runningSummary'] as String? ?? '';
      final rawHighlights =
          jsonContent['highlights'] as List<dynamic>? ?? const [];

      final highlights = rawHighlights
          .map((e) => MemoryNote.fromMap(e as Map<String, dynamic>))
          .toList();

      return MemoryState(
        runningSummary: summary,
        highlights: highlights,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
