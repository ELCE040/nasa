import 'package:flutter_test/flutter_test.dart';

import 'package:nasa_sport/main.dart';

void main() {
  testWidgets('starts on the fan home page', (WidgetTester tester) async {
    await tester.pumpWidget(const NasaSportApp());

    expect(find.text('Nasa Sport'), findsOneWidget);
    expect(find.text('Live events'), findsOneWidget);
    expect(find.text('Latest results'), findsOneWidget);
  });
}
