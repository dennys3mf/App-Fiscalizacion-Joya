// lib/models/boleta_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Boleta {
  final String placa;
  final String empresa;
  final String numeroLicencia;
  final String nombreConductor;
  final String codigoFiscalizador;
  final String motivo;
  final String conforme;
  final String descripciones;
  final String observaciones;
  final String inspectorId;
  final String? inspectorEmail;
  String? urlFotoLicencia; // Se actualiza después

  Boleta({
    required this.placa,
    required this.empresa,
    required this.numeroLicencia,
    required this.nombreConductor,
    required this.codigoFiscalizador,
    required this.motivo,
    required this.conforme,
    required this.descripciones,
    required this.observaciones,
    required this.inspectorId,
    this.inspectorEmail,
    this.urlFotoLicencia,
  });

  // Convierte un objeto Boleta a un Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'placa': placa,
      'empresa': empresa,
      'numeroLicencia': numeroLicencia,
      'nombreConductor': nombreConductor,
      'codigoFiscalizador': codigoFiscalizador,
      'motivo': motivo,
      'conforme': conforme,
      'descripciones': descripciones,
      'observaciones': observaciones,
      'fecha': FieldValue.serverTimestamp(), // La fecha se añade aquí
      'inspectorId': inspectorId,
      'inspectorEmail': inspectorEmail,
      'urlFotoLicencia': urlFotoLicencia ?? '',
    };
  }
}