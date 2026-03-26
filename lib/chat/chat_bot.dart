import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../pages/ar_wall_paint_page.dart';
import '../services/lidar_service.dart';
import 'package:flutter/rendering.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../controllers/plan_controller.dart';
import '../controllers/virtual_room_credit_manager.dart';
import '../memory/memory_manager.dart';
import '../models/cart_model.dart';
import '../models/product.dart';
import '../models/project_models.dart';
import '../models/projects_model.dart';
import '../pages/settings_page.dart';
import '../services/shopify_service.dart';
import '../services/consent_service.dart';
import '../services/credit_service.dart';
import '../services/image_edit_service.dart';
import '../services/everloxx_api.dart';
import '../utils/everloxx_overlay.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/mask_editor_page.dart';
import '../widgets/image_preview_page.dart';
import '../pages/cart_page.dart';
import '../theme/app_theme.dart';
import 'chat_models.dart';

/// =======================
///  MODEL-KLASSEN (shared models in chat_models.dart)
/// =======================

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

class EverloxxChatBot extends StatefulWidget {
  const EverloxxChatBot({super.key});

  static void clearCache() {
    _EverloxxChatBotState._cachedMessages = [];
    _EverloxxChatBotState._cachedUploads = [];
    _EverloxxChatBotState._cachedFallbacks = {};
    _EverloxxChatBotState._cachedCurrentProjectId = null;
    _EverloxxChatBotState._cachedGreetingRequested = false;
    _EverloxxChatBotState._cachedProjectPromptShown = false;
    _EverloxxChatBotState._cachedUploadPromptShown = false;
    _EverloxxChatBotState._cachedVoiceModeActive = false;
  }

  @override
  State<EverloxxChatBot> createState() => _EverloxxChatBotState();
}

class _EverloxxChatBotState extends State<EverloxxChatBot>
    with TickerProviderStateMixin {
  static List<ChatMessage> _cachedMessages = [];
  static List<_SentUpload> _cachedUploads = [];
  static Set<String> _cachedFallbacks = {};
  static String? _cachedCurrentProjectId;
  static bool _cachedGreetingRequested = false;
  static bool _cachedProjectPromptShown = false;
  static bool _cachedUploadPromptShown = false;
  static bool _cachedVoiceModeActive = false;

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
  static final RegExp _hexColorLooseRegex = RegExp(
    r'(?<![0-9a-fA-F])#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})(?![0-9a-fA-F])',
  );
  static const int _minVoiceMs = 650;
  static const String _renderingHintToken = '__rendering__';
  static const Map<String, String> _colorKeywordMap = {
    'rot': 'Rot',
    'bordeaux': 'Rot',
    'weinrot': 'Rot',
    'blau': 'Blau',
    'hellblau': 'Blau',
    'dunkelblau': 'Blau',
    'gruen': 'Grün',
    'grün': 'Grün',
    'hellgruen': 'Grün',
    'hellgrün': 'Grün',
    'dunkelgruen': 'Grün',
    'dunkelgrün': 'Grün',
    'gelb': 'Gelb',
    'orange': 'Orange',
    'pink': 'Pink',
    'rosa': 'Rosa',
    'lila': 'Lila',
    'violett': 'Violett',
    'beige': 'Beige',
    'grau': 'Grau',
    'hellgrau': 'Grau',
    'lichtgrau': 'Grau',
    'dunkelgrau': 'Grau',
    'schwarz': 'Schwarz',
    'weiss': 'Weiß',
    'weiß': 'Weiß',
    'braun': 'Braun',
    'tuerkis': 'Türkis',
    'türkis': 'Türkis',
    'cyan': 'Cyan',
  };

  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _voiceBarKey = GlobalKey();

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
  String? _queuedTranscript;

  /// Ob der User aktuell „am unteren Rand“ des Chats ist.
  bool _autoScroll = true;
  bool _userHasScrolled = false;

  /// Verhindert, dass Default-Buttons mehrfach für die gleiche Kategorie erscheinen.
  final Set<String> _shownFallbacks = {};
  bool _greetingRequested = false;
  String? _currentProjectId;
  bool _projectPromptShown = false;
  bool _projectPromptAttemptedInTurn = false;
  bool _uploadPromptShown = false;
  bool _consentPromptShown = false;
  bool _voiceConsentPromptShown = false;
  late final ConsentService _consentService;
  bool _lastAiAllowed = false;

  bool _hasInputText = false;
  bool _voiceModeActive = false;
  bool _voicePressActive = false;
  String? _lastDetectedHex;
  bool _isStartingRecording = false;
  bool _pendingStopAfterStart = false;
  DateTime? _recordingStartedAt;
  double _voiceBarHeight = 0;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isSpeaking = false;
  bool _isTtsLoading = false;
  bool _ttsNoticeShown = false;
  bool _enableVoiceOutput = false;
  double _lastInputLevel = 0.0;
  AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  String? _recordingPath;
  final GlobalKey _voiceButtonKey = GlobalKey();
  final math.Random _voiceRand = math.Random();
  double _voiceVizLevel = 0.0;
  Timer? _voiceVizTimer;
  late final AudioPlayer _ttsPlayer;
  late final AnimationController _voiceRingCtrl;
  late final AnimationController _voicePulseCtrl;
  final ImageEditService _imageEditService = const ImageEditService();
  late final VirtualRoomCreditManager _renderCreditManager;
  bool _isRenderBusy = false;
  bool _renderCreditsConsumed = false;
  Uint8List? _pendingRenderImageBytes;
  Uint8List? _pendingRenderMaskBytes;
  String? _pendingRenderPrompt;
  ui.Size? _pendingRenderImageSize;

  void _resetVoiceFlags() {
    _isStartingRecording = false;
    _pendingStopAfterStart = false;
    _voicePressActive = false;
    _recordingStartedAt = null;
  }

  Future<void> _cancelRecorderSafely() async {
    try {
      await _audioRecorder.cancel();
    } catch (_) {}
  }

  Future<void> _resetRecorderInstance() async {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    try {
      await _audioRecorder.cancel();
    } catch (_) {}
    try {
      await _audioRecorder.dispose();
    } catch (_) {}
    _audioRecorder = AudioRecorder();
  }

  Future<void> _flushQueuedTranscript() async {
    if (_isSending) return;
    final queued = _queuedTranscript;
    if (queued == null || queued.trim().isEmpty) return;
    _queuedTranscript = null;
    await _sendMessage(quickReplyText: queued.trim());
  }

  void _addAssistantMessage(
    String text, {
    List<QuickReplyButton>? buttons,
    List<String>? localImagePaths,
  }) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'assistant',
          text: text,
          content: text,
          buttons: buttons,
          localImagePaths: localImagePaths,
        ),
      );
    });
    _scrollToBottom(animated: true);
  }

  bool _ensureAiConsent() {
    final consent = context.read<ConsentService>();
    if (consent.aiAllowed) return true;
    _showAiConsentPrompt();
    return false;
  }

  Future<bool> _ensureChatAccess() async {
    // Chat is free for all users
    return true;
  }

  void _showAiConsentPrompt() {
    if (_consentPromptShown) return;
    final hasExisting = _messages.any(
      (msg) =>
          (msg.buttons ?? const <QuickReplyButton>[])
              .any((b) => b.action == QuickReplyAction.acceptAllConsents),
    );
    if (hasExisting) {
      _consentPromptShown = true;
      return;
    }
    _consentPromptShown = true;
    const message =
        'Ich nutze KI, um dir bei Analysen und Bildern zu helfen.\n'
        'Zusätzlich nutze ich Analytics zur Produktverbesserung (180 Tage).\n'
        'Darf ich das für dich tun?';
    _addAssistantMessage(
      message,
      buttons: const [
        QuickReplyButton(
          label: '✅ Ja, alles aktivieren',
          value: 'Ich stimme allen optionalen Einwilligungen zu.',
          preferred: true,
          action: QuickReplyAction.acceptAllConsents,
        ),
      ],
    );
  }

  Future<bool> _ensureVoiceConsent() async {
    final consent = context.read<ConsentService>();
    if (consent.aiAllowed) return true;
    if (_voiceConsentPromptShown) {
      _showSnack(
        'Spracherkennung ist deaktiviert. Du kannst sie in Einstellungen aktivieren.',
      );
      return false;
    }
    _voiceConsentPromptShown = true;

    final approved = await EverloxxOverlay.showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spracherkennung'),
        content: const Text(
          'Für die Spracherkennung senden wir deine Audioaufnahme an OpenAI (Cloud). '
          'Möchtest du das erlauben?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Verzichten'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Zustimmen'),
          ),
        ],
      ),
    );

    if (approved == true) {
      await consent.setAiAllowed(true);
      if (!mounted) return false;
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _memoryManager = MemoryManager.withApiBase(apiBase: kEverloxxApiBase);
    _consentService = context.read<ConsentService>();
    _lastAiAllowed = _consentService.aiAllowed;
    _consentService.addListener(_handleConsentChange);
    _inputController.addListener(_handleInputTextChanged);
    _renderCreditManager = VirtualRoomCreditManager(
      consume: ({required amount, required requestId}) =>
          context.read<CreditService>().consumeCredit(
                amount: amount,
                requestId: requestId,
              ),
    );

    _ttsPlayer = AudioPlayer();
    _ttsPlayer.setReleaseMode(ReleaseMode.stop);
    _ttsPlayer.onPlayerComplete.listen((_) {
      _stopSpeaking();
    });

    final tokens = EverloxxTokens.light;
    _voiceRingCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringRotationDuration,
    )..repeat();
    _voicePulseCtrl = AnimationController(
      vsync: this,
      duration: tokens.ringPulseDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    // Scroll-Position beobachten, damit wir nur auto-scrollen,
    // wenn der User nicht manuell nach oben gescrollt hat.
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final atBottom = (pos.maxScrollExtent - pos.pixels) < 80;
      if (atBottom) {
        _autoScroll = true;
        _userHasScrolled = false;
      } else if (_userHasScrolled) {
        _autoScroll = false;
      } else {
        _autoScroll = true;
      }
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
        _voiceModeActive = _cachedVoiceModeActive;
        if (isFreshStart) {
          _projectPromptShown = false;
          _projectPromptAttemptedInTurn = false;
          _uploadPromptShown = false;
        }
      });
    } else {
      _voiceModeActive = _cachedVoiceModeActive;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScroll = true;
      _scrollToBottom(animated: false);
    });

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
    _consentService.removeListener(_handleConsentChange);
    _cachedMessages = List<ChatMessage>.from(_messages);
    _cachedUploads = List<_SentUpload>.from(_recentUploads);
    _cachedFallbacks = Set<String>.from(_shownFallbacks);
    _cachedCurrentProjectId = _currentProjectId;
    _cachedGreetingRequested = _greetingRequested;
    _cachedProjectPromptShown = _projectPromptShown;
    _cachedUploadPromptShown = _uploadPromptShown;
    _cachedVoiceModeActive = _voiceModeActive;

    _inputController.removeListener(_handleInputTextChanged);
    _voiceVizTimer?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    _ttsPlayer.dispose();
    _voiceRingCtrl.dispose();
    _voicePulseCtrl.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleConsentChange() {
    final allowed = _consentService.aiAllowed;
    if (_lastAiAllowed && !allowed) {
      _memoryManager.clearLocal();
      _consentPromptShown = false;
    } else if (!_lastAiAllowed && allowed) {
      _consentPromptShown = false;
    }
    _lastAiAllowed = allowed;
  }

  void _handleInputTextChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (hasText == _hasInputText) return;
    setState(() {
      _hasInputText = hasText;
    });
  }

  Future<void> _handleMicTap() async {
    if (_isSending || _isTranscribing) return;
    final chatOk = await _ensureChatAccess();
    if (!chatOk) return;
    if (!mounted) return;
    final consentOk = await _ensureVoiceConsent();
    if (!consentOk) return;
    if (!mounted) return;
    _enterVoiceMode();
  }

  Future<bool> _showPremiumGate({required String featureName}) async {
    // Only Projekte and Virtuelle Raumgestaltung are premium
    final premiumFeatures = ['Projekte', 'Virtuelle Raumgestaltung'];
    if (!premiumFeatures.contains(featureName)) return true;

    final planController = context.read<PlanController>();
    if (planController.isPro) return true;

    await EverloxxOverlay.showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('EVERLOXX', style: TextStyle(fontFamily: 'Times New Roman', fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            const SizedBox(width: 8),
            const Text('Premium'),
          ],
        ),
        content: Text('$featureName ist ein Premium-Feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _ensureRecordingReady() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      _showSnack(
        'Bitte in iOS Einstellungen > EVERLOXX Mikrofon erlauben.',
      );
      return false;
    }
    return true;
  }

  Future<String?> _transcribeRecording(String path) async {
    try {
      final uri = Uri.parse('$kEverloxxApiBase/stt');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(buildWorkerHeaders());
      request.fields['model'] = 'gpt-4o-mini-transcribe';
      request.fields['temperature'] = '0';
      request.fields['response_format'] = 'json';

      request.files.add(await http.MultipartFile.fromPath('file', path));

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(body);
        if (data is Map<String, dynamic>) {
          final text = data['text'];
          if (text is String && text.trim().isNotEmpty) {
            return text.trim();
          }
        }
        return null;
      }

      String? errorMessage;
      try {
        final data = jsonDecode(body);
        if (data is Map<String, dynamic>) {
          final error = data['error'];
          if (error is Map<String, dynamic>) {
            errorMessage = error['message']?.toString();
          } else if (error != null) {
            errorMessage = error.toString();
          }
        }
      } catch (_) {
        errorMessage = null;
      }
      _showSnack(errorMessage ?? 'Spracherkennung fehlgeschlagen.');
      return null;
    } catch (_) {
      _showSnack('Spracherkennung fehlgeschlagen.');
      return null;
    }
  }

  void _resetRenderPending() {
    _pendingRenderImageBytes = null;
    _pendingRenderMaskBytes = null;
    _pendingRenderPrompt = null;
    _pendingRenderImageSize = null;
    _renderCreditsConsumed = false;
  }

  Project? _currentProject() {
    final projectId = _currentProjectId;
    if (projectId == null) return null;
    try {
      return context.read<ProjectsModel>().projects.firstWhere(
            (p) => p.id == projectId,
          );
    } catch (_) {
      return null;
    }
  }

  ProjectItem? _currentProjectImageItem() {
    final project = _currentProject();
    if (project == null) return null;
    try {
      return project.items.firstWhere((i) => i.type == 'image');
    } catch (_) {
      return null;
    }
  }

  String? _currentProjectColorHex() {
    final project = _currentProject();
    if (project == null) return null;
    try {
      final colorItem = project.items.firstWhere((i) => i.type == 'color');
      final hex = colorItem.name.trim();
      if (hex.isEmpty) return null;
      return _normalizeHex(hex);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _loadImageBytes(ProjectItem item) async {
    final path = item.path;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    }
    final url = item.url;
    if (url == null || url.isEmpty) {
      throw StateError('Missing image source');
    }
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw StateError('Image download failed');
    }
    return res.bodyBytes;
  }

  Future<Uint8List> _ensurePng(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data?.buffer.asUint8List() ?? bytes;
    } catch (_) {
      return bytes;
    }
  }

  Future<ui.Size> _readImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return ui.Size(image.width.toDouble(), image.height.toDouble());
  }

  Future<Uint8List> _resizeToMatch(Uint8List bytes, ui.Size target) async {
    try {
      if (target.width <= 0 || target.height <= 0) return bytes;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = Paint();
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final dst = Rect.fromLTWH(0, 0, target.width, target.height);
      canvas.drawImageRect(image, src, dst, paint);
      final picture = recorder.endRecording();
      final outImage = await picture.toImage(
        target.width.round(),
        target.height.round(),
      );
      final data = await outImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data?.buffer.asUint8List() ?? bytes;
    } catch (_) {
      return bytes;
    }
  }

  Future<String> _writeTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final file = File('${dir.path}/render_$stamp.png');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _buildRenderPrompt(String hex, String userHint) {
    final hint = userHint.trim().isEmpty
        ? ''
        : ' Nutzerwunsch: "$userHint".';
    return 'Edit only the masked wall areas. Paint them with color $hex.'
        ' Ignore all unmasked areas, even if they are walls.'
        ' Preserve texture, lighting, and perspective.'
        ' Do not change ceiling, floor, furniture, windows, doors, or trim.'
        '$hint';
  }

  Future<void> _showRenderCreditsPaywall() async {
    final shouldOpen = await EverloxxOverlay.showAppDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Visualisierungen aufgebraucht'),
          content: const Text(
            'Du hast keine Visualisierungen mehr. '
            '10 neue Visualisierungen kosten 9,90€.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Später'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Visualisierungen kaufen'),
            ),
          ],
        );
      },
    );

    if (shouldOpen == true) {
      if (!mounted) return;
      EverloxxOverlay.showSnack(
        context,
        'Nachkauf ist noch nicht verfügbar.',
      );
    }
  }

  void _showRenderRetryMessage() {
    _addAssistantMessage(
      'Beim Rendern ist etwas schiefgelaufen. Soll ich es erneut versuchen?',
      buttons: const [
        QuickReplyButton(
          label: 'Erneut versuchen',
          value: 'Bitte erneut versuchen',
          preferred: true,
          action: QuickReplyAction.startRender,
        ),
      ],
    );
  }

  void _showRenderHint() {
    if (!mounted) return;
    final exists = _messages.any((m) => m.text == _renderingHintToken);
    if (exists) return;
    setState(() {
      _messages.add(
        const ChatMessage(
          role: 'assistant',
          text: _renderingHintToken,
          excludeFromApi: true,
        ),
      );
    });
    _scrollToBottom(animated: true);
  }

  void _removeRenderHint() {
    if (!mounted) return;
    final index =
        _messages.indexWhere((m) => m.text == _renderingHintToken);
    if (index < 0) return;
    setState(() {
      _messages.removeAt(index);
    });
  }

  Future<void> _startARWallPaint() async {
    // Gate: LiDAR required
    final hasLidar = await LidarService.isAvailable();
    if (!hasLidar) {
      _addAssistantMessage(
        'Die AR-Wandfarbe benötigt ein iPhone Pro mit LiDAR-Sensor. '
        'Aber ich kann dir dein Foto virtuell einfärben — das funktioniert auf allen Geräten! 🎨',
        buttons: [
          QuickReplyButton(
            label: 'Foto einfärben',
            value: 'Ich möchte ein Foto virtuell einfärben',
            preferred: true,
            action: QuickReplyAction.uploadAttachment,
          ),
        ],
      );
      return;
    }

    // Ensure project exists
    if (!mounted) return;
    final projectsModel = context.read<ProjectsModel>();
    var projectId = _currentProjectId ?? _cachedCurrentProjectId;
    if (projectId == null || projectId.isEmpty) {
      // Auto-create project
      final name = 'AR Wandfarbe ${DateTime.now().day}.${DateTime.now().month}';
      await projectsModel.addProject(name);
      if (!mounted) return;
      final projects = projectsModel.projects;
      if (projects.isNotEmpty) {
        projectId = projects.last.id;
        _currentProjectId = projectId;
        _cachedCurrentProjectId = projectId;
      }
    }
    if (projectId == null || projectId.isEmpty) {
      _addAssistantMessage('Es gab ein Problem beim Erstellen des Projekts. Bitte versuche es erneut.');
      return;
    }
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ARWallPaintPage(projectId: projectId!),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      _addAssistantMessage(
        'Super! Die AR-Vorschau ist gespeichert. 🏠✨ Wie gefällt dir das Ergebnis?',
        buttons: [
          QuickReplyButton(
            label: 'Farbe passt perfekt',
            value: 'Die Farbe passt, ich möchte bestellen',
            preferred: true,
          ),
          QuickReplyButton(
            label: 'Andere Farbe',
            value: 'Schlage mir eine andere Farbe vor',
          ),
        ],
      );
    } else {
      _addAssistantMessage(
        'Kein Problem! Möchtest du es nochmal versuchen oder eine andere Visualisierung nutzen?',
        buttons: [
          QuickReplyButton(
            label: 'AR nochmal starten',
            value: 'AR Wandfarbe nochmal starten',
            preferred: true,
            action: QuickReplyAction.arWallPaint,
          ),
          QuickReplyButton(
            label: 'Foto einfärben',
            value: 'Ich möchte ein Foto virtuell einfärben',
            action: QuickReplyAction.uploadAttachment,
          ),
        ],
      );
    }
  }

  Future<void> _startVirtualRoomRenderFromChat({bool isRetry = false}) async {
    if (_isRenderBusy) return;
    if (!_ensureAiConsent()) return;

    final planController = context.read<PlanController>();
    if (!planController.isPro) {
      await _showPremiumGate(featureName: 'Virtuelle Raumgestaltung');
      return;
    }
    final projectsModel = context.read<ProjectsModel>();
    if (_currentProjectId == null || _currentProject() == null) {
      if (projectsModel.projects.isNotEmpty) {
        _currentProjectId = projectsModel.projects.first.id;
      }
    }

    final reusePending =
        isRetry ||
        (_pendingRenderMaskBytes != null &&
            _pendingRenderPrompt != null &&
            _pendingRenderImageBytes != null);

    if (!reusePending) {
      _resetRenderPending();
      var project = _currentProject();
      if (project == null) {
        _addAssistantMessage(
          'Bitte lege zuerst ein Projekt an, damit ich das Bild zuordnen kann.',
          buttons: const [
            QuickReplyButton(
              label: 'Projekt starten',
              value: 'Ich möchte ein Projekt starten',
              preferred: true,
            ),
          ],
        );
        return;
      }

      final imageItem = _currentProjectImageItem();
      if (imageItem == null) {
        _addAssistantMessage(
          'Bitte lade zuerst ein Raumfoto hoch, damit ich die Wände einfärben kann.',
          buttons: const [
            QuickReplyButton(
              label: 'Foto hochladen',
              value: 'Ich lade ein Raumfoto hoch',
              preferred: true,
              action: QuickReplyAction.uploadAttachment,
            ),
          ],
        );
        return;
      }

      var colorHex = _currentProjectColorHex();
      if (colorHex == null) {
        final inferred = _inferRecentHex();
        if (inferred != null) {
          colorHex = inferred;
          _lastDetectedHex = inferred;
          unawaited(_persistHexColor(inferred));
        }
      }
      if (colorHex == null) {
        _addAssistantMessage(
          'Bitte wähle zuerst eine Farbe aus, damit ich die Wände einfärben kann.',
          buttons: const [
            QuickReplyButton(
              label: 'Farbe scannen',
              value: 'Ich möchte eine Farbe scannen',
              preferred: true,
            ),
          ],
        );
        return;
      }

      final imageBytes = await _loadImageBytes(imageItem);
      try {
        _pendingRenderImageSize = await _readImageSize(imageBytes);
      } catch (_) {
        _pendingRenderImageSize = null;
      }
      _addAssistantMessage('Markiere bitte jetzt die Wände im Foto.');
      if (!mounted) return;
      final maskBytes = await MaskEditorPage.open(
        context: context,
        imageBytes: imageBytes,
        title: 'Wände markieren',
      );
      if (maskBytes == null) return;

      final lastUserText = _messages.reversed
          .firstWhere(
            (m) => m.role == 'user',
            orElse: () => const ChatMessage(role: 'user', text: ''),
          )
          .text;

      _pendingRenderImageBytes = imageBytes;
      _pendingRenderMaskBytes = maskBytes;
      _pendingRenderPrompt = _buildRenderPrompt(colorHex, lastUserText);
    }

    if (_pendingRenderMaskBytes == null ||
        _pendingRenderPrompt == null ||
        _pendingRenderImageBytes == null) {
      return;
    }

    _isRenderBusy = true;
    try {
      if (!planController.isGodMode && !_renderCreditsConsumed) {
        if (planController.virtualRoomCredits <= 0) {
          _resetRenderPending();
          await _showRenderCreditsPaywall();
          return;
        }

        final result = await _renderCreditManager.consume(isRetry: isRetry);
        if (result.message == 'busy') {
          return;
        }
        if (result.isOk) {
          _renderCreditsConsumed = true;
          planController.updateCreditsBalance(result.balance);
        } else if (result.isNotEnoughCredits) {
          _resetRenderPending();
          await _showRenderCreditsPaywall();
          return;
        } else if (result.isProRequired) {
          _resetRenderPending();
          await _showPremiumGate(featureName: 'Virtuelle Raumgestaltung');
          return;
        } else {
          _showRenderRetryMessage();
          return;
        }
      } else if (planController.isGodMode) {
        _renderCreditsConsumed = true;
      }

      _showRenderHint();
      final editedBytes = await _imageEditService.editImage(
        imageUrl: null,
        imageBytes: await _ensurePng(_pendingRenderImageBytes!),
        maskPng: _pendingRenderMaskBytes!,
        prompt: _pendingRenderPrompt!,
      );

      var outputBytes = editedBytes;
      if (_pendingRenderImageSize != null) {
        outputBytes =
            await _resizeToMatch(editedBytes, _pendingRenderImageSize!);
      }
      final path = await _writeTempFile(outputBytes);
      if (!mounted) return;
      await context.read<ProjectsModel>().addRender(
            projectId: _currentProjectId!,
            name: 'Render',
            path: path,
          );

      _resetRenderPending();
      final renderPath = _currentProjectRenderPathOrUrl() ?? path;
      _addAssistantMessage(
        'Hier ist das bearbeitete Foto.',
        localImagePaths: [renderPath],
      );
    } catch (_) {
      _showRenderRetryMessage();
    } finally {
      _removeRenderHint();
      _isRenderBusy = false;
    }
  }

  void _enterVoiceMode() {
    if (_voiceModeActive) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _voiceModeActive = true;
      _enableVoiceOutput = true;
      _cachedVoiceModeActive = true;
    });
  }

  void _exitVoiceMode() {
    if (!_voiceModeActive) return;
    setState(() {
      _voiceModeActive = false;
      _enableVoiceOutput = false;
      _ttsNoticeShown = false;
      _cachedVoiceModeActive = false;
    });
  }

  void _startVoiceVisualization() {
    _voiceVizTimer?.cancel();
    _voiceVizTimer = Timer.periodic(
      const Duration(milliseconds: 90),
      (timer) {
        if (!mounted || !_isSpeaking) {
          timer.cancel();
          return;
        }
        setState(() {
          _voiceVizLevel = 0.25 + (_voiceRand.nextDouble() * 0.75);
        });
      },
    );
  }

  bool _isPointerInsideVoiceButton(Offset position) {
    final ctx = _voiceButtonKey.currentContext;
    if (ctx == null) return true;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return true;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    return rect.contains(position);
  }

  void _stopSpeaking() {
    _voiceVizTimer?.cancel();
    if (!mounted) {
      _isSpeaking = false;
      _voiceVizLevel = 0.0;
      return;
    }
    setState(() {
      _isSpeaking = false;
      _voiceVizLevel = 0.0;
    });
  }

  Future<void> _stopTtsPlayback() async {
    await _ttsPlayer.stop();
    _stopSpeaking();
  }

  void _startSpeaking() {
    if (!mounted) return;
    setState(() {
      _isSpeaking = true;
    });
    _startVoiceVisualization();
  }

  Future<void> _startVoiceCapture() async {
    if (_isRecording || _isTranscribing) return;
    try {
      final platformRecording = await _audioRecorder.isRecording();
      if (platformRecording) {
        await _cancelRecorderSafely();
      }
    } catch (_) {}
    if (!mounted) return;
    final planController = context.read<PlanController>();
    final hasVoiceAccess = planController.isPro || planController.canDowngrade;
    if (!hasVoiceAccess) {
      final allowed = await _showPremiumGate(featureName: 'Spracheingabe');
      if (!allowed) return;
    }
    if (!mounted) return;
    final consentOk = await _ensureVoiceConsent();
    if (!consentOk) return;
    if (!mounted) return;
    final ready = await _ensureRecordingReady();
    if (!ready) return;

    await _stopTtsPlayback();
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/everloxx_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordingPath = path;
    _lastInputLevel = 0.0;
    _isStartingRecording = true;
    _pendingStopAfterStart = false;

    setState(() {
      _isRecording = true;
      _isTranscribing = false;
    });

    try {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: path,
      );
      _isStartingRecording = false;
      _recordingStartedAt = DateTime.now();
      _amplitudeSub?.cancel();
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 160))
          .listen((amp) {
        if (!mounted || !_isRecording) return;
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        setState(() {
          _lastInputLevel = normalized.toDouble();
        });
      });
      if (_pendingStopAfterStart && _isRecording) {
        await _stopVoiceCapture(forceDiscard: true);
      } else if (!_voicePressActive && _isRecording) {
        await _stopVoiceCapture();
      }
    } catch (e) {
      await _resetRecorderInstance();
      _resetVoiceFlags();
      _recordingPath = null;
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isTranscribing = false;
        });
      }
      _showSnack('Sprachaufnahme konnte nicht gestartet werden.');
    }
  }

  Future<void> _stopVoiceCapture({bool forceDiscard = false}) async {
    if (!_isRecording) return;
    if (_isStartingRecording) {
      _pendingStopAfterStart = true;
      _voicePressActive = false;
      return;
    }
    _voicePressActive = false;

    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    _amplitudeSub?.cancel();

    final startedAt = _recordingStartedAt;
    _recordingStartedAt = null;
    final elapsedMs = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inMilliseconds;
    final shouldDiscard = forceDiscard || elapsedMs < _minVoiceMs;

    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (_) {
      path = null;
    }
    path ??= _recordingPath;
    _recordingPath = null;
    try {
      final stillRecording = await _audioRecorder.isRecording();
      if (stillRecording) {
        await _cancelRecorderSafely();
      }
    } catch (_) {}
    await _resetRecorderInstance();

    if (shouldDiscard) {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      await _cancelRecorderSafely();
      _resetVoiceFlags();
      return;
    }

    if (path == null) {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
      _showSnack('Sprachaufnahme fehlgeschlagen.');
      _resetVoiceFlags();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 160));
    final file = File(path);
    int fileSize = 0;
    try {
      fileSize = await file.length();
    } catch (_) {
      fileSize = 0;
    }

    if (fileSize < 2048) {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
      _showSnack('Ich konnte nichts hören.');
      try {
        await file.delete();
      } catch (_) {}
      await _cancelRecorderSafely();
      _resetVoiceFlags();
      return;
    }

    String? transcript;
    try {
      transcript = await _transcribeRecording(path)
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      _showSnack('Spracherkennung dauert zu lange.');
      transcript = null;
    }

    try {
      await File(path).delete();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isTranscribing = false;
      });
    }
    _resetVoiceFlags();

    if (transcript == null || transcript.trim().isEmpty) {
      if (_lastInputLevel > 0.1) {
        _showSnack('Audio erkannt, aber keine Spracherkennung.');
      } else {
        _showSnack('Ich konnte nichts hören.');
      }
      return;
    }

    if (_isSending) {
      _queuedTranscript = transcript.trim();
      _showSnack('Sende nach der aktuellen Antwort.');
      return;
    }

    await _sendMessage(quickReplyText: transcript.trim());
  }

  Future<void> _maybeSpeakAssistant(String text) async {
    if (!_voiceModeActive || !_enableVoiceOutput) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final planController = context.read<PlanController>();
    if (!planController.isPro) {
      if (!_ttsNoticeShown) {
        _ttsNoticeShown = true;
        await _showPremiumGate(featureName: 'Sprachausgabe');
      }
      return;
    }

    await _playTts(trimmed);
  }

  Future<void> _playTts(String text) async {
    if (_isTtsLoading) return;
    await _stopTtsPlayback();

    if (mounted) {
      setState(() {
        _isTtsLoading = true;
      });
    }

    try {
      final response = await http.post(
        Uri.parse('$kEverloxxApiBase/tts'),
        headers: buildWorkerHeaders(
          contentType: 'application/json',
          accept: 'audio/mpeg',
        ),
        body: jsonEncode({
          'text': text,
          'voice': 'onyx',
          'model': 'tts-1',
          'format': 'mp3',
        }),
      );

      if (response.statusCode != 200) {
        _showSnack(
          'Sprachausgabe fehlgeschlagen (${response.statusCode}).',
        );
        return;
      }

      await _ttsPlayer.play(BytesSource(response.bodyBytes));
      _startSpeaking();
    } catch (e) {
      _showSnack('Sprachausgabe fehlgeschlagen.');
    } finally {
      if (mounted) {
        setState(() {
          _isTtsLoading = false;
        });
      }
    }
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

  bool _currentProjectHasImage() {
    final projectId = _currentProjectId;
    if (projectId == null) return false;
    try {
      final project = context
          .read<ProjectsModel>()
          .projects
          .firstWhere((p) => p.id == projectId);
      return project.items.any(
        (item) =>
            item.type == 'image' &&
            ((item.path ?? '').isNotEmpty || (item.url ?? '').isNotEmpty),
      );
    } catch (_) {
      return false;
    }
  }

  String? _currentProjectRenderPathOrUrl() {
    final projectId = _currentProjectId;
    if (projectId == null) return null;
    try {
      final project = context
          .read<ProjectsModel>()
          .projects
          .firstWhere((p) => p.id == projectId);
      for (final item in project.items.reversed) {
        if (item.type != 'render') continue;
        if ((item.path ?? '').isNotEmpty) return item.path;
        if ((item.url ?? '').isNotEmpty) return item.url;
      }
      return null;
    } catch (_) {
      return null;
    }
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
            'name': _shorten(p.name, 40),
            'hasImage': p.items.any((i) => i.type == 'image'),
            'items': p.items
                .map(
                  (i) {
                    final item = <String, dynamic>{
                      'id': i.id,
                      'type': i.type,
                      'hasLocal': i.path != null,
                      'hasRemote': i.url != null,
                    };
                    if (i.type == 'color' && i.name.isNotEmpty) {
                      item['color'] = _shorten(i.name, 24);
                    }
                    if (i.type == 'note' && i.name.isNotEmpty) {
                      item['note'] = _shorten(i.name, 160);
                    }
                    return item;
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
          'start_render',
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
=== EVERLOXX DESIGN – SYSTEM-PROMPT ===

Du bist EVERLOXX, der digitale Farb- und Projektberater von EVERLOXX.
Du begleitest Nutzer ruhig, strukturiert und kompetent durch ihr Wandfarben-Projekt – von der Farbwahl bis zum Kauf.
Du bist Planungshelfer, kein Verkäufer. Produkte sind das Ergebnis guter Planung.
Alles außerhalb von Farbgestaltung, Projektplanung, Visualisierung und EVERLOXX-Produkten ist irrelevant.

=== BEGRÜSSUNG (nur bei neuer Sitzung) ===

Hallo 👋, ich bin EVERLOXX, Dein persönlicher Farb- und Projektberater.
Ich helfe Dir, die perfekte Wandfarbe zu finden, Deinen Bedarf zu berechnen und Dein Projekt zu planen.
Was möchtest Du als Nächstes tun? 🎨

BUTTONS: {"buttons":[{"label":"Farbe finden","value":"Ich suche eine passende Wandfarbe","variant":"preferred"},{"label":"Foto einfärben","value":"Ich möchte sehen wie eine Farbe in meinem Raum aussieht"}]}

Während einer laufenden Unterhaltung wird nie erneut begrüßt.

=== KOMMUNIKATION ===

- Du-Form, empathisch, professionell, nie werblich
- Umlaute korrekt: ä, ö, ü, ß
- Emojis sparsam: 🎨💡🏠✨
- Antworten übersichtlich mit Absätzen
- Sprache des Nutzers übernehmen, bei Wechsel sofort mitwechseln
- Rechtlich sicher: "Erfahrungsgemäß ...", "Viele Kunden berichten ..."
- JEDE Antwort endet mit Frage, BUTTONS-Block oder beidem. Nie ohne.
- Keine Nein-Buttons. Keine negativen Optionen.
- Bei Unentschlossenheit: klare Empfehlung + bevorzugter Button

=== DIE 6 FLOWS ===

--- FLOW 1: Farbberatung ---
Trigger: Farbfragen, "empfehle mir", Stil-/Stimmungsfragen, Raumnennung
1. Bedarf verstehen (Raum, Stil, Stimmung, vorhandene Einrichtung)
2. Projekt anlegen (falls keines existiert)
3. 3 konkrete Farben empfehlen (Format: Name – HEX #XXXXXX + 1 Satz Wirkung)
4. Auswahl verfeinern bis Nutzer zufrieden
5. Visualisierung anbieten → FLOW 2 (bevorzugt) oder FLOW 3
6. Nach Bestätigung → EXIT RAMP

Farbregel: Immer HEX-Codes mit #. Nie Farben nur sprachlich beschreiben. Bei konkreter Farbrichtung in dieser Farbfamilie bleiben.

--- FLOW 2: AR Wandfarbe (PRIMÄRE Visualisierung, nur App) ---
Trigger: "an meiner Wand", "AR", "live", "Kamera", "wie sieht das aus", oder Visualisierungsschritt aus Flow 1
WICHTIG: Dies ist IMMER die erste Wahl für Visualisierung. Flow 3 ist der Fallback.
1. Projekt sicherstellen (falls keines existiert → anlegen)
2. Farbe sicherstellen (falls keine gewählt → Flow 1)
3. AR starten per Button mit action:"ar_wall_paint"
4. Nutzer färbt Wände live ein, macht Screenshots
5. Ergebnis besprechen → EXIT RAMP

AR Wandfarbe ist nur auf Geräten mit LiDAR-Sensor verfügbar (iPhone Pro, iPad Pro). Auf anderen Geräten biete stattdessen die Virtuelle Raumgestaltung (Flow 3) an.
Web-Fallback: Auf Web ist AR nicht verfügbar → automatisch zu Flow 3 weiterleiten.

CTA: BUTTONS: {"buttons":[{"label":"AR Wandfarbe starten","value":"Zeige mir die Farbe live an meiner Wand","variant":"preferred","action":"ar_wall_paint"},{"label":"Foto einfärben","value":"Ich möchte ein Foto virtuell einfärben","action":"upload"}]}

--- FLOW 3: Virtuelle Raumgestaltung (Fallback zu AR) ---
Trigger: "Foto einfärben", "virtuell", Foto-Upload, Web-Plattform
1. Projekt sicherstellen
2. Foto beschaffen: vorhandenes aus Projekt anbieten ODER neues hochladen
3. Foto kurz beschreiben + Raumtyp nennen → per Button bestätigen lassen
4. 3 Farbrichtungen mit HEX empfehlen (falls keine Farbe gewählt)
5. Nach Farbwahl: Einfärbung anbieten per Button mit action:"render"
6. Erst nach Zustimmung rendern. Auf Vorher/Nachher-Vorschau im Projekt verweisen.
7. Ergebnis besprechen → EXIT RAMP

Nie behaupten, Bilder nicht bearbeiten zu können. Nie fertige Bearbeitung behaupten, bevor gestartet.

CTA Upload: BUTTONS: {"buttons":[{"label":"Foto hochladen","value":"Ich lade ein Raumfoto hoch","variant":"preferred","action":"upload"}]}
CTA Render: BUTTONS: {"buttons":[{"label":"Wände einfärben","value":"Bitte färbe die Wände in meiner gewählten Farbe.","variant":"preferred","action":"render"}]}

--- FLOW 4: Farb-Scan ---
Trigger: "Farbe erkennen", "scannen", "welche Farbe ist das"
1. Foto anfordern oder vorhandenes verwenden
2. Dominante Farben extrahieren mit HEX
3. Passende EVERLOXX-Farben zuordnen
4. Optionen anbieten → EXIT RAMP oder Weiterleitung zu Flow 1/2/3

CTA: BUTTONS: {"buttons":[{"label":"Farbe scannen","value":"Ich möchte eine Farbe aus einem Foto erkennen","variant":"preferred","action":"scan_color"}]}

--- FLOW 5: Mengenberechnung ---
Trigger: "wie viel", "m²", Maße, "Eimer", "Liter", Mengenangaben
1. Fläche ermitteln: Raummaße (L×B×H) oder direkte m²-Angabe
2. Berechnung: Netto-Wandfläche × 2 Anstriche ÷ Ergiebigkeit + 10% Reserve
3. Ergebnis präsentieren: X Eimer THERMO-COAT + Y Packungen THERMO-SEAL
4. → EXIT RAMP

--- FLOW 6: Direktkauf ---
Trigger: "bestellen", "kaufen", "Warenkorb", konkreter Produktname
1. Produkt identifizieren (aus Kontext-Produktliste)
2. Menge bestätigen → falls unklar, zu Flow 5
3. System-Check: COAT + SEAL zusammen anbieten (nie isoliert)
4. → EXIT RAMP

=== EXIT RAMP (nach jedem Flow-Abschluss) ===

Pflicht-Prüfung in dieser Reihenfolge:
1. Farbe gewählt? → Falls nein: zurück zur Farbwahl
2. Menge berechnet? → Falls nein: Berechnung anbieten
3. System präsentieren: "X Eimer THERMO-COAT [Farbname, HEX] + Y Packungen THERMO-SEAL"
4. In den Warenkorb:

BUTTONS: {"buttons":[{"label":"System in den Warenkorb","value":"Bitte lege das komplette System in den Warenkorb","variant":"preferred","action":"cart"}]}

5. Nach Warenkorb:

BUTTONS: {"buttons":[{"label":"Zur Kasse","value":"Ich möchte zur Kasse","variant":"preferred","action":"checkout"},{"label":"Weiteren Raum planen","value":"Ich möchte einen weiteren Raum planen"}]}

=== FLOW-WECHSEL ===

Nutzer können jederzeit den Flow wechseln. Bestätige kurz, merke dir den Stand, wechsle.

=== PRODUKT-SYSTEM ===

EVERLOXX funktioniert ausschließlich als System:
- THERMO-COAT (Wandfarbe) + THERMO-SEAL (Abdichtung)
- Immer zusammen empfehlen, nie isoliert
- Erkläre kurz, warum das System zusammengehört

=== PRODUKT-ERGIEBIGKEIT & MENGENBERECHNUNG ===

THERMO-COAT Ergiebigkeit:
- 4,5 Liter Eimer
- Ergiebigkeit: ca. 6 m² pro Liter bei 2 Anstrichen (= ca. 27 m² pro Eimer bei 2 Anstrichen)
- Empfehlung: immer 2 Anstriche für volle Deckkraft

THERMO-SEAL Ergiebigkeit:
- 6 Meter Rolle
- Verwendung: Abdichtung aller Kanten, Ecken, Anschlüsse
- Faustregel: Raumumfang × 1,1 = benötigte Meter

Berechnungsformel:
- Wandfläche = (Länge + Breite) × 2 × Höhe - Fenster/Türen
- THERMO-COAT Eimer = Wandfläche ÷ 27 (aufgerundet) + 10% Reserve
- THERMO-SEAL Rollen = Raumumfang × 1,1 ÷ 6 (aufgerundet)

=== PROJEKT-TRIGGER ===

Sobald ein konkreter Raum oder eine Umsetzungsabsicht genannt wird → Projekt anlegen vorschlagen.

=== BILD-LOGIK ===

Bei Foto-Upload: kurz beschreiben was du siehst, dann weiterführen. Dialog nie blockieren.

=== TECHNISCHE ANWEISUNGEN ===

--- Button-Format ---
BUTTONS: steht am Zeilenanfang. Inline-JSON, kein Markdown/Codeblock. Nur gerade ".
Felder: label, value, variant ("preferred"|"primary"), action ("upload"|"render"|"ar_wall_paint"|"scan_color"|"cart"|"checkout"|"settings")
Regeln: Keine Nein-Buttons. Max 1 Alternative neben Haupt-CTA. Nach Aktion menschlich bestätigen.

--- Skill-Format ---
```skill
{"action":"add_to_cart","payload":{"productId":"<id>","quantity":2}}
```
```skill
{"action":"create_project","payload":{"name":"Wohnzimmer"}}
```
```skill
{"action":"add_project_item","payload":{"projectId":"<id>","type":"note","name":"2x THERMO-COAT + 1x THERMO-SEAL für 24 m²"}}
```
Verfügbare Skills: add_to_cart, add_project_item, create_project, rename_project, rename_item, move_item, delete_item.
Nach jedem Skill den Nutzer normal informieren.

Kontext (JSON): $contextJson
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
    final history = _messages.where((m) => !m.excludeFromApi).toList();

    final last20 = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    return last20
        .map(
          (m) {
            dynamic content = m.content ?? m.text;
            if (content is List) {
              final sanitized = <Map<String, dynamic>>[];
              for (final part in content) {
                if (part is! Map) continue;
                final type = part['type']?.toString();
                if (type == 'image_url') {
                  final url = part['image_url']?['url']?.toString();
                  if (url == null || !_isValidImageUrlForChat(url)) {
                    continue;
                  }
                }
                sanitized.add(Map<String, dynamic>.from(part));
              }
              if (sanitized.isEmpty) {
                content = m.text;
              } else {
                content = sanitized;
              }
            }
            return <String, dynamic>{
              'role': m.role,
              // JS: content: m.content ?? m.text
              'content': content,
            };
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

  void _scheduleAutoScrollIfNeeded() {
    if (!_autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_autoScroll) return;
      _scrollToBottom(animated: false);
    });
  }

  void _scheduleVoiceBarMeasure() {
    if (!_voiceModeActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_voiceModeActive) return;
      final ctx = _voiceBarKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final height = box.size.height;
      if (height != _voiceBarHeight) {
        setState(() {
          _voiceBarHeight = height;
        });
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
    if (option.action == QuickReplyAction.acceptAllConsents) {
      final consent = context.read<ConsentService>();
      await consent.setAnalyticsAllowed(true);
      await consent.setAiAllowed(true);
      if (!mounted) return;
      final hasDraft =
          _inputController.text.trim().isNotEmpty ||
          _pendingAttachments.isNotEmpty;
      if (hasDraft) {
        EverloxxOverlay.showSnack(
          context,
          'Alles klar. Du kannst jetzt senden.',
        );
        return;
      }
      _addAssistantMessage(
        'Perfekt! Womit möchtest du starten?',
        buttons: const [
          QuickReplyButton(
            label: 'Projekt starten',
            value: 'Ich möchte ein Projekt starten',
            preferred: true,
          ),
          QuickReplyButton(
            label: 'Farbberatung',
            value: 'Ich möchte eine Farbberatung',
            preferred: false,
          ),
        ],
      );
      return;
    }
    if (option.action == QuickReplyAction.openSettings) {
      _consentPromptShown = false;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SettingsPage(
            initialTabIndex: 2,
            initialLegalTabIndex: 2,
          ),
        ),
      );
      return;
    }
    if (option.action == QuickReplyAction.declineConsents) {
      final consent = context.read<ConsentService>();
      await consent.setAnalyticsAllowed(false);
      await consent.setAiAllowed(false);
      if (!mounted) return;
      _consentPromptShown = false;
      _addAssistantMessage(
        'Alles klar. Ohne Einwilligung kann ich dir hier leider '
        'nicht helfen. Du kannst das jederzeit in den Einstellungen '
        'ändern.',
      );
      return;
    }
    if (option.action == QuickReplyAction.startRender) {
      await _startVirtualRoomRenderFromChat();
      return;
    }
    if (option.action == QuickReplyAction.arWallPaint) {
      await _startARWallPaint();
      return;
    }
    if (option.action == QuickReplyAction.scanColor) {
      _addAssistantMessage(
        'Lade ein Foto hoch, und ich erkenne die Farben darin. 🎨',
        buttons: [
          QuickReplyButton(
            label: 'Foto hochladen',
            value: 'Ich lade ein Foto zum Farb-Scan hoch',
            action: QuickReplyAction.uploadAttachment,
          ),
        ],
      );
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
        final isSettings =
            actionRaw == 'settings' ||
            actionRaw == 'open_settings' ||
            actionRaw == 'preferences';
        final isConsent =
            actionRaw == 'consent' ||
            actionRaw == 'accept_consents' ||
            actionRaw == 'accept_all_consents';
        final isRender =
            actionRaw == 'render' ||
            actionRaw == 'image_edit' ||
            actionRaw == 'edit_image' ||
            actionRaw == 'virtual_room' ||
            actionRaw == 'render_image' ||
            actionRaw == 'paint_walls';
        final isArWallPaint =
            actionRaw == 'ar_wall_paint' ||
            actionRaw == 'ar_wandfarbe' ||
            actionRaw == 'ar_paint';
        final isScanColor =
            actionRaw == 'scan_color' ||
            actionRaw == 'scanColor' ||
            actionRaw == 'color_scan';
        final isCheckout =
            actionRaw == 'checkout';
        final action = isUpload
            ? QuickReplyAction.uploadAttachment
            : isCart
            ? QuickReplyAction.goToCart
            : isCheckout
            ? QuickReplyAction.goToCart
            : isSettings
            ? QuickReplyAction.openSettings
            : isConsent
            ? QuickReplyAction.acceptAllConsents
            : isRender
            ? QuickReplyAction.startRender
            : isArWallPaint
            ? QuickReplyAction.arWallPaint
            : isScanColor
            ? QuickReplyAction.scanColor
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

  List<String> _extractHexColorsLoose(String text) {
    var source = text;
    if (RegExp(r'^[\s#0-9a-fA-F.,-]+$').hasMatch(source)) {
      source = source.replaceAll(RegExp(r'[^0-9a-fA-F#]'), '');
    }
    final matches = _hexColorLooseRegex.allMatches(source);
    if (matches.isEmpty) return const [];
    final seen = <String>{};
    final result = <String>[];
    for (final match in matches) {
      final raw = match.group(0);
      if (raw == null) continue;
      final hasHash = raw.startsWith('#');
      final hasDigit = RegExp(r'[0-9]').hasMatch(raw);
      if (!hasDigit && !hasHash) continue;
      final normalized = _normalizeHex(raw);
      if (seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  String? _inferRecentHex() {
    for (final msg in _messages.reversed) {
      if (msg.role == 'user') {
        final hexes = _extractHexColorsLoose(msg.text);
        if (hexes.isNotEmpty) return hexes.first;
      } else {
        final source = msg.content is String ? msg.content as String : msg.text;
        final hexes = _extractHexColors(source);
        if (hexes.isNotEmpty) return hexes.first;
      }
    }
    return _lastDetectedHex;
  }

  String? _extractColorPreference(String text) {
    final hexes = _extractHexColorsLoose(text);
    if (hexes.isNotEmpty) return hexes.first;
    final lower = text.toLowerCase();
    final compact = lower.replaceAll(RegExp(r'[\s-]'), '');
    for (final entry in _colorKeywordMap.entries) {
      if (lower.contains(entry.key) || compact.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> _persistHexColor(String hex) async {
    final projectId = _currentProjectId;
    if (projectId == null) return;
    try {
      await context.read<ProjectsModel>().addColorSwatch(
            projectId: projectId,
            hex: hex,
          );
    } catch (_) {
      // Ignorieren: Farbe nur lokal merken.
    }
  }

  Color _onColorForBackground(Color color) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  Future<void> _applyColorToCurrentProject(String hex) async {
    final projectId = _currentProjectId;
    final selectionMessage =
        'Ich habe die Farbe $hex ausgewählt. Bitte nutze diese Farbe für mein Projekt.';
    if (projectId == null) {
      EverloxxOverlay.showSnack(
        context,
        'Bitte zuerst ein Projekt anlegen.',
        isError: true,
      );
      await _sendMessage(quickReplyText: selectionMessage);
      return;
    }
    try {
      await context.read<ProjectsModel>().addColorSwatch(
            projectId: projectId,
            hex: hex,
          );
      if (!mounted) return;
      EverloxxOverlay.showSnack(
        context,
        'Farbe im Projekt gespeichert.',
      );
    } catch (_) {
      if (!mounted) return;
      EverloxxOverlay.showSnack(
        context,
        'Bitte anmelden, um Farben zu speichern.',
        isError: true,
      );
    } finally {
      await _sendMessage(quickReplyText: selectionMessage);
    }
  }

  void _showColorPreview(String hex) {
    final color = _colorFromHex(hex);
    final onColor = _onColorForBackground(color);

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'farbe',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final tokens = dialogContext.everloxxTokens;
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
                        ?.copyWith(color: onColor, fontWeight: FontWeight.w800),
                  ),
                ),
                Positioned(
                  left: tokens.screenPadding,
                  right: tokens.screenPadding,
                  bottom: tokens.gapLg,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await _applyColorToCurrentProject(hex);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Farbe übernehmen'),
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
    final hasProjectImage = _currentProjectHasImage();
    final wantsVisualEdit = _looksLikeVisualEditPrompt(lower);
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

    if (hasProjectImage && wantsVisualEdit) {
      final colorHex = _currentProjectColorHex();
      if (colorHex != null) {
        return _FallbackButtons(
          key: 'render_start',
          buttons: const [
            QuickReplyButton(
              label: 'Wände einfärben',
              value: 'Bitte färbe die Wände in meiner gewählten Farbe.',
              preferred: true,
              action: QuickReplyAction.startRender,
            ),
            QuickReplyButton(
              label: 'Neues Foto hochladen',
              value: 'Ich lade ein neues Raumfoto hoch',
              preferred: false,
              action: QuickReplyAction.uploadAttachment,
            ),
          ],
        );
      }
      return _FallbackButtons(
        key: 'upload_choice',
        buttons: const [
          QuickReplyButton(
            label: 'Vorhandenes Foto verwenden',
            value: 'Bitte verwende das vorhandene Foto aus meinem Projekt.',
            preferred: true,
          ),
          QuickReplyButton(
            label: 'Neues Foto hochladen',
            value: 'Ich lade ein neues Raumfoto hoch',
            preferred: false,
            action: QuickReplyAction.uploadAttachment,
          ),
        ],
      );
    }

    if (wantsUpload) {
      if (hasProjectImage) {
        return _FallbackButtons(
          key: 'upload_existing',
          buttons: const [
            QuickReplyButton(
              label: 'Vorhandenes Foto verwenden',
              value: 'Bitte verwende das vorhandene Foto aus meinem Projekt.',
              preferred: true,
            ),
            QuickReplyButton(
              label: 'Neues Foto hochladen',
              value: 'Ich lade ein neues Raumfoto hoch',
              preferred: false,
              action: QuickReplyAction.uploadAttachment,
            ),
          ],
        );
      }
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
    final hasAsset =
        lower.contains('foto') ||
        lower.contains('bild') ||
        lower.contains('grundriss') ||
        lower.contains('skizze');
    final hasAction =
        lower.contains('hochlad') ||
        lower.contains('upload') ||
        lower.contains('aufnehm') ||
        lower.contains('schick') ||
        lower.contains('sende') ||
        lower.contains('senden') ||
        lower.contains('hinzufueg');
    return hasAsset && hasAction;
  }

  bool _looksLikeResultRequest(String text) {
    final lower = text.toLowerCase();
    return lower.contains('ergebnis') ||
        lower.contains('ansehen') ||
        lower.contains('anzeigen') ||
        lower.contains('zeige') ||
        lower.contains('zeigen') ||
        lower.contains('vorher') ||
        lower.contains('nachher') ||
        lower.contains('vergleich') ||
        lower.contains('before') ||
        lower.contains('after') ||
        lower.contains('sehen');
  }

  bool _looksLikeVisualEditPrompt(String text) {
    final lower = text.toLowerCase();
    return lower.contains('virtuell') ||
        lower.contains('raumgestaltung') ||
        lower.contains('bearbeit') ||
        lower.contains('streichen') ||
        lower.contains('farbe auf') ||
        lower.contains('wand') ||
        lower.contains('anwenden') ||
        lower.contains('raumfoto') ||
        lower.contains('render') ||
        lower.contains('einfaerb') ||
        lower.contains('einfärb');
  }

  bool _isARWallPaintRequest(String text) {
    final lower = text.toLowerCase();
    return lower.contains('ar ') ||
        lower.contains('ar-wand') ||
        lower.contains('live') && lower.contains('wand') ||
        lower.contains('kamera') && lower.contains('farbe') ||
        lower.contains('an meiner wand') ||
        lower.contains('an der wand') ||
        lower.contains('projizier');
  }

  bool _looksLikeEditCompletion(String text) {
    final lower = text.toLowerCase();
    return lower.contains('bearbeitet') ||
        lower.contains('angewendet') ||
        lower.contains('fertig') ||
        lower.contains('abgeschlossen') ||
        lower.contains('gerendert') ||
        lower.contains('erstellt') ||
        lower.contains('erzeugt');
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

  bool _isRemotePath(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  bool _looksLikePng(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  bool _looksLikeJpeg(Uint8List bytes) {
    if (bytes.length < 2) return false;
    return bytes[0] == 0xFF && bytes[1] == 0xD8;
  }

  bool _isValidImageUrlForChat(String url) {
    if (_isRemotePath(url)) return true;
    if (!url.startsWith('data:image/')) return false;
    final commaIndex = url.indexOf(',');
    if (commaIndex <= 0) return false;
    final meta = url.substring(0, commaIndex);
    if (!meta.contains('base64')) return false;
    final payload = url.substring(commaIndex + 1).trim();
    if (payload.isEmpty) return false;
    try {
      base64Decode(payload);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _normalizeUmlautText(String text) {
    if (text.isEmpty) return text;
    var result = text;
    const replacements = {
      'Waende': 'Wände',
      'waende': 'wände',
      'Einfaerben': 'Einfärben',
      'einfaerben': 'einfärben',
      'Laeuft': 'Läuft',
      'laeuft': 'läuft',
      'Moechtest': 'Möchtest',
      'moechtest': 'möchtest',
      'Moechte': 'Möchte',
      'moechte': 'möchte',
      'Loeschen': 'Löschen',
      'loeschen': 'löschen',
      'Ueber': 'Über',
      'ueber': 'über',
      'Rueck': 'Rück',
      'rueck': 'rück',
      'Zurueck': 'Zurück',
      'zurueck': 'zurück',
      'Fuer': 'Für',
      'fuer': 'für',
      'Gross': 'Groß',
      'gross': 'groß',
    };
    replacements.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result;
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
    cleaned = cleaned.replaceAll(RegExp(r'\(\s*\)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\-–—:]\s*(?=\n|$)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r' *\n *'), '\n');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }


  Future<void> _startGreetingIfNeeded() async {
    if (_greetingRequested || !mounted || _messages.isNotEmpty) return;
    if (!await _ensureChatAccess()) return;
    if (!_ensureAiConsent()) return;
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
      final uri = Uri.parse('$kEverloxxApiBase/chat');

      final req = http.Request('POST', uri)
        ..headers.addAll(
          buildWorkerHeaders(
            contentType: 'application/json',
            accept: 'text/event-stream',
          ),
        )
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

      var done = false;
      await for (final chunk in streamedRes.stream.transform(decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final raw in lines) {
          final line = raw.trim();
          if (!line.startsWith('data:')) continue;

          final data = line.substring(5).trim();
          if (data == '[DONE]') {
            done = true;
            break;
          }

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
        if (done) break;
      }

      final displayText = await _processAssistantResponse(fullText);
      final cleanedAssistant = _sanitizeAssistantText(fullText);
      await _memoryManager.updateWithTurn(
        userText: '',
        assistantText: cleanedAssistant.isNotEmpty
            ? cleanedAssistant
            : fullText,
      );
      await _maybeSpeakAssistant(displayText);

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
      if (mounted) {
        await _flushQueuedTranscript();
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
            (typeRaw == 'image' ||
                    typeRaw == 'file' ||
                    typeRaw == 'note' ||
                    typeRaw == 'other')
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

        if (resolvedType == 'note') {
          final noteText =
              (payload['note'] as String? ?? payload['text'] as String? ?? name)
                  ?.trim();
          if (noteText == null || noteText.isEmpty) {
            return '⚠️ Notiz konnte nicht gespeichert werden.';
          }
          await projectsModel.addItem(
            projectId: projectId,
            name: noteText,
            type: 'note',
          );
          return '📝 Notiz gespeichert.';
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

      case 'start_render':
        await _startVirtualRoomRenderFromChat();
        return 'Rendering wird gestartet...';

      default:
        return null; // still unsupported, but nicht anzeigen
    }
  }

  Future<String> _processAssistantResponse(String fullText) async {
    if (!mounted) return _stripControlBlocks(fullText);

    final commands = _parseSkillBlocks(fullText);
    var buttons = _parseButtonBlocks(fullText);

    if (buttons.isNotEmpty && _currentProjectHasImage()) {
      final hasUpload = buttons.any(
        (b) => b.action == QuickReplyAction.uploadAttachment,
      );
      final hasExisting = buttons.any(
        (b) =>
            b.label.toLowerCase().contains('vorhand') ||
            b.value.toLowerCase().contains('vorhand'),
      );
      if (hasUpload && !hasExisting) {
        buttons = [
          const QuickReplyButton(
            label: 'Vorhandenes Foto verwenden',
            value: 'Bitte verwende das vorhandene Foto aus meinem Projekt.',
            preferred: true,
          ),
          ...buttons.map(
            (b) => b.preferred ? b.copyWith(preferred: false) : b,
          ),
        ];
      }
    }

    final feedback = <String>[];
    for (final cmd in commands) {
      final note = await _executeSkillCommand(cmd);
      if (note != null && note.isNotEmpty) {
        feedback.add(note);
      }
    }

    final cleaned = _sanitizeAssistantText(fullText);
    final assistantHexes = _extractHexColors(cleaned);
    if (assistantHexes.isNotEmpty) {
      _lastDetectedHex = assistantHexes.first;
    }
    var displayText = _cleanAssistantDisplayText(cleaned);
    displayText = _normalizeUmlautText(displayText);
    if (displayText.isEmpty && feedback.isNotEmpty) {
      displayText = _normalizeUmlautText(feedback.join('\n'));
    }
    displayText = displayText.trim();
    if (buttons.isNotEmpty) {
      buttons = buttons
          .map<QuickReplyButton>(
            (b) => QuickReplyButton(
              label: _normalizeUmlautText(b.label),
              value: _normalizeUmlautText(b.value),
              preferred: b.preferred,
              action: b.action,
            ),
          )
          .toList();
    }

    final lastUserText = _messages.reversed
        .firstWhere(
          (m) => m.role == 'user',
          orElse: () => const ChatMessage(role: 'user', text: ''),
        )
        .text;
    final renderPath = _currentProjectRenderPathOrUrl();
    final wantsResult = _looksLikeResultRequest(lastUserText) ||
        _looksLikeResultRequest(displayText);
    final looksLikeCompletion = _looksLikeEditCompletion(displayText);
    final shouldShowRender = renderPath != null && wantsResult;
    final needsRenderButMissing =
        renderPath == null && (wantsResult || looksLikeCompletion);
    final hasColorHex = _currentProjectColorHex() != null;

    if (shouldShowRender) {
      displayText = 'Hier ist das bearbeitete Foto.';
      buttons = const [];
    } else if (needsRenderButMissing) {
      if (_currentProjectHasImage() && hasColorHex) {
        displayText =
            'Ich habe das Bild noch nicht gerendert. Soll ich die Wände jetzt einfärben?';
        buttons = const [
          QuickReplyButton(
            label: 'Wände einfärben',
            value: 'Bitte färbe die Wände in meiner gewählten Farbe.',
            preferred: true,
            action: QuickReplyAction.startRender,
          ),
          QuickReplyButton(
            label: 'Neues Foto hochladen',
            value: 'Ich lade ein neues Raumfoto hoch',
            preferred: false,
            action: QuickReplyAction.uploadAttachment,
          ),
        ];
      } else {
        displayText = _currentProjectHasImage()
            ? 'Ich habe das Bild noch nicht fertig gerendert. Soll ich das vorhandene Foto verwenden oder ein neues aufnehmen?'
            : 'Damit ich starten kann, brauche ich zuerst ein Foto. Möchtest du ein neues hochladen?';
        buttons = _currentProjectHasImage()
            ? const [
                QuickReplyButton(
                  label: 'Vorhandenes Foto verwenden',
                  value: 'Bitte verwende das vorhandene Foto aus meinem Projekt.',
                  preferred: true,
                ),
                QuickReplyButton(
                  label: 'Neues Foto hochladen',
                  value: 'Ich lade ein neues Raumfoto hoch',
                  preferred: false,
                  action: QuickReplyAction.uploadAttachment,
                ),
              ]
            : const [
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
              ];
      }
    }

    final suppressFallback = shouldShowRender || needsRenderButMissing;
    if (!suppressFallback && buttons.isEmpty) {
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
            value: 'Ich möchte eine Farbberatung',
            preferred: false,
          ),
        ];
        _projectPromptShown = true;
        _projectPromptAttemptedInTurn = true;
      }
    }

    final isFirstGreeting =
        _messages.length <= 1 && _messages.every((m) => m.role != 'user');
    if (!suppressFallback && isFirstGreeting && buttons.isEmpty) {
      buttons = const [
        QuickReplyButton(
          label: 'Projekt starten',
          value: 'Ich möchte ein Projekt starten',
          preferred: true,
        ),
        QuickReplyButton(
          label: 'Farbberatung',
          value: 'Ich möchte eine Farbberatung',
          preferred: false,
        ),
      ];
      _projectPromptShown = true;
      _projectPromptAttemptedInTurn = true;
      _shownFallbacks.add('project_prompt');
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
        final current = _messages[_streamingMsgIndex!];
        _messages[_streamingMsgIndex!] = current.copyWith(
          text: displayText,
          content: suppressFallback ? displayText : cleaned,
          buttons: buttons.isNotEmpty ? buttons : null,
          localImagePaths: shouldShowRender
              ? [renderPath!]
              : current.localImagePaths,
        );
      });
    }

    return displayText;
  }

  /// =======================
  ///  ANHANG-MENÜ (EVERLOXX STYLE)
  /// =======================

  Future<void> _openAttachmentMenu() async {
    final picked = await pickEverloxxAttachment(context);
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
    if (!await _ensureChatAccess()) return;
    if (!_ensureAiConsent()) return;
    await _stopTtsPlayback();
    if (!mounted) return;

    // Always dismiss keyboard after sending
    FocusScope.of(context).unfocus();

    final rawText = quickReplyText ?? _inputController.text;
    final text = rawText.trim();
    final lower = text.toLowerCase();

    // Intercept direct AR wall paint requests — launch immediately
    if (text.isNotEmpty && _isARWallPaintRequest(lower)) {
      _inputController.clear();
      setState(() {
        _messages.add(ChatMessage(role: 'user', text: text));
      });
      await _startARWallPaint();
      return;
    }

    if (text.isNotEmpty) {
      final preference = _extractColorPreference(text);
      if (preference != null && preference.startsWith('#')) {
        _lastDetectedHex = preference;
        unawaited(_persistHexColor(preference));
      }
    }
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

    if (hasFiles && _currentProjectId == null) {
      final projectsModel = context.read<ProjectsModel>();
      if (projectsModel.projects.isNotEmpty) {
        _currentProjectId = projectsModel.projects.first.id;
      }
    }

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
          Uint8List? uploadBytes;
          String mime;
          if (_looksLikePng(bytes)) {
            uploadBytes = bytes;
            mime = 'image/png';
          } else if (_looksLikeJpeg(bytes)) {
            uploadBytes = bytes;
            mime = 'image/jpeg';
          } else {
            final converted = await _ensurePng(bytes);
            if (_looksLikePng(converted)) {
              uploadBytes = converted;
              mime = 'image/png';
            } else {
              setState(() {
                _messages.add(
                  const ChatMessage(
                    role: 'assistant',
                    text:
                        '❌ Dieses Bildformat kann ich nicht verarbeiten. Bitte JPG oder PNG verwenden.',
                  ),
                );
              });
              continue;
            }
          }

          final rawBase64 = base64Encode(uploadBytes);

          final dataUrl = 'data:$mime;base64,$rawBase64';

          final uploadRes = await http.post(
            Uri.parse('$kEverloxxApiBase/upload'),
            headers: buildWorkerHeaders(contentType: 'application/json'),
            body: jsonEncode({'base64': dataUrl}),
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

          if (imageUrl != null &&
              imageUrl.isNotEmpty &&
              _isValidImageUrlForChat(imageUrl)) {
            uploadedUrls.add(imageUrl);
            uploadRecord = uploadRecord.copyWith(remoteUrl: imageUrl);
          } else {
            setState(() {
              _messages.add(
                const ChatMessage(
                  role: 'assistant',
                  text:
                      '❌ Das hochgeladene Bild war ungültig. Bitte erneut als JPG oder PNG senden.',
                ),
              );
            });
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
      final uri = Uri.parse('$kEverloxxApiBase/chat');

      final req = http.Request('POST', uri)
        ..headers.addAll(
          buildWorkerHeaders(
            contentType: 'application/json',
            accept: 'text/event-stream',
          ),
        )
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

      var done = false;
      await for (final chunk in streamedRes.stream.transform(decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final raw in lines) {
          final line = raw.trim();
          if (!line.startsWith('data:')) continue;

          final data = line.substring(5).trim();
          if (data == '[DONE]') {
            done = true;
            break;
          }

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
        if (done) break;
      }

      final displayText = await _processAssistantResponse(fullText);
      final cleanedAssistant = _sanitizeAssistantText(fullText);
      await _memoryManager.updateWithTurn(
        userText: text,
        assistantText: cleanedAssistant.isNotEmpty
            ? cleanedAssistant
            : fullText,
      );
      await _maybeSpeakAssistant(displayText);

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
      if (mounted) {
        await _flushQueuedTranscript();
      }
    }
  }

  /// =======================
  ///  UI: Chat-Bubbles
  /// =======================

  Widget _buildBubble(ChatMessage msg, int messageIndex) {
    final isUser = msg.role == 'user';
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;
    final bubbleMaxWidth = MediaQuery.of(context).size.width * 0.8;

    final buttons = msg.buttons ?? const <QuickReplyButton>[];
    final bg = isUser
        ? theme.colorScheme.primary
        : const Color(0xFFF5EDE8);
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
    final hexSource = !isUser && msg.content is String
        ? msg.content as String
        : msg.text;
    final hexColors = !isUser ? _extractHexColors(hexSource) : const <String>[];
    final isRenderHint = msg.text == _renderingHintToken;

    if (isRenderHint) {
      return Column(
        crossAxisAlignment: align,
        children: [
          ChatBubbleAnimated(
            isUser: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: bg, borderRadius: radius),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_fix_high,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Render läuft …',
                        style:
                            theme.textTheme.bodyMedium?.copyWith(color: fg),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RenderDots(color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

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
                            child: GestureDetector(
                              onTap: () => _openImagePreview(path),
                              child: _isRemotePath(path)
                                  ? Image.network(
                                      path,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, progress) {
                                            if (progress == null) {
                                              _scheduleAutoScrollIfNeeded();
                                            }
                                            return child;
                                          },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                        child:
                                            Icon(Icons.broken_image_outlined),
                                      ),
                                    )
                                  : Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                      frameBuilder:
                                          (context, child, frame, _) {
                                            if (frame != null) {
                                              _scheduleAutoScrollIfNeeded();
                                            }
                                            return child;
                                          },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                        child:
                                            Icon(Icons.broken_image_outlined),
                                      ),
                                    ),
                            ),
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

  void _openImagePreview(String pathOrUrl, {String? title}) {
    if (!mounted) return;
    openImagePreview(
      context,
      pathOrUrl: pathOrUrl,
      title: title,
    );
  }

  Widget _buildAttachmentPreview() {
    if (_pendingAttachments.isEmpty) return const SizedBox.shrink();
    final tokens = context.everloxxTokens;

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
              color: const Color(0xFFD8DEE4),
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

  Widget _buildTextInputBar() {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;
    final hasPendingAttachments = _pendingAttachments.isNotEmpty;
    final showMic = !_hasInputText && !hasPendingAttachments;
    final canVoice = !_isSending && !_isTranscribing;

    return Padding(
      key: const ValueKey('text-input'),
      padding: EdgeInsets.only(
        left: 2,
        right: 2,
        bottom: MediaQuery.of(context).viewInsets.bottom + 6,
        top: 2,
      ),
      child: Row(
        children: [
          const SizedBox(width: 2),
          _AttachmentIconButton(onTap: _openAttachmentMenu),
          const SizedBox(width: 6),
          const SizedBox(width: 2),
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Nachricht an EVERLOXX …',
                filled: true,
                fillColor: const Color(0xFFFFFFFF),
                hintStyle: TextStyle(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  fontSize: 15,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusXl),
                  borderSide: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.15),
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
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              showMic ? Icons.mic_rounded : Icons.send_rounded,
              size: 30,
              color: theme.colorScheme.primary,
            ),
            onPressed: showMic
                ? (canVoice ? _handleMicTap : null)
                : (_isSending ? null : () => _sendMessage()),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceInputBar() {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canExit = !_isRecording && !_isTranscribing;

    return Padding(
      key: _voiceBarKey,
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: bottomInset + 10,
        top: 6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildVoiceActionButton(),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: canExit ? _exitVoiceMode : null,
            icon: Icon(
              Icons.keyboard_alt_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            label: Text(
              'Tastatur',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceActionButton() {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;
    final isDisabled = _isTranscribing || _isTtsLoading;
    final ringGlow = theme.colorScheme.primary.withValues(
      alpha: _isSpeaking ? 0.85 : 0.65,
    );

    final innerColor = _isRecording
        ? AppTheme.peachDark
        : theme.scaffoldBackgroundColor;
    final iconColor =
        _isRecording ? Colors.white : theme.colorScheme.primary;

    Widget innerChild;
    if (_isTranscribing) {
      innerChild = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.primary,
          ),
        ),
      );
    } else {
      innerChild = Icon(
        Icons.mic_rounded,
        size: 34,
        color: iconColor,
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_voiceRingCtrl, _voicePulseCtrl]),
      builder: (context, child) {
        final pulse = 0.96 + (_voicePulseCtrl.value * 0.08);
        final speakScale = 1.0 + (_voiceVizLevel * 0.12);
        final scale = _isSpeaking ? speakScale : pulse;
        return Opacity(
          opacity: isDisabled ? 0.6 : 1,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: isDisabled
                ? null
                : (_) {
                    _voicePressActive = true;
                    _startVoiceCapture();
                  },
            onPointerUp: isDisabled
                ? null
                : (_) {
                    _voicePressActive = false;
                    _stopVoiceCapture();
                  },
            onPointerCancel:
                isDisabled
                    ? null
                    : (_) {
                        _voicePressActive = false;
                        _stopVoiceCapture();
                      },
            onPointerMove: isDisabled
                ? null
                : (event) {
                    if (_isRecording &&
                        !_isPointerInsideVoiceButton(event.position)) {
                      _voicePressActive = false;
                      _stopVoiceCapture();
                    }
                  },
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                key: _voiceButtonKey,
                width: 120,
                height: 120,
                child: Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ringGlow,
                          blurRadius: 30,
                          spreadRadius: 4,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RotationTransition(
                          turns: _voiceRingCtrl,
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
                                  spreadRadius:
                                      tokens.rainbowRingHaloSpread,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: innerColor,
                          ),
                          child: Center(child: innerChild),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// =======================
  ///  BUILD
  /// =======================

  @override
  Widget build(BuildContext context) {
    final tokens = context.everloxxTokens;
    final double voicePadding = _voiceModeActive
        ? (_voiceBarHeight > 0 ? _voiceBarHeight + 12.0 : 190.0)
        : tokens.screenPadding.toDouble();

    if (_voiceModeActive) {
      _scheduleVoiceBarMeasure();
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              'EVERLOXX',
              style: TextStyle(fontFamily: 'Times New Roman',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),

          const Divider(height: 1),

          // CHAT-VERLAUF
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.direction != ScrollDirection.idle) {
                      _autoScroll = false;
                      _userHasScrolled = true;
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      tokens.screenPadding,
                      tokens.screenPadding,
                      tokens.screenPadding,
                      voicePadding,
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
                if (_voiceModeActive)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildVoiceInputBar(),
                  ),
              ],
            ),
          ),

          if (!_voiceModeActive) _buildAttachmentPreview(),
          if (!_voiceModeActive) _buildTextInputBar(),
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
    final tokens = context.everloxxTokens;
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
    final tokens = context.everloxxTokens;
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
///  EVERLOXX KREIS-WIDGET (Kamera / Galerie / Datei)
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
    final tokens = EverloxxTokens.light;
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
    final tokens = context.everloxxTokens;

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

  const _AttachmentIconButton({required this.onTap});

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
    final tokens = EverloxxTokens.light;

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
    final tokens = context.everloxxTokens;

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
    final tokens = EverloxxTokens.light;
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

class _RenderDots extends StatefulWidget {
  final Color color;

  const _RenderDots({required this.color});

  @override
  State<_RenderDots> createState() => _RenderDotsState();
}

class _RenderDotsState extends State<_RenderDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value * 2 * math.pi) +
                (index * 0.8);
            final scale = 0.6 + (math.sin(phase).abs() * 0.4);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
