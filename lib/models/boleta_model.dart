import 'package:cloud_firestore/cloud_firestore.dart';

class BoletaModel {
  final String id;
  final String placa;
  final String empresa;
  final String numeroLicencia;
  final String conductor;
  final String codigoFiscalizador;
  final String motivo;
  final String conforme;
  final String? descripciones;
  final String? observaciones;
  final String inspectorId;
  final String? inspectorEmail;
  final DateTime fecha;
  final String? urlFotoLicencia;

  BoletaModel({
    required this.id,
    required this.placa,
    required this.empresa,
    required this.numeroLicencia,
    required this.conductor,
    required this.codigoFiscalizador,
    required this.motivo,
    required this.conforme,
    this.descripciones,
    this.observaciones,
    required this.inspectorId,
    this.inspectorEmail,
    required this.fecha,
    this.urlFotoLicencia,
  });

  factory BoletaModel.fromMap(Map<String, dynamic> map) {
    return BoletaModel(
      id: map['id'],
      placa: map['placa'] ?? '',
      empresa: map['empresa'] ?? '',
      numeroLicencia: map['numeroLicencia'] ?? '',
      conductor: map['nombreConductor'] ?? '',
      codigoFiscalizador: map['codigoFiscalizador'] ?? '',
      motivo: map['motivo'] ?? '',
      conforme: map['conforme'] ?? 'No especificado',
      descripciones: map['descripciones'],
      observaciones: map['observaciones'],
      inspectorId: map['inspectorId'] ?? '',
      inspectorEmail: map['inspectorEmail'],
      fecha: (map['fecha'] as Timestamp).toDate(),
      urlFotoLicencia: map['urlFotoLicencia'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'placa': placa,
      'empresa': empresa,
      'numeroLicencia': numeroLicencia,
      'nombreConductor': conductor,
      'codigoFiscalizador': codigoFiscalizador,
      'motivo': motivo,
      'conforme': conforme,
      'descripciones': descripciones,
      'observaciones': observaciones,
      'inspectorId': inspectorId,
      'inspectorEmail': inspectorEmail,
      'fecha': Timestamp.fromDate(fecha),
      'urlFotoLicencia': urlFotoLicencia,
    };
  }
}