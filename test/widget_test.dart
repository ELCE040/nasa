import 'package:flutter_test/flutter_test.dart';

import 'package:nasa_sport/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const NaysaApp());
    await tester.pump(); // allow boot
    expect(find.byType(NaysaApp), findsOneWidget);
  });
}
