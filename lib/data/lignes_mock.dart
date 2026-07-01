import '../models/ligne.dart';
import '../models/gare.dart';
import '../services/gtfs_loader.dart';

List<Ligne> get lignesMock =>
    [...GtfsLoader.instance.lignes, ...lignesSotra];

const List<Ligne> lignesSotra = [
  Ligne(
    id: 'st_marcory_plateau',
    nom: 'Marcory Remblais → Plateau',
    type: TransportType.sotra,
    couleurVehicule: 'Bleu',
    prix: 200,
    conseil: 'Bus SOTRA entre Marcory et Plateau.',
    terminusDepart: Arret(
      nom: 'Arrêt SOTRA Marcory Remblais',
      latitude: 5.3020, longitude: -3.9750,
    ),
    terminusArrivee: Arret(
      nom: 'Arrêt SOTRA Plateau',
      latitude: 5.3196, longitude: -4.0167,
    ),
    arretsPossibles: [
      Arret(nom: 'Arrêt SOTRA Cocody CHU', latitude: 5.3478, longitude: -3.9734),
      Arret(nom: 'Arrêt SOTRA Adjamé Liberté', latitude: 5.3650, longitude: -4.0250),
    ],
  ),
  Ligne(
    id: 'st_plateau_cocody',
    nom: 'Plateau → Cocody CHU',
    type: TransportType.sotra,
    couleurVehicule: 'Bleu',
    prix: 220,
    conseil: 'Bus SOTRA vers Cocody CHU.',
    terminusDepart: Arret(
      nom: 'Arrêt SOTRA Plateau',
      latitude: 5.3196, longitude: -4.0167,
    ),
    terminusArrivee: Arret(
      nom: 'Arrêt SOTRA Cocody CHU',
      latitude: 5.3478, longitude: -3.9734,
    ),
    arretsPossibles: [
      Arret(nom: 'Arrêt SOTRA Marcory Remblais', latitude: 5.3020, longitude: -3.9750),
      Arret(nom: 'Arrêt SOTRA Adjamé Liberté', latitude: 5.3650, longitude: -4.0250),
    ],
  ),
  Ligne(
    id: 'st_plateau_treichville',
    nom: 'Plateau → Treichville',
    type: TransportType.sotra,
    couleurVehicule: 'Bleu',
    prix: 220,
    conseil: 'Bus SOTRA direct entre Plateau et Treichville.',
    terminusDepart: Arret(
      nom: 'Arrêt SOTRA Plateau',
      latitude: 5.3196, longitude: -4.0167,
    ),
    terminusArrivee: Arret(
      nom: 'Arrêt SOTRA Treichville',
      latitude: 5.2900, longitude: -4.0100,
    ),
    arretsPossibles: [
      Arret(nom: 'Arrêt SOTRA Marcory Remblais', latitude: 5.3020, longitude: -3.9750),
      Arret(nom: 'Arrêt SOTRA Cocody CHU', latitude: 5.3478, longitude: -3.9734),
    ],
  ),
  Ligne(
    id: 'st_cocody_adjame',
    nom: 'Cocody CHU → Adjamé Liberté',
    type: TransportType.sotra,
    couleurVehicule: 'Bleu',
    prix: 200,
    conseil: 'Bus SOTRA entre Cocody CHU et Adjamé Liberté via Plateau.',
    terminusDepart: Arret(
      nom: 'Arrêt SOTRA Cocody CHU',
      latitude: 5.3478, longitude: -3.9734,
    ),
    terminusArrivee: Arret(
      nom: 'Arrêt SOTRA Adjamé Liberté',
      latitude: 5.3650, longitude: -4.0250,
    ),
    arretsPossibles: [
      Arret(nom: 'Arrêt SOTRA Plateau', latitude: 5.3196, longitude: -4.0167),
      Arret(nom: 'Arrêt SOTRA Marcory Remblais', latitude: 5.3020, longitude: -3.9750),
    ],
  ),
  Ligne(
    id: 'st_koumassi_treichville',
    nom: 'Koumassi Akromiabla → Commissariat du Port',
    type: TransportType.sotra,
    couleurVehicule: 'Bleu',
    prix: 200,
    conseil: 'Bus SOTRA reliant le Terminus Akromiabla au Commissariat du Port.',
    terminusDepart: Arret(
      nom: 'Terminus Akromiabla',
      latitude: 5.311900, longitude: -3.952010,
    ),
    terminusArrivee: Arret(
      nom: 'Commissariat du Port',
      latitude: 5.305040, longitude: -4.023150,
    ),
    arretsPossibles: [
      Arret(nom: 'Carrefour Pinasse', latitude: 5.3133051, longitude: -3.9518204),
      Arret(nom: 'Ancien Terminus 32', latitude: 5.3117002, longitude: -3.9487192),
      Arret(nom: 'Pharmacie Fanny', latitude: 5.3099048, longitude: -3.9473289),
      Arret(nom: 'Collège Bon Samaritain', latitude: 5.3077511, longitude: -3.9466929),
      Arret(nom: 'Résidence Agouti', latitude: 5.3054068, longitude: -3.9451848),
      Arret(nom: 'Cours la Source', latitude: 5.3015611, longitude: -3.9469718),
      Arret(nom: 'Garage Akwaba', latitude: 5.2987485, longitude: -3.9476715),
      Arret(nom: 'Pharmacie Regina', latitude: 5.2982383, longitude: -3.9497783),
      Arret(nom: '1ère Entrée Sogefia', latitude: 5.2975990, longitude: -3.9526269),
      Arret(nom: 'UTB Koumassi', latitude: 5.2961331, longitude: -3.9565104),
      Arret(nom: 'Pharmacie St François', latitude: 5.2951940, longitude: -3.9603780),
      Arret(nom: 'Pharmacie Iroko', latitude: 5.2940572, longitude: -3.9653560),
      Arret(nom: 'Pharmacie Soleil', latitude: 5.2932236, longitude: -3.9690283),
      Arret(nom: 'Pharmacie du Gabon', latitude: 5.2927669, longitude: -3.9712223),
      Arret(nom: 'Station Shell Boulevard du Gabon', latitude: 5.2962463, longitude: -3.9796661),
      Arret(nom: 'Clinique La Madone', latitude: 5.2944182, longitude: -3.9761133),
      Arret(nom: 'Pharmacie Tiacoh', latitude: 5.2961308, longitude: -3.9792079),
      Arret(nom: 'Quartier Hibiscus', latitude: 5.2974657, longitude: -3.9818291),
      Arret(nom: 'Orca', latitude: 5.2983620, longitude: -3.9848626),
      Arret(nom: 'PMI Marcory', latitude: 5.3012653, longitude: -3.9835430),
      Arret(nom: 'Pharmacie Petit Marché', latitude: 5.3022895, longitude: -3.9848064),
      Arret(nom: 'Hôtel Hamanieh', latitude: 5.3052787, longitude: -3.9888629),
      Arret(nom: 'Station Total Marcory', latitude: 5.3076127, longitude: -3.9933399),
      Arret(nom: 'Notre-Dame de la Paix', latitude: 5.3035364, longitude: -4.0031127),
      Arret(nom: 'Carrefour Saint Jean Bosco', latitude: 5.305940, longitude: -4.004570),
      Arret(nom: 'Treichotel', latitude: 5.3046605, longitude: -4.0087240),
      Arret(nom: 'Avenue 15 Rue 12', latitude: 5.3039471, longitude: -4.0111420),
      Arret(nom: 'Avenue 11 Rue 12', latitude: 5.3058112, longitude: -4.0117916),
      Arret(nom: 'Arrêt Bolloré', latitude: 5.306600, longitude: -4.018900),
      Arret(nom: 'Grand Moulin', latitude: 5.3069217, longitude: -4.0211455),
      Arret(nom: 'Direction Générale du Port', latitude: 5.305420, longitude: -4.022560),
    ],
  ),
];
