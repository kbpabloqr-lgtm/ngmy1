// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ngmy1/main.dart';
import 'package:ngmy1/screens/home.dart';
import 'package:ngmy1/widgets/glass_menu.dart';

void main() {
  testWidgets('Home screen renders circular menu', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(CircularMenu), findsOneWidget);
  });
}
