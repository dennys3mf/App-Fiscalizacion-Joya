import 'package:cloud_firestore/cloud_firestore.dart';

class Boleta {
  final String? id; // Cambiado a String para el ID de Firestore
  final String placa;
  final String empresa;
  final String fiscalizador;
  final String motivo;
  final String conforme;
  final String descripciones;
  final String observaciones;
  final DateTime fecha;

  Boleta({
    this.id,
    required this.placa,
    required this.empresa,
    required this.fiscalizador,
    required this.motivo,
    required this.conforme,
    required this.descripciones,
    required this.observaciones,
    required this.fecha,
  });

  // Convierte un objeto Boleta a un Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'placa': placa,
      'empresa': empresa,
      'fiscalizador': fiscalizador,
      'motivo': motivo,
      'conforme': conforme,
      'descripciones': descripciones,
      'observaciones': observaciones,
      'fecha': Timestamp.fromDate(
          fecha), // Convertimos la fecha a Timestamp de Firestore
    };
  }

  // --- FUNCIÓN CORREGIDA ---
  // Convierte un documento de Firestore a un objeto Boleta
  static Boleta fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Boleta(
        id: doc.id,
        placa: data['placa'] as String,
        empresa: data['empresa'] as String,
        fiscalizador: data['fiscalizador'] as String,
        motivo: data['motivo'] as String,
        conforme: data['conforme'] as String,
        descripciones: data['descripciones'] as String,
        observaciones: data['observaciones'] as String,
        fecha: (data['fecha'] as Timestamp).toDate());
  }
}
