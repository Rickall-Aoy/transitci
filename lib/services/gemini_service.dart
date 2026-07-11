import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/gemini_config.dart';

class GeminiService {
  // Le modèle 'gemini-2.5-flash' est fermé aux nouveaux projets Google
  // Cloud (erreur "no longer available to new users"). On utilise l'alias
  // maintenu 'gemini-flash-latest' qui pointe toujours vers le modèle Flash
  // gratuit recommandé — évite d'être bloqué si Google change encore de
  // génération par défaut. Repli possible : 'gemini-3-flash-preview'
  // (confirmé disponible, modèle gratuit recommandé pour les nouveaux
  // projets).
  static const String _modelName = 'gemini-flash-latest';

  // Version d'API (doit correspondre à l'URL testée manuellement : v1beta).
  static const String _apiVersion = 'v1beta';

  static const String _systemPrompt = '''
Tu es « TransitBot », l'assistant virtuel de Transit CI, une application ivoirienne
d'aide au déplacement dans Abidjan et sa périphérie (Abobo, Adjamé, Cocody,
Yopougon, Plateau, Treichville, Marcory, Koumassi, Bingerville, Riviera...).

Contexte transport local :
- Modes disponibles : Woro-Woro (taxi communal, trajet court, on dit son arrêt
  au chauffeur), Gbaka (minicar, s'arrête à la demande, on crie son arrêt),
  SOTRA (bus et car, arrêts fixes aux panneaux), et Yango (VTC à la demande).
- Tarifs indicatifs : Woro-Woro ~300 FCFA, Gbaka ~200 FCFA, SOTRA ~200 FCFA,
  Yango bien plus cher (prix dynamique, ~1500 FCFA+).
- Heures de pointe : 7h-9h et 17h-20h (fortes embouteillages).
- La plupart des trajets nécessitent 1 à 2 correspondances.

Ton rôle :
- Aider l'utilisateur à planifier un trajet, choisir un mode, estimer un temps
  et un coût, et donner des conseils pratiques (où descendre, comment payer).
- Répondre en français, de façon concise, chaleureuse et claire.
- Si on te donne un point de départ et une destination, propose une ou deux
  options réalistes avec mode(s), correspondances, durée et prix estimés.
- Si une info est inconnue (horaires exacts, travaux), dis-le plutôt que
  d'inventer. Tu ne fais pas de réservation ni de paiement.
- Utilise des emojis avec parcimonie pour structurer la réponse.
''';

  static GenerativeModel? _model;
  static ChatSession? _chat;

  static bool get isReady => _model != null && _chat != null;

  /// Masque la clé pour le debug (ne jamais afficher la clé en clair).
  static String _maskKey(String k) {
    if (k.length <= 10) return '${k.substring(0, k.length.clamp(0, k.length))} (court)';
    return '${k.substring(0, 6)}…${k.substring(k.length - 4)} (${k.length} car.)';
  }

  /// (Re)charge la clé et (re)crée la session de chat.
  /// Retourne false si aucune clé n'est configurée.
  static Future<bool> init() async {
    final key = await GeminiConfig.apiKey;
    if (key.isEmpty) {
      _model = null;
      _chat = null;
      return false;
    }
    try {
      debugPrint(
        '🔍 Gemini: model=$_modelName | apiVersion=$_apiVersion | '
        'key=${_maskKey(key)}',
      );
      debugPrint(
        '🔍 Gemini URL: https://generativelanguage.googleapis.com/$_apiVersion/'
        'models/$_modelName:generateContent?key=${key.substring(0, key.length.clamp(0, 4))}...',
      );
      _model = GenerativeModel(
        model: _modelName,
        apiKey: key,
        requestOptions: RequestOptions(apiVersion: _apiVersion),
        systemInstruction: Content.system(_systemPrompt),
      );
      _chat = _model!.startChat();
      return true;
    } catch (e) {
      debugPrint('❌ Gemini init échoué: $e');
      _model = null;
      _chat = null;
      return false;
    }
  }

  /// Réinitialise l'historique de la conversation.
  static void resetChat() {
    if (_model != null) _chat = _model!.startChat();
  }

  /// Envoie un message et diffuse la réponse en streaming (texte accumulé).
  /// En cas d'erreur ou de clé manquante, émet un message explicite.
  static Stream<String> sendMessage(String text) async* {
    if (_chat == null) {
      final ok = await init();
      if (!ok) {
        yield _messageSansCle;
        return;
      }
    }

    // Retry simple avec backoff (utile pour les 429 / charge temporaire).
    const int maxRetries = 2;
    for (int attempt = 0;; attempt++) {
      final buffer = StringBuffer();
      try {
        final stream = _chat!.sendMessageStream(Content.text(text.trim()));
        await for (final response in stream) {
          final part = response.text;
          if (part != null && part.isNotEmpty) {
            buffer.write(part);
            // On diffuse le delta (texte du chunk), pas le texte cumulé :
            // les consommateurs (guide_service, assistant) recomposent eux-mêmes.
            yield part;
          }
        }
        if (buffer.isEmpty) {
          debugPrint('⚠️ Gemini: réponse reçue mais vide (candidates/safety).');
          yield _messageIndisponible;
        }
        return;
      } catch (e) {
        final msg = e.toString();
        debugPrint('❌ Gemini erreur (tentative $attempt): $msg');

        final is404 =
            msg.contains('404') || msg.toLowerCase().contains('not found');
        if (is404) {
          yield _messageModeleIntrouvable;
          return;
        }

        final isChargeElevee = msg.toLowerCase().contains('high demand') || msg.toLowerCase().contains('429');

        if (attempt < maxRetries) {
          await Future.delayed(isChargeElevee ? const Duration(seconds: 8) : const Duration(seconds: 2));
          continue;
        }

        if (buffer.isEmpty) {
          yield isChargeElevee
              ? "🤖 Service momentanément surchargé. Réessaie dans 30 secondes."
              : _messageIndisponible;
        } else {
          yield "${buffer.toString()}\n\n⚠️ Réponse interrompue.";
        }
        return;
      }
    }

  }

  static String get _messageSansCle =>
      "🔑 Clé API Gemini manquante. Ouvre les réglages de l'assistant et "
      "saisis ta clé (obtenable sur aistudio.google.com/apikey).";

  /// 404 : le modèle demandé n'existe pas pour cette clé/région.
  static String get _messageModeleIntrouvable =>
      "🤖 Modèle \"$_modelName\" introuvable pour ta clé/région.\n"
      "Liste tes modèles dispo :\n"
      "curl \"https://generativelanguage.googleapis.com/v1beta/models?key=TA_CLE\"\n"
      "puis change _modelName dans gemini_service.dart.";

  /// Repli amical pour quota/réseau : oriente vers la recherche classique.
  static String get _messageIndisponible =>
      "🤖 Assistant temporairement indisponible (quota ou région).\n"
      "Utilise la recherche classique ci-dessous pour planifier ton trajet.";
}
