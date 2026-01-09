import 'dart:io';

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
import '../theme/app_theme.dart';
import '../utils/plan_modal.dart';
import '../utils/thermolox_overlay.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/plan_card_view.dart';
import '../widgets/settings_auth_panel.dart';
import '../widgets/thermolox_secondary_tabs.dart';
import '../widgets/thermolox_segmented_tabs.dart';
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
      child: ThermoloxScaffold(
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
            const ThermoloxSegmentedTabs(
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
  String? _lastUserId;
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _houseNumberCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _streetCtrl.dispose();
    _houseNumberCtrl.dispose();
    _zipCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
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

  Future<void> _pickProfileImage() async {
    final picked = await pickThermoloxAttachment(context);
    if (picked == null) return;
    if (!picked.isImage) {
      ThermoloxOverlay.showSnack(context, 'Bitte ein Foto auswählen.');
      return;
    }
    setState(() => _profileImagePath = picked.path);
  }

  Future<void> _loadProfile(User user) async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    final locale = Localizations.localeOf(context).toLanguageTag();
    final profileService = ProfileService();
    try {
      await profileService.seedProfileFromAuth(user: user, locale: locale);
      final profile = await profileService.getProfile(user.id);
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
      await AuthService().signOut();
      if (!mounted) return;
      context.read<PlanController>().load(force: true);
    } catch (_) {
      if (!mounted) return;
      ThermoloxOverlay.showSnack(
        context,
        'Logout fehlgeschlagen.',
        isError: true,
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await ThermoloxOverlay.confirm(
      context: context,
      title: 'Logout',
      message: 'Möchtest Du Dich wirklich ausloggen?',
      confirmLabel: 'Logout',
      cancelLabel: 'Abbrechen',
    );
    if (!confirm) return;
    await _logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;
    final isLoggedIn = context.watch<PlanController>().isLoggedIn;
    final user = Supabase.instance.client.auth.currentUser;

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
                      child: avatarImage == null
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
              child: Align(
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: user != null ? _confirmLogout : null,
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    final tokens = context.thermoloxTokens;
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
    final tokens = context.thermoloxTokens;
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
          const ThermoloxSecondaryTabs(
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

    final tokens = context.thermoloxTokens;

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
    final tokens = context.thermoloxTokens;
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
                            ThermoloxOverlay.showSnack(
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
            final confirm = await ThermoloxOverlay.confirm(
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
            ThermoloxOverlay.showSnack(
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
              final confirm = await ThermoloxOverlay.confirm(
                context: context,
                title: title,
                message: message,
                confirmLabel: 'Löschen',
                cancelLabel: 'Abbrechen',
              );
              if (!confirm) return;
              setState(() => _isDeleting = true);
              try {
                await authService.deleteAccount();
                if (!context.mounted) return;
                context.read<PlanController>().load(force: true);
                ThermoloxOverlay.showSnack(
                  context,
                  isAnonymous
                      ? 'Cloud-Daten gelöscht.'
                      : 'Account gelöscht. Du wurdest abgemeldet.',
                );
              } catch (error) {
                if (!context.mounted) return;
                debugPrint('Delete account failed: $error');
                ThermoloxOverlay.showSnack(
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
