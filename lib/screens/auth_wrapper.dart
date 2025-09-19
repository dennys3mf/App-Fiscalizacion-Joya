// lib/screens/auth_wrapper.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder escucha los cambios de autenticación en tiempo real
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras espera la primera respuesta del stream, muestra un spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Si el snapshot tiene datos, significa que hay un usuario logueado
        if (snapshot.hasData && snapshot.data != null) {
          // El 'username' se puede obtener del objeto User
          return HomeScreen(username: snapshot.data!.email ?? 'Usuario');
        }

        // Si no hay datos, muestra la pantalla de login
        return const LoginScreen();
      },
    );
  }
}