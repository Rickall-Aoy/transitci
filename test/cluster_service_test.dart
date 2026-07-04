import 'package:flutter_test/flutter_test.dart';
import 'package:transit_ci/models/gare.dart';
import 'package:transit_ci/models/ligne.dart';
import 'package:transit_ci/services/cluster_service.dart';

void main() {
  group('ClusterService', () {
    test('construit des items de cluster à partir des lignes', () {
      final ligne = Ligne(
        id: 'L1',
        nom: 'Ligne A',
        type: TransportType.sotra,
        terminusDepart: const Arret(
          nom: 'Terminal Nord',
          latitude: 5.35,
          longitude: -4.01,
        ),
        terminusArrivee: const Arret(
          nom: 'Terminal Sud',
          latitude: 5.36,
          longitude: -4.02,
        ),
        arretsPossibles: const [
          Arret(nom: 'Arrêt 1', latitude: 5.351, longitude: -4.011),
        ],
        prix: 200,
        couleurVehicule: '0xFF0000FF',
      );

      final items = ClusterService.construireItems(
        lignes: [ligne],
        arretsSupabase: const [],
      );

      expect(items.length, 3);
      expect(items.any((item) => item.nom == 'Terminal Nord' && item.estTerminus), isTrue);
      expect(items.any((item) => item.nom == 'Arrêt 1' && !item.estTerminus), isTrue);
    });
  });
}
