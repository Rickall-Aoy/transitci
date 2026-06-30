class Chauffeur {
  final String id;
  final String nom;
  final String telephone;
  final String? typeVehicule;
  final bool estActif;

  const Chauffeur({
    required this.id,
    required this.nom,
    required this.telephone,
    this.typeVehicule,
    this.estActif = false,
  });

  factory Chauffeur.fromJson(Map<String, dynamic> json) {
    return Chauffeur(
      id: json['id']?.toString() ?? '',
      nom: json['nom'] ?? '',
      telephone: json['telephone'] ?? '',
      typeVehicule: json['type_vehicule']?.toString(),
      estActif: json['est_actif'] == true || json['est_actif'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'telephone': telephone,
        'type_vehicule': typeVehicule,
        'est_actif': estActif,
      };
}
