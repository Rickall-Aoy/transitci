import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/transitbot_phrases.dart';
import '../services/gemini_service.dart';

enum GuideStep {
  idle,
  searching,
  destinationSelected,
  resultsShown,
  navigating,
  arrived,
  signalProblem,
  addStop,
  chauffeurMode,
}

class GuideMessage {
  final String text;
  final String? targetWidget;
  final bool highlightTarget;
  final bool showActionButton;
  final String? actionLabel;
  final VoidCallback? onAction;

  const GuideMessage({
    required this.text,
    this.targetWidget,
    this.highlightTarget = false,
    this.showActionButton = false,
    this.actionLabel,
    this.onAction,
  });
}

class GuideService {
  static final GuideService _instance = GuideService._();
  factory GuideService() => _instance;
  GuideService._();

  StreamController<GuideMessage>? _controller;
  Stream<GuideMessage> get stream => _controller?.stream ?? const Stream.empty();
  bool get isActive => _controller != null;

  void start() {
    _controller ??= StreamController<GuideMessage>.broadcast();
  }

  void dispose() {
    _controller?.close();
    _controller = null;
  }

  Future<void> triggerStep(GuideStep step, {String? destination}) async {
    final message = await _generateMessage(step);
    _controller?.add(message);
  }

  Future<void> showTutorial(String context) async {
    final message = await _generateTutorial(context);
    _controller?.add(message);
  }

  void showTip(String text) {
    if (text.isEmpty) return;
    _controller?.add(GuideMessage(text: text));
  }

  Future<GuideMessage> askQuestion(String question, {String? context}) async {
    final partials = <String>[];
    await for (final msg in askQuestionStream(question, context: context)) {
      partials.add(msg.text);
    }
    return GuideMessage(text: partials.join(), showActionButton: false);
  }

  Stream<GuideMessage> askQuestionStream(String question, {String? context}) async* {
    final prompt = _buildQuestionPrompt(question, context);
    if (!GeminiService.isReady) {
      final msg = GuideMessage(text: _staticAnswerForQuestion(question), showActionButton: false);
      _controller?.add(msg);
      yield msg;
      return;
    }

    try {
      final stream = GeminiService.sendMessage(prompt);
      final combined = stream.timeout(const Duration(seconds: 10), onTimeout: (sink) {
        sink.addError(TimeoutException('Gemini timeout'));
        sink.close();
      });
      final buffer = StringBuffer();
      await for (final partial in combined) {
        buffer.write(partial);
        final msg = GuideMessage(text: buffer.toString(), showActionButton: false);
        _controller?.add(msg);
        yield msg;
      }
    } on TimeoutException {
      final msg = GuideMessage(text: 'Délai dépassé. Réessaie dans un instant.', showActionButton: false);
      _controller?.add(msg);
      yield msg;
    } catch (e) {
      final msg = GuideMessage(text: _staticAnswerForQuestion(question), showActionButton: false);
      _controller?.add(msg);
      yield msg;
    }
  }

  Future<GuideMessage> _generateMessage(GuideStep step) async {
    // Phrase 100 % locale (voir transitBotPhrases) : le fade-in de l'overlay
    // se déclenche instantanément, sans aucun appel Gemini/réseau.
    final text =
        transitBotPhrases[step] ?? transitBotPhrases[GuideStep.idle]!;
    return GuideMessage(text: text, showActionButton: false);
  }

  Future<GuideMessage> _generateTutorial(String context) async {
    return GuideMessage(
      text: transitBotTutorial(context),
      showActionButton: false,
    );
  }

  static const Map<String, String> _transportDescriptions = {
    'sotra': 'la SOTRA (bus urbains officiels d\'Abidjan : tarifs, lignes, horaires, gares, avantages, inconvénients, conseils pratiques pour un usager à Abidjan)',
    'gbaka': 'les Gbaka (minibus collectifs privés d\'Abidjan : fonctionnement, tarifs approximatifs, gares de départ, avantages, inconvénients, sécurité, heures de service)',
    'woro_woro': 'les Woro-Woro (taxis collectifs de couleur selon la commune : fonctionnement, tarifs, zones desservies, conseils, différences avec le taxi compteur)',
    'warren_express': 'le Warren Express (minibus express interurbain rapide : tarifs, gares, destinations principales, confort, comparaison avec les autres modes)',
    'yango': 'Yango (VTC à Abidjan : tarification dynamique, estimation de prix, conseils pour réduire le coût, comparaison avec le taxi compteur, disponibilité selon les heures)',
    'taxi_compteur': 'les taxis compteur à Abidjan (tarification, négociation, zones, avantages par rapport au Woro-Woro, sécurité, disponibilité nocturne)',
    'marche': 'les déplacements à pied à Abidjan (distances raisonnables, sécurité piétonne, zones praticables, passerelles, risques par temps de pluie)',
    'metro': 'le futur Métro d\'Abidjan (projet en cours, lignes prévues, calendrier estimé, impact sur la mobilité, stations prévues)',
    'bateau_bus': 'le Bateau Bus à Abidjan (liaison lagunaire : gares, tarifs, horaires, zones desservies, avantages pour éviter les embouteillages)',
  };

  String _buildQuestionPrompt(String question, String? context) {
    final q = question.toLowerCase();
    String? type;
    if (q.contains('sotra') || q.contains('bus')) {
      type = 'sotra';
    } else if (q.contains('gbaka')) {
      type = 'gbaka';
    } else if (q.contains('woro-woro') || q.contains('woro woro') || q.contains('woro')) {
      type = 'woro_woro';
    } else if (q.contains('warren') || q.contains('express')) {
      type = 'warren_express';
    } else if (q.contains('yango')) {
      type = 'yango';
    } else if (q.contains('taxi compteur') || q.contains('taxi')) {
      type = 'taxi_compteur';
    } else if (q.contains('bateau bus') || q.contains('bateau')) {
      type = 'bateau_bus';
    } else if (q.contains('métro') || q.contains('metro')) {
      type = 'metro';
    } else if (q.contains('marche') || q.contains('à pied') || q.contains('pied')) {
      type = 'marche';
    }

    final desc = _transportDescriptions[type] ??
        'les transports en commun à Abidjan (modes disponibles, tarifs, conseils pratiques, sécurité)';

    final safeContext = context?.trim();
    final contextBlock = safeContext != null && safeContext.isNotEmpty
        ? "\nContexte actuel : $safeContext."
        : "";

    return '''
Tu es TransitBot, assistant de mobilité spécialisé sur $desc.
Réponds en français, de façon claire et concise (3 à 5 phrases max).
Adopte un ton naturel et bienveillant, comme un habitant d\'Abidjan qui connaît bien les transports.
Donne des informations pratiques : tarifs approximatifs, conseils, avantages, inconvénients, sécurité si pertinent.
$contextBlock

Question de l\'utilisateur : $question
''';
  }

  String _staticAnswerForQuestion(String question) {
    final q = question.toLowerCase();

    // ── Transports ──
    if (q.contains('sotra') || q.contains('bus')) {
      return 'La SOTRA, c\'est le bus officiel d\'Abidjan. Tarif fixe à 200 FCFA, confortable et climatisé sur certaines lignes. Idéal aux heures creuses, mais attention : aux heures de pointe, les arrêts bondés peuvent faire perdre beaucoup de temps.';
    }
    if (q.contains('gbaka')) {
      return 'Le Gbaka, c\'est le minibus collectif privé — rapide, pas cher (~200 FCFA), mais souvent bondé. Il part quand il est plein. Aux heures de pointe à Adjamé ou Yopougon, préfère partir tôt ou attendre un second passage.';
    }
    if (q.contains('woro-woro') || q.contains('woro woro') || q.contains('woro')) {
      return 'Les Woro-Woro sont des taxis collectifs reconnaissables par leur couleur selon la commune (~300 FCFA). Ils suivent des axes fixes mais s\'arrêtent à la demande. Plus rapides que le Gbaka sur courte distance, mais plus chers.';
    }
    if (q.contains('warren') || q.contains('express')) {
      return 'Le Warren Express est un minibus rapide interurbain, idéal pour les longues distances comme Abobo–Plateau ou Yopougon–Cocody. Tarif entre 300 et 500 FCFA selon la distance. Départ depuis les grandes gares routières.';
    }
    if (q.contains('yango')) {
      return 'Yango est disponible partout à Abidjan, 24h/24. Le prix varie selon la distance et la demande. Pour économiser, évite les heures de pointe (7h–9h et 17h–19h) où le tarif peut doubler. Très pratique la nuit quand les autres modes sont rares.';
    }
    if (q.contains('taxi compteur') || q.contains('taxi')) {
      return 'Le taxi compteur est plus cher mais plus confortable et direct. Négociable si le compteur n\'est pas enclenché. Disponible 24h/24, pratique pour les trajets de nuit ou les zones mal desservies par les transports collectifs.';
    }
    if (q.contains('bateau bus') || q.contains('bateau')) {
      return 'Le Bateau Bus relie plusieurs communes via la lagune (Plateau, Treichville, Locodjro…). Tarif ~200 FCFA, très pratique pour éviter les embouteillages du pont. Attention aux horaires : dernier départ souvent vers 19h–20h.';
    }
    if (q.contains('métro') || q.contains('metro')) {
      return 'Le Métro d\'Abidjan est en cours de construction. La ligne 1 devrait relier Anyama à l\'Aéroport. Pas encore en service, mais il changera profondément la mobilité de la ville quand il ouvrira.';
    }
    if (q.contains('marche') || q.contains('à pied') || q.contains('pied')) {
      return 'À Abidjan, marcher est envisageable sur de courtes distances dans des zones comme le Plateau ou Cocody. Évite les grands axes sans trottoir et les zones inondables par temps de pluie. La marche est un bon complément pour les correspondances courtes (< 400m).';
    }

    // ── Trafic ──
    if (q.contains('embouteillage') || q.contains('bouchon') ||
        q.contains('circulation') || q.contains('trafic')) {
      return 'Les embouteillages sont fréquents à Abidjan aux heures de pointe (7h–9h et 17h–19h), surtout à Adjamé, sur le boulevard VGE et les accès aux ponts. Préfère partir avant 7h ou après 9h30 le matin. Pense au Bateau Bus si tu traverses la lagune.';
    }
    if (q.contains('heure de pointe')) {
      return 'Les heures de pointe à Abidjan : 7h–9h le matin et 17h–19h le soir. Pendant ces créneaux, les Gbaka et Woro-Woro sont bondés et les routes saturées. Prévois +15 à +30 min sur ton temps de trajet habituel.';
    }

    // ── Horaires ──
    if (q.contains('premier départ') || q.contains('ouverture')) {
      return 'Les premiers Gbaka et Woro-Woro démarrent généralement vers 5h30–6h selon les axes. La SOTRA commence ses rotations vers 6h. Le Bateau Bus ouvre vers 6h30. Très tôt le matin, Yango ou un taxi compteur sont souvent les seules options fiables.';
    }
    if (q.contains('dernier départ') || q.contains('fermeture')) {
      return 'Les Gbaka et Woro-Woro circulent généralement jusqu\'à 21h–22h selon les axes, parfois moins en banlieue. Après 22h, Yango ou un taxi compteur sont recommandés. Le Bateau Bus s\'arrête souvent vers 19h–20h.';
    }
    if (q.contains('horaire') || q.contains('fréquence') || q.contains('attente')) {
      return 'Les Gbaka et Woro-Woro n\'ont pas d\'horaires fixes : ils partent quand ils sont pleins. Aux heures de pointe, l\'attente est courte (2–5 min) mais les véhicules sont bondés. Aux heures creuses, l\'attente peut monter à 10–20 min.';
    }

    // ── Tarifs ──
    if (q.contains('prix') || q.contains('coût') || q.contains('tarif') ||
        q.contains('combien') || q.contains('payer')) {
      return 'Tarifs approximatifs à Abidjan :\n• SOTRA : 200 FCFA fixe\n• Gbaka : 200–300 FCFA\n• Woro-Woro : 300–500 FCFA\n• Warren Express : 300–500 FCFA\n• Taxi compteur : 1 000–3 000 FCFA selon distance\n• Yango : variable (1 500 FCFA+)\n• Bateau Bus : 200 FCFA';
    }

    // ── Météo ──
    if (q.contains('pluie') || q.contains('inondation') || q.contains('route barrée')) {
      return 'Par temps de pluie à Abidjan, certaines zones sont rapidement inondées (Abobo, Yopougon, Adjamé marché). Les Woro-Woro deviennent rares car les chauffeurs évitent les axes inondés. Prévois +20 à +40 min et préfère le Bateau Bus si tu traverses la lagune.';
    }

    // ── Gares ──
    if (q.contains('gare') || q.contains('terminus') ||
        q.contains('arrêt') || q.contains('station')) {
      return 'Les principales gares routières d\'Abidjan : Adjamé (nord), Yopougon (ouest), Koumassi (sud), Abobo (nord-est), Gare de Treichville. Le Plateau concentre les arrêts SOTRA et le terminal du Bateau Bus. Vérifie toujours la gare de départ selon ton point d\'origine.';
    }

    // ── Conseils ──
    if (q.contains('sécurité')) {
      return 'Pour voyager sereinement à Abidjan : garde tes affaires devant toi dans les Gbaka bondés, évite d\'afficher ton téléphone dans les embouteillages, préfère les taxis Yango la nuit. Les zones de Plateau, Cocody et Marcory sont généralement plus sûres.';
    }
    if (q.contains('rapide') || q.contains('plus vite')) {
      return 'Pour aller vite à Abidjan : Woro-Woro sur courte distance, Warren Express pour les longs axes, Yango si tu peux te le permettre. Évite les axes Adjamé–Plateau et les ponts aux heures de pointe — ils peuvent tripler ton temps de trajet.';
    }
    if (q.contains('économique') || q.contains('pas cher') || q.contains('moins cher')) {
      return 'Pour voyager économique : SOTRA ou Gbaka à 200 FCFA sont les moins chers. Si ton trajet nécessite une correspondance, combine Gbaka + Woro-Woro plutôt que Yango. Le Bateau Bus est aussi très abordable (200 FCFA) et évite les embouteillages.';
    }
    if (q.contains('meilleur trajet') || q.contains('itinéraire')) {
      return 'Le meilleur trajet dépend de l\'heure et de ta destination. En heure de pointe, privilégie le Bateau Bus ou un itinéraire évitant Adjamé et les ponts. En heures creuses, le Gbaka direct est souvent le plus rapide et le moins cher.';
    }
    if (q.contains('correspondance') || q.contains('changement')) {
      return 'Pour une correspondance à Abidjan, prévois toujours un arrêt dans une gare centrale (Adjamé, Plateau, Treichville). Les correspondances Gbaka → Woro-Woro se font souvent au bord de la route. Compte 5–10 min d\'attente entre deux modes.';
    }
    if (q.contains('retard')) {
      return 'En cas de retard probable (heure de pointe, pluie, accident), pars 20 à 30 min plus tôt que prévu. Si ton trajet passe par Adjamé ou les ponts, double ce délai. Yango reste la solution la plus prévisible en termes de temps.';
    }

    // ── Fallback ──
    return _fallbackMessage();
  }

  String _fallbackMessage() {
    const fallbacks = [
      'Je n\'ai pas assez d\'informations pour répondre avec précision. Peux-tu me préciser ton point de départ, ta destination ou le moyen de transport concerné ?',
      'Je ne suis pas certain de la réponse. Donne-moi un peu plus de contexte — départ, destination, heure — et je t\'aiderai à trouver le meilleur trajet.',
      'Hmm, je n\'ai pas cette info pour l\'instant. Tu peux me demander : tarifs, horaires, embouteillages, meilleur trajet ou conseils sur un transport spécifique.',
    ];
    final index = DateTime.now().second % fallbacks.length;
    return fallbacks[index];
  }
}
