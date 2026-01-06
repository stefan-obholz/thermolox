import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const redirectUrl = String.fromEnvironment(
    'SUPABASE_REDIRECT_URL',
    defaultValue: 'thermolox://auth/callback',
  );

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw SupabaseConfigException(
        'Missing Supabase config. Provide SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    if (kDebugMode) {
      final host = Uri.tryParse(supabaseUrl)?.host ?? 'invalid';
      debugPrint(
        'Supabase config: host=$host anonLen=${supabaseAnonKey.length}',
      );
      debugPrint('Supabase redirect: $redirectUrl');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
      ),
    );
  }
}

class SupabaseConfigException implements Exception {
  final String message;

  const SupabaseConfigException(this.message);

  @override
  String toString() => message;
}
