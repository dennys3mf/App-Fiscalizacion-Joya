// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:app_fiscalizacion/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    // Simula que el usuario no ha iniciado sesión
    await tester.pumpWidget(const MyApp(isLoggedIn: false, username: '',));

    // Verifica que se muestra la pantalla de login (puedes buscar un widget específico)
    expect(find.text('Control de Fiscalización'), findsOneWidget);
  });
}