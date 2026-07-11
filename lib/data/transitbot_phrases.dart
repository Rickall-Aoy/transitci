import '../services/guide_service.dart';

/// Bibliothèque de phrases locales TransitBot.
///
/// Source unique du guide animé (fade-in de [AiGuideOverlay]) : plus aucun
/// appel réseau / Gemini pour déclencher le fade, ce qui élimine les freeze
/// et crash liés aux appels Gemini automatiques (navigation, résultats…).
const Map<GuideStep, String> transitBotPhrases = {
  GuideStep.idle:
      "Bienvenue sur Transit CI 👋 Dis-moi où tu veux aller.",
  GuideStep.searching:
      "💡 Astuce : saisis ta destination dans la barre de recherche en bas.",
  GuideStep.destinationSelected:
      "Bien joué ! Les itinéraires possibles s'affichent maintenant.",
  GuideStep.resultsShown:
      "Compare les options : Woro-Woro rapide, Gbaka pas cher, SOTRA confortable.",
  GuideStep.navigating:
      "Appuie sur play pour démarrer le guidage en temps réel.",
  GuideStep.arrived:
      "🎉 Tu es arrivé ! N'hésite pas à explorer les autres options.",
  GuideStep.signalProblem:
      "Signaler un arrêt aide toute la communauté. Merci !",
  GuideStep.addStop:
      "Tu peux ajouter un arrêt personnalisé en appuyant longuement sur la carte.",
  GuideStep.chauffeurMode:
      "Démarre une session pour commencer à partager ta position.",
};

/// Phrases locales pour les tutoriels contextuels (aide sur une fonction).
const Map<String, String> transitBotTutorials = {
  'recherche':
      "Appuie sur la barre de recherche en bas pour commencer.",
  'carte':
      "Explore la carte : zoome et déplace-toi pour repérer les arrêts près de toi.",
  'assistant':
      "L'assistant répond à tes questions sur les trajets, prix et horaires.",
  'default':
      "Explore les options pour découvrir l'application.",
};

String transitBotTutorial(String context) {
  final key = context.trim().toLowerCase();
  return transitBotTutorials[key] ?? transitBotTutorials['default']!;
}
