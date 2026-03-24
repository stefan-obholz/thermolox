import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/plan_controller.dart';
import '../data/plan_ui_strings.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../services/local_data_service.dart';
import '../services/profile_service.dart';
import '../services/shopify_auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/plan_modal.dart';
import '../utils/everloxx_overlay.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/plan_card_view.dart';
import '../widgets/settings_auth_panel.dart';
import '../widgets/everloxx_secondary_tabs.dart';
import '../widgets/everloxx_segmented_tabs.dart';
import '../chat/chat_bot.dart';
import 'auth_page.dart';

class SettingsPage extends StatelessWidget {
  final int initialTabIndex;
  final int initialLegalTabIndex;

  const SettingsPage({
    super.key,
    this.initialTabIndex = 0,
    this.initialLegalTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex.clamp(0, 2).toInt(),
      child: EverloxxScaffold(
        safeArea: true,
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Einstellungen',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.0,
            ),
          ),
        ),
        body: Column(
          children: [
            const EverloxxSegmentedTabs(
              labels: ['Profil', 'Tarif', 'Rechtliches'],
              margin: EdgeInsets.zero,
              fill: true,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const ProfileTab(),
                  const PlanTab(),
                  LegalTab(initialTabIndex: initialLegalTabIndex),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String? _profileImagePath;
  String? _profileImageUrl;
  UserProfile? _profile;
  String? _profileError;
  bool _loadingProfile = false;
  bool _uploadingAvatar = false;
  String? _lastUserId;
  Timer? _saveTimer;
  StreamSubscription<bool>? _shopifyAuthSub;
  final _profileService = ProfileService();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _houseNumberCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Shopify customer profile data
  String? _shopifyDisplayName;
  String? _shopifyEmail;
  List<Map<String, dynamic>> _shopifyOrders = [];

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.addListener(_onFieldChanged);
    _lastNameCtrl.addListener(_onFieldChanged);
    _streetCtrl.addListener(_onFieldChanged);
    _houseNumberCtrl.addListener(_onFieldChanged);
    _zipCtrl.addListener(_onFieldChanged);
    _cityCtrl.addListener(_onFieldChanged);
    _shopifyAuthSub =
        ShopifyAuthService.instance.onAuthStateChanged.listen((loggedIn) {
      if (!mounted) return;
      if (loggedIn) {
        _loadShopifyProfile();
      } else {
        setState(() {
          _shopifyDisplayName = null;
          _shopifyEmail = null;
          _shopifyOrders = [];
        });
      }
    });
    if (ShopifyAuthService.instance.isLoggedIn) {
      _loadShopifyProfile();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _shopifyAuthSub?.cancel();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _streetCtrl.dispose();
    _houseNumberCtrl.dispose();
    _zipCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_loadingProfile || _lastUserId == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1500), _saveProfile);
  }

  Future<void> _saveProfile() async {
    final userId = _lastUserId;
    if (userId == null) return;
    try {
      final data = <String, dynamic>{
        'id': userId,
        'first_name': _firstNameCtrl.text,
        'last_name': _lastNameCtrl.text,
        'street': _streetCtrl.text,
        'house_number': _houseNumberCtrl.text,
        'postal_code': _zipCtrl.text,
        'city': _cityCtrl.text,
      };
      await _profileService.upsertProfile(UserProfile.fromMap(data));
      if (!mounted) return;
      EverloxxOverlay.showSnack(context, 'Gespeichert');
    } catch (e) {
      if (!mounted) return;
      EverloxxOverlay.showSnack(context, 'Speichern fehlgeschlagen.',
          isError: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    if (userId == null || user == null || userId == _lastUserId) return;
    _lastUserId = userId;
    _loadProfile(user);
  }

  Future<void> _loadShopifyProfile() async {
    try {
      final customer = await ShopifyAuthService.instance.getCustomerProfile();
      if (!mounted) return;
      setState(() {
        _shopifyDisplayName =
            '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'
                .trim();
        _shopifyEmail = customer['emailAddress']?['emailAddress'] as String? ??
            customer['email'] as String?;
        final orders = customer['orders']?['edges'] as List<dynamic>?;
        _shopifyOrders = orders
                ?.map((e) =>
                    (e as Map<String, dynamic>)['node'] as Map<String, dynamic>)
                .toList() ??
            [];
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ShopifyAuth: profile fetch failed: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await pickEverloxxAttachment(context);
    if (picked == null) return;
    if (!mounted) return;
    if (!picked.isImage) {
      EverloxxOverlay.showSnack(context, 'Bitte ein Foto auswählen.');
      return;
    }
    setState(() {
      _profileImagePath = picked.path;
      _uploadingAvatar = true;
    });
    try {
      final url = await _profileService.uploadAvatar(picked.path);
      if (!mounted) return;
      setState(() {
        _profileImageUrl = url;
        _profileImagePath = null;
        _uploadingAvatar = false;
      });
      EverloxxOverlay.showSnack(context, 'Profilbild gespeichert.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      EverloxxOverlay.showSnack(
        context,
        'Profilbild konnte nicht hochgeladen werden.',
        isError: true,
      );
    }
  }

  Future<void> _loadProfile(User user) async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    final locale = Localizations.localeOf(context).toLanguageTag();
    try {
      await _profileService.seedProfileFromAuth(user: user, locale: locale);
      final profile = await _profileService.getProfile(user.id);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileImageUrl = profile?.avatarUrl;
      });
      if (profile != null) {
        _firstNameCtrl.text = profile.firstName ?? '';
        _lastNameCtrl.text = profile.lastName ?? '';
        _streetCtrl.text = profile.street ?? '';
        _houseNumberCtrl.text = profile.houseNumber ?? '';
        _zipCtrl.text = profile.postalCode ?? '';
        _cityCtrl.text = profile.city ?? '';
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _profileError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      EverloxxChatBot.clearCache();
      // Logout from Shopify if logged in
      if (ShopifyAuthService.instance.isLoggedIn) {
        await ShopifyAuthService.instance.logout();
      }
      // Also sign out from Supabase
      await AuthService().signOut();
      if (!mounted) return;
      context.read<PlanController>().load(force: true);
    } catch (_) {
      if (!mounted) return;
      EverloxxOverlay.showSnack(
        context,
        'Logout fehlgeschlagen.',
        isError: true,
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await EverloxxOverlay.confirm(
      context: context,
      title: 'Logout',
      message: 'Möchtest Du Dich wirklich ausloggen?',
      confirmLabel: 'Logout',
      cancelLabel: 'Abbrechen',
    );
    if (!confirm) return;
    if (!mounted) return;
    await _logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;
    final isLoggedIn = context.watch<PlanController>().isLoggedIn;
    final user = Supabase.instance.client.auth.currentUser;
    final isShopifyLoggedIn = ShopifyAuthService.instance.isLoggedIn;

    if (!isLoggedIn) {
      return SettingsAuthPanel(
        padding: EdgeInsets.fromLTRB(
          0,
          tokens.gapMd,
          0,
          tokens.gapLg,
        ),
        initialMode: SettingsAuthMode.signup,
        onAuthenticated: () {
          context.read<PlanController>().load(force: true);
        },
      );
    }

    final ImageProvider<Object>? avatarImage = _profileImagePath != null
        ? FileImage(File(_profileImagePath!))
        : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
            ? NetworkImage(_profileImageUrl!)
            : null;

    // Determine display name and email: prefer Shopify profile data
    final displayName = _shopifyDisplayName ??
        '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim();
    final displayEmail = _shopifyEmail ?? user?.email ?? '';

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        tokens.gapMd,
        0,
        tokens.gapLg,
      ),
      children: [
        if (_loadingProfile)
          const LinearProgressIndicator(minHeight: 2),
        if (_profileError != null) ...[
          SizedBox(height: tokens.gapSm),
          Text(
            'Profil konnte nicht geladen werden.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        Text(
          'Profilbild',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tokens.gapSm),
        Row(
          children: [
            GestureDetector(
              onTap: _pickProfileImage,
              child: SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: theme.colorScheme.primary.withAlpha(31),
                      backgroundImage: avatarImage,
                      child: _uploadingAvatar
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : avatarImage == null
                              ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: tokens.gapMd),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayName.isNotEmpty)
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (displayEmail.isNotEmpty) ...[
                    SizedBox(height: tokens.gapXs),
                    Text(
                      displayEmail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  SizedBox(height: tokens.gapSm),
                  ElevatedButton(
                    onPressed:
                        (user != null || isShopifyLoggedIn) ? _confirmLogout : null,
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Shopify order history
        if (isShopifyLoggedIn && _shopifyOrders.isNotEmpty) ...[
          SizedBox(height: tokens.gapLg),
          Text(
            'Bestellungen',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.gapSm),
          ..._shopifyOrders.map((order) {
            final name = order['name'] as String? ?? '';
            final processedAt = order['processedAt'] as String? ?? '';
            final totalPrice = order['totalPrice'] as Map<String, dynamic>?;
            final amount = totalPrice?['amount'] as String? ?? '';
            final currency = totalPrice?['currencyCode'] as String? ?? 'EUR';
            final date = processedAt.length >= 10
                ? processedAt.substring(0, 10)
                : processedAt;
            return Card(
              margin: EdgeInsets.only(bottom: tokens.gapSm),
              child: ListTile(
                title: Text(name),
                subtitle: Text(date),
                trailing: Text(
                  '$amount $currency',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }),
        ],
        SizedBox(height: tokens.gapLg),
        Text(
          'Persönliche Angaben',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tokens.gapXs),
        Text(
          'Ihre Angaben werden als Rechnungsadresse verwendet',
          style: theme.textTheme.bodySmall,
        ),
        SizedBox(height: tokens.gapMd),
        TextFormField(
          controller: _firstNameCtrl,
          decoration: const InputDecoration(labelText: 'Vorname'),
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
        ),
        SizedBox(height: tokens.gapSm),
        TextFormField(
          controller: _lastNameCtrl,
          decoration: const InputDecoration(labelText: 'Nachname'),
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
        ),
        SizedBox(height: tokens.gapSm),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _streetCtrl,
                decoration: const InputDecoration(labelText: 'Straße'),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                keyboardType: TextInputType.streetAddress,
              ),
            ),
            SizedBox(width: tokens.gapSm),
            SizedBox(
              width: 110,
              child: TextFormField(
                controller: _houseNumberCtrl,
                decoration: const InputDecoration(labelText: 'Nr.'),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.gapSm),
        Row(
          children: [
            SizedBox(
              width: 110,
              child: TextFormField(
                controller: _zipCtrl,
                decoration: const InputDecoration(labelText: 'PLZ'),
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(width: tokens.gapSm),
            Expanded(
              child: TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'Stadt'),
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PlanTab extends StatelessWidget {
  const PlanTab({super.key});

  Future<void> _openPlanModal(BuildContext context) async {
    final planController = context.read<PlanController>();
    final plans = planController.planCards;
    if (plans.isEmpty) return;
    final selectedPlanId =
        planController.activePlan?.plan.slug ?? 'basic';
    final selected = await showPlanModal(
      context: context,
      plans: plans,
      selectedPlanId: selectedPlanId,
      allowDowngrade: planController.canDowngrade,
    );
    if (selected == null) return;
    if (!context.mounted) return;

    if (!planController.isLoggedIn && selected == 'pro') {
      final navigator = Navigator.of(context, rootNavigator: true);
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => const AuthPage(initialTabIndex: 1),
        ),
      );
      await planController.load(force: true);
      if (!planController.isLoggedIn) return;
    }

    if (selected != planController.activePlan?.plan.slug) {
      await planController.selectPlan(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;
    final controller = context.watch<PlanController>();
    final plans = controller.planCards;
    final selectedPlanId = controller.activePlan?.plan.slug;
    final selectedPlan = plans.isNotEmpty
        ? plans.firstWhere(
            (plan) => plan.id == (selectedPlanId ?? plans.first.id),
            orElse: () => plans.first,
          )
        : null;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        tokens.gapMd,
        0,
        tokens.gapLg,
      ),
      children: [
        Text(
          PlanUiStrings.yourPlan,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (controller.isLoading) ...[
          SizedBox(height: tokens.gapSm),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (controller.error != null) ...[
          SizedBox(height: tokens.gapSm),
          Text(
            PlanUiStrings.loadError,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        SizedBox(height: tokens.gapSm),
        if (selectedPlan != null)
          PlanCardView(
            data: selectedPlan,
            actionLabel: PlanUiStrings.actionActive,
            canTap: false,
            isSelected: true,
            showActionButton: false,
          ),
        SizedBox(height: tokens.gapMd),
        ElevatedButton(
          onPressed: plans.isEmpty || controller.isLoading
              ? null
              : () => _openPlanModal(context),
          child: const Text(PlanUiStrings.managePlans),
        ),
      ],
    );
  }
}

class LegalTab extends StatelessWidget {
  final int initialTabIndex;

  const LegalTab({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final tokens = context.everloxxTokens;
    const labels = [
      'Impressum',
      'AGB',
      'Datenschutz',
      'Widerrufsrecht',
    ];

    return DefaultTabController(
      length: labels.length,
      initialIndex:
          initialTabIndex.clamp(0, labels.length - 1).toInt(),
      child: Column(
        children: [
          const EverloxxSecondaryTabs(
            labels: labels,
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _LegalSection(
                  title: 'Impressum',
                  body: 'Hier folgt das Impressum.',
                  padding: tokens.gapMd,
                ),
                _LegalSection(
                  title: 'AGB',
                  body: 'Hier folgen die Allgemeinen Geschäftsbedingungen.',
                  padding: tokens.gapMd,
                ),
                const _PrivacySection(),
                _LegalSection(
                  title: 'Widerrufsrecht',
                  body: 'Hier folgt die Widerrufsbelehrung.',
                  padding: tokens.gapMd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final String title;
  final String body;
  final double padding;

  const _LegalSection({
    required this.title,
    required this.body,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tokens = context.everloxxTokens;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        padding,
        0,
        tokens.gapLg,
      ),
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PrivacySection extends StatefulWidget {
  const _PrivacySection();

  @override
  State<_PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<_PrivacySection> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.everloxxTokens;
    final consent = context.watch<ConsentService>();
    final isLoaded = consent.isLoaded;
    final authService = context.read<AuthService>();
    final user = Supabase.instance.client.auth.currentUser;
    final hasServerUser = user != null;
    final isAnonymous = authService.isUserAnonymous(user);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        tokens.gapMd,
        0,
        tokens.gapLg,
      ),
      children: [
        Text(
          'Datenschutz',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hier folgt die Datenschutzerklärung.',
          style: theme.textTheme.bodyMedium,
        ),
        SizedBox(height: tokens.gapMd),
        Text(
          'Einwilligungen (optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tokens.gapXs),
        Text(
          'Diese Funktionen sind optional und können jederzeit deaktiviert werden.',
          style: theme.textTheme.bodySmall,
        ),
        SizedBox(height: tokens.gapSm),
        Card(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.gapSm,
              vertical: tokens.gapXs,
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Analytics zur Produktverbesserung',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Speicherdauer: 180 Tage.',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: consent.analyticsAllowed,
                  onChanged: isLoaded
                      ? (value) => consent.setAnalyticsAllowed(value)
                      : null,
                ),
                Divider(height: tokens.gapMd),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'KI-Chat und Bildbearbeitung',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Anfragen gehen über Cloudflare an OpenAI. '
                    'Ohne Einwilligung ist der Chat aus. '
                    'Widerruf löscht lokales Chat-Gedächtnis.',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: consent.aiAllowed,
                  onChanged: isLoaded
                      ? (value) async {
                          await consent.setAiAllowed(value);
                          if (!value && context.mounted) {
                            EverloxxOverlay.showSnack(
                              context,
                              'Lokales Chat-Gedächtnis wurde gelöscht.',
                            );
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: tokens.gapMd),
        Text(
          'Daten löschen',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: tokens.gapXs),
        Text(
          'Du kannst lokale Daten auf diesem Gerät löschen. '
          'Serverdaten sind nur vorhanden, wenn eine Sitzung besteht.',
          style: theme.textTheme.bodySmall,
        ),
        SizedBox(height: tokens.gapSm),
        OutlinedButton(
          onPressed: () async {
            final confirm = await EverloxxOverlay.confirm(
              context: context,
              title: 'Lokale Daten löschen',
              message:
                  'Löscht lokale Projekte, Uploads und das Chat-Gedächtnis auf diesem Gerät.',
              confirmLabel: 'Löschen',
              cancelLabel: 'Abbrechen',
            );
            if (!confirm) return;
            await LocalDataService.clearAll();
            if (!context.mounted) return;
            EverloxxOverlay.showSnack(
              context,
              'Lokale Daten gelöscht.',
            );
          },
          child: const Text('Lokale Daten löschen'),
        ),
        if (hasServerUser) ...[
          SizedBox(height: tokens.gapSm),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: _isDeleting
                ? null
                : () async {
              final title =
                  isAnonymous ? 'Daten in der Cloud löschen' : 'Account löschen';
              final message = isAnonymous
                  ? 'Löscht deine in der Cloud gespeicherten Daten. Dieser Schritt kann nicht rückgängig gemacht werden.'
                  : 'Möchtest Du Deinen Account endgültig löschen? Dieser Schritt kann nicht rückgängig gemacht werden.';
              final confirm = await EverloxxOverlay.confirm(
                context: context,
                title: title,
                message: message,
                confirmLabel: 'Löschen',
                cancelLabel: 'Abbrechen',
              );
              if (!confirm) return;
              setState(() => _isDeleting = true);
              try {
                EverloxxChatBot.clearCache();
                await authService.deleteAccount();
                if (!context.mounted) return;
                context.read<PlanController>().load(force: true);
                EverloxxOverlay.showSnack(
                  context,
                  isAnonymous
                      ? 'Cloud-Daten gelöscht.'
                      : 'Account gelöscht. Du wurdest abgemeldet.',
                );
              } catch (error) {
                if (!context.mounted) return;
                debugPrint('Delete account failed: $error');
                EverloxxOverlay.showSnack(
                  context,
                  'Daten konnten nicht gelöscht werden.',
                  isError: true,
                );
              } finally {
                if (mounted) {
                  setState(() => _isDeleting = false);
                }
              }
            },
            child: _isDeleting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onError,
                          ),
                        ),
                      ),
                      SizedBox(width: tokens.gapXs),
                      const Text('Lösche...'),
                    ],
                  )
                : Text(
                    isAnonymous
                        ? 'Daten in der Cloud löschen'
                        : 'Account löschen',
                  ),
          ),
        ],
        SizedBox(height: tokens.gapSm),
        Text(
          'Auftragsverarbeiter: Supabase, Shopify, Cloudflare, OpenAI.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
