class SuggestionLocale {
  final String nom;
  final String categorie;
  final String emoji;
  final double latitude;
  final double longitude;

  const SuggestionLocale({
    required this.nom,
    required this.categorie,
    required this.emoji,
    required this.latitude,
    required this.longitude,
  });
}

const List<SuggestionLocale> suggestionsLocales = [
  // ── Marchés ──
  SuggestionLocale(
    nom: 'Marché d\'Adjamé',
    categorie: 'Marché',
    emoji: '🛍️',
    latitude: 5.3711,
    longitude: -4.0200,
  ),
  SuggestionLocale(
    nom: 'Marché de Treichville',
    categorie: 'Marché',
    emoji: '🛍️',
    latitude: 5.2969,
    longitude: -4.0011,
  ),
  SuggestionLocale(
    nom: 'Marché de Cocody',
    categorie: 'Marché',
    emoji: '🛍️',
    latitude: 5.3478,
    longitude: -3.9734,
  ),

  // ── Centres commerciaux ──
  SuggestionLocale(
    nom: 'Sococé',
    categorie: 'Centre commercial',
    emoji: '🏬',
    latitude: 5.3667,
    longitude: -3.9833,
  ),
  SuggestionLocale(
    nom: 'Playce Palmeraie',
    categorie: 'Centre commercial',
    emoji: '🏬',
    latitude: 5.3856,
    longitude: -3.9567,
  ),
  SuggestionLocale(
    nom: 'Cap Sud',
    categorie: 'Centre commercial',
    emoji: '🏬',
    latitude: 5.2956,
    longitude: -4.0178,
  ),

  // ── Quartiers clés ──
  SuggestionLocale(
    nom: 'Plateau',
    categorie: 'Quartier',
    emoji: '🏙️',
    latitude: 5.3196,
    longitude: -4.0167,
  ),
  SuggestionLocale(
    nom: 'Cocody',
    categorie: 'Quartier',
    emoji: '🏘️',
    latitude: 5.3600,
    longitude: -3.9989,
  ),
  SuggestionLocale(
    nom: 'Yopougon',
    categorie: 'Quartier',
    emoji: '🏘️',
    latitude: 5.3456,
    longitude: -4.0789,
  ),
  SuggestionLocale(
    nom: 'Abobo',
    categorie: 'Quartier',
    emoji: '🏘️',
    latitude: 5.4167,
    longitude: -4.0167,
  ),
  SuggestionLocale(
    nom: 'Bingerville',
    categorie: 'Ville',
    emoji: '🌿',
    latitude: 5.3569,
    longitude: -3.8861,
  ),
  SuggestionLocale(
    nom: 'Riviera Attoban',
    categorie: 'Quartier',
    emoji: '🏘️',
    latitude: 5.3800,
    longitude: -3.9200,
  ),
  SuggestionLocale(
    nom: 'Angré',
    categorie: 'Quartier',
    emoji: '🏘️',
    latitude: 5.3878,
    longitude: -3.9689,
  ),
  SuggestionLocale(
    nom: 'Deux Plateaux',
    categorie: 'Quartier',
    emoji: '🏘️',
    latitude: 5.3744,
    longitude: -3.9856,
  ),

  // ── Lieux iconiques ──
  SuggestionLocale(
    nom: 'Aéroport Felix Houphouët-Boigny',
    categorie: 'Transport',
    emoji: '✈️',
    latitude: 5.2619,
    longitude: -3.9264,
  ),
  SuggestionLocale(
    nom: 'CHU de Cocody',
    categorie: 'Hôpital',
    emoji: '🏥',
    latitude: 5.3478,
    longitude: -3.9734,
  ),
  SuggestionLocale(
    nom: 'Université FHB',
    categorie: 'Université',
    emoji: '🎓',
    latitude: 5.3456,
    longitude: -3.9889,
  ),
  SuggestionLocale(
    nom: 'Stade Félix Houphouët-Boigny',
    categorie: 'Sport',
    emoji: '🏟️',
    latitude: 5.3072,
    longitude: -4.0167,
  ),
  SuggestionLocale(
    nom: 'Gare Routière d\'Adjamé',
    categorie: 'Transport',
    emoji: '🚌',
    latitude: 5.3667,
    longitude: -4.0333,
  ),
];
