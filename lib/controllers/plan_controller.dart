import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/plan_feature_catalog.dart';
import '../data/plan_ui_strings.dart';
import '../models/current_plan.dart';
import '../models/plan.dart';
import '../models/plan_feature.dart';
import '../models/plan_models.dart';
import '../models/user_entitlements.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/plan_service.dart';

class PlanController extends ChangeNotifier {
  PlanController(this._planService, this._authService) {
    _authSub = _authService.currentUserStream.listen((_) {
      load(force: true);
    });
    load();
  }

  final PlanService _planService;
  final AuthService _authService;
  StreamSubscription? _authSub;

  bool _isLoading = false;
  Object? _error;
  Map<String, CurrentPlan> _publicPlans = {};
  CurrentPlan? _activePlan;
  PlanSubscriptionInfo? _subscriptionInfo;
  UserEntitlements? _entitlements;

  bool get isLoading => _isLoading;
  Object? get error => _error;
  CurrentPlan? get activePlan => _activePlan;
  Map<String, CurrentPlan> get publicPlans => _publicPlans;
  UserEntitlements? get entitlements => _entitlements;
  int get virtualRoomCredits => _entitlements?.creditsBalance ?? 0;

  bool get isLoggedIn =>
      _authService.currentUser != null && !_authService.isAnonymous;
  bool get isEmailVerified => _authService.isEmailVerified;
  String? get currentUserEmail => _authService.currentUser?.email;
  bool get canDowngrade =>
      currentUserEmail?.toLowerCase() == 'stefan.obholz@gmail.com';

  bool get isPro {
    if (!isLoggedIn || !isEmailVerified) return false;
    if (_entitlements?.proLifetime == true && !canDowngrade) return true;
    if (_activePlan?.plan.slug != 'pro') return false;
    final status = _subscriptionInfo?.status;
    return status == null || status == 'active' || status == 'lifetime';
  }

  bool get hasProjectsAccess => isPro;

  List<PlanCardData> get planCards {
    const order = ['basic', 'pro'];
    final cards = <PlanCardData>[];
    for (final slug in order) {
      final plan = _publicPlans[slug];
      if (plan == null) continue;
      cards.add(_mapPlanCard(plan));
    }
    return cards;
  }

  Future<void> load({bool force = false}) async {
    if (_isLoading && !force) return;
    _isLoading = true;
    notifyListeners();

    try {
      final plans = await _planService.loadPlans();
      final features = await _planService.loadPlanFeatures(plans);
      _publicPlans = _buildPublicPlans(plans, features);

      final user = _authService.currentUser;
      if (user != null && _authService.isEmailVerified) {
        _subscriptionInfo = await _planService.getCurrentUserPlanInfo();
        _entitlements = await _planService.loadEntitlements(userId: user.id) ??
            const UserEntitlements(proLifetime: false, creditsBalance: 0);
      } else {
        _subscriptionInfo = null;
        _entitlements = null;
      }

      _activePlan = _resolveActivePlan();
      _error = null;
    } catch (e) {
      _error = e;
      await AnalyticsService.instance.logEvent(
        'plan_load_failed',
        source: 'plan_controller',
        payload: {'error': e.toString()},
      );
      if (kDebugMode) {
        debugPrint('PlanController load failed: $e');
      }
      _publicPlans = {};
      _activePlan = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectPlan(String planSlug) async {
    final user = _authService.currentUser;
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
      await _planService.upsertSubscription(
        userId: user.id,
        planId: target.plan.id,
      );
      await load(force: true);
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateCreditsBalance(int? balance) {
    if (balance == null) return;
    final current = _entitlements ??
        const UserEntitlements(proLifetime: false, creditsBalance: 0);
    _entitlements = current.copyWith(creditsBalance: balance);
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Map<String, CurrentPlan> _buildPublicPlans(
    List<Plan> plans,
    Map<String, List<PlanFeature>> featuresBySlug,
  ) {
    final result = <String, CurrentPlan>{};
    for (final plan in plans) {
      final features = <String, PlanFeature>{};
      for (final feature in featuresBySlug[plan.slug] ?? []) {
        features[feature.featureKey] = feature;
      }
      result[plan.slug] = CurrentPlan(plan: plan, features: features);
    }
    return result;
  }

  CurrentPlan? _resolveActivePlan() {
    if (_publicPlans.isEmpty) return null;
    if (!isLoggedIn) return _publicPlans['basic'] ?? _publicPlans.values.first;
    if (_entitlements?.proLifetime == true && !canDowngrade) {
      return _publicPlans['pro'] ??
          _publicPlans['basic'] ??
          _publicPlans.values.first;
    }

    final slug = _subscriptionInfo?.planSlug ?? 'basic';
    return _publicPlans[slug] ?? _publicPlans['basic'] ?? _publicPlans.values.first;
  }

  PlanCardData _mapPlanCard(CurrentPlan plan) {
    final price = _formatPrice(plan.plan.priceEur);
    final subline = plan.plan.slug == 'pro'
        ? PlanUiStrings.proSubline
        : PlanUiStrings.basicSubline;

    return PlanCardData(
      id: plan.plan.slug,
      title: plan.plan.name,
      price: price,
      subline: subline,
      features: _mapFeatures(plan),
    );
  }

  List<PlanFeatureData> _mapFeatures(CurrentPlan plan) {
    final features = plan.features;
    final result = <PlanFeatureData>[];

    for (final descriptor in planFeatureOrder) {
      final feature = features[descriptor.key];
      if (feature == null) continue;

      if (descriptor.key == 'virtual_room') {
        result.add(_mapVirtualRoom(plan, feature));
        continue;
      }

      result.add(
        PlanFeatureData(
          label: descriptor.label,
          included: feature.isEnabled,
          description: feature.isEnabled
              ? PlanUiStrings.included
              : PlanUiStrings.notIncluded,
        ),
      );
    }

    return result;
  }

  PlanFeatureData _mapVirtualRoom(CurrentPlan plan, PlanFeature feature) {
    if (!feature.isEnabled) {
      return const PlanFeatureData(
        label: PlanUiStrings.virtualRoomLabel,
        included: false,
        description: PlanUiStrings.notIncluded,
      );
    }

    final limit = feature.monthlyLimit ?? (plan.plan.slug == 'pro' ? 10 : null);
    final value = limit != null ? '${limit}x' : null;
    final description =
        limit != null ? PlanUiStrings.usageLabel(limit) : PlanUiStrings.included;

    return PlanFeatureData(
      label: PlanUiStrings.virtualRoomLabel,
      included: true,
      value: value,
      description: description,
    );
  }

  String _formatPrice(double price) {
    if (price <= 0) return 'Free';
    final formatted = price.toStringAsFixed(2).replaceAll('.', ',');
    return '$formatted€';
  }
}
