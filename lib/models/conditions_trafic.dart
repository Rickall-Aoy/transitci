/// Conditions de trafic utilisées pour simuler un trajet (pluie, embouteillages)
/// et influencer le choix du meilleur itinéraire.
class ConditionsTrafic {
  /// Présence de pluie : ralentit tous les modes (véhicules ouverts, marche
  /// plus lente) et pénalise les correspondances (exposition, attente).
  final bool pluie;

  /// Embouteillages : ralentit fortement les modes collectifs coincés dans la
  /// circulation (Woro-Woro, Gbaka, SOTRA) plus que le VTC (Yango).
  final bool embouteillage;

  const ConditionsTrafic({this.pluie = false, this.embouteillage = false});

  /// Au moins une condition active.
  bool get actif => pluie || embouteillage;

  ConditionsTrafic copyWith({bool? pluie, bool? embouteillage}) {
    return ConditionsTrafic(
      pluie: pluie ?? this.pluie,
      embouteillage: embouteillage ?? this.embouteillage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConditionsTrafic &&
          pluie == other.pluie &&
          embouteillage == other.embouteillage;

  @override
  int get hashCode => pluie.hashCode ^ embouteillage.hashCode;
}
