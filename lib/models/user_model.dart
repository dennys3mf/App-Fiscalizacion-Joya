// lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String nombreCompleto;
  final String codigoFiscalizador;
  final String telefono;
  final String rol;
  final String estado;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.nombreCompleto,
    required this.codigoFiscalizador,
    required this.telefono,
    required this.rol,
    required this.estado,
    required this.createdAt,
  });

  // Constructor desde DocumentSnapshot de Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      nombreCompleto: data['nombreCompleto'] ?? '',
      codigoFiscalizador: data['codigoFiscalizador'] ?? '',
      telefono: data['telefono'] ?? '',
      rol: data['rol'] ?? 'inspector',
      estado: data['estado'] ?? 'Activo',
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  // Constructor desde Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      nombreCompleto: map['nombreCompleto'] ?? '',
      codigoFiscalizador: map['codigoFiscalizador'] ?? '',
      telefono: map['telefono'] ?? '',
      rol: map['rol'] ?? 'inspector',
      estado: map['estado'] ?? 'Activo',
      createdAt: _parseTimestamp(map['createdAt']),
    );
  }

  // Convertir a Map para Firestore (usando los nombres exactos de tu BD)
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'nombreCompleto': nombreCompleto,
      'codigoFiscalizador': codigoFiscalizador,
      'telefono': telefono,
      'rol': rol,
      'estado': estado,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Convertir a Map simple
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nombreCompleto': nombreCompleto,
      'codigoFiscalizador': codigoFiscalizador,
      'telefono': telefono,
      'rol': rol,
      'estado': estado,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Método copyWith para crear copias con cambios
  UserModel copyWith({
    String? uid,
    String? email,
    String? nombreCompleto,
    String? codigoFiscalizador,
    String? telefono,
    String? rol,
    String? estado,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      codigoFiscalizador: codigoFiscalizador ?? this.codigoFiscalizador,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Getters para compatibilidad con código existente
  String get name => nombreCompleto;
  String get code => codigoFiscalizador;
  String get phone => telefono;
  String get role => rol;
  String get status => estado;

  // Método para verificar si el usuario está activo
  bool get isActive => estado.toLowerCase() == 'activo';

  // Método para verificar si es inspector
  bool get isInspector => rol.toLowerCase() == 'inspector';

  // Método para verificar si es gerente
  bool get isManager => rol.toLowerCase() == 'gerente';

  // Método para verificar si es admin
  bool get isAdmin => rol.toLowerCase() == 'admin';

  // Método para obtener el nombre completo formateado
  String get displayName => nombreCompleto.isNotEmpty ? nombreCompleto : email;

  // Método para obtener el código formateado
  String get displayCode => codigoFiscalizador.isNotEmpty ? codigoFiscalizador.toUpperCase() : 'SIN CÓDIGO';

  // Método toString para debugging
  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, nombreCompleto: $nombreCompleto, codigoFiscalizador: $codigoFiscalizador, rol: $rol, estado: $estado)';
  }

  // Método equals para comparaciones
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  // Método privado para parsear timestamps de manera segura
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    
    if (timestamp is DateTime) {
      return timestamp;
    }
    
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    
    if (timestamp is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    
    return DateTime.now();
  }

  // Método para validar el modelo
  bool isValid() {
    return uid.isNotEmpty && 
           email.isNotEmpty && 
           email.contains('@') &&
           nombreCompleto.isNotEmpty &&
           rol.isNotEmpty;
  }

  // Método para obtener el color del rol
  String getRoleColor() {
    switch (rol.toLowerCase()) {
      case 'admin':
        return '#1E40AF'; // Azul
      case 'gerente':
        return '#DC2626'; // Rojo
      case 'inspector':
        return '#16A34A'; // Verde
      default:
        return '#6B7280'; // Gris
    }
  }

  // Método para obtener el icono del rol
  String getRoleIcon() {
    switch (rol.toLowerCase()) {
      case 'admin':
        return 'admin_panel_settings';
      case 'gerente':
        return 'shield';
      case 'inspector':
        return 'person';
      default:
        return 'person';
    }
  }
}
