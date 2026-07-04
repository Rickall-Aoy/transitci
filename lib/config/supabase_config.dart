import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ligne.dart';
import '../models/gare.dart';
import '.env.dart';

class SupabaseConfig {
  static String get _url {
    try {
      return Env.supabaseUrl;
    } catch (e) {
      debugPrint('⚠️ $e');
      return String.fromEnvironment('SUPABASE_URL');
    }
  }

  static String get _publishableKey {
    try {
      return Env.supabasePublishableKey;
    } catch (e) {
      debugPrint('⚠️ $e');
      return String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    }
  }

  static String get url => _url;
  static String get publishableKey => _publishableKey;

  static bool get isConfigured =>
      url.isNotEmpty &&
      url != 'https://placeholder.supabase.co' &&
      publishableKey.isNotEmpty &&
      !publishableKey.contains('placeholder');
}
