import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import 'supabase_service.dart';

class ProfileService {
  ProfileService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<UserProfile?> getProfile(String userId) async {
    final row = await _fetchProfileRow(userId);
    if (row == null) return null;
    return UserProfile.fromMap(row);
  }

  Future<void> upsertProfile(UserProfile profile) async {
    final data = profile.toMap();
    await _upsertProfileData(data);
  }

  Future<void> ensureConsents({
    required String userId,
    required bool termsAccepted,
    required bool privacyAccepted,
    bool marketingAccepted = false,
    String? locale,
    bool forceIfMissing = false,
    String? source,
  }) async {
    final existing = await getProfile(userId);
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{};

    if (termsAccepted || forceIfMissing) {
      if (existing?.termsAcceptedAt == null) {
        payload['terms_accepted_at'] = now;
      }
    }

    if (privacyAccepted || forceIfMissing) {
      if (existing?.privacyAcceptedAt == null) {
        payload['privacy_accepted_at'] = now;
      }
    }

    if (marketingAccepted && existing?.marketingAcceptedAt == null) {
      payload['marketing_accepted_at'] = now;
    }

    if (locale != null && locale.isNotEmpty && (existing?.locale ?? '').isEmpty) {
      payload['locale'] = locale;
    }

    if (payload.isEmpty) return;
    payload['id'] = userId;

    await _upsertProfileData(payload);
    await _insertUserConsents(
      userId: userId,
      payload: payload,
      locale: locale,
      source: source,
    );
  }

  Future<void> recordLegalAcceptance({
    required String userId,
    required DateTime termsAcceptedAt,
    required DateTime privacyAcceptedAt,
    String? termsVersion,
    String? privacyVersion,
    String? locale,
    String? source,
  }) async {
    final payload = <String, dynamic>{
      'id': userId,
      'terms_accepted_at': termsAcceptedAt.toUtc().toIso8601String(),
      'privacy_accepted_at': privacyAcceptedAt.toUtc().toIso8601String(),
      if (termsVersion != null && termsVersion.isNotEmpty)
        'terms_version': termsVersion,
      if (privacyVersion != null && privacyVersion.isNotEmpty)
        'privacy_version': privacyVersion,
      if (locale != null && locale.isNotEmpty) 'locale': locale,
    };

    await _upsertProfileData(payload);
    await _insertUserConsents(
      userId: userId,
      payload: payload,
      locale: locale,
      source: source,
    );
  }

  Future<void> seedProfileFromAuth({
    required User user,
    String? locale,
  }) async {
    final existing = await getProfile(user.id);
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final fullName = _readMetadataValue(metadata, [
      'full_name',
      'fullName',
      'name',
    ]);
    final firstName = _readMetadataValue(metadata, [
      'first_name',
      'firstName',
      'given_name',
      'givenName',
    ]) ??
        _firstNameFromFullName(fullName);
    final lastName = _readMetadataValue(metadata, [
      'last_name',
      'lastName',
      'family_name',
      'familyName',
    ]) ??
        _lastNameFromFullName(fullName);
    final avatar = _readMetadataValue(metadata, [
      'avatar_url',
      'avatarUrl',
      'picture',
    ]);
    final address = _readAddressMap(metadata);
    String? street = _readAddressValue(address, [
          'street',
          'street_address',
          'streetAddress',
          'address1',
          'line1',
        ]) ??
        _readMetadataValue(metadata, [
          'street',
          'street_address',
          'streetAddress',
          'address1',
          'line1',
        ]);
    String? houseNumber = _readAddressValue(address, [
          'house_number',
          'houseNumber',
          'street_number',
          'streetNumber',
          'line2',
          'address2',
        ]) ??
        _readMetadataValue(metadata, [
          'house_number',
          'houseNumber',
          'street_number',
          'streetNumber',
          'line2',
          'address2',
        ]);
    final postalCode = _readAddressValue(address, [
          'postal_code',
          'postalCode',
          'zip',
          'zip_code',
        ]) ??
        _readMetadataValue(metadata, [
          'postal_code',
          'postalCode',
          'zip',
          'zip_code',
        ]);
    final city = _readAddressValue(address, [
          'city',
          'locality',
          'town',
        ]) ??
        _readMetadataValue(metadata, [
          'city',
          'locality',
          'town',
        ]);
    final country = _readAddressValue(address, [
          'country',
          'country_code',
          'countryCode',
        ]) ??
        _readMetadataValue(metadata, [
          'country',
          'country_code',
          'countryCode',
        ]);

    if (houseNumber == null && street != null) {
      final parsed = _splitStreetNumber(street);
      if (parsed != null) {
        street = parsed.street;
        houseNumber = parsed.houseNumber;
      }
    }

    final payload = <String, dynamic>{'id': user.id};
    if ((existing?.firstName ?? '').isEmpty && firstName != null) {
      payload['first_name'] = firstName;
    }
    if ((existing?.lastName ?? '').isEmpty && lastName != null) {
      payload['last_name'] = lastName;
    }
    if ((existing?.avatarUrl ?? '').isEmpty && avatar != null) {
      payload['avatar_url'] = avatar;
    }
    if ((existing?.street ?? '').isEmpty && street != null) {
      payload['street'] = street;
    }
    if ((existing?.houseNumber ?? '').isEmpty && houseNumber != null) {
      payload['house_number'] = houseNumber;
    }
    if ((existing?.postalCode ?? '').isEmpty && postalCode != null) {
      payload['postal_code'] = postalCode;
    }
    if ((existing?.city ?? '').isEmpty && city != null) {
      payload['city'] = city;
    }
    if ((existing?.country ?? '').isEmpty && country != null) {
      payload['country'] = country;
    }
    if ((existing?.locale ?? '').isEmpty &&
        locale != null &&
        locale.isNotEmpty) {
      payload['locale'] = locale;
    }

    if (payload.length <= 1) return;
    await _upsertProfileData(payload);
  }

  bool needsConsents(UserProfile? profile) {
    if (profile == null) return true;
    return profile.termsAcceptedAt == null || profile.privacyAcceptedAt == null;
  }

  Future<Map<String, dynamic>?> _fetchProfileRow(String userId) async {
    try {
      return await _client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      if (_isMissingColumnError(e)) {
        return await _client
            .from('profiles')
            .select('*')
            .eq('user_id', userId)
            .maybeSingle();
      }
      rethrow;
    }
  }

  Future<void> _upsertProfileData(Map<String, dynamic> data) async {
    try {
      await _client.from('profiles').upsert(data, onConflict: 'id');
    } catch (e) {
      if (_isMissingColumnError(e)) {
        final adjusted = Map<String, dynamic>.from(data);
        final userId = adjusted.remove('id');
        adjusted['user_id'] = userId;
        await _client.from('profiles').upsert(adjusted, onConflict: 'user_id');
      } else {
        rethrow;
      }
    }
  }

  Future<void> _insertUserConsents({
    required String userId,
    required Map<String, dynamic> payload,
    String? locale,
    String? source,
  }) async {
    final data = <String, dynamic>{
      'user_id': userId,
      if (payload['terms_accepted_at'] != null)
        'terms_accepted_at': payload['terms_accepted_at'],
      if (payload['privacy_accepted_at'] != null)
        'privacy_accepted_at': payload['privacy_accepted_at'],
      if (payload['marketing_accepted_at'] != null)
        'marketing_accepted_at': payload['marketing_accepted_at'],
      if (locale != null && locale.isNotEmpty) 'locale': locale,
      if (source != null && source.isNotEmpty) 'source': source,
    };

    if (data.length <= 1) return;
    try {
      await _client.from('user_consents').insert(data);
    } catch (e) {
      if (_isMissingColumnError(e)) {
        final fallback = Map<String, dynamic>.from(data)
          ..removeWhere((key, _) => key == 'source' || key == 'locale');
        if (fallback.length <= 1) return;
        try {
          await _client.from('user_consents').insert(fallback);
        } catch (_) {
          if (kDebugMode) {
            debugPrint('user_consents fallback insert failed: $e');
          }
        }
      } else if (kDebugMode) {
        debugPrint('user_consents insert failed: $e');
      }
    }
  }

  String? _readMetadataValue(Map<String, dynamic> metadata, List<String> keys) {
    for (final key in keys) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  Map<String, dynamic>? _readAddressMap(Map<String, dynamic> metadata) {
    final candidates = [
      'address',
      'addresses',
      'billing_address',
      'billingAddress',
      'shipping_address',
      'shippingAddress',
    ];
    for (final key in candidates) {
      final value = metadata[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return value.cast<String, dynamic>();
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is Map<String, dynamic>) return first;
        if (first is Map) return first.cast<String, dynamic>();
      }
    }
    return null;
  }

  String? _readAddressValue(Map<String, dynamic>? address, List<String> keys) {
    if (address == null) return null;
    for (final key in keys) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  _StreetParseResult? _splitStreetNumber(String value) {
    final match = RegExp(r'^(.*?)[,\\s]+(\\d+\\w*)$').firstMatch(value.trim());
    if (match == null) return null;
    final street = match.group(1)?.trim();
    final number = match.group(2)?.trim();
    if (street == null || street.isEmpty || number == null || number.isEmpty) {
      return null;
    }
    return _StreetParseResult(street: street, houseNumber: number);
  }

  String? _firstNameFromFullName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return null;
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;
    return parts.first;
  }

  String? _lastNameFromFullName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return null;
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    return parts.sublist(1).join(' ');
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

class _StreetParseResult {
  final String street;
  final String houseNumber;

  const _StreetParseResult({required this.street, required this.houseNumber});
}
