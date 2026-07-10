import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiConfig {
  /// Passe à false pour cacher proprement l'accès à TransitBot (région/quota
  /// non supporté en démo) SANS supprimer le code. Le bouton du header et la
  /// route /assistant restent présents mais l'entrée est masquée.
  static const bool transitBotEnabled = true;

  /// Clé injectée au build : --dart-define=GEMINI_API_KEY=xxx
  static const String _envKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Chemin de l'asset .env embarqué (gitignoré) lu au runtime.
  static const String _assetEnv = 'assets/env/.env';

  static const String _prefsKey = 'gemini_api_key';

  /// Clé effective, par ordre de priorité :
  /// 1. saisie runtime (dialogue 🔑 de l'assistant, SharedPreferences)
  /// 2. fichier .env embarqué (gitignoré, lu au runtime)
  /// 3. variable de compilation --dart-define
  static Future<String> get apiKey async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null && stored.isNotEmpty) return stored;

    try {
      final content = await rootBundle.loadString(_assetEnv);
      for (final raw in content.split('\n')) {
        final line = raw.trim();
        if (line.startsWith('GEMINI_API_KEY') && line.contains('=')) {
          final value = line
              .split('=')
              .skip(1)
              .join('=')
              .trim();
          final clean = value.length >= 2 &&
                  ((value.startsWith("'") && value.endsWith("'")) ||
                      (value.startsWith('"') && value.endsWith('"')))
              ? value.substring(1, value.length - 1)
              : value;
          if (clean.isNotEmpty) return clean;
        }
      }
    } catch (_) {
      // asset absent ou non renseigné -> on continue
    }

    return _envKey;
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, key.trim());
  }

  static Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
