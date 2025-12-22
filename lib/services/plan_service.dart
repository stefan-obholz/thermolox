import 'dart:math' as math;

import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/current_plan.dart';
import '../models/plan.dart';
import '../models/plan_feature.dart';

class PlanService {
  PlanService(this._client);

  final SupabaseClient _client;

  Future<Map<String, CurrentPlan>> getAllPlansPublic() async {
    final plans = await _fetchPlansBySlugs(const ['basic', 'pro']);
    final result = <String, CurrentPlan>{};
    for (final plan in plans) {
      final features = await _fetchFeaturesForPlan(plan);
      result[plan.slug] = _buildCurrentPlan(plan, features);
    }
    return result;
  }

  Future<CurrentPlan> getPlanForAnonymous() async {
    final plans = await getAllPlansPublic();
    final basic = plans['basic'];
    if (basic == null) {
      throw StateError('Basic plan not found.');
    }
    return basic;
  }

  Future<CurrentPlan> getPlanForCurrentUser({
    CurrentPlan? fallback,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return fallback ?? await getPlanForAnonymous();
    }

    final sub = await _fetchSubscriptionRow(user.id);

    if (sub == null) {
      return fallback ?? await getPlanForAnonymous();
    }

    final status = sub['status']?.toString();
    if (status != null && status != 'active') {
      return fallback ?? await getPlanForAnonymous();
    }

    final planId = sub['plan_id']?.toString();
    if (planId == null || planId.isEmpty) {
      return fallback ?? await getPlanForAnonymous();
    }

    final plan = await _fetchPlanByIdOrSlug(planId);
    if (plan == null) {
      return fallback ?? await getPlanForAnonymous();
    }

    final features = await _fetchFeaturesForPlan(plan);
    int? used;
    if (features['virtual_room']?.isEnabled == true) {
      used = await _fetchVirtualRoomUsage(user.id);
    }

    return _buildCurrentPlan(plan, features, virtualRoomUsed: used);
  }

  Future<bool> hasSubscription(String userId) async {
    final row = await _fetchSubscriptionRow(userId, select: 'id');
    return row != null;
  }

  Future<void> upsertSubscription({
    required String userId,
    required Plan plan,
  }) async {
    final now = DateTime.now().toUtc();
    final end = now.add(const Duration(days: 30));
    final planId = _planIdForSubscription(plan);

    final payload = {
      'user_id': userId,
      'plan_id': planId,
      'status': 'active',
      'current_period_start': now.toIso8601String(),
      'current_period_end': end.toIso8601String(),
    };

    try {
      await _client
          .from('user_subscriptions')
          .upsert(payload, onConflict: 'user_id');
    } catch (e) {
      if (_isMissingTableError(e)) {
        await _client
            .from('subscriptions')
            .upsert(payload, onConflict: 'user_id');
      } else {
        rethrow;
      }
    }
  }

  Future<List<Plan>> _fetchPlansBySlugs(List<String> slugs) async {
    final rows = await _client
        .from('plans')
        .select('id,slug,name,price_eur,is_active')
        .inFilter('slug', slugs);

    final plans = <Plan>[];
    for (final row in rows) {
      final plan = _mapPlanRow(row as Map<String, dynamic>);
      if (plan == null) continue;
      final isActive = row['is_active'];
      if (isActive is bool && !isActive) continue;
      plans.add(plan);
    }
    return plans;
  }

  Future<Plan?> _fetchPlanByIdOrSlug(String planId) async {
    final byId = await _client
        .from('plans')
        .select('id,slug,name,price_eur,is_active')
        .eq('id', planId)
        .maybeSingle();
    final mappedById = _mapPlanRow(byId as Map<String, dynamic>?);
    if (mappedById != null) {
      return mappedById;
    }

    final bySlug = await _client
        .from('plans')
        .select('id,slug,name,price_eur,is_active')
        .eq('slug', planId)
        .maybeSingle();
    return _mapPlanRow(bySlug as Map<String, dynamic>?);
  }

  Future<Map<String, PlanFeature>> _fetchFeaturesForPlan(Plan plan) async {
    final ids = <String>{plan.id, plan.slug}
        .where((value) => value.trim().isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      return {};
    }
    try {
      return await _fetchFeaturesFromTable('plan_features', ids);
    } catch (e) {
      if (_isMissingTableError(e)) {
        return await _fetchFeaturesFromTable('plan_limits', ids);
      }
      rethrow;
    }
  }

  Future<int> _fetchVirtualRoomUsage(String userId) async {
    try {
      return await _fetchUsageFromTable('feature_usage', userId);
    } catch (e) {
      if (_isMissingTableError(e)) {
        try {
          return await _fetchUsageFromTable('usage_counters', userId);
        } catch (_) {
          return 0;
        }
      }
      return 0;
    }
  }

  CurrentPlan _buildCurrentPlan(
    Plan plan,
    Map<String, PlanFeature> features, {
    int? virtualRoomUsed,
  }) {
    final virtual = features['virtual_room'];
    final limit = virtual?.monthlyLimit;
    final enabled = virtual?.isEnabled ?? false;
    final used = enabled ? (virtualRoomUsed ?? 0) : null;
    final remaining = enabled && limit != null
        ? math.max(0, limit - (used ?? 0))
        : null;

    return CurrentPlan(
      plan: plan,
      features: features,
      virtualRoomLimit: enabled ? limit : null,
      virtualRoomUsed: used,
      virtualRoomRemaining: remaining,
    );
  }

  Plan? _mapPlanRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final slug = row['slug']?.toString() ?? row['plan_id']?.toString();
    if (slug == null || slug.isEmpty) return null;
    final id = row['id']?.toString() ?? slug;
    final name = row['name']?.toString() ?? slug;
    final price = (row['price_eur'] as num?)?.toDouble() ?? 0.0;
    return Plan(id: id, slug: slug, name: name, priceEur: price);
  }

  String _planIdForSubscription(Plan plan) {
    final id = plan.id.trim();
    return id.isNotEmpty ? id : plan.slug;
  }

  String _currentPeriodYm() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  Future<Map<String, dynamic>?> _fetchSubscriptionRow(
    String userId, {
    String select = 'plan_id,status',
  }) async {
    try {
      return await _client
          .from('user_subscriptions')
          .select(select)
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      if (_isMissingTableError(e)) {
        return await _client
            .from('subscriptions')
            .select(select)
            .eq('user_id', userId)
            .maybeSingle();
      }
      rethrow;
    }
  }

  Future<Map<String, PlanFeature>> _fetchFeaturesFromTable(
    String table,
    List<String> planIds,
  ) async {
    final features = <String, PlanFeature>{};
    for (final planId in planIds) {
      if (planId.trim().isEmpty) continue;
      List<dynamic> rows;
      try {
        rows = await _client
            .from(table)
            .select('*')
            .eq('plan_id', planId) as List<dynamic>;
      } catch (e) {
        if (_isInvalidInputError(e)) {
          continue;
        }
        if (_isMissingColumnError(e)) {
          return {};
        }
        rethrow;
      }
      if (rows.isEmpty) continue;
      for (final row in rows) {
        final data = row as Map<String, dynamic>;
        final keyRaw = data['feature_key'] ??
            data['feature'] ??
            data['featureKey'] ??
            data['key'];
        final key = keyRaw?.toString();
        if (key == null || key.isEmpty) continue;

        final enabledRaw =
            data['is_enabled'] ?? data['enabled'] ?? data['isEnabled'];
        final enabled = _toBool(enabledRaw);

        final limitRaw = data['monthly_limit'] ??
            data['limit_per_month'] ??
            data['limit'] ??
            data['monthlyLimit'];
        final limit = (limitRaw as num?)?.toInt();

        features[key] = PlanFeature(
          featureKey: key,
          isEnabled: enabled,
          monthlyLimit: limit,
        );
      }
      if (features.isNotEmpty) {
        break;
      }
    }
    return features;
  }

  Future<int> _fetchUsageFromTable(String table, String userId) async {
    final period = _currentPeriodYm();
    final rows = await _client
        .from(table)
        .select('*')
        .eq('user_id', userId)
        .eq('feature_key', 'virtual_room')
        .eq('period_ym', period)
        .limit(1);
    if (rows is List && rows.isNotEmpty) {
      final data = rows.first as Map<String, dynamic>;
      final value = data['used_count'] ?? data['used'];
      return (value as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  bool _toBool(dynamic value) {
    if (value == true) return true;
    if (value is num) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  bool _isMissingTableError(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final message = error.message.toLowerCase();
      if (code == '42P01') return true;
      return message.contains('relation') && message.contains('does not exist');
    }
    return false;
  }

  bool _isInvalidInputError(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final message = error.message.toLowerCase();
      if (code == '22P02') return true;
      return message.contains('invalid input syntax');
    }
    return false;
  }

  bool _isMissingColumnError(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final message = error.message.toLowerCase();
      if (code == '42703') return true;
      return message.contains('column') && message.contains('does not exist');
    }
    return false;
  }
}
