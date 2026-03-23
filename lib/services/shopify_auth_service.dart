import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for Shopify Customer Account API OAuth authentication.
///
/// Handles login (via in-app browser), deep-link callback, token storage,
/// auto-refresh, and customer profile fetching through the Cloudflare Worker.
class ShopifyAuthService {
  ShopifyAuthService._();
  static final ShopifyAuthService instance = ShopifyAuthService._();

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const _workerBase =
      'https://shopify-deploy.stefan-obholz.workers.dev';

  static const _keyAccessToken = 'shopify_access_token';
  static const _keyRefreshToken = 'shopify_refresh_token';
  static const _keyExpiresAt = 'shopify_expires_at';
  static const _keyIdToken = 'shopify_id_token';
  static const _keyCustomerId = 'shopify_customer_id';

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  String? _accessToken;
  String? _refreshToken;
  String? _idToken;
  String? _customerId;
  DateTime? _expiresAt;

  Completer<bool>? _loginCompleter;

  final _authStateController = StreamController<bool>.broadcast();

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  bool get isLoggedIn => _accessToken != null && !_isExpired;

  String? get accessToken => _accessToken;

  String? get customerId => _customerId;

  /// Emits `true` when logged in, `false` when logged out.
  Stream<bool> get onAuthStateChanged => _authStateController.stream;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Call once on app start. Loads stored tokens and validates them.
  Future<void> initialize() async {
    await _loadTokens();

    if (_accessToken != null && _isExpired && _refreshToken != null) {
      try {
        await refreshToken();
      } catch (e) {
        if (kDebugMode) debugPrint('ShopifyAuth: auto-refresh failed: $e');
        await _clearTokens();
      }
    }

    _authStateController.add(isLoggedIn);
  }

  /// Clean up resources.
  Future<void> dispose() async {
    await _authStateController.close();
  }

  /// Call this from [DeepLinkService] when a URI is received.
  /// Returns `true` if the URI was handled by this service.
  bool handleUri(Uri uri) {
    if (uri.scheme == 'everloxx' && uri.host == 'auth') {
      _handleDeepLink(uri);
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------

  /// Opens Shopify login in the system browser.
  /// Returns `true` if login succeeded, `false` if cancelled or failed.
  Future<bool> login() async {
    final loginUrl = Uri.parse('$_workerBase/auth/login');

    _loginCompleter = Completer<bool>();

    final launched = await launchUrl(
      loginUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      _loginCompleter = null;
      throw Exception('Could not open login URL.');
    }

    // Wait for the deep link callback (or timeout after 5 min)
    final result = await _loginCompleter!.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => false,
    );

    _loginCompleter = null;
    return result;
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  /// Logs out of Shopify and clears local tokens.
  Future<void> logout() async {
    // Open Shopify logout endpoint if we have an id_token
    if (_idToken != null) {
      final logoutUrl = Uri.parse(
        '$_workerBase/auth/logout?id_token=${Uri.encodeComponent(_idToken!)}',
      );
      try {
        await launchUrl(logoutUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (kDebugMode) debugPrint('ShopifyAuth: logout redirect failed: $e');
      }
    }

    await _clearTokens();
    _authStateController.add(false);
  }

  // ---------------------------------------------------------------------------
  // Token refresh
  // ---------------------------------------------------------------------------

  /// Refreshes the access token using the stored refresh token.
  /// Throws if no refresh token is available or the request fails.
  Future<void> refreshToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available.');
    }

    final response = await http.post(
      Uri.parse('$_workerBase/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': _refreshToken}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Token refresh failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception('Token refresh error: ${data['error']}');
    }

    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String? ?? _refreshToken;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    await _saveTokens();
    _authStateController.add(true);
  }

  /// Ensures we have a valid (non-expired) access token.
  /// Refreshes automatically if expired.
  Future<String> getValidAccessToken() async {
    if (_accessToken == null) {
      throw Exception('Not logged in.');
    }

    if (_isExpired && _refreshToken != null) {
      await refreshToken();
    }

    if (_accessToken == null) {
      throw Exception('Failed to obtain valid access token.');
    }

    return _accessToken!;
  }

  // ---------------------------------------------------------------------------
  // Customer profile
  // ---------------------------------------------------------------------------

  /// Fetches the customer profile and recent orders from Shopify.
  Future<Map<String, dynamic>> getCustomerProfile() async {
    final token = await getValidAccessToken();

    final response = await http.post(
      Uri.parse('$_workerBase/auth/customer'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      // Token might be expired server-side, try refresh once
      if (_refreshToken != null) {
        await refreshToken();
        return getCustomerProfile();
      }
      throw Exception('Unauthorized. Please log in again.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Customer profile request failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception('Customer profile error: ${data['error']}');
    }

    final customer = data['customer'] as Map<String, dynamic>;

    // Store customer ID for Supabase bridge
    if (customer['id'] != null) {
      _customerId = customer['id'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCustomerId, _customerId!);
    }

    return customer;
  }

  // ---------------------------------------------------------------------------
  // Supabase bridge
  // ---------------------------------------------------------------------------

  /// Links the Shopify customer to the current Supabase session.
  /// If the user is anonymous, updates their profile metadata with the
  /// Shopify customer ID. If not logged in to Supabase, signs in anonymously.
  Future<void> linkToSupabase() async {
    if (_customerId == null) {
      try {
        await getCustomerProfile();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ShopifyAuth: failed to get customer for Supabase link: $e');
        }
        return;
      }
    }

    if (_customerId == null) return;

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      // Sign in anonymously so RLS still works
      await supabase.auth.signInAnonymously();
    }

    // Update user metadata with Shopify customer ID
    await supabase.auth.updateUser(
      UserAttributes(data: {
        'shopify_customer_id': _customerId,
      }),
    );

    if (kDebugMode) {
      debugPrint('ShopifyAuth: linked Shopify customer $_customerId to Supabase');
    }
  }

  // ---------------------------------------------------------------------------
  // Deep link handling
  // ---------------------------------------------------------------------------

  void _handleDeepLink(Uri uri) {
    if (uri.path == '/callback') {
      _handleAuthCallback(uri);
    } else if (uri.path == '/logout') {
      _handleLogoutCallback();
    }
  }

  Future<void> _handleAuthCallback(Uri uri) async {
    final params = uri.queryParameters;

    final error = params['error'];
    if (error != null) {
      if (kDebugMode) debugPrint('ShopifyAuth: login error: $error');
      _loginCompleter?.complete(false);
      return;
    }

    final accessToken = params['access_token'];
    if (accessToken == null || accessToken.isEmpty) {
      if (kDebugMode) debugPrint('ShopifyAuth: no access_token in callback');
      _loginCompleter?.complete(false);
      return;
    }

    _accessToken = accessToken;
    _refreshToken = params['refresh_token'];
    _idToken = params['id_token'];

    final expiresIn = int.tryParse(params['expires_in'] ?? '') ?? 3600;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    await _saveTokens();
    _authStateController.add(true);

    if (kDebugMode) {
      debugPrint('ShopifyAuth: login successful, expires in ${expiresIn}s');
    }

    // Link to Supabase in the background
    linkToSupabase().catchError((e) {
      if (kDebugMode) debugPrint('ShopifyAuth: Supabase link failed: $e');
    });

    _loginCompleter?.complete(true);
  }

  void _handleLogoutCallback() {
    if (kDebugMode) debugPrint('ShopifyAuth: logout callback received');
    // Tokens already cleared in logout()
  }

  // ---------------------------------------------------------------------------
  // Token persistence
  // ---------------------------------------------------------------------------

  bool get _isExpired {
    if (_expiresAt == null) return true;
    // Consider expired 60 seconds early to avoid edge cases
    return DateTime.now().isAfter(_expiresAt!.subtract(const Duration(seconds: 60)));
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString(_keyAccessToken, _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString(_keyRefreshToken, _refreshToken!);
    }
    if (_idToken != null) {
      await prefs.setString(_keyIdToken, _idToken!);
    }
    if (_expiresAt != null) {
      await prefs.setInt(
        _keyExpiresAt,
        _expiresAt!.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_keyAccessToken);
    _refreshToken = prefs.getString(_keyRefreshToken);
    _idToken = prefs.getString(_keyIdToken);
    _customerId = prefs.getString(_keyCustomerId);

    final expiresAtMs = prefs.getInt(_keyExpiresAt);
    if (expiresAtMs != null) {
      _expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
    }

    if (kDebugMode && _accessToken != null) {
      debugPrint(
        'ShopifyAuth: loaded stored tokens, expired=$_isExpired',
      );
    }
  }

  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _idToken = null;
    _expiresAt = null;
    _customerId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyIdToken);
    await prefs.remove(_keyExpiresAt);
    await prefs.remove(_keyCustomerId);
  }
}
