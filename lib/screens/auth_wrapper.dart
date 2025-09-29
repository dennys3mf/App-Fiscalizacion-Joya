// lib/screens/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/auth_service.dart';
import '../models/user_model.dart';

import 'login_screen.dart';
import 'home_screen.dart'; // ✅ AGREGADO: Para inspectores en móvil
import 'manager_dashboard_screen.dart';
import 'admin_dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final User? firebaseUser = snapshot.data;

        if (firebaseUser == null) {
          // Usuario no autenticado: mostrar login
          return const LoginScreen(errorMessage: '');
        } else {
          // Usuario autenticado: obtener su modelo de usuario para determinar el rol
          return FutureBuilder<UserModel?>(
            future: authService.getCurrentUser(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (userSnapshot.hasError) {
                // Error al obtener datos del usuario
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  authService.signOut();
                });
                return const LoginScreen(
                  errorMessage:
                      'Error al cargar datos del usuario. Inicie sesión nuevamente.',
                );
              }

              final UserModel? userModel = userSnapshot.data;
              if (userModel == null) {
                // Usuario no encontrado en Firestore
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  authService.signOut();
                });
                return const LoginScreen(
                  errorMessage: 'Usuario no encontrado en el sistema.',
                );
              }

              final String userRole = userModel.rol.toLowerCase();

              if (kIsWeb) {
                // ===== PLATAFORMA WEB =====
                if (userRole == 'inspector') {
                  // Los inspectores no tienen acceso a la web
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    authService.signOut();
                  });
                  return const LoginScreen(
                    errorMessage:
                        'Los inspectores deben usar la aplicación móvil.',
                  );
                } else if (userRole == 'gerente') {
                  // Los gerentes van al ManagerDashboardScreen en web
                  return ManagerDashboardScreen();
                } else if (userRole == 'admin') {
                  // Los admins van al AdminDashboardScreen en web
                  return AdminDashboardScreen(onBack: () {});
                } else {
                  // Rol desconocido
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    authService.signOut();
                  });
                  return const LoginScreen(
                    errorMessage:
                        'Rol de usuario no reconocido para la plataforma web.',
                  );
                }
              } else {
                // ===== PLATAFORMA MÓVIL =====
                if (userRole == 'inspector') {
                  // ✅ CORREGIDO: Los inspectores van al HomeScreen en móvil
                  return HomeScreen(
                    currentUser: userModel,
                    onLogout: () {
                      authService.signOut();
                    },
                    onNavigate: (String route) {},
                    username: '',
                  );
                } else if (userRole == 'gerente') {
                  // Los gerentes pueden usar el HomeScreen o un dashboard específico
                  // Por ahora, usamos HomeScreen para consistencia
                  return HomeScreen(
                    currentUser: userModel,
                    onLogout: () {
                      authService.signOut();
                    },
                    onNavigate: (String route) {},
                    username: '',
                  );
                } else if (userRole == 'admin') {
                  // Los admins pueden usar el HomeScreen o un dashboard específico
                  return HomeScreen(
                    currentUser: userModel,
                    onLogout: () {
                      authService.signOut();
                    },
                    onNavigate: (String route) {},
                    username: '',
                  );
                } else {
                  // Rol desconocido o no permitido en móvil
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    authService.signOut();
                  });
                  return const LoginScreen(
                    errorMessage: 'Rol de usuario no reconocido.',
                  );
                }
              }
            },
          );
        }
      },
    );
  }
}
