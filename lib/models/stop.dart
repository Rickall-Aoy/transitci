import 'ligne.dart';

/// Nœud « arrêt » du graphe de transport.
///
/// Le projet modélise un arrêt par [Arret] (nom + coordonnées) mais sans
/// rattachement à une ligne. Or les walking edges relient des arrêts de
/// *lignes différentes* : ce wrapper associe donc un [Arret] à l'identifiant
/// de la [Ligne] qui le dessert, en réutilisant les champs existants
/// ([Arret.latitude]/[Arret.longitude] et [Ligne.id]).
class Stop {
  final Arret arret;
  final String ligneId;

  const Stop({required this.arret, required this.ligneId});

  String get id =>
      '$ligneId|${arret.latitude.toStringAsFixed(5)},'
      '${arret.longitude.toStringAsFixed(5)}';
  String get nom => arret.nom;
  double get latitude => arret.latitude;
  double get longitude => arret.longitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Stop && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
