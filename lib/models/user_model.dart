// lib/models/user_model.dart

class User {
  final int? id;
  final String username;
  final String password; // Esta será la contraseña hasheada

  User({this.id, required this.username, required this.password});

  // Convierte un Map de la BD a un objeto User
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      password: map['password'],
    );
  }

  // Convierte un objeto User a un Map para la BD
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
    };
  }
}