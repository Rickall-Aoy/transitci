import 'package:flutter/foundation.dart';
import '../models/conditions_trafic.dart'; // adapte le chemin si nécessaire

// ─────────────────────────────────────────────────────────────
//  Événements déclencheurs
// ─────────────────────────────────────────────────────────────
enum TipEvent {
  appOpen,          // ouverture / retour dans l'app
  searchFocused,    // barre de recherche activée
  searchInactive,   // aucune recherche depuis un moment
  destinationSet,   // destination sélectionnée
  resultsShown,     // résultats affichés
  noResults,        // aucun résultat trouvé
  navigationStart,  // trajet démarré
  approachTransfer, // approche d'une correspondance
  longWalk,         // segment marche > 10 min détecté
  arrived,          // arrivée à destination
  rainToggled,      // pluie activée manuellement
  trafficToggled,   // embouteillage activé manuellement
}

// ─────────────────────────────────────────────────────────────
//  TipService
// ─────────────────────────────────────────────────────────────
class TipService {
  TipService._();
  static final TipService instance = TipService._();

  // Dernier index utilisé par événement pour éviter la répétition
  final Map<TipEvent, int> _lastIndex = {};

  /// Retourne une phrase contextuelle selon l'événement, l'heure et les conditions.
  String getTip(
    TipEvent event, {
    required int heure,
    required ConditionsTrafic conditions,
    String? destination,
    int? walkMinutes,
    String? transferStop,
  }) {
    final phrases = _select(
      event,
      heure: heure,
      conditions: conditions,
      destination: destination,
      walkMinutes: walkMinutes,
      transferStop: transferStop,
    );

    if (phrases.isEmpty) return '';

    // Rotation sans répétition immédiate
    final last = _lastIndex[event] ?? -1;
    int index = (last + 1) % phrases.length;
    _lastIndex[event] = index;
    return phrases[index];
  }

  // ─────────────────────────────────────────────────────────────
  //  Sélection par priorité
  //  Priorité : conditions actives > heure > événement générique
  // ─────────────────────────────────────────────────────────────
  List<String> _select(
    TipEvent event, {
    required int heure,
    required ConditionsTrafic conditions,
    String? destination,
    int? walkMinutes,
    String? transferStop,
  }) {
    final bool heurePointe = _isHeurePointe(heure);
    final bool matin = heure >= 5 && heure < 12;
    final bool soir = heure >= 17 && heure < 21;
    final bool nuit = heure >= 21 || heure < 5;
    final bool pluie = conditions.pluie;
    final bool bouchon = conditions.embouteillage;
    final dest = destination ?? 'ta destination';

    switch (event) {

      // ── Ouverture app ──
      case TipEvent.appOpen:
        if (pluie && bouchon && heurePointe) return [
          'Pluie + bouchons + heure de pointe : le cocktail parfait pour partir tôt. Laisse-moi t\'aider à trouver le meilleur trajet.',
          'Conditions difficiles ce matin. Pluie et trafic chargé — je te conseille le Bateau Bus si tu traverses la lagune.',
        ];
        if (pluie && heurePointe) return [
          'Il pleut et c\'est l\'heure de pointe. Les Woro-Woro vont se faire rares. Prévois de la marge.',
          'Pluie + heure chargée : les axes Adjamé et les ponts vont souffrir. Pars 20 min plus tôt si tu peux.',
        ];
        if (bouchon && heurePointe) return [
          'Bouchons signalés + heure de pointe. Évite le boulevard VGE et les accès aux ponts si possible.',
          'Trafic chargé sur les grands axes. Le Warren Express ou le Bateau Bus peuvent te faire gagner du temps.',
        ];
        if (pluie) return [
          'Il pleut à Abidjan. Attention aux zones inondables comme Abobo et Yopougon. Prévois +15 min.',
          'Temps pluvieux. Les Woro-Woro deviennent rares sur certains axes. Anticipe un peu l\'attente.',
        ];
        if (bouchon) return [
          'Bouchons signalés sur certains axes. Je tiens compte du trafic pour te proposer le meilleur itinéraire.',
          'Circulation dense en ce moment. On va trouver une alternative rapide ensemble.',
        ];
        if (heurePointe && matin) return [
          'Bonjour ! C\'est l\'heure de pointe du matin. Les transports sont chargés — pars maintenant pour éviter le pire.',
          'Il est ${heure}h, les bus et Gbaka sont bondés. Utilise la recherche pour trouver le trajet le plus fluide.',
        ];
        if (heurePointe && soir) return [
          'C\'est l\'heure de pointe du soir. Les axes Plateau–Adjamé et les ponts sont saturés. Bon courage !',
          'Il est ${heure}h, heure chargée. Le Bateau Bus peut te faire éviter les embouteillages si tu traverses la lagune.',
        ];
        if (nuit) return [
          'Bonsoir ! À cette heure, les Gbaka et Woro-Woro sont rares. Yango ou un taxi compteur sont tes meilleures options.',
          'Il est tard. Peu de transports collectifs disponibles après 21h. Pense à Yango pour rentrer sereinement.',
        ];
        return [
          'Bonjour ! Où vas-tu aujourd\'hui ? Saisis ta destination et je te trouve le meilleur itinéraire.',
          'Prêt à bouger ? Tape ta destination en bas et je calcule ton trajet en temps réel.',
          'Bienvenue sur Transit CI. Dis-moi où tu vas et je te guide dans les transports d\'Abidjan.',
        ];

      // ── Recherche activée ──
      case TipEvent.searchFocused:
        if (heurePointe) return [
          'Heure de pointe en cours. Tape ta destination, je vais optimiser ton trajet pour éviter les axes chargés.',
        ];
        if (pluie) return [
          'Tape ta destination. Par temps de pluie, je privilégie les trajets qui évitent les zones inondables.',
        ];
        return [
          'Tape le nom d\'un quartier, d\'une école, d\'un marché ou d\'un lieu connu.',
          'Dis-moi où tu vas. Je connais les arrêts, les lignes et les correspondances d\'Abidjan.',
          'Recherche une adresse, un quartier ou un lieu pour commencer.',
        ];

      // ── Inactivité ──
      case TipEvent.searchInactive:
        if (heurePointe) return [
          'Tu hésites ? L\'heure de pointe est là — mieux vaut partir maintenant qu\'attendre.',
          'Les transports se remplissent vite à cette heure. Une destination en tête ?',
        ];
        if (nuit) return [
          'Il se fait tard. Si tu dois rentrer, Yango est disponible 24h/24.',
        ];
        return [
          'Tu veux aller quelque part ? Tape ta destination, je m\'occupe du reste.',
          'Pas encore de destination ? Je peux aussi répondre à tes questions sur les transports d\'Abidjan.',
          'Une idée de destination ? Je calcule le trajet le plus rapide selon les conditions actuelles.',
        ];

      // ── Destination sélectionnée ──
      case TipEvent.destinationSet:
        if (pluie && bouchon) return [
          'Destination $dest enregistrée. Conditions difficiles : pluie + trafic. Je cherche le trajet le plus fiable.',
        ];
        if (pluie) return [
          'Destination $dest. Il pleut — je privilégie les itinéraires couverts et les arrêts accessibles.',
        ];
        if (bouchon) return [
          'Destination $dest. Bouchons en cours — je cherche une alternative aux grands axes.',
        ];
        if (heurePointe) return [
          'Direction $dest en heure de pointe. Je calcule le trajet le moins chargé pour toi.',
        ];
        return [
          'Direction $dest. Calcul en cours…',
          'Bien, $dest c\'est noté. Je cherche les meilleures options de transport.',
          'Destination $dest enregistrée. Voilà les itinéraires disponibles.',
        ];

      // ── Résultats affichés ──
      case TipEvent.resultsShown:
        if (pluie && bouchon) return [
          'Voilà tes options. Par pluie et bouchons, j\'ai favorisé les trajets les plus fiables même s\'ils sont un peu plus longs.',
        ];
        if (pluie) return [
          'Résultats calculés en tenant compte de la pluie. Les temps peuvent varier si des axes sont inondés.',
        ];
        if (bouchon) return [
          'J\'ai évité les axes chargés dans mon calcul. Le trajet proposé contourne les bouchons signalés.',
        ];
        if (heurePointe) return [
          'Heure de pointe : les durées incluent une marge pour le trafic. Le premier résultat est souvent le plus fiable.',
          'En heure chargée, compare la durée ET le confort. Un trajet un peu plus long mais assis vaut souvent mieux.',
        ];
        return [
          'Voilà tes options. Compare la durée, le prix et le nombre de correspondances.',
          'Plusieurs itinéraires disponibles. Le premier est le plus rapide, les suivants sont les plus économiques.',
          'Choisis selon tes priorités : rapidité, prix ou confort. Je les ai tous calculés pour toi.',
        ];

      // ── Aucun résultat ──
      case TipEvent.noResults:
        return [
          'Je n\'ai pas trouvé d\'itinéraire direct pour $dest. Essaie un lieu plus proche ou un quartier connu.',
          'Aucun résultat pour $dest. Les données de certaines zones sont encore incomplètes — essaie un nom de quartier.',
          'Pas d\'itinéraire trouvé. Tu peux aussi me poser la question directement dans le chat.',
        ];

      // ── Navigation démarrée ──
      case TipEvent.navigationStart:
        if (pluie) return [
          'Navigation démarrée vers $dest. Attention aux trottoirs glissants et aux zones inondables sur le chemin.',
        ];
        if (bouchon) return [
          'C\'est parti vers $dest. Bouchons signalés sur certains axes — suis bien les indications pour les éviter.',
        ];
        if (nuit) return [
          'Navigation de nuit vers $dest. Reste vigilant aux arrêts et dans les zones peu éclairées.',
        ];
        return [
          'C\'est parti ! Suis les instructions à l\'écran. Je te préviens avant chaque correspondance.',
          'Navigation démarrée vers $dest. Bon trajet !',
          'En route pour $dest. Je reste disponible si tu as une question en chemin.',
        ];

      // ── Approche correspondance ──
      case TipEvent.approachTransfer:
        final stop = transferStop ?? 'l\'arrêt suivant';
        return [
          'Tu approches de $stop. Prépare-toi à descendre pour prendre ta correspondance.',
          'Correspondance dans peu de temps à $stop. Reste près de la sortie.',
          'Prochaine étape : descends à $stop et prends le transport indiqué.',
        ];

      // ── Marche longue ──
      case TipEvent.longWalk:
        final min = walkMinutes ?? 10;
        return [
          'Ce trajet inclut environ $min min de marche. Si c\'est trop, je peux chercher une alternative tout en transport.',
          'Correspondance à pied d\'environ $min min détectée. Faisable, mais prévois de bonnes chaussures si tu es en tenue.',
          '$min min de marche sur ce trajet. Par temps de pluie ou en heure de pointe, préfère une alternative en véhicule.',
        ];

      // ── Arrivée ──
      case TipEvent.arrived:
        return [
          '🎉 Tu es arrivé à $dest ! J\'espère que le trajet s\'est bien passé.',
          'Destination atteinte ! N\'hésite pas à signaler un arrêt si tu as remarqué un problème en chemin.',
          'Arrivé à $dest. Tu peux noter ton trajet ou explorer d\'autres fonctionnalités de l\'app.',
        ];

      // ── Pluie activée ──
      case TipEvent.rainToggled:
        return [
          'Simulation pluie activée. Les conseils et durées s\'adaptent aux conditions pluvieuses.',
          'Mode pluie : je tiens compte des zones inondables et de la rareté des Woro-Woro par temps de pluie.',
        ];

      // ── Embouteillage activé ──
      case TipEvent.trafficToggled:
        return [
          'Simulation bouchons activée. Je vais proposer des itinéraires qui contournent les axes chargés.',
          'Mode embouteillage : les durées estimées incluent le trafic dense sur les grands axes d\'Abidjan.',
        ];
    }
  }

  bool _isHeurePointe(int heure) =>
      (heure >= 7 && heure <= 9) || (heure >= 17 && heure <= 20);
}
