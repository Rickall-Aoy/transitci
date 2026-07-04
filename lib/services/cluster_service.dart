import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/gare.dart';
import '../models/ligne.dart';

class ArretClusterItem {
  ArretClusterItem({
    required LatLng position,
    required this.nom,
    required this.type,
    required this.ligneNom,
    required this.prix,
    this.estTerminus = false,
  }) : _position = position;

  final String nom;
  final TransportType type;
  final String ligneNom;
  final int prix;
  final bool estTerminus;
  final LatLng _position;

  LatLng get location => _position;
}

class ClusterService {
  static const int _maxLignesCarte = 80;
  static const int _maxArretsParLigne = 20;
  static const int _maxItemsCarte = 1200;

  static Function(Set<Marker>)? _onMarkersUpdated;
  static CameraPosition? _cameraPosition;
  static List<ArretClusterItem> _items = const [];

  static void initialiser({
    required Function(Set<Marker>) onMarkersUpdated,
    required List<Ligne> lignes,
    List<dynamic> arretsSupabase = const [],
  }) {
    _onMarkersUpdated = onMarkersUpdated;
    _items = construireItems(lignes: lignes, arretsSupabase: arretsSupabase);
    _mettreAJourMarqueurs();
  }

  static void mettreAJourCamera(CameraPosition position) {
    _cameraPosition = position;
  }

  static void onCameraIdle() {
    _mettreAJourMarqueurs();
  }

  static List<ArretClusterItem> construireItems({
    required List<Ligne> lignes,
    List<dynamic> arretsSupabase = const [],
  }) {
    final items = <ArretClusterItem>[];

    final parType = <TransportType, List<Ligne>>{};
    for (final ligne in lignes) {
      parType.putIfAbsent(ligne.type, () => []).add(ligne);
    }

    debugPrint(
      '📊 Lignes par type avant troncature: '
      '${parType.map((k, v) => MapEntry(k.name, v.length))}',
    );

    // Répartition round-robin: une ligne de chaque type à tour de rôle,
    // pour éviter qu'un type dense ne monopolise les items générés
    // en cas de troncature ultérieure (zoom, rayon caméra, etc.)
    final typesPresents = parType.keys.toList();
    final lignesEquilibrees = <Ligne>[];
    int index = 0;
    while (lignesEquilibrees.length < _maxLignesCarte) {
      bool auMoinsUnAjout = false;
      for (final type in typesPresents) {
        final liste = parType[type]!;
        if (index < liste.length) {
          lignesEquilibrees.add(liste[index]);
          auMoinsUnAjout = true;
          if (lignesEquilibrees.length >= _maxLignesCarte) break;
        }
      }
      if (!auMoinsUnAjout) break; // plus aucune ligne à ajouter
      index++;
    }

    debugPrint(
      '📊 Lignes retenues après équilibrage (${lignesEquilibrees.length}): '
      '${lignesEquilibrees.fold<Map<String, int>>({}, (m, l) {
        m[l.type.name] = (m[l.type.name] ?? 0) + 1;
        return m;
      })}',
    );

    for (final ligne in lignesEquilibrees) {
      if (items.length >= _maxItemsCarte) break;
      items.add(
        ArretClusterItem(
          position: LatLng(
            ligne.terminusDepart.latitude,
            ligne.terminusDepart.longitude,
          ),
          nom: ligne.terminusDepart.nom,
          type: ligne.type,
          ligneNom: ligne.nom,
          prix: ligne.prix,
          estTerminus: true,
        ),
      );

      items.add(
        ArretClusterItem(
          position: LatLng(
            ligne.terminusArrivee.latitude,
            ligne.terminusArrivee.longitude,
          ),
          nom: ligne.terminusArrivee.nom,
          type: ligne.type,
          ligneNom: ligne.nom,
          prix: ligne.prix,
          estTerminus: true,
        ),
      );

      for (final arret in ligne.arretsPossibles.take(_maxArretsParLigne)) {
        if (items.length >= _maxItemsCarte) break;
        items.add(
          ArretClusterItem(
            position: LatLng(arret.latitude, arret.longitude),
            nom: arret.nom,
            type: ligne.type,
            ligneNom: ligne.nom,
            prix: ligne.prix,
            estTerminus: false,
          ),
        );
      }
    }

    for (final arret in arretsSupabase) {
      if (items.length >= _maxItemsCarte) break;
      try {
        items.add(
          ArretClusterItem(
            position: LatLng(
              (arret['latitude'] as num).toDouble(),
              (arret['longitude'] as num).toDouble(),
            ),
            nom: arret['nom']?.toString() ?? 'Arrêt',
            type: TransportType.sotra,
            ligneNom: arret['ligne']?.toString() ?? '',
            prix: int.tryParse(arret['prix']?.toString() ?? '') ?? 200,
            estTerminus: false,
          ),
        );
      } catch (_) {}
    }

    return items;
  }

  static void _mettreAJourMarqueurs() async {
    if (_onMarkersUpdated == null) return;

    final zoom = _cameraPosition?.zoom ?? 13;
    final center = _cameraPosition?.target;

    final itemsFiltres = center == null
        ? _items
        : _items.where((item) {
            final rayon = zoom < 11
                ? 0.3
                : zoom < 13
                    ? 0.15
                    : 0.08;
            return (item.location.latitude - center.latitude).abs() <= rayon &&
                (item.location.longitude - center.longitude).abs() <= rayon;
          }).toList();

    final markers = <Marker>{};

    if (zoom >= 14) {
      for (final item in itemsFiltres.take(150)) {
        markers.add(_marqueurIndividuel(item));
      }
    } else {
      final groupes = _construireGroupes(zoom, itemsFiltres.take(300).toList());
      for (final g in groupes) markers.add(_marqueurGroupe(g));
    }

    _onMarkersUpdated!.call(markers);
  }

  static List<_ClusterGroup> _construireGroupes(
      double zoom, List<ArretClusterItem> items) {
    final groupes = <_ClusterGroup>[];
    final seuil = zoom < 10
        ? 0.08
        : zoom < 12
            ? 0.04
            : 0.015;

    for (final item in items) {
      _ClusterGroup? groupeTrouve;
      for (final groupe in groupes) {
        final distance = _distance(groupe.position, item.location);
        if (distance <= seuil) {
          groupeTrouve = groupe;
          break;
        }
      }

      if (groupeTrouve == null) {
        groupes.add(_ClusterGroup(items: [item], position: item.location));
      } else {
        groupeTrouve.items.add(item);
      }
    }

    return groupes;
  }

  static double _distance(LatLng a, LatLng b) {
    return ((a.latitude - b.latitude).abs() +
        (a.longitude - b.longitude).abs());
  }

  static Marker _marqueurIndividuel(ArretClusterItem item) {
    return Marker(
      markerId: MarkerId(
          '${item.nom}_${item.location.latitude.toStringAsFixed(4)}_${item.location.longitude.toStringAsFixed(4)}'),
      position: item.location,
      icon: BitmapDescriptor.defaultMarkerWithHue(_hue(item.type)),
      infoWindow: InfoWindow(
        title: '${_emoji(item.type)} ${item.nom}',
        snippet:
            '${item.ligneNom} · ${item.prix} FCFA${item.estTerminus ? ' · Terminus' : ' · Arrêt possible'}',
      ),
    );
  }

  static Marker _marqueurGroupe(_ClusterGroup groupe) {
    final count = groupe.items.length;
    final hue = count > 20
        ? BitmapDescriptor.hueRed
        : count > 5
            ? BitmapDescriptor.hueOrange
            : BitmapDescriptor.hueGreen;

    return Marker(
      markerId: MarkerId(
        'cluster_${count}_'
        '${groupe.position.latitude.toStringAsFixed(4)}_'
        '${groupe.position.longitude.toStringAsFixed(4)}',
      ),
      position: groupe.position,
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(
        title: count > 1 ? '$count arrêts' : groupe.items.first.nom,
        snippet: count > 1
            ? 'Zoomez pour voir le détail'
            : '${groupe.items.first.ligneNom} · ${groupe.items.first.prix} FCFA',
      ),
    );
  }

  static double _hue(TransportType type) {
    switch (type) {
      case TransportType.woroWoro:
        return BitmapDescriptor.hueOrange;
      case TransportType.gbaka:
        return BitmapDescriptor.hueGreen;
      case TransportType.sotra:
        return BitmapDescriptor.hueBlue;
      case TransportType.yango:
        return BitmapDescriptor.hueYellow;
    }
  }

  static String _emoji(TransportType type) {
    switch (type) {
      case TransportType.woroWoro:
        return '🚕';
      case TransportType.gbaka:
        return '🚐';
      case TransportType.sotra:
        return '🚌';
      case TransportType.yango:
        return '🚗';
    }
  }
}

class _ClusterGroup {
  _ClusterGroup({required this.items, required this.position});

  final List<ArretClusterItem> items;
  final LatLng position;
}