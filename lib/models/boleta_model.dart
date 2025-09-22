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
  // --- INICIO DE MEJORAS: Añadimos el nombre del inspector ---
  final String? inspectorNombre;
  final double? multa;
  final String estado; // 'Activa', 'Pagada', 'Anulada'
  // --- FIN DE MEJORAS ---
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
    // --- INICIO DE MEJORAS ---
    this.inspectorNombre,
    this.multa,
    this.estado = 'Activa', // Valor por defecto 'Activa'
    // --- FIN DE MEJORAS ---
    required this.fecha,
    this.urlFotoLicencia,
  });

  factory BoletaModel.fromMap(Map<String, dynamic> map) {
    DateTime parseFecha(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        final asInt = int.tryParse(v);
        if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
        final d = DateTime.tryParse(v);
        if (d != null) return d;
      }
      return DateTime.now();
    }

    return BoletaModel(
      id: map['id'] ?? '',
      placa: map['placa'] ?? '',
      empresa: map['empresa'] ?? '',
      numeroLicencia: map['numeroLicencia'] ?? '',
      // Aceptar 'conductor' o 'nombreConductor'
      conductor: map['nombreConductor'] ?? map['conductor'] ?? '',
      codigoFiscalizador: map['codigoFiscalizador'] ?? '',
      motivo: map['motivo'] ?? map['infraccion'] ?? '',
      conforme: map['conforme'] ?? 'No especificado',
      descripciones: map['descripciones'],
      observaciones: map['observaciones'],
      inspectorId: map['inspectorId'] ?? '',
      inspectorEmail: map['inspectorEmail'],
      // --- INICIO DE MEJORAS ---
      inspectorNombre: map['inspectorNombre'],
      multa: (map['multa'] as num?)?.toDouble(),
      estado: map['estado'] ?? 'Activa',
      // --- FIN DE MEJORAS ---
      fecha: parseFecha(map['fecha']),
      // Aceptar ambas variantes
      urlFotoLicencia: map['urlFotoLicencia'] ?? map['fotoLicencia'],
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
      // --- INICIO DE MEJORAS ---
      'inspectorNombre': inspectorNombre,
      'multa': multa,
      'estado': estado,
      // --- FIN DE MEJORAS ---
      'fecha': Timestamp.fromDate(fecha),
      'urlFotoLicencia': urlFotoLicencia,
    };
  }

  // --- INICIO DE MEJORAS: Añadimos el método copyWith ---
  BoletaModel copyWith({
    String? id,
    String? urlFotoLicencia,
  }) {
    return BoletaModel(
      id: id ?? this.id,
      placa: placa,
      empresa: empresa,
      numeroLicencia: numeroLicencia,
      conductor: conductor,
      codigoFiscalizador: codigoFiscalizador,
      motivo: motivo,
      conforme: conforme,
      descripciones: descripciones,
      observaciones: observaciones,
      inspectorId: inspectorId,
      inspectorEmail: inspectorEmail,
      inspectorNombre: inspectorNombre,
      multa: multa,
      estado: estado,
      fecha: fecha,
      urlFotoLicencia: urlFotoLicencia ?? this.urlFotoLicencia,
    );
  }
  // --- FIN DE MEJORAS ---
}
