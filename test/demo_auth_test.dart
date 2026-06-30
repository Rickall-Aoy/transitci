import 'package:flutter_test/flutter_test.dart';
import 'package:transit_ci/services/demo_auth.dart';

void main() {
  group('DemoAuth', () {
    test('accepte les identifiants de test prédéfinis', () {
      expect(DemoAuth.matchesTestCredentials('chauffeur.test', 'TransitTest2026!'), isTrue);
    });

    test('rejette un mot de passe incorrect', () {
      expect(DemoAuth.matchesTestCredentials('chauffeur.test', 'mauvais'), isFalse);
    });
  });
}
