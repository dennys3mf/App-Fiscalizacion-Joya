import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import '../fiscalizacion_form_screen.dart';
import 'screens/impresoras_screen.dart';
import 'screens/historial_screen.dart';
import 'package:firebase_core/firebase_core.dart'; // <-- 1. Importar Firebase Core
import 'firebase_options.dart'; // <-- 2. Importar el archivo de configuración

// Paleta de colores inspirada en el gobierno del Perú
const Color azulGobierno = Color(0xFF002B5C); // Azul institucional
const Color rojoGobierno = Color(0xFFDA291C); // Rojo bandera
const Color fondoOscuro = Color(0xFF121212);
const Color superficieOscura = Color(0xFF1E1E1E);

void main() async {
  // Asegurarse de que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // --- 3. INICIALIZACIÓN DE FIREBASE ---
  // Esta línea es crucial. Debe ir antes de cualquier otra lógica.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // ------------------------------------

  await initializeDateFormatting('es_PE', null);

  // Esta lógica de SharedPreferences la reemplazaremos más adelante
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String username = prefs.getString('username') ?? '';

  runApp(MyApp(isLoggedIn: isLoggedIn, username: username));
}


class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String username;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Fiscalización',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: azulGobierno,
        scaffoldBackgroundColor: fondoOscuro,
        colorScheme: const ColorScheme.dark(
          primary: azulGobierno,
          secondary: rojoGobierno,
          surface: superficieOscura,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white70,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: superficieOscura,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: const OutlineInputBorder(
            borderSide: BorderSide.none,
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: azulGobierno, width: 2.0),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azulGobierno,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white38),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        cardTheme: CardThemeData(
          color: superficieOscura,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: rojoGobierno,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14.0, color: Colors.white60),
        ),
      ),
      home: isLoggedIn ? HomeScreen(username: username) : const LoginScreen(),
      routes: {
        '/fiscalizacion_form': (context) => const FiscalizacionFormScreen(),
        '/impresoras': (context) => const ImpresorasScreen(),
        '/historial': (context) => const HistorialScreen(),
      },
    );
  }
}
