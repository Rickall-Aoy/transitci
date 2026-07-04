import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transit_ci/widgets/signaler_arret_widget.dart';

void main() {
  testWidgets('shows the problem-reporting flow when requested',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignalerArretWidget(
            latitude: 5.0,
            longitude: -4.0,
            isNight: false,
            onSuccess: () {},
            mode: SignalerArretMode.probleme,
          ),
        ),
      ),
    );

    expect(find.text('Signaler un problème'), findsOneWidget);
    expect(find.text('Envoyer le signalement'), findsOneWidget);
  });
}
