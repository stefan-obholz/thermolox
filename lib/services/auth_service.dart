import 'package:supabase_flutter/supabase_flutter.dart';

import 'consent_service.dart';
import 'local_data_service.dart';
import 'supabase_service.dart';

class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  bool get isAnonymous => isUserAnonymous(currentUser);

  bool get isEmailVerified {
    final user = currentUser;
    return isUserVerified(user);
  }

  bool isUserVerified(User? user) {
    if (user == null) return false;
    return user.emailConfirmedAt != null || user.confirmedAt != null;
  }

  bool isUserAnonymous(User? user) {
    if (user == null) return false;
    final appMeta = user.appMetadata;
    final provider = appMeta['provider']?.toString();
    if (provider == 'anonymous') return true;
    final providers = appMeta['providers'];
    if (providers is List && providers.contains('anonymous')) return true;
    final isAnon = appMeta['is_anonymous'];
    return isAnon == true;
  }

  Stream<User?> get currentUserStream => _client.auth.onAuthStateChange.map(
        (event) => event.session?.user,
      );

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: SupabaseService.redirectUrl,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> refreshSession() => _client.auth.refreshSession();

  Future<ResendResponse> resendSignupEmail({
    required String email,
  }) {
    return _client.auth.resend(
      email: email,
      type: OtpType.signup,
      emailRedirectTo: SupabaseService.redirectUrl,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke('delete_account');
    if (response.status != 200) {
      final message = response.data?.toString() ?? 'Account deletion failed.';
      throw Exception(message);
    }
    await _client.auth.signOut();
    try {
      await LocalDataService.clearAll();
      await ConsentService.instance.clearLocal();
    } catch (_) {
      // ignore local cleanup errors after account deletion
    }
  }
}
