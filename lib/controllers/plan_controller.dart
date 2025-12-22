import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/plan_data.dart';
import '../models/current_plan.dart';
import '../models/plan.dart';
import '../models/plan_feature.dart';
import '../models/plan_models.dart';
import '../services/plan_service.dart';

class PlanController extends ChangeNotifier {
  PlanController(this._service) {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      load(force: true);
    });
    load();
  }

  final PlanService _service;
  StreamSubscription<AuthState>? _authSub;

  bool _isLoading = false;
  Object? _error;
  CurrentPlan? _activePlan;
  Map<String, CurrentPlan> _publicPlans = {};

  bool get isLoading => _isLoading;
  Object? get error => _error;
  CurrentPlan? get activePlan => _activePlan;
  Map<String, CurrentPlan> get publicPlans => _publicPlans;

  bool get isLoggedIn => Supabase.instance.client.auth.currentUser != null;
  bool get isPro => _activePlan?.plan.slug == 'pro';
  bool get hasProjectsAccess =>
      _activePlan?.features['project_folder']?.isEnabled ?? false;

  List<PlanCardData> get planCards {
    if (_publicPlans.isEmpty) {
      return thermoloxPlanCards;
    }
    const order = ['basic', 'pro'];
    return [
      for (final slug in order)
        if (_publicPlans[slug] != null) _mapPlanCard(_publicPlans[slug]!),
    ];
  }

  Future<void> load({bool force = false}) async {
    if (_isLoading && !force) return;
    _isLoading = true;
    notifyListeners();

    try {
      final publicPlans = await _service.getAllPlansPublic();
      final fallbackPlans = _fallbackPlans();
      if (publicPlans.isNotEmpty) {
        _publicPlans = _mergeFallbackPlans(
          fallbackPlans,
          publicPlans,
        );
      } else if (_publicPlans.isEmpty) {
        _publicPlans = fallbackPlans;
      }

      final fallback = _publicPlans['basic'];
      if (isLoggedIn) {
        _activePlan = await _service.getPlanForCurrentUser(fallback: fallback);
      } else {
        _activePlan = fallback;
      }
      _error = null;
    } catch (e) {
      _error = e;
      if (kDebugMode) {
        debugPrint('PlanController load failed: $e');
      }
      if (_publicPlans.isEmpty) {
        _publicPlans = _fallbackPlans();
      }
      _activePlan ??= _publicPlans['basic'];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectPlan(String planSlug) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _error = StateError('No user session');
      notifyListeners();
      return;
    }

    final target = _publicPlans[planSlug];
    if (target == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.upsertSubscription(userId: user.id, plan: target.plan);
      await load(force: true);
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  PlanCardData _mapPlanCard(CurrentPlan plan) {
    final price = _formatPrice(plan.plan.priceEur);
    final priceSubline = plan.plan.priceEur > 0 ? 'pro Monat' : '';
    final subline = plan.plan.slug == 'pro'
        ? 'Für ambitionierte Projekte'
        : 'Für den Einstieg';

    return PlanCardData(
      id: plan.plan.slug,
      title: plan.plan.name,
      price: price,
      priceSubline: priceSubline,
      subline: subline,
      features: [
        for (final descriptor in _featureOrder)
          _mapFeature(plan, descriptor),
      ],
    );
  }

  PlanFeatureData _mapFeature(CurrentPlan plan, _FeatureDescriptor descriptor) {
    final feature = plan.features[descriptor.key];
    final enabled = feature?.isEnabled ?? false;

    if (descriptor.key == 'virtual_room') {
      if (!enabled) {
        return const PlanFeatureData(
          label: 'Virtuelle Raumgestaltung',
          included: false,
          description: 'Nicht enthalten',
        );
      }
      final limit = feature?.monthlyLimit;
      if (limit != null && limit > 0) {
        return PlanFeatureData(
          label: 'Virtuelle Raumgestaltung',
          included: true,
          value: '${limit}x',
          description: '$limit Nutzungen',
        );
      }
      return const PlanFeatureData(
        label: 'Virtuelle Raumgestaltung',
        included: true,
        description: 'Inklusive',
      );
    }

    return PlanFeatureData(
      label: descriptor.label,
      included: enabled,
      description: enabled ? 'Inklusive' : 'Nicht enthalten',
    );
  }

  String _formatPrice(double price) {
    if (price <= 0) return 'Kostenlos';
    final rounded = price % 1 == 0 ? price.toInt().toString() : price.toString();
    return '$rounded€';
  }

  Map<String, CurrentPlan> _fallbackPlans() {
    final result = <String, CurrentPlan>{};
    for (final card in thermoloxPlanCards) {
      final plan = Plan(
        id: card.id,
        slug: card.id,
        name: card.title,
        priceEur: _parsePrice(card.price),
      );

      final features = <String, PlanFeature>{};
      for (final feature in card.features) {
        final key = _featureKeyFromLabel(feature.label);
        if (key == null) continue;
        final limit = _parseLimit(feature.value);
        features[key] = PlanFeature(
          featureKey: key,
          isEnabled: feature.included,
          monthlyLimit: limit,
        );
      }

      final virtual = features['virtual_room'];
      final limit = virtual?.monthlyLimit;
      final enabled = virtual?.isEnabled ?? false;
      result[plan.slug] = CurrentPlan(
        plan: plan,
        features: features,
        virtualRoomLimit: enabled ? limit : null,
        virtualRoomUsed: enabled ? 0 : null,
        virtualRoomRemaining: enabled ? limit : null,
      );
    }
    return result;
  }

  Map<String, CurrentPlan> _mergeFallbackPlans(
    Map<String, CurrentPlan> fallback,
    Map<String, CurrentPlan> remote,
  ) {
    final merged = <String, CurrentPlan>{...fallback};
    remote.forEach((slug, plan) {
      final fallbackPlan = fallback[slug];
      if (plan.features.isEmpty && fallbackPlan != null) {
        merged[slug] = CurrentPlan(
          plan: plan.plan,
          features: fallbackPlan.features,
          virtualRoomLimit: fallbackPlan.virtualRoomLimit,
          virtualRoomUsed: fallbackPlan.virtualRoomUsed,
          virtualRoomRemaining: fallbackPlan.virtualRoomRemaining,
        );
      } else {
        merged[slug] = plan;
      }
    });
    return merged;
  }

  double _parsePrice(String price) {
    final cleaned =
        price.replaceAll(RegExp(r'[^0-9,\\.]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  int? _parseLimit(String? value) {
    if (value == null) return null;
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned);
  }

  String? _featureKeyFromLabel(String label) {
    switch (label) {
      case 'THERMOLOX Chatbot':
        return 'chatbot';
      case 'Farbberatung':
        return 'color_advice';
      case 'Projektmappe':
        return 'project_folder';
      case 'Projektberatung':
        return 'project_consulting';
      case 'Virtuelle Raumgestaltung':
        return 'virtual_room';
      default:
        return null;
    }
  }
}

class _FeatureDescriptor {
  final String key;
  final String label;

  const _FeatureDescriptor(this.key, this.label);
}

const _featureOrder = <_FeatureDescriptor>[
  _FeatureDescriptor('chatbot', 'THERMOLOX Chatbot'),
  _FeatureDescriptor('color_advice', 'Farbberatung'),
  _FeatureDescriptor('project_folder', 'Projektmappe'),
  _FeatureDescriptor('project_consulting', 'Projektberatung'),
  _FeatureDescriptor('virtual_room', 'Virtuelle Raumgestaltung'),
];
