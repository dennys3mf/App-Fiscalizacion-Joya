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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Si el usuario no está logueado (user es null), va al Login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen(errorMessage: 'Por favor, inicie sesión.');
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Si no se encuentra el documento del usuario o hay un error
        if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
          // Por seguridad, cerramos sesión y lo mandamos al login
          FirebaseAuth.instance.signOut();
          return const LoginScreen(errorMessage: 'Por favor, inicie sesión.');
        }

        // Obtenemos el rol del documento del usuario
        final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
        final String userRole = userData['role'] ?? 'inspector'; // Rol por defecto 'inspector'

        // --- ¡AQUÍ ESTÁ LA LÓGICA CLAVE! ---

        // 1. SI ESTAMOS EN LA WEB
        if (kIsWeb) {
          if (userRole == 'gerente') {
            return ManagerDashboardScreen(); // ¡Bienvenido al panel de Gerente!
          } else {
            // Si cualquier otro rol (ej. 'inspector') intenta acceder por la web, lo bloqueamos.
            // Es una buena práctica cerrar sesión para evitar bucles.
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
             // El flujo normal para los inspectores en la app móvil
            return DashboardScreen(onBack: () {  },);
          } else {
            // Si un gerente usa la app móvil, podemos mandarlo al mismo dashboard
            // o a una pantalla de error. Por simplicidad, lo dejamos entrar.
            return DashboardScreen(onBack: () {  },);
          }
        }
      },
    );
  }
}