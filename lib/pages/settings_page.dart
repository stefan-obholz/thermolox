import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/plan_controller.dart';
import '../theme/app_theme.dart';
import '../utils/plan_modal.dart';
import '../utils/thermolox_overlay.dart';
import '../widgets/attachment_sheet.dart';
import '../widgets/plan_card_view.dart';
import '../widgets/thermolox_secondary_tabs.dart';
import '../widgets/thermolox_segmented_tabs.dart';
import 'auth_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
          children: const [
            ThermoloxSegmentedTabs(
              labels: ['Profil', 'Tarif', 'Rechtliches'],
              margin: EdgeInsets.zero,
              fill: true,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ProfileTab(),
                  PlanTab(),
                  LegalTab(),
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

  Future<void> _pickProfileImage() async {
    final picked = await pickThermoloxAttachment(context);
    if (picked == null) return;
    if (!picked.isImage) {
      ThermoloxOverlay.showSnack(context, 'Bitte ein Foto auswählen.');
      return;
    }
    setState(() => _profileImagePath = picked.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        tokens.gapMd,
        0,
        tokens.gapLg,
      ),
      children: [
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
                      backgroundImage: _profileImagePath != null
                          ? FileImage(File(_profileImagePath!))
                          : null,
                      child: _profileImagePath == null
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profilbild hinzufügen',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
    final selectedPlanId =
        planController.activePlan?.plan.slug ?? 'basic';
    final selected = await showPlanModal(
      context: context,
      plans: plans,
      selectedPlanId: selectedPlanId,
    );
    if (selected == null) return;

    if (!planController.isLoggedIn && selected == 'pro') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AuthPage(initialTabIndex: 1),
        ),
      );
      await planController.load(force: true);
      if (planController.isLoggedIn &&
          planController.activePlan?.plan.slug != 'pro') {
        await planController.selectPlan('pro');
      }
      return;
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
    final selectedPlanId =
        controller.activePlan?.plan.slug ?? 'basic';
    final selectedPlan = plans.firstWhere(
      (plan) => plan.id == selectedPlanId,
      orElse: () => plans.first,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        tokens.gapMd,
        0,
        tokens.gapLg,
      ),
      children: [
        Text(
          'Dein Tarif',
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
            'Tarife konnten nicht geladen werden.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        SizedBox(height: tokens.gapSm),
        PlanCardView(
          data: selectedPlan,
          actionLabel: 'Aktiv',
          canTap: false,
          isSelected: true,
          showActionButton: false,
        ),
        SizedBox(height: tokens.gapMd),
        ElevatedButton(
          onPressed: () => _openPlanModal(context),
          child: const Text('Tarife verwalten'),
        ),
      ],
    );
  }
}

class LegalTab extends StatelessWidget {
  const LegalTab({super.key});

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
                _LegalSection(
                  title: 'Datenschutz',
                  body: 'Hier folgt die Datenschutzerklärung.',
                  padding: tokens.gapMd,
                ),
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
