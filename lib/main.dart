import 'package:app_fiscalizacion/screens/admin_dashboard_screen.dart';
import 'package:app_fiscalizacion/screens/auth_wrapper.dart';
import 'package:app_fiscalizacion/screens/dashboard_screen.dart';
import 'package:app_fiscalizacion/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// --- INICIO DE MEJORAS: Importaciones necesarias ---
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:app_fiscalizacion/screens/registration_screen.dart';
// --- FIN DE MEJORAS ---

import 'package:app_fiscalizacion/screens/home_screen.dart';
import 'package:app_fiscalizacion/fiscalizacion_form_screen.dart';
import 'package:app_fiscalizacion/screens/impresoras_screen.dart';
import 'package:app_fiscalizacion/screens/historial_screen.dart';
// Se elimina la importación de test_impresora.dart que no se usa en la lógica final
// import 'package:app_fiscalizacion/test_impresora.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- INICIO DE MEJORAS: Configuración condicional de App Check ---
  // Usamos kIsWeb para saber si estamos en la web o en una app móvil
  if (kIsWeb) {
    // Si estamos en la web, activamos App Check con reCAPTCHA Enterprise
    await FirebaseAppCheck.instance.activate(
      // IMPORTANTE: Recuerda obtener esta clave desde tu Consola de Firebase
      webProvider:
          ReCaptchaEnterpriseProvider('n9QTY]>ap23.ZrVY-957468005Pl@3is5071*'),
    );
  } else {
    // Android/iOS
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity // producción
          : AndroidProvider
              .debug, // desarrollo: requiere registrar el debug token
    );
    // Nota: En modo debug, verás en el logcat un token de App Check Debug.
    // Copia ese token y añádelo en la consola de Firebase > App Check > Depuración.
  }
  // --- FIN DE MEJORAS ---

  await initializeDateFormatting('es_PE', null);

  runApp(const MyApp(isLoggedIn: false, username: ''));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required bool isLoggedIn, required String username});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Fiscalización',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme, // Usamos el nuevo tema centralizado
      home: const AuthWrapper(),
      // home: const TestImpresoraScreen(), // Y añade esta para la prueba

      // --- RUTAS CORREGIDAS ---
      // Aquí está la corrección. Cada ruta ahora es una función que
      // construye la pantalla correspondiente y le pasa la lógica de navegación.
      routes: {
        '/home': (context) => HomeScreen(
              onNavigate: (route) => Navigator.pushNamed(context, route),
              username: '',
            ),
        '/fiscalizacion_form': (context) => FiscalizacionFormScreen(
              onBack: () => Navigator.pop(context),
            ),
        '/impresoras': (context) => ImpresorasScreen(
              onBack: () => Navigator.pop(context),
            ),
        '/historial': (context) => HistorialScreen(
              onBack: () => Navigator.pop(context),
            ),
        // --- INICIO DE MEJORAS: Nuevas rutas de la aplicación ---
        '/registration': (context) => const RegistrationScreen(),
        '/dashboard': (context) =>
            DashboardScreen(onBack: () => Navigator.pop(context)),

        '/admin_dashboard': (context) => AdminDashboardScreen(
              onBack: () => Navigator.pop(context),
            ),
        // --- FIN DE MEJORAS ---
      },
    );
  }
}
