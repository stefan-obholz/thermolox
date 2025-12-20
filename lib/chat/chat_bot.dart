import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../memory/memory_manager.dart';
import '../models/cart_model.dart';
import '../models/product.dart';
import '../models/project_models.dart';
import '../models/projects_model.dart';
import '../services/shopify_service.dart';
import '../widgets/attachment_sheet.dart';
import '../pages/cart_page.dart';
import '../theme/app_theme.dart';

/// Base-URL deines Cloudflare-Workers – identisch zum JS
const String kThermoloxApiBase =
    'https://thermolox-proxy.stefan-obholz.workers.dev';

/// =======================
///  MODEL-KLASSEN
/// =======================

class ChatMessage {
  final String role; // "user" oder "assistant"
  final String text;
  final List<QuickReplyButton>? buttons;

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
  });

  ChatMessage copyWith({
    String? role,
    String? text,
    List<QuickReplyButton>? buttons,
    dynamic content,
    List<String>? localImagePaths,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      buttons: buttons ?? this.buttons,
      content: content ?? this.content,
      localImagePaths: localImagePaths ?? this.localImagePaths,
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

  QuickReplyButton copyWith({bool? preferred, QuickReplyAction? action}) {
    return QuickReplyButton(
      label: label,
      value: value,
      preferred: preferred ?? this.preferred,
      action: action ?? this.action,
    );
  }
}

enum QuickReplyAction { send, uploadAttachment, goToCart }

class _FallbackButtons {
  final List<QuickReplyButton> buttons;
  final String key;

  const _FallbackButtons({required this.buttons, required this.key});
}

class _Attachment {
  final String path;
  final bool isImage;
  final String? name;

  const _Attachment({required this.path, required this.isImage, this.name});
}

class _SentUpload {
  final String id;
  final String name;
  final bool isImage;
  final String? localPath;
  final String? remoteUrl;

  const _SentUpload({
    required this.id,
    required this.name,
    required this.isImage,
    this.localPath,
    this.remoteUrl,
  });

  _SentUpload copyWith({String? remoteUrl}) {
    return _SentUpload(
      id: id,
      name: name,
      isImage: isImage,
      localPath: localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
    );
  }
}

/// =======================
///  CHATBOT WIDGET
/// =======================

class ThermoloxChatBot extends StatefulWidget {
  const ThermoloxChatBot({super.key});

  @override
  State<ThermoloxChatBot> createState() => _ThermoloxChatBotState();
}

class _ThermoloxChatBotState extends State<ThermoloxChatBot> {
  static List<ChatMessage> _cachedMessages = [];
  static List<_SentUpload> _cachedUploads = [];
  static Set<String> _cachedFallbacks = {};
  static String? _cachedCurrentProjectId;
  static bool _cachedGreetingRequested = false;
  static bool _cachedProjectPromptShown = false;
  static bool _cachedUploadPromptShown = false;

  static final RegExp _skillBlockRegex = RegExp(
    r'```skill\s+([\s\S]*?)```',
    multiLine: true,
  );
  static final RegExp _buttonBlockRegex = RegExp(
    r'```buttons?\s+([\s\S]*?)```',
    multiLine: true,
  );
  static final RegExp _inlineButtonsRegex = RegExp(
    r'BUTTONS\s*:\s*(\{[\s\S]*\})',
    multiLine: true,
    caseSensitive: false,
  );
  static final RegExp _hexColorRegex = RegExp(
    r'#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b',
  );

  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Anhänge, die ausgewählt wurden, aber noch nicht gesendet sind
  final List<_Attachment> _pendingAttachments = [];
  List<_SentUpload> _recentUploads = [];

  /// Produkte / Shop-Kontext für Skills
  List<Product> _products = [];
  bool _productsLoading = false;
  String? _productError;

  /// Memory
  late final MemoryManager _memoryManager;
  bool _memoryLoaded = false;

  bool _isSending = false;
  int? _streamingMsgIndex; // Index der gerade gestreamten Bot-Nachricht

  /// Ob der User aktuell „am unteren Rand“ des Chats ist.
  bool _autoScroll = true;

  /// Verhindert, dass Default-Buttons mehrfach für die gleiche Kategorie erscheinen.
  final Set<String> _shownFallbacks = {};
  bool _greetingRequested = false;
  String? _currentProjectId;
  bool _projectPromptShown = false;
  bool _projectPromptAttemptedInTurn = false;
  bool _uploadPromptShown = false;

  void _addAssistantMessage(String text, {List<QuickReplyButton>? buttons}) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'assistant',
          text: text,
          content: text,
          buttons: buttons,
        ),
      );
    });
    _scrollToBottom(animated: true);
  }

  @override
  void initState() {
    super.initState();
    _memoryManager = MemoryManager.withApiBase(apiBase: kThermoloxApiBase);

    // Scroll-Position beobachten, damit wir nur auto-scrollen,
    // wenn der User nicht manuell nach oben gescrollt hat.
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final atBottom = (pos.maxScrollExtent - pos.pixels) < 80;
      _autoScroll = atBottom;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGreetingIfNeeded();
    });

    if (_cachedMessages.isNotEmpty) {
      final isFreshStart = _cachedMessages.isEmpty;
      setState(() {
        _messages.addAll(_cachedMessages);
        _recentUploads = List<_SentUpload>.from(_cachedUploads);
        _shownFallbacks.addAll(_cachedFallbacks);
        _currentProjectId = _cachedCurrentProjectId;
        _greetingRequested = _cachedGreetingRequested;
        _projectPromptShown = _cachedProjectPromptShown;
        _uploadPromptShown = _cachedUploadPromptShown;
        if (isFreshStart) {
          _projectPromptShown = false;
          _projectPromptAttemptedInTurn = false;
          _uploadPromptShown = false;
        }
      });
    }

    // Falls schon Projekte existieren, Projekt-Fallback unterdrücken
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectsModel = context.read<ProjectsModel>();
      if (_currentProjectId == null && projectsModel.projects.isNotEmpty) {
        setState(() {
          _currentProjectId = projectsModel.projects.first.id;
          _uploadPromptShown = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _cachedMessages = List<ChatMessage>.from(_messages);
    _cachedUploads = List<_SentUpload>.from(_recentUploads);
    _cachedFallbacks = Set<String>.from(_shownFallbacks);
    _cachedCurrentProjectId = _currentProjectId;
    _cachedGreetingRequested = _greetingRequested;
    _cachedProjectPromptShown = _projectPromptShown;
    _cachedUploadPromptShown = _uploadPromptShown;

    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// =======================
  ///  HELFER
  /// =======================

  String _fileNameFromPath(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : path;
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

  Color _colorFromHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length < 6) {
      h = h.padRight(6, '0');
    }
    final val = int.tryParse(h.substring(0, 6), radix: 16) ?? 0x777777;
    return Color(0xFF000000 | val);
  }

  String _shorten(String? value, [int max = 200]) {
    if (value == null) return '';
    if (value.length <= max) return value;
    return '${value.substring(0, max)}...';
  }

  Future<void> _ensureMemoryLoaded() async {
    if (_memoryLoaded) return;
    await _memoryManager.load();
    if (!mounted) return;
    setState(() {
      _memoryLoaded = true;
    });
  }

  List<_SentUpload> _mergeUploads(List<_SentUpload> incoming) {
    const maxUploads = 15;
    final combined = [..._recentUploads, ...incoming];
    if (combined.length <= maxUploads) return combined;
    return combined.sublist(combined.length - maxUploads);
  }

  Future<void> _ensureProductsLoaded() async {
    if (_products.isNotEmpty || _productsLoading) return;

    setState(() {
      _productsLoading = true;
      _productError = null;
    });

    try {
      final fetched = await ShopifyService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = fetched;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productError = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _productsLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _skillContextSnapshot(
    CartModel cart,
    ProjectsModel projectsModel,
  ) {
    final products = _products
        .map(
          (p) => {
            'id': p.id,
            'title': p.title,
            'price': p.price,
            'description': _shorten(p.description, 180),
            'imageUrl': p.imageUrl,
          },
        )
        .toList();

    final cartItems = cart.items
        .map(
          (item) => {
            'productId': item.product.id,
            'title': item.product.title,
            'quantity': item.quantity,
          },
        )
        .toList();

    final projects = projectsModel.projects
        .map(
          (p) => {
            'id': p.id,
            'name': p.name,
            'items': p.items
                .map(
                  (i) => {
                    'id': i.id,
                    'name': i.name,
                    'type': i.type,
                    'hasLocal': i.path != null,
                    'hasRemote': i.url != null,
                  },
                )
                .toList(),
          },
        )
        .toList();

    final uploads = _recentUploads
        .map(
          (u) => {
            'id': u.id,
            'name': u.name,
            'isImage': u.isImage,
            'hasRemoteUrl': u.remoteUrl != null,
          },
        )
        .toList();

    return {
      'products': products,
      'cart': {'items': cartItems, 'totalPrice': cart.totalPrice},
      'projects': projects,
      'uploads': uploads,
      'notes': {
        'uploadHint': 'Nutze uploadId um frische Uploads zu adressieren.',
        'skills': [
          'add_to_cart',
          'add_project_item',
          'create_project',
          'rename_project',
          'rename_item',
          'move_item',
          'delete_item',
        ],
      },
      if (_productError != null) 'productError': _productError,
    };
  }

  Map<String, dynamic> _buildSkillSystemMessage(
    CartModel cart,
    ProjectsModel projectsModel,
  ) {
    final contextJson = jsonEncode(_skillContextSnapshot(cart, projectsModel));
    final instructions = '''
Name des Chatbots
THERMOLOX

⸻

Rolle und Identität

Du bist THERMOLOX, der offizielle digitale Farb-, Produkt- und Projektberater von THERMOLOX Systems.

Du begleitest Nutzer wie ein erfahrener Mensch durch ihr Projekt – ruhig, strukturiert, empathisch und kompetent.
Du bist kein klassischer Verkäufer, sondern ein Planungs-, Entscheidungs- und Umsetzungshelfer.

Deine Aufgabe ist es:
• Bedürfnisse zu verstehen
• Informationen gezielt zu sammeln
• Projekte sinnvoll aufzubauen
• Lösungen Schritt für Schritt zu entwickeln
• und erst dann passende Systemlösungen anzubieten

Produkte sind immer das Ergebnis guter Planung – niemals deren Ersatz.

Alles außerhalb von THERMOLOX Systems, Farbgestaltung, Projektplanung, Visualisierung und Produktanwendung ist für dich irrelevant.

⸻

Gesprächseinstieg

Diese Begrüßung erfolgt ausschließlich bei einer neuen Sitzung:

Hallo 👋, ich bin THERMOLOX, Dein persönlicher Farb- und Produktberater.
Ich helfe Dir, die perfekte Wand- und Deckenfarbe zu finden und Dein Projekt sinnvoll zu planen.
Was möchtest Du als Nächstes tun? 🎨

Während einer laufenden Unterhaltung wird nie erneut begrüßt.

⸻

Kommunikationsstil

Du sprichst immer in der freundlichen Du-Form.
Dein Ton ist ruhig, empathisch, aufmerksam und professionell.
Du klingst maximal menschlich, niemals werblich oder technisch.
Du formulierst klar, verständlich und emotional, ohne zu übertreiben.
Emojis setzt du gezielt und sparsam ein 🎨💡🏠✨
Deine Antworten sind übersichtlich, mit Absätzen und klarer Struktur.
Du führst das Gespräch aktiv, aber respektvoll.

Ziel jeder Antwort ist Vertrauen, Orientierung und Sicherheit – nicht Druck.

⸻

Spracherkennung

Du antwortest immer in der Sprache des Nutzers.
Wechselt der Nutzer die Sprache, wechselst du sofort mit – ohne Hinweis.
Der Gesprächsfaden bleibt logisch, inhaltlich und emotional erhalten.

⸻

Zwingende Dialogfortführung

Jede einzelne Antwort von THERMOLOX MUSS den Dialog aktiv fortführen.

Eine Antwort gilt nur dann als vollständig, wenn sie am Ende mindestens eines enthält:
• eine konkrete Frage
• oder einen BUTTONS-Block
• oder beides

Reine Abschlussaussagen ohne Frage oder Button sind verboten.
THERMOLOX darf niemals erwarten, dass der Nutzer von sich aus weiterschreibt.

⸻

Geführte Antwortvorschläge

Wann immer THERMOLOX eine Frage stellt, formuliert er – wenn sinnvoll – 1–2 mögliche Antworten vor.

Diese Antwortvorschläge dienen dazu:
• Tipparbeit zu sparen
• die Konversation zu strukturieren
• das Gespräch steuerbar zu halten

Der Nutzer darf jederzeit frei tippen.
Buttons sind eine Hilfe, keine Pflicht.

⸻

Gesprächsführung und Phasenlogik

THERMOLOX arbeitet strikt in dieser Reihenfolge:
  1. Entwurf
  2. Planung
  3. Berechnung
  4. System
  5. Warenkorb

Kein Schritt darf übersprungen werden.

⸻

Projekt-Trigger

Sobald der Nutzer
• einen konkreten Raum nennt
• oder eine konkrete Umsetzungsabsicht äußert

gilt dies als Projektstart.

In diesem Fall schlägst du sofort vor, ein Projekt anzulegen, bevor du Detailfragen stellst.

Beispiel:
„Das klingt nach einem konkreten Projekt. Ich lege das direkt für Dich an, damit wir sauber weiterarbeiten können.“

Danach MUSS ein Button folgen.

⸻

Führungs-Trigger bei Unentschlossenheit

Wenn der Nutzer keine klare Richtung vorgibt oder Unsicherheit zeigt:

Du formulierst neutral und natürlich, z. B.:
„Alles klar, dann lass uns weitermachen 😊“

Danach:
• gibst du eine klare Empfehlung
• erzeugst zwingend einen bevorzugten Button
• keine offenen Fragen ohne Button

Pflicht-CTA:

BUTTONS: {"buttons":[{"label":"Empfehle mir was","value":"Empfehle mir etwas Passendes","variant":"preferred"}]}

⸻

Bild- und Dokumentenlogik

Wenn ein Bild hochgeladen wird:
• du sagst explizit, dass du es dir ansiehst
• du beschreibst kurz, was du erkennst
• du blockierst den Dialog niemals

Wenn das Bild ungewöhnlich ist oder der Nutzer sagt „Das ist schon richtig“:
• akzeptierst du die Aussage
• wechselst sofort in den Entwurf-Modus
• führst aktiv weiter

Danach zwingend:

BUTTONS: {"buttons":[{"label":"Empfehle mir was","value":"Empfehle mir etwas Passendes","variant":"preferred"}]}

⸻

Farbempfehlungs-Logik (WICHTIG)

Wenn der Nutzer eine Farbe möchte oder „Vorschlagen“ wählt:

Du kannst Farben erzeugen und gibst sie immer als HEX-Code mit # aus.

❌ Du beschreibst keine Farben rein sprachlich
❌ Keine vagen Begriffe wie „warm“, „erdig“, „gemütlich“ ohne Daten

✅ Du empfiehlst immer konkrete Farbwerte

Pflichtformat:
• Name der Farbe (frei, intern)
• HEX-Code
• optional 1 kurzer Satz Wirkung

Beispiel:
• Warmes Braun – HEX #8B6A4F
• Sanftes Sandbraun – HEX #C2A27E

Nach jeder Farbempfehlung MUSS folgen:
• eine Frage
• und/oder Buttons zur Auswahl

⸻

Farb- und Mengenberechnung

Du kannst:
• Farbbedarf berechnen
• Deckkraft berücksichtigen
• Anzahl der Anstriche einschätzen
• THERMO-SEAL Bedarf ableiten

Bei Quadratmeterangaben gehst du von Wohnfläche aus.

Nach jeder Berechnung MUSS folgen:
• eine Entscheidungsfrage
• oder ein Warenkorb-Button

⸻

Produkt- und Systemlogik

THERMOLOX funktioniert ausschließlich als System.

Du erklärst immer:
• warum THERMO-COAT + THERMO-SEAL zusammengehören
• warum nur das System die volle Performance erreicht

Isolierte Produktempfehlungen ohne Systembezug sind verboten.

⸻

Verkaufslogik

Verkauf ist ein logischer Abschluss.
Kein harter Verkauf.
Kein vorschneller Warenkorb-Push.

Der Nutzer soll innerlich sagen:
„Jetzt ergibt das Sinn.“

⸻

Gesprächsgrenzen

Bei Abschweifungen leitest du freundlich zurück.
Bei Provokation bleibst du ruhig und fokussiert.

⸻

Rechtlicher Rahmen

Du triffst keine verbindlichen Zusagen.
Du nutzt ausschließlich sichere Formulierungen wie:
• Erfahrungsgemäß …
• Viele Kunden berichten …
• Individuelle Ergebnisse können variieren.

⸻

Skill-Aufrufe immer als JSON in einem ```skill``` Block senden.
Beispiele:
```skill
{"action":"add_to_cart","payload":{"productId":"<id>","quantity":2}}
```
```skill
{"action":"add_project_item","payload":{"projectId":"<id>","uploadId":"<uploadId>","name":"Decke","type":"image"}}
```
Verfügbare Skills: add_to_cart, add_project_item, create_project, rename_project, rename_item, move_item, delete_item.
Nach jedem Skill den Nutzer normal informieren.
Kontext (JSON): $contextJson

⸻
⸻⸻⸻
TECHNISCHE ANWEISUNGEN – UNVERÄNDERLICH
⸻⸻⸻

Dieser Abschnitt darf niemals verändert oder gekürzt werden.

Button-Logik

Buttons werden nur gerendert, wenn sie exakt so ausgegeben werden.

Buttons werden immer als Inline-JSON ausgegeben.
Kein Markdown.
Kein Codeblock.

Das Schlüsselwort BUTTONS: steht immer am Zeilenanfang.

Es werden ausschließlich gerade Anführungszeichen " verwendet.
Typografische Anführungszeichen sind verboten.

Beispiel:

BUTTONS: {"buttons":[{"label":"Foto hochladen","value":"Ich lade ein Raumfoto hoch","variant":"preferred","action":"upload"}]}

Button-Felder

label – sichtbarer Text
value – gesendete Nutzer-Nachricht
variant – preferred | primary
action – upload (nur bei Uploads)

Regeln

• Keine Nein-Buttons
• Maximal eine alternative Option
• Oft nur ein klarer CTA
• Bei Upload immer action:"upload"
• Bei Warenkorb/Kasse immer variant:"preferred"
• Klare Labels wie „Zum Warenkorb“ oder „System in den Warenkorb legen“

Nach jeder Button-Aktion bestätigst du die Handlung klar und menschlich, bevor du fortfährst.

⸻

Ende des Prompts
''';

    return {'role': 'system', 'content': instructions};
  }

  Map<String, dynamic> _buildMemorySystemMessage(String userText) {
    final state = _memoryManager.state;
    final notes = _memoryManager.relevantNotes(userText, max: 6);
    final relevant = notes
        .map(
          (n) => {
            'id': n.id,
            'text': _shorten(n.text, 200),
            'tags': n.tags,
            'score': n.score,
          },
        )
        .toList();

    final snapshot = {
      'runningSummary': _shorten(state.runningSummary, 400),
      'highlights': relevant,
    };

    final content =
        '''
Langzeitgedächtnis (kompakt, lokal):
${jsonEncode(snapshot)}
Nutze die Fakten für Konsistenz, erfinde nichts hinzu. Wenn keine Relevanz, ignoriere Highlights.
''';

    return {'role': 'system', 'content': content};
  }

  // ---- History → API-Payload (analog buildMessagesForApi in JS) ----
  List<Map<String, dynamic>> _buildMessagesForApi() {
    final history = _messages;

    final last20 = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    return last20
        .map(
          (m) => <String, dynamic>{
            'role': m.role,
            // JS: content: m.content ?? m.text
            'content': m.content ?? m.text,
          },
        )
        .toList();
  }

  void _appendAssistantDelta(String delta) {
    if (!mounted || delta.isEmpty) return;

    setState(() {
      if (_streamingMsgIndex == null) {
        _messages.add(
          ChatMessage(role: 'assistant', text: delta, content: delta),
        );
        _streamingMsgIndex = _messages.length - 1;
      } else {
        final current = _messages[_streamingMsgIndex!];
        final newText = current.text + delta;
        _messages[_streamingMsgIndex!] = current.copyWith(
          text: newText,
          content: newText,
        );
      }
    });

    _scrollToBottom(animated: false);
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!_autoScroll) return;

      final max = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  Future<void> _handleQuickReplyTap(
    QuickReplyButton option,
    int messageIndex,
  ) async {
    if (messageIndex >= 0 && messageIndex < _messages.length) {
      final msg = _messages[messageIndex];
      if (msg.buttons != null && msg.buttons!.isNotEmpty) {
        setState(() {
          _messages[messageIndex] = msg.copyWith(buttons: null);
        });
      }
    }
    if (option.action == QuickReplyAction.uploadAttachment) {
      await _openAttachmentMenu();
      await _sendMessage(quickReplyText: option.value);
      return;
    }
    if (option.action == QuickReplyAction.goToCart) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CartPage()));
      return;
    }
    await _sendMessage(quickReplyText: option.value);
  }

  List<Map<String, dynamic>> _parseSkillBlocks(String text) {
    final matches = _skillBlockRegex.allMatches(text);
    final List<Map<String, dynamic>> parsed = [];
    for (final m in matches) {
      final raw = m.group(1);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw.trim());
        if (decoded is Map<String, dynamic>) {
          parsed.add(decoded);
        }
      } catch (_) {
        // ignorieren
      }
    }
    return parsed;
  }

  List<QuickReplyButton> _parseButtonBlocks(String text) {
    final matches = _buttonBlockRegex.allMatches(text);
    final parsed = <QuickReplyButton>[];

    for (final m in matches) {
      final raw = m.group(1);
      if (raw == null) continue;
      parsed.addAll(_decodeButtons(raw));
    }

    // Inline Variante ohne Markdown: BUTTONS: {...}
    for (final m in _inlineButtonsRegex.allMatches(text)) {
      final raw = m.group(1);
      if (raw == null) continue;
      final decoded = _decodeButtons(raw);
      parsed.addAll(decoded);
    }

    if (parsed.isEmpty) return parsed;

    final normalized = <QuickReplyButton>[];
    for (final btn in parsed) {
      final preferred = btn.preferred || _isCheckoutLabel(btn.label);
      normalized.add(btn.copyWith(preferred: preferred));
    }

    final hasPreferred = normalized.any((b) => b.preferred);
    if (!hasPreferred && normalized.isNotEmpty) {
      normalized[0] = normalized[0].copyWith(preferred: true);
    }

    return normalized;
  }

  List<QuickReplyButton> _decodeButtons(String raw) {
    try {
      final normalized = _normalizeJsonQuotes(raw);
      final decoded = jsonDecode(normalized.trim());
      List<dynamic> entries = [];

      if (decoded is List) {
        entries = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final candidates =
            decoded['buttons'] ??
            decoded['options'] ??
            decoded['choices'] ??
            decoded['actions'];
        if (candidates is List) {
          entries = candidates;
        } else if (decoded.containsKey('label')) {
          entries = [decoded];
        }
      }

      final result = <QuickReplyButton>[];
      for (final entry in entries) {
        if (entry is! Map<String, dynamic>) continue;
        final labelRaw =
            (entry['label'] ??
                    entry['title'] ??
                    entry['text'] ??
                    entry['display'])
                ?.toString();
        if (labelRaw == null || labelRaw.trim().isEmpty) continue;
        final label = labelRaw.trim();
        final lowerLabel = label.toLowerCase();

        final valueRaw =
            (entry['value'] ?? entry['reply'] ?? entry['message'] ?? label)
                .toString();
        final value = valueRaw.trim().isEmpty ? label : valueRaw.trim();

        final variantRaw =
            (entry['variant'] ??
                    entry['tone'] ??
                    entry['type'] ??
                    entry['style'] ??
                    entry['kind'])
                ?.toString()
                .toLowerCase();

        final preferred =
            entry['preferred'] == true ||
            variantRaw == 'preferred' ||
            variantRaw == 'primary' ||
            variantRaw == 'cta' ||
            variantRaw == 'positive';

        final actionRaw =
            (entry['action'] ??
                    entry['intent'] ??
                    entry['kind'] ??
                    entry['type'])
                ?.toString()
                .toLowerCase();
        final isUpload =
            actionRaw == 'upload' ||
            actionRaw == 'attachment' ||
            actionRaw == 'upload_attachment' ||
            actionRaw == 'photo' ||
            actionRaw == 'image' ||
            actionRaw == 'file';
        final isCart = actionRaw == 'checkout' || actionRaw == 'cart';
        final action = isUpload
            ? QuickReplyAction.uploadAttachment
            : isCart
            ? QuickReplyAction.goToCart
            : QuickReplyAction.send;

        // Normalize „System in den Warenkorb legen“ → „In den Warenkorb“
        String normalizedLabel = label;
        String normalizedValue = value;
        if (lowerLabel.contains('system in den warenkorb')) {
          normalizedLabel = 'In den Warenkorb';
          normalizedValue = 'Bitte in den Warenkorb legen';
        }

        result.add(
          QuickReplyButton(
            label: normalizedLabel,
            value: normalizedValue,
            preferred: preferred || lowerLabel.contains('warenkorb'),
            action: action,
          ),
        );
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  String _normalizeJsonQuotes(String raw) {
    return raw.replaceAll(RegExp('[“”]'), '"').replaceAll(RegExp('[‘’]'), '"');
  }

  List<String> _extractHexColors(String text) {
    final matches = _hexColorRegex.allMatches(text);
    if (matches.isEmpty) return const [];
    final seen = <String>{};
    final result = <String>[];
    for (final match in matches) {
      final raw = match.group(0);
      if (raw == null) continue;
      final normalized = _normalizeHex(raw);
      if (seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  Color _onColorForBackground(Color color) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  void _showColorPreview(String hex) {
    final color = _colorFromHex(hex);
    final onColor = _onColorForBackground(color);

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'farbe',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, _, __) {
        final tokens = dialogContext.thermoloxTokens;
        return Material(
          color: color,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: tokens.gapSm,
                  right: tokens.gapSm,
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: Icon(Icons.close_rounded, color: onColor),
                  ),
                ),
                Center(
                  child: Text(
                    hex,
                    style: Theme.of(dialogContext).textTheme.headlineMedium
                        ?.copyWith(
                          color: onColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _FallbackButtons? _defaultButtonsForText(String text) {
    final lower = text.toLowerCase();
    final mentionsProject = lower.contains('projekt');
    final mentionsAdvice = lower.contains('beratung');
    final asksQuestion = lower.contains('?');
    final wantsUpload = _looksLikeUploadPrompt(lower);
    final wantsCart = _looksLikeCartPrompt(lower);
    final hasProject = _currentProjectId != null;
    final mentionsRoom =
        lower.contains('zimmer') ||
        lower.contains('wohnzimmer') ||
        lower.contains('schlafzimmer') ||
        lower.contains('küche') ||
        lower.contains('bad');
    final cartHasItems = context.read<CartModel>().items.isNotEmpty;
    final cartConfirmed =
        lower.contains('ist nun im warenkorb') ||
        lower.contains('liegt jetzt im warenkorb') ||
        lower.contains('warenkorb ist jetzt') ||
        lower.contains('im warenkorb hinzugefügt');

    if (!hasProject &&
        !_projectPromptAttemptedInTurn &&
        (mentionsProject || mentionsRoom)) {
      _projectPromptAttemptedInTurn = true;
      return _FallbackButtons(
        key: 'project_prompt',
        buttons: const [
          QuickReplyButton(
            label: 'Projekt starten',
            value: 'Ja, bitte ein neues Projekt anlegen',
            preferred: true,
          ),
          QuickReplyButton(
            label: 'Später',
            value: 'Lass uns erst Farben klären',
            preferred: false,
          ),
        ],
      );
    }

    if (!hasProject && (mentionsProject || mentionsAdvice) && asksQuestion) {
      return _FallbackButtons(
        key: 'project_advice',
        buttons: const [
          QuickReplyButton(
            label: 'Neues Projekt',
            value: 'Neues Projekt anlegen',
            preferred: true,
          ),
          QuickReplyButton(
            label: 'Farbberatung',
            value: 'Ich brauche eine Farbberatung',
            preferred: false,
          ),
        ],
      );
    }

    if (wantsUpload) {
      return _FallbackButtons(
        key: 'upload',
        buttons: const [
          QuickReplyButton(
            label: 'Foto hochladen',
            value: 'Ich lade ein Raumfoto hoch',
            preferred: true,
            action: QuickReplyAction.uploadAttachment,
          ),
          QuickReplyButton(
            label: 'Grundriss/Skizze',
            value: 'Ich lade einen Grundriss oder eine Skizze hoch',
            preferred: false,
            action: QuickReplyAction.uploadAttachment,
          ),
        ],
      );
    }

    if (wantsCart) {
      // Sobald etwas im Warenkorb ist → nur noch Checkout/Weiter einkaufen
      if (cartHasItems || cartConfirmed) {
        return const _FallbackButtons(
          key: 'checkout',
          buttons: [
            QuickReplyButton(
              label: 'Zur Kasse',
              value: 'Zur Kasse',
              preferred: true,
              action: QuickReplyAction.goToCart,
            ),
            QuickReplyButton(
              label: 'Weiter einkaufen',
              value: 'Weiter einkaufen',
              preferred: false,
            ),
          ],
        );
      }

      // Noch nichts drin → erst hinzufügen
      return const _FallbackButtons(
        key: 'checkout',
        buttons: [
          QuickReplyButton(
            label: 'In den Warenkorb',
            value: 'Bitte in den Warenkorb legen',
            preferred: true,
          ),
        ],
      );
    }

    return null;
  }

  bool _looksLikeUploadPrompt(String text) {
    final lower = text.toLowerCase();
    return lower.contains('foto') ||
        lower.contains('bild') ||
        lower.contains('grundriss') ||
        lower.contains('skizze') ||
        lower.contains('hochladen') ||
        lower.contains('upload');
  }

  bool _looksLikeCartPrompt(String text) {
    final lower = text.toLowerCase();
    return lower.contains('warenkorb') ||
        lower.contains('kasse') ||
        lower.contains('bestellen') ||
        lower.contains('checkout');
  }

  bool _isCheckoutLabel(String label) {
    final lower = label.toLowerCase();
    return lower.contains('warenkorb') ||
        lower.contains('kasse') ||
        lower.contains('checkout');
  }

  String _stripControlBlocks(String text) {
    return text
        .replaceAll(_skillBlockRegex, '')
        .replaceAll(_buttonBlockRegex, '')
        .replaceAll(_inlineButtonsRegex, '')
        .trim();
  }

  String _sanitizeAssistantText(String text) {
    var cleaned = _stripControlBlocks(text);
    cleaned = cleaned.replaceAll(RegExp(r'```[a-zA-Z]*'), '');
    cleaned = cleaned.replaceAll('```', '');
    cleaned = cleaned.replaceAll('**', '');
    cleaned = cleaned.replaceAll('__', '');
    cleaned = cleaned.replaceAll(RegExp(r'\n?[}\]]+$'), '').trimRight();
    final trimmed = cleaned.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      // Falls nur JSON/Code übrig ist, nicht anzeigen
      return '';
    }
    return cleaned.trim();
  }

  String _cleanAssistantDisplayText(String text) {
    var cleaned = text;
    cleaned = cleaned.replaceAll(_hexColorRegex, '');
    cleaned = cleaned.replaceAll(RegExp(r'\bhex\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(
      RegExp(r'[\-–—:]\s*(?=\n|$)'),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r' *\n *'), '\n');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  Future<void> _startGreetingIfNeeded() async {
    if (_greetingRequested || !mounted || _messages.isNotEmpty) return;
    _projectPromptShown = false;
    _projectPromptAttemptedInTurn = false;
    _uploadPromptShown = false;
    _greetingRequested = true;
    final prevSending = _isSending;
    setState(() {
      _isSending = true;
      _streamingMsgIndex = null;
    });

    await _ensureProductsLoaded();
    await _ensureMemoryLoaded();
    if (!mounted) return;
    final cart = context.read<CartModel>();
    final projectsModel = context.read<ProjectsModel>();

    final messagesForApi = [
      _buildMemorySystemMessage(''),
      _buildSkillSystemMessage(cart, projectsModel),
      {
        'role': 'user',
        'content': 'Starte die Unterhaltung mit deiner Begrüßung.',
      },
    ];

    final payload = <String, dynamic>{
      'model': 'gpt-4o',
      'temperature': 0.7,
      'messages': messagesForApi,
    };

    try {
      final uri = Uri.parse('$kThermoloxApiBase/chat');

      final req = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode(payload);

      final streamedRes = await http.Client().send(req);

      if (streamedRes.statusCode != 200) {
        final body = await streamedRes.stream.bytesToString();
        setState(() {
          _messages.add(
            ChatMessage(
              role: 'assistant',
              text: '❌ API-Fehler (${streamedRes.statusCode}):\n$body',
            ),
          );
        });
        _scrollToBottom(animated: true);
        return;
      }

      final decoder = utf8.decoder;
      String buffer = '';
      String fullText = '';

      await for (final chunk in streamedRes.stream.transform(decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final raw in lines) {
          final line = raw.trim();
          if (!line.startsWith('data:')) continue;

          final data = line.substring(5).trim();
          if (data == '[DONE]') continue;

          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta']?['content'] as String?;
            if (delta != null && delta.isNotEmpty) {
              fullText += delta;
              _appendAssistantDelta(delta);
            }
          } catch (_) {
            // ignorieren
          }
        }
      }

      await _processAssistantResponse(fullText);
      final cleanedAssistant = _sanitizeAssistantText(fullText);
      await _memoryManager.updateWithTurn(
        userText: '',
        assistantText: cleanedAssistant.isNotEmpty
            ? cleanedAssistant
            : fullText,
      );

      if (fullText.trim().isEmpty) {
        setState(() {
          _messages.add(
            const ChatMessage(
              role: 'assistant',
              text: '⚠️ Es kam keine verwertbare Antwort.',
            ),
          );
        });
        _scrollToBottom(animated: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            text: '❌ Fehler beim Laden der Begrüßung:\n$e',
          ),
        );
      });
      _scrollToBottom(animated: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = prevSending;
          _streamingMsgIndex = null;
        });
      }
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Product? _findProduct(String? id, String? title) {
    if (id != null) {
      try {
        return _products.firstWhere((p) => p.id == id);
      } catch (_) {}
    }
    if (title != null) {
      final lower = title.toLowerCase();
      try {
        return _products.firstWhere((p) => p.title.toLowerCase() == lower);
      } catch (_) {}
      try {
        return _products.firstWhere(
          (p) => p.title.toLowerCase().contains(lower),
        );
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _executeSkillCommand(Map<String, dynamic> cmd) async {
    if (!mounted) return null;

    final action = (cmd['action'] ?? cmd['skill'] ?? cmd['name']) as String?;
    final payload = (cmd['payload'] ?? cmd['args'] ?? <String, dynamic>{});

    if (action == null || payload is! Map<String, dynamic>) {
      return '⚠️ Aktion konnte nicht gelesen werden.';
    }

    switch (action) {
      case 'add_to_cart':
        final id = payload['productId'] as String? ?? payload['id'] as String?;
        final title = payload['title'] as String?;
        final qty = _toInt(payload['quantity']) ?? 1;
        final product = _findProduct(id, title);
        if (product == null) {
          return '⚠️ Produkt konnte nicht gefunden werden.';
        }
        final cart = context.read<CartModel>();
        for (var i = 0; i < qty; i++) {
          cart.add(product);
        }
        return '🛒 Produkt(e) in den Warenkorb gelegt.';

      case 'create_project':
        final name = (payload['name'] as String?)?.trim();
        if (name == null || name.isEmpty) {
          return '⚠️ Projekt konnte nicht angelegt werden (Name fehlt).';
        }
        final projectsModel = context.read<ProjectsModel>();
        final existing = projectsModel.projects.firstWhere(
          (p) => p.name.toLowerCase() == name.toLowerCase(),
          orElse: () => Project(id: '', name: '', items: []),
        );
        if (existing.id.isNotEmpty) {
          _currentProjectId = existing.id;
          _uploadPromptShown = false;
          _uploadPromptShown = true;
          _addAssistantMessage(
            '📁 Projekt "$name" existiert bereits – ich nutze das bestehende Projekt. Magst du mir ein Foto oder eine Skizze hochladen, damit ich gezielt beraten kann? 📸📄',
            buttons: const [
              QuickReplyButton(
                label: 'Foto hochladen',
                value: 'Ich lade ein Raumfoto hoch',
                preferred: true,
                action: QuickReplyAction.uploadAttachment,
              ),
              QuickReplyButton(
                label: 'Grundriss/Skizze',
                value: 'Ich lade einen Grundriss oder eine Skizze hoch',
                action: QuickReplyAction.uploadAttachment,
              ),
            ],
          );
          return '📁 Projekt "$name" existiert bereits – ich nutze das bestehende Projekt.';
        }
        final project = await projectsModel.addProject(name);
        _currentProjectId = project.id;
        _uploadPromptShown = false;
        _uploadPromptShown = true;
        _addAssistantMessage(
          'Perfekt, Projekt "$name" ist angelegt. Magst du mir ein Foto oder eine Skizze hochladen, damit ich gezielt beraten kann? 📸📄',
          buttons: const [
            QuickReplyButton(
              label: 'Foto hochladen',
              value: 'Ich lade ein Raumfoto hoch',
              preferred: true,
              action: QuickReplyAction.uploadAttachment,
            ),
            QuickReplyButton(
              label: 'Grundriss/Skizze',
              value: 'Ich lade einen Grundriss oder eine Skizze hoch',
              action: QuickReplyAction.uploadAttachment,
            ),
          ],
        );
        return '📁 Projekt angelegt.';

      case 'rename_project':
        final projectId = payload['projectId'] as String?;
        final newName = (payload['name'] as String?)?.trim();
        if (projectId == null || newName == null || newName.isEmpty) {
          return '⚠️ Projekt konnte nicht umbenannt werden.';
        }
        final projectsModel = context.read<ProjectsModel>();
        final exists = projectsModel.projects.any((p) => p.id == projectId);
        if (!exists) return '⚠️ Projekt wurde nicht gefunden.';
        await projectsModel.renameProject(projectId, newName);
        return '✏️ Projekt umbenannt.';

      case 'add_project_item':
        final projectId = payload['projectId'] as String?;
        if (projectId == null) {
          return '⚠️ Upload konnte nicht hinzugefügt werden.';
        }
        _currentProjectId = projectId;
        final projectsModel = context.read<ProjectsModel>();
        final exists = projectsModel.projects.any((p) => p.id == projectId);
        if (!exists) return '⚠️ Upload-Projekt nicht gefunden.';

        final uploadId = payload['uploadId'] as String?;
        final providedName = payload['name'] as String?;
        final typeRaw = (payload['type'] as String?)?.toLowerCase();
        String resolvedType =
            (typeRaw == 'image' || typeRaw == 'file' || typeRaw == 'other')
            ? typeRaw!
            : 'file';
        String? path = payload['path'] as String?;
        String? url = payload['url'] as String?;
        String? name = providedName;
        bool? isImageFromUpload;

        if (uploadId != null) {
          final upload = _recentUploads.firstWhere(
            (u) => u.id == uploadId,
            orElse: () => const _SentUpload(id: '', name: '', isImage: false),
          );
          if (upload.id.isNotEmpty) {
            path ??= upload.localPath;
            url ??= upload.remoteUrl;
            isImageFromUpload = upload.isImage;
            name ??= upload.name;
            if (typeRaw == null) {
              resolvedType = upload.isImage ? 'image' : 'file';
            }
          }
        }

        if ((isImageFromUpload ?? false) && resolvedType != 'image') {
          resolvedType = 'image';
        }

        if (path == null && url == null) {
          return '⚠️ Upload konnte nicht angelegt werden.';
        }

        name ??= 'Upload';

        await projectsModel.addItem(
          projectId: projectId,
          name: name,
          type: resolvedType,
          path: path,
          url: url,
        );
        return '📂 Upload hinzugefügt.';

      case 'rename_item':
        final itemId = payload['itemId'] as String?;
        final newName = (payload['name'] as String?)?.trim();
        if (itemId == null || newName == null || newName.isEmpty) {
          return '⚠️ Upload konnte nicht umbenannt werden.';
        }
        await context.read<ProjectsModel>().renameItem(itemId, newName);
        return '✏️ Upload umbenannt.';

      case 'move_item':
        final itemId = payload['itemId'] as String?;
        final targetProjectId = payload['targetProjectId'] as String?;
        if (itemId == null || targetProjectId == null) {
          return '⚠️ Upload konnte nicht verschoben werden.';
        }
        await context.read<ProjectsModel>().moveItem(
          itemId: itemId,
          targetProjectId: targetProjectId,
        );
        return '📦 Upload verschoben.';

      case 'delete_item':
        final itemId = payload['itemId'] as String?;
        if (itemId == null) return '⚠️ Upload konnte nicht gelöscht werden.';
        await context.read<ProjectsModel>().deleteItem(itemId);
        return '🗑️ Upload gelöscht.';

      default:
        return null; // still unsupported, but nicht anzeigen
    }
  }

  Future<String> _processAssistantResponse(String fullText) async {
    if (!mounted) return _stripControlBlocks(fullText);

    final commands = _parseSkillBlocks(fullText);
    var buttons = _parseButtonBlocks(fullText);

    final feedback = <String>[];
    for (final cmd in commands) {
      final note = await _executeSkillCommand(cmd);
      if (note != null && note.isNotEmpty) {
        feedback.add(note);
      }
    }

    final cleaned = _sanitizeAssistantText(fullText);
    var displayText = _cleanAssistantDisplayText(cleaned);
    if (displayText.isEmpty && feedback.isNotEmpty) {
      displayText = feedback.join('\n');
    }
    displayText = displayText.trim();

    if (buttons.isEmpty) {
      final fallback = _defaultButtonsForText(displayText);
      if (fallback != null) {
        final allowRepeat = fallback.key == 'checkout';
        final alreadyShown = _shownFallbacks.contains(fallback.key);
        if (!alreadyShown || allowRepeat) {
          buttons = fallback.buttons;
          if (fallback.key == 'project_prompt') {
            _projectPromptShown = true;
            _projectPromptAttemptedInTurn = true;
          }
          if (!allowRepeat) _shownFallbacks.add(fallback.key);
        }
      }
      // Notfall: Wenn kein Projekt existiert, keine Buttons geliefert wurden
      // und noch keine Projekt-Buttons in diesem Turn versucht wurden, zeige sie einmalig.
      if (buttons.isEmpty &&
          !_projectPromptAttemptedInTurn &&
          !_projectPromptShown &&
          _messages.length <= 1) {
        buttons = const [
          QuickReplyButton(
            label: 'Projekt starten',
            value: 'Ich möchte ein Projekt starten',
            preferred: true,
          ),
          QuickReplyButton(
            label: 'Farbberatung',
            value: 'Ich brauche eine Farbberatung',
            preferred: false,
          ),
        ];
        _projectPromptShown = true;
        _projectPromptAttemptedInTurn = true;
      }
    }

    // Nach Projektanlage immer Upload-CTA nachschieben, falls nicht geliefert.
    if (buttons.isEmpty && _currentProjectId != null && !_uploadPromptShown) {
      buttons = const [
        QuickReplyButton(
          label: 'Foto hochladen',
          value: 'Ich lade ein Raumfoto hoch',
          preferred: true,
          action: QuickReplyAction.uploadAttachment,
        ),
        QuickReplyButton(
          label: 'Grundriss/Skizze',
          value: 'Ich lade einen Grundriss oder eine Skizze hoch',
          action: QuickReplyAction.uploadAttachment,
        ),
      ];
      _uploadPromptShown = true;
    }

    if (_streamingMsgIndex != null &&
        _streamingMsgIndex! < _messages.length &&
        mounted) {
      setState(() {
        _messages[_streamingMsgIndex!] = _messages[_streamingMsgIndex!]
            .copyWith(
          text: displayText,
          content: cleaned,
          buttons: buttons.isNotEmpty ? buttons : null,
        );
      });
    }

    return displayText;
  }

  /// =======================
  ///  ANHANG-MENÜ (THERMOLOX STYLE)
  /// =======================

  Future<void> _openAttachmentMenu() async {
    final picked = await pickThermoloxAttachment(context);
    if (picked != null && mounted) {
      setState(() {
        _pendingAttachments.add(
          _Attachment(
            path: picked.path,
            isImage: picked.isImage,
            name: picked.name,
          ),
        );
      });
    }
  }

  /// =======================
  ///  SENDEN (Text + evtl. Anhänge)
  /// =======================

  Future<void> _sendMessage({String? quickReplyText}) async {
    if (_isSending) return;

    final rawText = quickReplyText ?? _inputController.text;
    final text = rawText.trim();
    final lower = text.toLowerCase();
    if (_currentProjectId == null &&
        (lower.contains('projekt') || lower.contains('zimmer'))) {
      // neue Projekt-Intention → CTA wieder zulassen, aber nur einmal pro Turn
      _projectPromptShown = false;
      _projectPromptAttemptedInTurn = false;
      _uploadPromptShown = false;
    }
    _projectPromptAttemptedInTurn = false;
    final hasFiles = _pendingAttachments.isNotEmpty;

    if (text.isEmpty && !hasFiles) return;

    final displayText = text.isNotEmpty
        ? text
        : (hasFiles ? 'Anhang gesendet' : '');

    // ==== 1) Bilder / Dateien hochladen ====
    final List<String> uploadedUrls = [];
    final List<_SentUpload> justUploaded = [];
    int uploadCounter = 0;

    if (hasFiles) {
      for (final att in List<_Attachment>.from(_pendingAttachments)) {
        final uploadId =
            'upl_${DateTime.now().microsecondsSinceEpoch}_${uploadCounter++}';
        var uploadRecord = _SentUpload(
          id: uploadId,
          name: att.name ?? _fileNameFromPath(att.path),
          isImage: att.isImage,
          localPath: att.path,
        );

        if (!att.isImage) {
          justUploaded.add(uploadRecord);
          continue; // nur Bilder für GPT-4o hochladen
        }

        try {
          final bytes = await File(att.path).readAsBytes();
          final rawBase64 = base64Encode(bytes);

          final lower = att.path.toLowerCase();
          final mime = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';

          final dataUrl = 'data:$mime;base64,$rawBase64';

          final uploadRes = await http.post(
            Uri.parse('$kThermoloxApiBase/upload'),
            body: {'base64': dataUrl},
          );

          if (uploadRes.statusCode != 200) {
            setState(() {
              _messages.add(
                ChatMessage(
                  role: 'assistant',
                  text:
                      '❌ Upload-Fehler (${uploadRes.statusCode}): ${uploadRes.body}',
                ),
              );
            });
            continue;
          }

          final data = jsonDecode(uploadRes.body);
          final imageUrl = data['imageUrl'] as String?;

          if (imageUrl != null && imageUrl.isNotEmpty) {
            uploadedUrls.add(imageUrl);
            uploadRecord = uploadRecord.copyWith(remoteUrl: imageUrl);
          }
        } catch (e) {
          setState(() {
            _messages.add(
              ChatMessage(
                role: 'assistant',
                text: '❌ Upload fehlgeschlagen: $e',
              ),
            );
          });
        } finally {
          justUploaded.add(uploadRecord);
        }
      }
    }

    // ===== 2) contentParts bauen (Text + image_url[]) =====
    final List<Map<String, dynamic>> contentParts = [];

    if (text.isNotEmpty) {
      contentParts.add({'type': 'text', 'text': text});
    }

    for (final url in uploadedUrls) {
      contentParts.add({
        'type': 'image_url',
        'image_url': {'url': url},
      });
    }

    final dynamic historyContent = contentParts.isNotEmpty
        ? contentParts
        : (text.isNotEmpty ? text : '');

    // ===== 3) User-Message im UI / History =====
    final List<String> localPaths = _pendingAttachments
        .where((a) => a.isImage)
        .map((a) => a.path)
        .toList();

    setState(() {
      _isSending = true;
      _messages.add(
        ChatMessage(
          role: 'user',
          text: displayText,
          content: historyContent,
          localImagePaths: localPaths,
        ),
      );
      if (justUploaded.isNotEmpty) {
        _recentUploads = _mergeUploads(justUploaded);
      }
      _inputController.clear();
      _pendingAttachments.clear();
      _streamingMsgIndex = null;
    });

    _scrollToBottom(animated: true);
    if (!mounted) return;

    // ===== 3b) Uploads direkt ins aktuelle Projekt hängen (falls gesetzt) =====
    if (_currentProjectId != null && justUploaded.isNotEmpty) {
      final projectsModel = context.read<ProjectsModel>();
      for (final upload in justUploaded) {
        await projectsModel.addItem(
          projectId: _currentProjectId!,
          name: upload.name,
          type: upload.isImage ? 'image' : 'file',
          path: upload.localPath,
          url: upload.remoteUrl,
        );
      }
    }

    // ===== 4) Payload → Worker =====
    await _ensureProductsLoaded();
    await _ensureMemoryLoaded();
    if (!mounted) return;
    final cart = context.read<CartModel>();
    final projectsModel = context.read<ProjectsModel>();

    final messagesForApi = [
      _buildMemorySystemMessage(text),
      _buildSkillSystemMessage(cart, projectsModel),
      ..._buildMessagesForApi(),
    ];

    final payload = <String, dynamic>{
      'model': 'gpt-4o',
      'temperature': 0.7,
      'messages': messagesForApi,
    };

    try {
      final uri = Uri.parse('$kThermoloxApiBase/chat');

      final req = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode(payload);

      final streamedRes = await http.Client().send(req);

      if (streamedRes.statusCode != 200) {
        final body = await streamedRes.stream.bytesToString();
        setState(() {
          _messages.add(
            ChatMessage(
              role: 'assistant',
              text: '❌ API-Fehler (${streamedRes.statusCode}):\n$body',
            ),
          );
        });
        _scrollToBottom(animated: true);
        return;
      }

      final decoder = utf8.decoder;
      String buffer = '';
      String fullText = '';

      await for (final chunk in streamedRes.stream.transform(decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final raw in lines) {
          final line = raw.trim();
          if (!line.startsWith('data:')) continue;

          final data = line.substring(5).trim();
          if (data == '[DONE]') continue;

          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta']?['content'] as String?;
            if (delta != null && delta.isNotEmpty) {
              fullText += delta;
              _appendAssistantDelta(delta);
            }
          } catch (_) {
            // ignorieren
          }
        }
      }

      await _processAssistantResponse(fullText);
      final cleanedAssistant = _sanitizeAssistantText(fullText);
      await _memoryManager.updateWithTurn(
        userText: text,
        assistantText: cleanedAssistant.isNotEmpty
            ? cleanedAssistant
            : fullText,
      );

      if (fullText.trim().isEmpty) {
        setState(() {
          _messages.add(
            const ChatMessage(
              role: 'assistant',
              text: '⚠️ Es kam keine verwertbare Antwort.',
            ),
          );
        });
        _scrollToBottom(animated: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            text: '❌ Fehler beim Laden der Antwort:\n$e',
          ),
        );
      });
      _scrollToBottom(animated: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _streamingMsgIndex = null;
        });
      }
    }
  }

  /// =======================
  ///  UI: Chat-Bubbles
  /// =======================

  Widget _buildBubble(ChatMessage msg, int messageIndex) {
    final isUser = msg.role == 'user';
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final bubbleMaxWidth = MediaQuery.of(context).size.width * 0.8;

    final buttons = msg.buttons ?? const <QuickReplyButton>[];
    final bg = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radiusValue = tokens.radiusLg;
    final radius = isUser
        ? BorderRadius.only(
            topLeft: Radius.circular(radiusValue),
            topRight: Radius.circular(radiusValue),
            bottomLeft: Radius.circular(radiusValue),
          )
        : BorderRadius.only(
            topLeft: Radius.circular(radiusValue),
            topRight: Radius.circular(radiusValue),
            bottomRight: Radius.circular(radiusValue),
          );

    const double maxPreviewWidth = 220;
    const double maxPreviewHeight = 220;

    final hasImages =
        msg.localImagePaths != null && msg.localImagePaths!.isNotEmpty;
    final hexSource =
        !isUser && msg.content is String ? msg.content as String : msg.text;
    final hexColors =
        !isUser ? _extractHexColors(hexSource) : const <String>[];

    return Column(
      crossAxisAlignment: align,
      children: [
        ChatBubbleAnimated(
          isUser: isUser,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: bg, borderRadius: radius),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (msg.text.isNotEmpty)
                    Text(
                      msg.text,
                      style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                    ),
                  if (hasImages) ...[
                    if (msg.text.isNotEmpty) const SizedBox(height: 8),
                    for (final path in msg.localImagePaths!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(tokens.radiusMd),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: maxPreviewWidth,
                              maxHeight: maxPreviewHeight,
                            ),
                            child: Image.file(File(path), fit: BoxFit.cover),
                          ),
                        ),
                      ),
                  ],
                  if (!isUser && hexColors.isNotEmpty) ...[
                    if (msg.text.isNotEmpty || hasImages)
                      const SizedBox(height: 10),
                    Wrap(
                      spacing: tokens.gapSm,
                      runSpacing: tokens.gapSm,
                      children: [
                        for (final hex in hexColors)
                          _ColorSwatchChip(
                            hex: hex,
                            color: _colorFromHex(hex),
                            onTap: () => _showColorPreview(hex),
                          ),
                      ],
                    ),
                  ],
                  if (!isUser && buttons.isNotEmpty) ...[
                    if (msg.text.isNotEmpty || hasImages)
                      const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final btn in buttons)
                          _QuickReplyChip(
                            button: btn,
                            onTap: () =>
                                _handleQuickReplyTap(btn, messageIndex),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// =======================
  ///  UI: Preview-Leiste für Anhänge
  /// =======================

  Widget _buildAttachmentPreview() {
    if (_pendingAttachments.isEmpty) return const SizedBox.shrink();
    final tokens = context.thermoloxTokens;

    return Container(
      height: 90,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.screenPadding,
        vertical: tokens.gapSm,
      ),
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingAttachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final att = _pendingAttachments[index];
          final isImage = att.isImage;

          Widget content;
          if (isImage) {
            content = Image.file(File(att.path), fit: BoxFit.cover);
          } else {
            content = Container(
              color: Colors.grey.shade200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.insert_drive_file, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      att.name ?? 'Datei',
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                child: AspectRatio(aspectRatio: 1, child: content),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _pendingAttachments.removeAt(index);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black87,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// =======================
  ///  BUILD
  /// =======================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.only(top: 0, bottom: 4),
            child: Image.asset(
              'assets/logos/THERMOLOX_SYSTEMS.png',
              height: 60,
              fit: BoxFit.contain,
            ),
          ),

          const Divider(height: 1),

          // CHAT-VERLAUF
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.screenPadding,
                vertical: tokens.screenPadding,
              ),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.role == 'user'
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: _buildBubble(msg, index),
                );
              },
            ),
          ),

          // PREVIEW-ZEILE FÜR ANHÄNGE
          _buildAttachmentPreview(),

          // INPUT-LEISTE
          Padding(
            padding: EdgeInsets.only(
              left: 2,
              right: 2,
              bottom: MediaQuery.of(context).viewInsets.bottom + 6,
              top: 2,
            ),
            child: Row(
              children: [
                // 📎 Regenbogen-Büroklammer
                const SizedBox(width: 2),
                _AttachmentIconButton(onTap: _openAttachmentMenu),
                const SizedBox(width: 6),

                const SizedBox(width: 2),

                // 📝 INPUT
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Nachricht an THERMOLOX …',
                      filled: true,
                      fillColor: Colors.white,
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusXl),
                        borderSide: BorderSide(
                          color: Colors.grey.shade400,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusXl),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // ✈ SEND
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.send_rounded,
                    size: 30,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: _isSending ? null : () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  final QuickReplyButton button;
  final VoidCallback onTap;

  const _QuickReplyChip({required this.button, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final isPreferred = button.preferred;

    final background = isPreferred ? theme.colorScheme.primary : Colors.white;
    final foreground = isPreferred
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.primary;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: background,
        foregroundColor: foreground,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          side: BorderSide(
            color: isPreferred
                ? background
                : theme.colorScheme.primary.withAlpha(217),
            width: 1.3,
          ),
        ),
        overlayColor: theme.colorScheme.primary.withAlpha(20),
      ),
      child: Text(
        button.label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ColorSwatchChip extends StatelessWidget {
  final String hex;
  final Color color;
  final VoidCallback onTap;

  const _ColorSwatchChip({
    required this.hex,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final labelColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.onSurface.withAlpha(36),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.gapXs),
          Text(
            hex,
            style: theme.textTheme.bodySmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
///  THERMOLOX KREIS-WIDGET (Kamera / Galerie / Datei)
/// =======================

class _AttachmentActionCircle extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentActionCircle({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_AttachmentActionCircle> createState() =>
      _AttachmentActionCircleState();
}

class _AttachmentActionCircleState extends State<_AttachmentActionCircle>
    with TickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    final tokens = ThermoloxTokens.light;
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringRotationDuration,
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringPulseDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.04).animate(
            CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(166),
                    blurRadius: 26,
                    spreadRadius: 3,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 🌈 rotierender Ring
                  RotationTransition(
                    turns: _rotationCtrl,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: tokens.rainbowRingGradient,
                        boxShadow: [
                          BoxShadow(
                            color: tokens.rainbowRingHaloColor,
                            blurRadius: tokens.rainbowRingHaloBlur,
                            spreadRadius: tokens.rainbowRingHaloSpread,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // innerer Kreis
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                  // Icon
                  Icon(widget.icon, size: 30, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// =======================
///  REGENBOGEN-BÜROKLAMMER
/// =======================

class _AttachmentIconButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AttachmentIconButton({super.key, required this.onTap});

  @override
  State<_AttachmentIconButton> createState() => _AttachmentIconButtonState();
}

class _AttachmentIconButtonState extends State<_AttachmentIconButton>
    with TickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    final tokens = ThermoloxTokens.light;

    _rotationCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringRotationDuration,
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringPulseDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;

    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.96,
        end: 1.04,
      ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut)),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(153),
                blurRadius: 20,
                spreadRadius: 3,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🌈 rotierender Ring
              RotationTransition(
                turns: _rotationCtrl,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: tokens.rainbowRingGradient,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.rainbowRingHaloColor,
                        blurRadius: tokens.rainbowRingHaloBlurSm,
                        spreadRadius: tokens.rainbowRingHaloSpreadSm,
                      ),
                    ],
                  ),
                ),
              ),
              // innerer Kreis
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.scaffoldBackgroundColor,
                ),
              ),
              // 📎 Icon
              Transform.rotate(
                angle: 0.25 * math.pi, // 0.25 = 45°, 0.5 = 90°, usw.
                child: Icon(
                  Icons.attach_file,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                  weight: 800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kleine iMessage-artige Aufpopp-Animation für jede Bubble.
class ChatBubbleAnimated extends StatefulWidget {
  final Widget child;
  final bool isUser;

  const ChatBubbleAnimated({
    super.key,
    required this.child,
    required this.isUser,
  });

  @override
  State<ChatBubbleAnimated> createState() => _ChatBubbleAnimatedState();
}

class _ChatBubbleAnimatedState extends State<ChatBubbleAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final tokens = ThermoloxTokens.light;
    _controller = AnimationController(
      vsync: this,
      duration: tokens.bubbleIntroDuration,
    );

    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    final beginOffset = widget.isUser
        ? const Offset(0.1, 0.05)
        : const Offset(-0.1, 0.05);
    _slide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
