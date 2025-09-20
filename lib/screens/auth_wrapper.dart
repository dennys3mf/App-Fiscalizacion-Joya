import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras espera la conexión
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si el usuario está logueado
        if (snapshot.hasData) {
          // --- ESTA ES LA LÍNEA CORREGIDA ---
          // Aquí le pasamos la función de navegación a la HomeScreen.
          // Le decimos: "cuando alguien te pida navegar, usa el Navigator de Flutter".
          return HomeScreen(
            username: snapshot.data?.displayName ?? snapshot.data?.email ?? 'Usuario',
            onNavigate: (route) {
              Navigator.pushNamed(context, route);
            },
          );
        }

        // Si el usuario no está logueado
        return const LoginScreen();
      },
    );
  }
}