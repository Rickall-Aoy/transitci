import '../models/conditions_trafic.dart';
import '../models/gare.dart';
import '../models/ligne.dart';
import '../models/trajet.dart';
import 'location_service.dart';

class RoutingService {
  /// Conditions de trafic actives pendant le calcul courant (pluie / embouteillage).
  /// Définies au début de [_calculer] et lue par les fonctions de temps/score.
  static ConditionsTrafic _conditionsActives = const ConditionsTrafic();

  /// Plafond strict de marche (en mètres) par jambe d'accès/sortie (~18 min à 4 km/h).
  /// Au-delà, un trajet est rejeté pour éviter les longues marches.
  static const double _marcheMaxStricteMetres = 1200;

  /// Plafond relâché utilisé uniquement en fallback (si aucun trajet ne passe
  /// le plafond strict), pour ne jamais renvoyer une liste vide.
  static const double _marcheMaxFallbackMetres = 3500;

  /// Pénalité de score par minute de marche (en plus de la durée). Une minute
  /// de marche « coûte » ainsi davantage qu'une minute assise dans un véhicule,
  /// ce qui fait remonter les itinéraires avec le moins de marche.
  static const double _penaliteMarcheParMinute = 1.5;

  /// Plafond de marche courant (strict par défaut, relâché en fallback).
  static double _maxMarcheMetres = _marcheMaxStricteMetres;

  static List<Trajet> calculerTrajets({
    required double userLat,
    required double userLon,
    required double destLat,
    required double destLon,
    required List<Ligne> lignes,
    required int heure,
    ConditionsTrafic conditions = const ConditionsTrafic(),
  }) {
    return _calculer(options: _RoutingOptions(
      userLat: userLat,
      userLon: userLon,
      destLat: destLat,
      destLon: destLon,
      lignes: lignes,
      heure: heure,
      conditions: conditions,
    ));
  }

  static List<Trajet> calculerAvecContraintes({
    required double userLat,
    required double userLon,
    required double destLat,
    required double destLon,
    required List<Ligne> lignes,
    required int heure,
    List<String>? lignesExcluesIds,
    bool prioriteWoroWoro = false,
    ConditionsTrafic conditions = const ConditionsTrafic(),
  }) {
    final excluded = <String>{};
    if (lignesExcluesIds != null) excluded.addAll(lignesExcluesIds);
    if (prioriteWoroWoro) {
      for (final l in lignes) {
        if (l.type != TransportType.woroWoro) excluded.add(l.id);
      }
    }

    return _calculer(options: _RoutingOptions(
      userLat: userLat,
      userLon: userLon,
      destLat: destLat,
      destLon: destLon,
      lignes: lignes,
      heure: heure,
      lignesExclues: excluded,
      forcerWoroWoro: prioriteWoroWoro,
      conditions: conditions,
    ));
  }

  static List<Trajet> _calculer({required _RoutingOptions options}) {
    _conditionsActives = options.conditions;

    // Passe 1 : plafond de marche strict (itinéraires confortables).
    _maxMarcheMetres = _marcheMaxStricteMetres;
    var trajets = _genererTrajets(options);

    // Fallback anti-liste-vide : si le plafond strict ne laisse passer aucun
    // trajet, on le relâche pour ne jamais renvoyer une liste vide.
    if (trajets.isEmpty) {
      _maxMarcheMetres = _marcheMaxFallbackMetres;
      trajets = _genererTrajets(options);
    }

    trajets.sort((a, b) => a.score.compareTo(b.score));
    final deduped = _dedupeTrajets(trajets);
    return deduped.take(3).toList();
  }

  static List<Trajet> _genererTrajets(_RoutingOptions options) {
    final trajets = <Trajet>[];
    final filteredLignes = options.lignes
        .where((l) => !options.lignesExclues.contains(l.id))
        .toList();

    final lignesDepart = _lignesProches(
      lignes: filteredLignes,
      lat: options.userLat,
      lon: options.userLon,
    );
    final lignesDestination = _lignesProches(
      lignes: filteredLignes,
      lat: options.destLat,
      lon: options.destLon,
    );
    final lignesDirectes = _dedupeLignes([...lignesDepart, ...lignesDestination]);

    for (final ligne in lignesDirectes) {
      final t = _trajetDirect(
        userLat: options.userLat, userLon: options.userLon,
        destLat: options.destLat, destLon: options.destLon,
        ligne: ligne, heure: options.heure,
      );
      if (t != null) trajets.add(t);
    }

    final woroWoroProches = options.forcerWoroWoro
        ? _dedupeLignes(filteredLignes).where((l) => l.type == TransportType.woroWoro).toList()
        : _lignesWoroWoroProches(filteredLignes, options.userLat, options.userLon);
    for (final woro in woroWoroProches) {
      final t = _trajetRaccordementWoroWoro(
        userLat: options.userLat, userLon: options.userLon,
        destLat: options.destLat, destLon: options.destLon,
        woroWoro: woro,
        lignesCibles: lignesDirectes,
        heure: options.heure,
      );
      if (t != null) trajets.add(t);
    }

    for (final l1 in lignesDepart) {
      for (final l2 in lignesDestination) {
        if (l1.id == l2.id) continue;
        final t = _trajetCorrespondance(
          userLat: options.userLat, userLon: options.userLon,
          destLat: options.destLat, destLon: options.destLon,
          ligne1: l1, ligne2: l2, heure: options.heure,
        );
        if (t != null) trajets.add(t);
      }
    }

    final distTotale = LocationService.distanceEnMetres(
      lat1: options.userLat, lon1: options.userLon,
      lat2: options.destLat, lon2: options.destLon,
    );

    if (distTotale > 8000) {
      final lignesIntermediaires = _dedupeLignes(filteredLignes)
          .where((ligne) =>
              !lignesDepart.any((l) => l.id == ligne.id) &&
              !lignesDestination.any((l) => l.id == ligne.id))
          .take(32)
          .toList();

      for (final l1 in lignesDepart.take(12)) {
        for (final l2 in lignesIntermediaires) {
          for (final l3 in lignesDestination.take(12)) {
            if (l1.id == l2.id || l2.id == l3.id || l1.id == l3.id) continue;
            final t = _trajetDoubleCorrespondance(
              userLat: options.userLat, userLon: options.userLon,
              destLat: options.destLat, destLon: options.destLon,
              ligne1: l1, ligne2: l2, ligne3: l3, heure: options.heure,
            );
            if (t != null) trajets.add(t);
          }
        }
      }
    }

    if (distTotale <= 800 && distTotale > 0) {
      final tempsMarche = _tempsAPied(distTotale);
      trajets.add(Trajet(
        segments: [
          Segment(
            type: TypeSegment.piedVersDest,
            deLatitude: options.userLat, deLongitude: options.userLon,
            versLatitude: options.destLat, versLongitude: options.destLon,
            dureeMinutes: tempsMarche,
            prix: 0,
            description: 'Marche directe vers ta destination (~${tempsMarche} min)',
          ),
        ],
        dureeTotal: tempsMarche,
        prixTotal: 0,
        score: _score(duree: tempsMarche, prix: 0, correspondances: 0, marcheMinutes: tempsMarche),
        resume: '🚶 Marche directe (~${tempsMarche} min)',
      ));
    }

    return trajets;
  }

  static List<Ligne> _lignesProches({
    required List<Ligne> lignes,
    required double lat,
    required double lon,
    double maxDistance = 8000,
  }) {
    final scored = lignes.map((ligne) {
      final arret = ligne.arretLePlusProche(lat, lon);
      final distance = LocationService.distanceEnMetres(
        lat1: lat,
        lon1: lon,
        lat2: arret.latitude,
        lon2: arret.longitude,
      );
      return MapEntry(ligne, distance);
    }).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return scored
        .where((entry) => entry.value <= maxDistance)
        .take(48)
        .map((entry) => entry.key)
        .toList();
  }

  static double _rayonMetres(Ligne ligne) =>
      ligne.type == TransportType.woroWoro ? 15000 : 1000;

  static List<Ligne> _lignesWoroWoroProches(
      List<Ligne> lignes, double lat, double lon) {
    return _lignesProches(
      lignes: lignes.where((l) => l.type == TransportType.woroWoro).toList(),
      lat: lat,
      lon: lon,
      maxDistance: 12000,
    );
  }

  static List<Ligne> _dedupeLignes(List<Ligne> lignes) {
    final seen = <String>{};
    final result = <Ligne>[];
    for (final ligne in lignes) {
      if (seen.add(ligne.id)) result.add(ligne);
    }
    return result;
  }

  static List<Trajet> _dedupeTrajets(List<Trajet> trajets) {
    final seen = <String>{};
    final result = <Trajet>[];
    for (final trajet in trajets) {
      final key = trajet.resume;
      if (seen.add(key)) result.add(trajet);
    }
    return result;
  }

  static ({Arret arret, int indexLigne1, int indexLigne2})? _trouverCorrespondance(
      Ligne ligne1, Ligne ligne2) {
    final arrets1 = ligne1.tousLesArrets;
    final arrets2 = ligne2.tousLesArrets;

    Arret? meilleur;
    int meilleurIndex1 = -1;
    int meilleurIndex2 = -1;
    double minDist = double.infinity;

    for (int i = 0; i < arrets1.length; i++) {
      for (int j = 0; j < arrets2.length; j++) {
        final dist = LocationService.distanceEnMetres(
          lat1: arrets1[i].latitude, lon1: arrets1[i].longitude,
          lat2: arrets2[j].latitude, lon2: arrets2[j].longitude,
        );
        if (dist < 400 && dist < minDist) {
          minDist = dist;
          meilleur = arrets1[i];
          meilleurIndex1 = i;
          meilleurIndex2 = j;
        }
      }
    }

    if (meilleur == null) return null;
    return (arret: meilleur, indexLigne1: meilleurIndex1, indexLigne2: meilleurIndex2);
  }

  // ── Trajet direct ──
  static Trajet? _trajetDirect({
    required double userLat, required double userLon,
    required double destLat, required double destLon,
    required Ligne ligne, required int heure,
  }) {
    if (!ligne.peutDesservir(userLat, userLon, rayonMetres: _rayonMetres(ligne))) return null;
    if (!ligne.peutDesservir(destLat, destLon)) return null;

    final departInfo = ligne.arretLePlusProcheAvecIndex(userLat, userLon);
    final arriveeInfo = ligne.arretLePlusProcheAvecIndex(destLat, destLon);

    if (departInfo.index >= arriveeInfo.index) {
      final distGare2Dest = LocationService.distanceEnMetres(
        lat1: arriveeInfo.arret.latitude,
        lon1: arriveeInfo.arret.longitude,
        lat2: destLat,
        lon2: destLon,
      );
      if (distGare2Dest > 2000) return null;
    }

    final arretDepart = departInfo.arret;
    final arretArrivee = arriveeInfo.arret;

    final distUserArret = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: arretDepart.latitude, lon2: arretDepart.longitude,
    );
    final distArretDest = LocationService.distanceEnMetres(
      lat1: arretArrivee.latitude, lon1: arretArrivee.longitude,
      lat2: destLat, lon2: destLon,
    );

    if (distUserArret > _maxMarcheMetres) return null;
    if (distArretDest > _maxMarcheMetres) return null;

    final tempsAPied1 = _tempsAPied(distUserArret);
    final tempsTransport = _estimerTempsTransport(ligne.type, heure);
    final tempsAPied2 = _tempsAPied(distArretDest);

    final segments = [
      Segment(
        type: TypeSegment.piedVersGare,
        deLatitude: userLat, deLongitude: userLon,
        versLatitude: arretDepart.latitude,
        versLongitude: arretDepart.longitude,
        dureeMinutes: tempsAPied1,
        prix: 0,
        description: 'Marche vers ${arretDepart.nom} (~${tempsAPied1} min)',
        conseil: 'Dirige-toi vers ${arretDepart.nom} à pied.',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretDepart.latitude,
        deLongitude: arretDepart.longitude,
        versLatitude: arretArrivee.latitude,
        versLongitude: arretArrivee.longitude,
        dureeMinutes: tempsTransport,
        prix: ligne.prix,
        description: 'Prends ${_labelType(ligne.type)} direction ${ligne.terminusArrivee.nom}'
            ' — descends à ${arretArrivee.nom}',
        conseil: _conseilParType(ligne.type, arretArrivee.nom),
        arretMontee: arretDepart.nom,
        arretDescente: arretArrivee.nom,
        couleurVehicule: ligne.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.piedVersDest,
        deLatitude: arretArrivee.latitude,
        deLongitude: arretArrivee.longitude,
        versLatitude: destLat, versLongitude: destLon,
        dureeMinutes: tempsAPied2,
        prix: 0,
        description: 'Marche vers ta destination (~${tempsAPied2} min)',
      ),
    ];

    final duree = tempsAPied1 + tempsTransport + tempsAPied2;

    return Trajet(
      segments: segments,
      dureeTotal: duree,
      prixTotal: ligne.prix,
      score: _score(duree: duree, prix: ligne.prix, correspondances: 0, marcheMinutes: tempsAPied1 + tempsAPied2),
      resume: _construireResumeDirect(
        tempsAPied1: tempsAPied1,
        ligne: ligne,
        tempsTransport: tempsTransport,
        tempsAPied2: tempsAPied2,
        arretArrivee: arretArrivee,
      ),
    );
  }

  // ── Trajet avec 1 correspondance ──
  static Trajet? _trajetCorrespondance({
    required double userLat, required double userLon,
    required double destLat, required double destLon,
    required Ligne ligne1, required Ligne ligne2,
    required int heure,
  }) {
    if (!ligne1.peutDesservir(userLat, userLon, rayonMetres: _rayonMetres(ligne1))) return null;
    if (!ligne2.peutDesservir(destLat, destLon, rayonMetres: _rayonMetres(ligne2))) return null;

    final corr = _trouverCorrespondance(ligne1, ligne2);
    if (corr == null) return null;

    final departInfo = ligne1.arretLePlusProcheAvecIndex(userLat, userLon);
    final arriveeInfo = ligne2.arretLePlusProcheAvecIndex(destLat, destLon);

    if (departInfo.index >= corr.indexLigne1) return null;
    if (corr.indexLigne2 >= arriveeInfo.index) return null;

    final pointCorrespondance = corr.arret;
    final arretDepart = departInfo.arret;
    final arretArrivee = arriveeInfo.arret;

    final distCorrDest = LocationService.distanceEnMetres(
      lat1: pointCorrespondance.latitude,
      lon1: pointCorrespondance.longitude,
      lat2: destLat, lon2: destLon,
    );
    final distDepartDest = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: destLat, lon2: destLon,
    );
    if (distCorrDest >= distDepartDest) return null;

    final distUserArret = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: arretDepart.latitude, lon2: arretDepart.longitude,
    );
    if (distUserArret > _maxMarcheMetres) return null;

    final distArretDest = LocationService.distanceEnMetres(
      lat1: arretArrivee.latitude, lon1: arretArrivee.longitude,
      lat2: destLat, lon2: destLon,
    );
    if (distArretDest > _maxMarcheMetres) return null;

    final tempsAPied1 = _tempsAPied(distUserArret);
    final tempsT1 = _estimerTempsTransport(ligne1.type, heure);
    const tempsCorr = 5;
    final tempsT2 = _estimerTempsTransport(ligne2.type, heure);
    final tempsAPied2 = _tempsAPied(distArretDest);

    final segments = [
      Segment(
        type: TypeSegment.piedVersGare,
        deLatitude: userLat, deLongitude: userLon,
        versLatitude: arretDepart.latitude,
        versLongitude: arretDepart.longitude,
        dureeMinutes: tempsAPied1,
        prix: 0,
        description: 'Marche vers ${arretDepart.nom} (~${tempsAPied1} min)',
        conseil: 'Dirige-toi vers ${arretDepart.nom} à pied.',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretDepart.latitude,
        deLongitude: arretDepart.longitude,
        versLatitude: pointCorrespondance.latitude,
        versLongitude: pointCorrespondance.longitude,
        dureeMinutes: tempsT1,
        prix: ligne1.prix,
        description: 'Prends ${_labelType(ligne1.type)} direction ${ligne1.terminusArrivee.nom}'
            ' — descends à ${pointCorrespondance.nom}',
        conseil: _conseilParType(ligne1.type, pointCorrespondance.nom),
        arretMontee: arretDepart.nom,
        arretDescente: pointCorrespondance.nom,
        couleurVehicule: ligne1.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: pointCorrespondance.latitude,
        deLongitude: pointCorrespondance.longitude,
        versLatitude: arretArrivee.latitude,
        versLongitude: arretArrivee.longitude,
        dureeMinutes: tempsCorr + tempsT2,
        prix: ligne2.prix,
        description: 'Prends ${_labelType(ligne2.type)} direction ${ligne2.terminusArrivee.nom}'
            ' — descends à ${arretArrivee.nom}',
        conseil: _conseilParType(ligne2.type, arretArrivee.nom),
        arretMontee: pointCorrespondance.nom,
        arretDescente: arretArrivee.nom,
        couleurVehicule: ligne2.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.piedVersDest,
        deLatitude: arretArrivee.latitude,
        deLongitude: arretArrivee.longitude,
        versLatitude: destLat, versLongitude: destLon,
        dureeMinutes: tempsAPied2,
        prix: 0,
        description: 'Marche vers ta destination (~${tempsAPied2} min)',
      ),
    ];

    final duree = tempsAPied1 + tempsT1 + tempsCorr + tempsT2 + tempsAPied2;
    final prix = ligne1.prix + ligne2.prix;

    return Trajet(
      segments: segments,
      dureeTotal: duree,
      prixTotal: prix,
      score: _score(duree: duree, prix: prix, correspondances: 1, marcheMinutes: tempsAPied1 + tempsAPied2),
      resume: _construireResumeCorrespondance1(
        tempsAPied1: tempsAPied1,
        ligne1: ligne1,
        ligne2: ligne2,
        tempsAPied2: tempsAPied2,
        arretArrivee: arretArrivee,
      ),
    );
  }

  // ── Trajet avec 2 correspondances ──
  static Trajet? _trajetDoubleCorrespondance({
    required double userLat, required double userLon,
    required double destLat, required double destLon,
    required Ligne ligne1, required Ligne ligne2, required Ligne ligne3,
    required int heure,
  }) {
    if (!ligne1.peutDesservir(userLat, userLon, rayonMetres: _rayonMetres(ligne1))) return null;
    if (!ligne3.peutDesservir(destLat, destLon, rayonMetres: _rayonMetres(ligne3))) return null;

    final corr1 = _trouverCorrespondance(ligne1, ligne2);
    if (corr1 == null) return null;

    final corr2 = _trouverCorrespondance(ligne2, ligne3);
    if (corr2 == null) return null;

    final departInfo = ligne1.arretLePlusProcheAvecIndex(userLat, userLon);
    final arriveeInfo = ligne3.arretLePlusProcheAvecIndex(destLat, destLon);

    if (departInfo.index >= corr1.indexLigne1) return null;
    if (corr1.indexLigne2 >= corr2.indexLigne1) return null;
    if (corr2.indexLigne2 >= arriveeInfo.index) return null;

    final arretDepart = departInfo.arret;
    final arretArrivee = arriveeInfo.arret;

    final distUserArret = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: arretDepart.latitude, lon2: arretDepart.longitude,
    );
    if (distUserArret > _maxMarcheMetres) return null;

    final distArretDest = LocationService.distanceEnMetres(
      lat1: arretArrivee.latitude, lon1: arretArrivee.longitude,
      lat2: destLat, lon2: destLon,
    );
    if (distArretDest > _maxMarcheMetres) return null;

    final t0 = _tempsAPied(distUserArret);
    final t1 = _estimerTempsTransport(ligne1.type, heure);
    final t2 = _estimerTempsTransport(ligne2.type, heure);
    final t3 = _estimerTempsTransport(ligne3.type, heure);
    final t4 = _tempsAPied(distArretDest);

    final segments = [
      Segment(
        type: TypeSegment.piedVersGare,
        deLatitude: userLat, deLongitude: userLon,
        versLatitude: arretDepart.latitude,
        versLongitude: arretDepart.longitude,
        dureeMinutes: t0, prix: 0,
        description: 'Marche vers ${arretDepart.nom} (~${t0} min)',
        conseil: 'Dirige-toi vers ${arretDepart.nom} à pied.',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretDepart.latitude,
        deLongitude: arretDepart.longitude,
        versLatitude: corr1.arret.latitude, versLongitude: corr1.arret.longitude,
        dureeMinutes: t1, prix: ligne1.prix,
        description: 'Prends ${_labelType(ligne1.type)} direction ${ligne1.terminusArrivee.nom}'
            ' — descends à ${corr1.arret.nom}',
        conseil: _conseilParType(ligne1.type, corr1.arret.nom),
        arretMontee: arretDepart.nom,
        arretDescente: corr1.arret.nom,
        couleurVehicule: ligne1.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: corr1.arret.latitude, deLongitude: corr1.arret.longitude,
        versLatitude: corr2.arret.latitude, versLongitude: corr2.arret.longitude,
        dureeMinutes: 5 + t2, prix: ligne2.prix,
        description: 'Prends ${_labelType(ligne2.type)} direction ${ligne2.terminusArrivee.nom}'
            ' — descends à ${corr2.arret.nom}',
        conseil: _conseilParType(ligne2.type, corr2.arret.nom),
        arretMontee: corr1.arret.nom,
        arretDescente: corr2.arret.nom,
        couleurVehicule: ligne2.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: corr2.arret.latitude, deLongitude: corr2.arret.longitude,
        versLatitude: arretArrivee.latitude, versLongitude: arretArrivee.longitude,
        dureeMinutes: t3, prix: ligne3.prix,
        description: 'Prends ${_labelType(ligne3.type)} direction ${ligne3.terminusArrivee.nom}'
            ' — descends à ${arretArrivee.nom}',
        conseil: _conseilParType(ligne3.type, arretArrivee.nom),
        arretMontee: corr2.arret.nom,
        arretDescente: arretArrivee.nom,
        couleurVehicule: ligne3.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.piedVersDest,
        deLatitude: arretArrivee.latitude,
        deLongitude: arretArrivee.longitude,
        versLatitude: destLat, versLongitude: destLon,
        dureeMinutes: t4,
        prix: 0,
        description: 'Marche vers ta destination (~${t4} min)',
      ),
    ];

    final duree = t0 + t1 + 5 + t2 + t3 + t4;
    final prix = ligne1.prix + ligne2.prix + ligne3.prix;

    return Trajet(
      segments: segments,
      dureeTotal: duree,
      prixTotal: prix,
      score: _score(duree: duree, prix: prix, correspondances: 2, marcheMinutes: t0 + t4),
      resume: _construireResumeCorrespondance2(
        ligne1: ligne1, ligne2: ligne2, ligne3: ligne3,
        arretArrivee: arretArrivee,
      ),
    );
  }

  // ── Raccordement Woro-Woro vers gare/ligne quand user trop loin ──
  static Trajet? _trajetRaccordementWoroWoro({
    required double userLat,
    required double userLon,
    required double destLat,
    required double destLon,
    required Ligne woroWoro,
    required List<Ligne> lignesCibles,
    required int heure,
  }) {
    if (woroWoro.type != TransportType.woroWoro) return null;
    if (lignesCibles.isEmpty) return null;

    final arretMontee = woroWoro.arretLePlusProcheAvecIndex(userLat, userLon);
    final distMontee = LocationService.distanceEnMetres(
      lat1: userLat, lon1: userLon,
      lat2: arretMontee.arret.latitude, lon2: arretMontee.arret.longitude,
    );
    if (distMontee > _maxMarcheMetres) return null;

    Ligne? meilleureCible;
    Arret? arretCibleProche;
    double meilleureDistCible = double.infinity;

    for (final cible in lignesCibles) {
      if (cible.type == TransportType.woroWoro) continue;
      final arretProche = cible.arretLePlusProcheAvecIndex(destLat, destLon);
      final arretWoroProche = woroWoro.arretLePlusProcheAvecIndex(
        arretProche.arret.latitude, arretProche.arret.longitude,
      );
      final distWoroGare = LocationService.distanceEnMetres(
        lat1: arretWoroProche.arret.latitude, lon1: arretWoroProche.arret.longitude,
        lat2: arretProche.arret.latitude, lon2: arretProche.arret.longitude,
      );
      if (distWoroGare <= 600 && distWoroGare < meilleureDistCible) {
        meilleureDistCible = distWoroGare;
        meilleureCible = cible;
        arretCibleProche = arretProche.arret;
      }
    }

    if (meilleureCible == null || arretCibleProche == null) return null;

    final arretWoroPresGare = woroWoro.arretLePlusProcheAvecIndex(
      arretCibleProche.latitude, arretCibleProche.longitude,
    );
    final distArretCibleDest = LocationService.distanceEnMetres(
      lat1: arretCibleProche.latitude, lon1: arretCibleProche.longitude,
      lat2: destLat, lon2: destLon,
    );
    if (distArretCibleDest > _maxMarcheMetres) return null;

    final t0 = _tempsAPied(distMontee);
    final t1 = _estimerTempsTransport(woroWoro.type, heure);
    final t2 = _tempsAPied(meilleureDistCible);
    final t3 = _estimerTempsTransport(meilleureCible.type, heure);
    final t4 = _tempsAPied(distArretCibleDest);

    final segments = [
      Segment(
        type: TypeSegment.piedVersGare,
        deLatitude: userLat, deLongitude: userLon,
        versLatitude: arretMontee.arret.latitude,
        versLongitude: arretMontee.arret.longitude,
        dureeMinutes: t0,
        prix: 0,
        description: 'Marche vers l\'arrêt ${woroWoro.nom} (~${t0} min)',
        conseil: 'Prends un ${_labelType(woroWoro.type)} devant toi.',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretMontee.arret.latitude,
        deLongitude: arretMontee.arret.longitude,
        versLatitude: arretWoroPresGare.arret.latitude,
        versLongitude: arretWoroPresGare.arret.longitude,
        dureeMinutes: t1,
        prix: woroWoro.prix,
        description: 'Prends ${_labelType(woroWoro.type)} vers ${arretCibleProche.nom}'
            ' — descends près de ${arretCibleProche.nom}',
        conseil: _conseilParType(woroWoro.type, arretCibleProche.nom),
        arretMontee: arretMontee.arret.nom,
        arretDescente: arretCibleProche.nom,
        couleurVehicule: woroWoro.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.piedVersGare,
        deLatitude: arretWoroPresGare.arret.latitude,
        deLongitude: arretWoroPresGare.arret.longitude,
        versLatitude: arretCibleProche.latitude,
        versLongitude: arretCibleProche.longitude,
        dureeMinutes: t2,
        prix: 0,
        description: 'Marche vers ${arretCibleProche.nom} (~${t2} min)',
      ),
      Segment(
        type: TypeSegment.transport,
        deLatitude: arretCibleProche.latitude,
        deLongitude: arretCibleProche.longitude,
        versLatitude: destLat,
        versLongitude: destLon,
        dureeMinutes: t3,
        prix: meilleureCible.prix,
        description: 'Prends ${_labelType(meilleureCible.type)} direction ${meilleureCible.terminusArrivee.nom}'
            ' — descends à ${arretCibleProche.nom}',
        conseil: _conseilParType(meilleureCible.type, arretCibleProche.nom),
        arretMontee: arretCibleProche.nom,
        arretDescente: arretCibleProche.nom,
        couleurVehicule: meilleureCible.couleurVehicule,
      ),
      Segment(
        type: TypeSegment.piedVersDest,
        deLatitude: destLat,
        deLongitude: destLon,
        versLatitude: destLat,
        versLongitude: destLon,
        dureeMinutes: t4,
        prix: 0,
        description: 'Marche vers ta destination (~${t4} min)',
      ),
    ];

    final duree = t0 + t1 + t2 + t3 + t4;
    final prix = woroWoro.prix + meilleureCible.prix;

    return Trajet(
      segments: segments,
      dureeTotal: duree,
      prixTotal: prix,
      score: _score(duree: duree, prix: prix, correspondances: 2, marcheMinutes: t0 + t2 + t4),
      resume: '🚕 ${_labelType(woroWoro.type)} + ${_labelType(meilleureCible.type)} vers ${arretCibleProche.nom}',
    );
  }

  // ── Helpers ──
  static String _construireResumeDirect({
    required int tempsAPied1,
    required Ligne ligne,
    required int tempsTransport,
    required int tempsAPied2,
    required Arret arretArrivee,
  }) {
    final label = _labelType(ligne.type);
    final total = tempsAPied1 + tempsTransport + tempsAPied2;
    return '$label vers ${arretArrivee.nom} (~${total} min)';
  }

  static String _construireResumeCorrespondance1({
    required int tempsAPied1,
    required Ligne ligne1,
    required Ligne ligne2,
    required int tempsAPied2,
    required Arret arretArrivee,
  }) {
    final l1 = _labelType(ligne1.type);
    final l2 = _labelType(ligne2.type);
    final total = tempsAPied1 + 10 + tempsAPied2;
    return '$l1 + $l2 vers ${arretArrivee.nom} (~${total} min)';
  }

  static String _construireResumeCorrespondance2({
    required Ligne ligne1,
    required Ligne ligne2,
    required Ligne ligne3,
    required Arret arretArrivee,
  }) {
    final l1 = _labelType(ligne1.type);
    final l2 = _labelType(ligne2.type);
    final l3 = _labelType(ligne3.type);
    return '$l1 + $l2 + $l3 vers ${arretArrivee.nom}';
  }

  static String _labelType(TransportType type) {
    switch (type) {
      case TransportType.woroWoro:
        return 'Woro-Woro';
      case TransportType.gbaka:
        return 'Gbaka';
      case TransportType.sotra:
        return 'SOTRA';
      case TransportType.yango:
        return 'Yango';
    }
  }

  static String _conseilParType(TransportType type, String arret) {
    switch (type) {
      case TransportType.woroWoro:
        return 'Dis "${arret}" au chauffeur pour descendre.';
      case TransportType.gbaka:
        return 'Crie "$arret" au chauffeur ou au receveur.';
      case TransportType.sotra:
        return 'Prépare-toi à descendre à l\'arrêt annoncé.';
      case TransportType.yango:
        return 'Suis la navigation Yango jusqu\'à destination.';
    }
  }

  static int _tempsAPied(double metres) {
    if (metres <= 0) return 0;
    var minutes = (metres / 4000 * 60).round().clamp(1, 120);
    if (_conditionsActives.pluie) minutes = (minutes * 1.25).round();
    return minutes;
  }

  static int _estimerTempsTransport(TransportType type, int heure) {
    final base = switch (type) {
      TransportType.woroWoro => 18,
      TransportType.gbaka => 22,
      TransportType.sotra => 25,
      TransportType.yango => 20,
    };

    var facteur = 1.0;

    final pointe = (heure >= 7 && heure <= 9) || (heure >= 17 && heure <= 20);
    if (pointe) facteur *= 1.5;

    // Embouteillages : les véhicules collectifs coincés dans la circulation
    // sont plus pénalisés que le VTC (Yango peut esquiver une partie).
    if (_conditionsActives.embouteillage) {
      facteur *= switch (type) {
        TransportType.woroWoro => 1.6,
        TransportType.gbaka => 1.6,
        TransportType.sotra => 1.5,
        TransportType.yango => 1.3,
      };
    }

    // Pluie : ralentit tout (véhicules ouverts, visibilité, marche plus lente).
    if (_conditionsActives.pluie) {
      facteur *= switch (type) {
        TransportType.woroWoro => 1.3,
        TransportType.gbaka => 1.25,
        TransportType.sotra => 1.2,
        TransportType.yango => 1.15,
      };
    }

    return (base * facteur).round();
  }

  static double _score({
    required int duree,
    required int prix,
    required int correspondances,
    int marcheMinutes = 0,
  }) {
    var s = duree + prix * 2.0 + correspondances * 5;
    // Pénalité de marche : chaque minute à pied compte plus qu'une minute
    // assise, ce qui fait remonter les itinéraires avec le moins de marche.
    s += marcheMinutes * _penaliteMarcheParMinute;
    // Sous la pluie, chaque correspondance devient un point d'exposition/attente
    // supplémentaire : on pénalise davantage les trajets à plusieurs correspondances.
    if (_conditionsActives.pluie) s += correspondances * 4;
    return s;
  }
}

class _RoutingOptions {
  final double userLat;
  final double userLon;
  final double destLat;
  final double destLon;
  final List<Ligne> lignes;
  final int heure;
  final Set<String> lignesExclues;
  final bool forcerWoroWoro;
  final ConditionsTrafic conditions;

  const _RoutingOptions({
    required this.userLat,
    required this.userLon,
    required this.destLat,
    required this.destLon,
    required this.lignes,
    required this.heure,
    this.lignesExclues = const <String>{},
    this.forcerWoroWoro = false,
    this.conditions = const ConditionsTrafic(),
  });
}
