import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plan.dart';
import '../models/plan_feature.dart';
import '../models/user_entitlements.dart';
import 'supabase_service.dart';

class PlanService {
  PlanService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Plan>> loadPlans({bool onlyActive = true}) async {
    final rows = await _client
        .from('plans')
        .select('id,slug,name,price_eur,is_active');

    final plans = <Plan>[];
    for (final row in rows) {
      final data = row as Map<String, dynamic>;
      final isActive = data['is_active'];
      if (onlyActive && isActive is bool && !isActive) continue;
      final plan = _mapPlanRow(data);
      if (plan != null) {
        plans.add(plan);
      }
    }
    return plans;
  }

  Future<Map<String, List<PlanFeature>>> loadPlanFeatures(
    List<Plan> plans,
  ) async {
    final idToSlug = <String, String>{};
    for (final plan in plans) {
      if (_isNotEmpty(plan.id)) {
        idToSlug[plan.id] = plan.slug;
      }
    }

    final planIds = idToSlug.keys.toList();
    if (planIds.isEmpty) return {};

    final rows = await _client
        .from('plan_features')
        .select('plan_id,feature_key,is_enabled,monthly_limit')
        .inFilter('plan_id', planIds);

    final featuresBySlug = <String, List<PlanFeature>>{};
    for (final row in rows) {
      final data = row as Map<String, dynamic>;
      final planId = data['plan_id']?.toString();
      final feature = _mapFeatureRow(data);
      if (planId == null || feature == null) continue;
      final slug = idToSlug[planId];
      if (slug == null) continue;
      featuresBySlug.putIfAbsent(slug, () => []).add(feature);
    }
    return featuresBySlug;
  }

  Future<PlanSubscriptionInfo?> getCurrentUserPlanInfo() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('user_subscriptions')
        .select('plan_id,status')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) return null;

    final planId = row['plan_id']?.toString();
    if (planId == null || planId.isEmpty) return null;

    final status = row['status']?.toString();
    final slug = await _resolvePlanSlug(planId);

    return PlanSubscriptionInfo(
      userId: user.id,
      planId: planId,
      planSlug: slug ?? planId,
      status: status,
    );
  }

  Future<UserEntitlements?> loadEntitlements({required String userId}) async {
    final row = await _client
        .from('user_entitlements')
        .select('pro_lifetime,credits_balance')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;

    final proLifetime = row['pro_lifetime'] == true;
    final balance = (row['credits_balance'] as num?)?.toInt() ?? 0;
    return UserEntitlements(proLifetime: proLifetime, creditsBalance: balance);
  }

  Future<void> upsertSubscription({
    required String userId,
    required String planId,
    String status = 'active',
  }) async {
    final now = DateTime.now().toUtc();
    final end = now.add(const Duration(days: 30));

    await _client.from('user_subscriptions').upsert(
      {
        'user_id': userId,
        'plan_id': planId,
        'status': status,
        'current_period_start': now.toIso8601String(),
        'current_period_end': end.toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  Future<String?> _resolvePlanSlug(String planId) async {
    if (!_looksLikeUuid(planId)) {
      return planId;
    }

    final row = await _client
        .from('plans')
        .select('slug')
        .eq('id', planId)
        .maybeSingle();

    return row?['slug']?.toString();
  }

  Plan? _mapPlanRow(Map<String, dynamic> row) {
    final slug = row['slug']?.toString();
    if (slug == null || slug.isEmpty) return null;
    final id = row['id']?.toString() ?? slug;
    final name = row['name']?.toString() ?? slug;
    final price = (row['price_eur'] as num?)?.toDouble() ?? 0.0;
    return Plan(id: id, slug: slug, name: name, priceEur: price);
  }

  PlanFeature? _mapFeatureRow(Map<String, dynamic> row) {
    final key = row['feature_key']?.toString();
    if (key == null || key.isEmpty) return null;
    final enabled = _toBool(row['is_enabled']);
    final limit = (row['monthly_limit'] as num?)?.toInt();
    return PlanFeature(
      featureKey: key,
      isEnabled: enabled,
      monthlyLimit: limit,
    );
  }

  bool _toBool(dynamic value) {
    if (value == true) return true;
    if (value is num) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  bool _looksLikeUuid(String value) {
    return RegExp(r'^[0-9a-fA-F\-]{32,}$').hasMatch(value);
  }

  bool _isNotEmpty(String value) => value.trim().isNotEmpty;
}

class PlanSubscriptionInfo {
  final String userId;
  final String planId;
  final String planSlug;
  final String? status;

  const PlanSubscriptionInfo({
    required this.userId,
    required this.planId,
    required this.planSlug,
    required this.status,
  });
}
