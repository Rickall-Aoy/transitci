import 'package:flutter_test/flutter_test.dart';
import 'package:transit_ci/main.dart';

void main() {
  testWidgets('TransitCIApp renders successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const TransitCIApp());

    expect(find.byType(TransitCIApp), findsOneWidget);
  });
}
