// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream de usuario autenticado
  Stream<User?> get user => _auth.authStateChanges();

  // Usuario actual
  User? get currentUser => _auth.currentUser;

  // Obtener el modelo de usuario actual desde Firestore
  Future<UserModel?> getCurrentUser() async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) return null;

      return UserModel.fromFirestore(userDoc);
    } catch (e) {
      print('Error al obtener usuario actual: $e');
      return null;
    }
  }

  // Iniciar sesión con email y contraseña
  Future<UserModel?> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Normalizar email
      email = email.trim().toLowerCase();
      
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = result.user;
      if (firebaseUser == null) {
        throw Exception('No se pudo autenticar el usuario');
      }

      // Obtener datos del usuario desde Firestore
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Usuario no encontrado en la base de datos');
      }

      return UserModel.fromFirestore(userDoc);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No existe una cuenta con este correo electrónico');
        case 'wrong-password':
          throw Exception('Contraseña incorrecta');
        case 'invalid-email':
          throw Exception('El formato del correo electrónico es inválido');
        case 'user-disabled':
          throw Exception('Esta cuenta ha sido deshabilitada');
        case 'too-many-requests':
          throw Exception('Demasiados intentos fallidos. Intenta más tarde');
        default:
          throw Exception('Error de autenticación: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  // Registrar nuevo usuario (solo para administradores)
  Future<UserModel?> registerUser({
    required String email,
    required String password,
    required String nombreCompleto,
    required String codigoFiscalizador,
    required String telefono,
    String rol = 'inspector',
    String estado = 'Activo',
  }) async {
    try {
      // Normalizar datos
      email = email.trim().toLowerCase();
      nombreCompleto = nombreCompleto.trim();
      codigoFiscalizador = codigoFiscalizador.trim().toUpperCase();
      telefono = telefono.trim();

      // Crear usuario en Firebase Auth
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = result.user;
      if (firebaseUser == null) {
        throw Exception('No se pudo crear el usuario');
      }

      // Actualizar el displayName en Firebase Auth
      await firebaseUser.updateDisplayName(nombreCompleto);

      // Crear documento del usuario en Firestore usando los nombres exactos de tu BD
      final UserModel newUser = UserModel(
        uid: firebaseUser.uid,
        email: email,
        nombreCompleto: nombreCompleto,
        codigoFiscalizador: codigoFiscalizador,
        telefono: telefono,
        rol: rol,
        estado: estado,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(newUser.toFirestore());

      return newUser;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          throw Exception('La contraseña es muy débil');
        case 'email-already-in-use':
          throw Exception('Ya existe una cuenta con este correo electrónico');
        case 'invalid-email':
          throw Exception('El formato del correo electrónico es inválido');
        default:
          throw Exception('Error al crear cuenta: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  // Actualizar perfil de usuario
  Future<void> updateUserProfile({
    String? nombreCompleto,
    String? telefono,
    String? codigoFiscalizador,
  }) async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw Exception('Usuario no autenticado');
      }

      Map<String, dynamic> updates = {};
      
      if (nombreCompleto != null) {
        updates['nombreCompleto'] = nombreCompleto.trim();
        // También actualizar en Firebase Auth
        await firebaseUser.updateDisplayName(nombreCompleto.trim());
      }
      
      if (telefono != null) {
        updates['telefono'] = telefono.trim();
      }
      
      if (codigoFiscalizador != null) {
        updates['codigoFiscalizador'] = codigoFiscalizador.trim().toUpperCase();
      }

      if (updates.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .update(updates);
      }
    } catch (e) {
      throw Exception('Error al actualizar perfil: $e');
    }
  }

  // Cambiar contraseña
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw Exception('Usuario no autenticado');
      }

      // Reautenticar usuario
      final credential = EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: currentPassword,
      );

      await firebaseUser.reauthenticateWithCredential(credential);
      
      // Cambiar contraseña
      await firebaseUser.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          throw Exception('La contraseña actual es incorrecta');
        case 'weak-password':
          throw Exception('La nueva contraseña es muy débil');
        default:
          throw Exception('Error al cambiar contraseña: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  // Recuperar contraseña
  Future<void> resetPassword(String email) async {
    try {
      email = email.trim().toLowerCase();
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No existe una cuenta con este correo electrónico');
        case 'invalid-email':
          throw Exception('El formato del correo electrónico es inválido');
        default:
          throw Exception('Error al enviar correo de recuperación: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  // Verificar si el usuario está autenticado
  bool get isAuthenticated => _auth.currentUser != null;

  // Obtener UID del usuario actual
  String? get currentUserUid => _auth.currentUser?.uid;

  // Obtener email del usuario actual
  String? get currentUserEmail => _auth.currentUser?.email;

  bool? get isLoading => null;

  // Reautenticar usuario (útil para operaciones sensibles)
  Future<void> reauthenticate(String password) async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final credential = EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: password,
      );

      await firebaseUser.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          throw Exception('Contraseña incorrecta');
        default:
          throw Exception('Error de reautenticación: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  // Verificar si el usuario tiene un rol específico
  Future<bool> hasRole(String role) async {
    try {
      final UserModel? user = await getCurrentUser();
      return user?.rol.toLowerCase() == role.toLowerCase();
    } catch (e) {
      return false;
    }
  }

  // Verificar si el usuario es administrador o gerente
  Future<bool> isAdminOrManager() async {
    try {
      final UserModel? user = await getCurrentUser();
      if (user == null) return false;
      
      final role = user.rol.toLowerCase();
      return role == 'admin' || role == 'gerente';
    } catch (e) {
      return false;
    }
  }

  // Obtener todos los usuarios (solo para administradores)
  Stream<List<UserModel>> getAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  // Obtener usuarios por rol
  Stream<List<UserModel>> getUsersByRole(String role) {
    return _firestore
        .collection('users')
        .where('rol', isEqualTo: role)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }
}
