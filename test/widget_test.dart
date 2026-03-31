// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:landscape/app/home_lan_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HomeLanApp());

    expect(find.text('MQTT Dashboard'), findsOneWidget);
    expect(find.text('MQTT Connection'), findsOneWidget);
    expect(find.text('Broker host'), findsOneWidget);
    expect(find.text('Topic'), findsOneWidget);
    expect(find.text('Client ID'), findsOneWidget);
  });
}
