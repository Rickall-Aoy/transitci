import '../models/ligne.dart';
import '../models/gare.dart';

const List<Ligne> lignesMock = [

  // ══════════════════════════════════════
  // WORO-WORO
  // ══════════════════════════════════════

  Ligne(
    id: 'ww_cocody_plateau',
    nom: 'Cocody Mairie → Plateau',
    type: TransportType.woroWoro,
    couleurVehicule: 'Jaune',
    prix: 300,
    conseil: 'Dites votre arrêt au chauffeur avant de monter. '
        'Ce woro-woro ne s\'arrête pas toujours à tous les points.',
    terminusDepart: Arret(
      nom: 'Gare Cocody Mairie',
      latitude: 5.3600, longitude: -3.9989,
    ),
    terminusArrivee: Arret(
      nom: 'Gare Plateau',
      latitude: 5.3196, longitude: -4.0167,
    ),
    arretsPossibles: [
      Arret(nom: 'CHU Cocody',         latitude: 5.3478, longitude: -3.9734),
      Arret(nom: 'RTI',                latitude: 5.3550, longitude: -3.9900),
      Arret(nom: 'Blockhauss',         latitude: 5.3400, longitude: -4.0050),
      Arret(nom: 'Cathédrale St-Paul', latitude: 5.3280, longitude: -4.0120),
    ],
  ),

  Ligne(
    id: 'ww_angre_plateau',
    nom: 'Angré → Plateau',
    type: TransportType.woroWoro,
    couleurVehicule: 'Jaune',
    prix: 300,
    conseil: 'Demandez si le chauffeur passe par votre arrêt avant de monter.',
    terminusDepart: Arret(
      nom: 'Gare Angré',
      latitude: 5.3878, longitude: -3.9689,
    ),
    terminusArrivee: Arret(
      nom: 'Gare Plateau',
      latitude: 5.3196, longitude: -4.0167,
    ),
    arretsPossibles: [
      Arret(nom: 'Deux Plateaux Vallon', latitude: 5.3744, longitude: -3.9856),
      Arret(nom: 'Adjamé',              latitude: 5.3711, longitude: -4.0200),
      Arret(nom: 'CHU Treichville',     latitude: 5.3100, longitude: -4.0050),
    ],
  ),

  Ligne(
    id: 'ww_adjame_plateau',
    nom: 'Adjamé → Plateau',
    type: TransportType.woroWoro,
    couleurVehicule: 'Jaune',
    prix: 200,
    conseil: 'Arrêt à la demande entre Adjamé et le Plateau.',
    terminusDepart: Arret(
      nom: 'Gare Adjamé',
      latitude: 5.3711, longitude: -4.0200,
    ),
    terminusArrivee: Arret(
      nom: 'Gare Plateau',
      latitude: 5.3196, longitude: -4.0167,
    ),
    arretsPossibles: [
      Arret(nom: 'Marché Adjamé',    latitude: 5.3680, longitude: -4.0180),
      Arret(nom: 'CHU Treichville',  latitude: 5.3100, longitude: -4.0050),
    ],
  ),

  Ligne(
    id: 'ww_attoban_bingerville',
    nom: 'Riviera Attoban → Bingerville',
    type: TransportType.woroWoro,
    couleurVehicule: 'Jaune',
    prix: 400,
    conseil: 'Demandez au chauffeur s\'il va jusqu\'à Bingerville Centre '
        'ou s\'arrête à l\'entrée.',
    terminusDepart: Arret(
      nom: 'Riviera Attoban',
      latitude: 5.3800, longitude: -3.9200,
    ),
    terminusArrivee: Arret(
      nom: 'Bingerville Centre',
      latitude: 5.3569, longitude: -3.8861,
    ),
    arretsPossibles: [
      Arret(nom: 'Riviera 3',          latitude: 5.3756, longitude: -3.9350),
      Arret(nom: 'Riviera 4',          latitude: 5.3722, longitude: -3.9100),
      Arret(nom: 'Bingerville Entrée', latitude: 5.3650, longitude: -3.9000),
    ],
  ),

  Ligne(
    id: 'ww_treichville_plateau',
    nom: 'Treichville → Plateau',
    type: TransportType.woroWoro,
    couleurVehicule: 'Bleu',
    prix: 300,
    conseil: 'Arrêt à la demande. Précisez votre destination au chauffeur.',
    terminusDepart: Arret(
      nom: 'Gare Treichville',
      latitude: 5.2969, longitude: -4.0011,
    ),
    terminusArrivee: Arret(
      nom: 'Gare Plateau',
      latitude: 5.3196, longitude: -4.0167,
    ),
    arretsPossibles: [
      Arret(nom: 'CHU Treichville', latitude: 5.3100, longitude: -4.0050),
      Arret(nom: 'Anoumabo',        latitude: 5.3000, longitude: -3.9900),
    ],
  ),

  Ligne(
    id: 'ww_marcory_cocody',
    nom: 'Marcory → Cocody',
    type: TransportType.woroWoro,
    couleurVehicule: 'Vert',
    prix: 300,
    conseil: 'Demandez si le chauffeur va jusqu\'au CHU ou s\'arrête avant.',
    terminusDepart: Arret(
      nom: 'Gare Marcory',
      latitude: 5.3050, longitude: -3.9800,
    ),
    terminusArrivee: Arret(
      nom: 'Gare Cocody Mairie',
      latitude: 5.3600, longitude: -3.9989,
    ),
    arretsPossibles: [
      Arret(nom: 'Koumassi',    latitude: 5.3150, longitude: -3.9650),
      Arret(nom: 'CHU Cocody',  latitude: 5.3478, longitude: -3.9734),
    ],
  ),

  // ══════════════════════════════════════
  // GBAKA
  // ══════════════════════════════════════

  Ligne(
    id: 'gb_yopougon_adjame',
    nom: 'Yopougon → Adjamé',
    type: TransportType.gbaka,
    couleurVehicule: 'Multicolore',
    prix: 250,
    conseil: 'Le gbaka s\'arrête aux points habituels. '
        'Criez votre arrêt quand vous approchez.',
    terminusDepart: Arret(
      nom: 'Gare Yopougon Selmer',
      latitude: 5.3456, longitude: -4.0789,
    ),
    terminusArrivee: Arret(
      nom: 'Gare Adjamé',
      latitude: 5.3711, longitude: -4.0200,
    ),
    arretsPossibles: [
      Arret(nom: 'Yopougon Wassakara',   latitude: 5.3300, longitude: -4.0900),
      Arret(nom: 'Yopougon Marché',      latitude: 5.3500, longitude: -4.0650),
      Arret(nom: 'Échangeur',            latitude: 5.3600, longitude: -4.0500),
      Arret(nom: 'Adjamé 220 Logements', latitude: 5.3750, longitude: -4.0150),
    ],
  ),

  Ligne(
    id: 'gb_abobo_plateau',
    nom: 'Abobo → Plateau',
    type: TransportType.gbaka,
    couleurVehicule: 'Multicolore',
    prix: 300,
    conseil: 'Arrêts principaux : Adjamé et CHU Treichville. '
        'Demandez avant de monter.',
    terminusDepart: Arret(
      nom: 'Gare Abobo',
      latitude: 5.4167, longitude: -4.0167,
    ),
    terminusArrivee: Arret(
      nom: 'Plateau',
      latitude: 5.3196, longitude: -4.0167,
    ),
    arretsPossibles: [
      Arret(nom: 'Adjamé',          latitude: 5.3711, longitude: -4.0200),
      Arret(nom: 'CHU Treichville', latitude: 5.3100, longitude: -4.0050),
    ],
  ),

  Ligne(
    id: 'gb_marcory_plateau',
    nom: 'Marcory → Plateau',
    type: TransportType.gbaka,
    couleurVehicule: 'Multicolore',
    prix: 250,
    conseil: 'Passe par Treichville. Criez votre arrêt à l\'approche.',
    terminusDepart: Arret(
      nom: 'Gare Marcory',
      latitude: 5.3050, longitude: -3.9800,
    ),
    terminusArrivee: Arret(
      nom: 'Plateau',
      latitude: 5.3196, longitude: -4.0167,
    ),
    arretsPossibles: [
      Arret(nom: 'Remblais',         latitude: 5.3020, longitude: -3.9750),
      Arret(nom: 'Treichville',      latitude: 5.2969, longitude: -4.0011),
      Arret(nom: 'CHU Treichville',  latitude: 5.3100, longitude: -4.0050),
    ],
  ),

  Ligne(
    id: 'gb_yopougon_plateau',
    nom: 'Yopougon → Plateau',
    type: TransportType.gbaka,
    couleurVehicule: 'Multicolore',
    prix: 300,
    conseil: 'Ligne directe. Peu d\'arrêts intermédiaires.',
    terminusDepart: Arret(
      nom: 'Gare Yopougon Selmer',
      latitude: 5.3456, longitude: -4.0789,
    ),
    terminusArrivee: Arret(
      nom: 'Plateau',
      latitude: 5.3196, longitude: -4.0167,
    ),
    arretsPossibles: [
      Arret(nom: 'Échangeur',       latitude: 5.3600, longitude: -4.0500),
      Arret(nom: 'Adjamé',          latitude: 5.3711, longitude: -4.0200),
    ],
  ),
];