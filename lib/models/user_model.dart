// lib/models/user_model.dart

class UserModel {
  final String uid;
  final String nombreCompleto;
  final String email;
  final String rol;
  final String? codigoFiscalizador;
  final String? telefono;
  final String estado; // 'Activo', 'Inactivo'


  UserModel({
    required this.uid,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
    this.codigoFiscalizador,
    this.telefono,
    required this.estado,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      nombreCompleto: map['nombreCompleto'] ?? 'Sin nombre',
      email: map['email'] ?? 'Sin email',
      rol: map['rol'] ?? 'inspector',
      telefono: map['telefono'],
      estado: map['estado'] ?? 'Activo',
      codigoFiscalizador: map['codigoFiscalizador'],
    );
  }
}