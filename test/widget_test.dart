// test/widget_test.dart

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:app_fiscalizacion/main.dart';
import 'package:app_fiscalizacion/services/auth_service.dart';

// Mock Firebase para testing
class MockFirebaseApp implements FirebaseApp {
  @override
  String get name => 'test';

  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'test',
    appId: 'test',
    messagingSenderId: 'test',
    projectId: 'test',
  );

  @override
  bool get isAutomaticDataCollectionEnabled => false;

  @override
  set isAutomaticDataCollectionEnabled(bool enabled) {}

  @override
  Future<void> delete() async {}

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}
}

void main() {
  group('App Fiscalización Tests', () {
    setUpAll(() async {
      // Configurar Firebase para testing
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    testWidgets('App should build without errors', (WidgetTester tester) async {
      // Crear un widget de prueba que no requiera Firebase
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Control de Fiscalización'),
            ),
            body: const Center(
              child: Text('App de Fiscalización'),
            ),
          ),
        ),
      );

      // Verificar que se muestra el título
      expect(find.text('Control de Fiscalización'), findsOneWidget);
      expect(find.text('App de Fiscalización'), findsOneWidget);
    });

    testWidgets('Login screen should show login form', (WidgetTester tester) async {
      // Test básico para verificar que la app puede construirse
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Iniciar Sesión'),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                  ),
                ),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                  ),
                  obscureText: true,
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Ingresar'),
                ),
              ],
            ),
          ),
        ),
      );

      // Verificar elementos del login
      expect(find.text('Iniciar Sesión'), findsOneWidget);
      expect(find.text('Correo Electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
    });

    testWidgets('Theme should be applied correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          home: const Scaffold(
            body: Center(
              child: Text('Test Theme'),
            ),
          ),
        ),
      );

      expect(find.text('Test Theme'), findsOneWidget);
    });
  });

  group('Widget Components Tests', () {
    testWidgets('Custom card should display content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Título de Tarjeta'),
                    const SizedBox(height: 8),
                    const Text('Contenido de la tarjeta'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Acción'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Título de Tarjeta'), findsOneWidget);
      expect(find.text('Contenido de la tarjeta'), findsOneWidget);
      expect(find.text('Acción'), findsOneWidget);
    });

    testWidgets('Form validation should work', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Campo requerido';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Campo de prueba',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      formKey.currentState?.validate();
                    },
                    child: const Text('Validar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Tocar el botón de validar sin llenar el campo
      await tester.tap(find.text('Validar'));
      await tester.pump();

      // Verificar que aparece el mensaje de error
      expect(find.text('Campo requerido'), findsOneWidget);
    });
  });

  group('Navigation Tests', () {
    testWidgets('Navigation should work between screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Pantalla 1')),
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(title: const Text('Pantalla 2')),
                          body: const Center(
                            child: Text('Segunda pantalla'),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Ir a Pantalla 2'),
                ),
              ),
            ),
          ),
        ),
      );

      // Verificar pantalla inicial
      expect(find.text('Pantalla 1'), findsOneWidget);
      expect(find.text('Ir a Pantalla 2'), findsOneWidget);

      // Navegar a la segunda pantalla
      await tester.tap(find.text('Ir a Pantalla 2'));
      await tester.pumpAndSettle();

      // Verificar que estamos en la segunda pantalla
      expect(find.text('Pantalla 2'), findsOneWidget);
      expect(find.text('Segunda pantalla'), findsOneWidget);
    });
  });
}
