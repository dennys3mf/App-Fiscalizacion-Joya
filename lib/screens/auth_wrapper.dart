import 'package:app_fiscalizacion/screens/dashboard_screen.dart';
import 'package:app_fiscalizacion/screens/login_screen.dart';
import 'package:app_fiscalizacion/screens/manager_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras espera la conexión, muestra un spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Si el usuario no está logueado (user es null), va al Login
        if (!snapshot.hasData || snapshot.data == null) {
          // Usuario no autenticado: mostrar login con mensaje vacío (requerido por el constructor)
          return const LoginScreen(errorMessage: '');
        }

        // Si el usuario SÍ está logueado, verificamos su rol
        return RoleBasedRedirect(userId: snapshot.data!.uid);
      },
    );
  }
}

class RoleBasedRedirect extends StatelessWidget {
  final String userId;

  const RoleBasedRedirect({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Usamos un FutureBuilder para obtener el rol del usuario desde Firestore una sola vez
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userDocSnapshot) {
        // Mientras carga los datos del usuario
        if (userDocSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Si no se encuentra el documento del usuario o hay un error
        if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
          // Por seguridad, cerramos sesión y lo mandamos al login
          FirebaseAuth.instance.signOut();
          return const LoginScreen(
              errorMessage: 'No se encontraron datos del usuario.');
        }

        // Obtenemos el rol del documento del usuario
        final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
        final String userRole =
            userData['role'] ?? 'inspector'; // Rol por defecto 'inspector'

        // --- INICIO DE LA MODIFICACIÓN ---
        // 1. Imprimimos el rol que estamos leyendo para depurar.
        print(
            'AuthWrapper Check -> Rol del usuario: "$userRole" | Plataforma: ${kIsWeb ? "Web" : "Móvil"}');
        // --- FIN DE LA MODIFICACIÓN ---

        // 1. SI ESTAMOS EN LA WEB
        if (kIsWeb) {
          if (userRole == 'gerente') {
            return ManagerDashboardScreen(); // ¡Bienvenido al panel de Gerente!
          } else {
            // --- INICIO DE LA MODIFICACIÓN ---
            // 2. Imprimimos por qué estamos denegando el acceso.
            print(
                'AuthWrapper Check -> ¡Acceso denegado en web! El rol "$userRole" no es "gerente". Cerrando sesión.');
            // --- FIN DE LA MODIFICACIÓN ---

            // Si cualquier otro rol (ej. 'inspector') intenta acceder por la web, lo bloqueamos.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FirebaseAuth.instance.signOut();
            });
            return const LoginScreen(
              errorMessage: 'Acceso exclusivo para administradores.',
            );
          }
        }
        // 2. SI ESTAMOS EN MÓVIL
        else {
          if (userRole == 'inspector') {
            // Flujo normal para inspectores en móvil
            return DashboardScreen(onBack: () {});
          } else {
            // Si un gerente usa la app móvil, lo mandamos al mismo dashboard
            return DashboardScreen(onBack: () {});
          }
        }
      },
    );
  }
}
