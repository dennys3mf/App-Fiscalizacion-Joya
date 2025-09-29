// lib/services/pdf_service.dart

import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/boleta_model.dart';

class PDFService {
  static const PdfColor rojoMuni = PdfColor.fromInt(0xffD32F2F);
  static const PdfColor doradoMuni = PdfColor.fromInt(0xffFBC02D);

  Future<Uint8List> generateBoletaPDF(BoletaModel boleta) async {
    final pdf = pw.Document();

    final logoBytes = await rootBundle.load('assets/images/logo_muni_joya.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return _buildPDFContent(boleta, logoImage);
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generateAndSharePDF(BoletaModel boleta) async {
    final pdf = pw.Document();

    final logoBytes = await rootBundle.load('assets/images/logo_muni_joya.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return _buildPDFContent(boleta, logoImage);
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'boleta_${boleta.placa}_${DateFormat('yyyyMMdd_HHmm').format(boleta.fecha)}.pdf',
    );
  }

  static pw.Widget _buildPDFContent(
      BoletaModel boleta, pw.ImageProvider logoImage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Encabezado con logo
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(logoImage, width: 90, height: 90),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MUNICIPALIDAD DISTRITAL DE LA JOYA',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 20,
                      color: rojoMuni,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'GERENCIA DE TRANSPORTE',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.Divider(height: 30, thickness: 2, color: doradoMuni),
        pw.Center(
          child: pw.Text(
            'BOLETA DE FISCALIZACIÓN',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: rojoMuni,
            ),
          ),
        ),
        pw.SizedBox(height: 24),

        // Datos del vehículo
        _buildPDFSection(
          'DATOS DEL VEHÍCULO',
          [
            ['Placa:', boleta.placa.toUpperCase()],
            ['Empresa:', boleta.empresa],
          ],
        ),
        pw.SizedBox(height: 16),
        
        // Datos del conductor - CAMPO CORREGIDO
        _buildPDFSection(
          'DATOS DEL CONDUCTOR',
          [
            ['Conductor:', boleta.nombreConductor], // ✅ CORREGIDO: era boleta.conductor
            ['N° Licencia:', boleta.numeroLicencia],
          ],
        ),
        pw.SizedBox(height: 16),
        
        // Detalles de la fiscalización
        _buildPDFSection(
          'DETALLES DE LA FISCALIZACIÓN',
          [
            [
              'Fecha y Hora:',
              DateFormat('dd/MM/yyyy HH:mm').format(boleta.fecha)
            ],
            ['Inspector:', boleta.inspectorNombre ?? 'N/A'],
            ['Cód. Fiscalizador:', boleta.codigoFiscalizador],
            ['Motivo:', boleta.motivo],
            ['Conforme:', boleta.conforme ?? 'No especificado'],
            if (boleta.observaciones != null &&
                boleta.observaciones!.isNotEmpty)
              ['Observaciones:', boleta.observaciones!],
            if (boleta.multa != null && boleta.multa! > 0)
              ['Multa:', 'S/ ${boleta.multa!.toStringAsFixed(2)}'],
          ],
        ),
        
        pw.Spacer(),
        
        // QR Code para verificación
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: 'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/verificarBoleta?id=${boleta.id}',
            width: 100,
            height: 100,
            color: PdfColors.grey800,
          ),
        ),
        pw.Center(
          child: pw.Text(
            'Escanee para verificar boleta',
            style: const pw.TextStyle(
              color: PdfColors.grey600,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPDFSection(String title, List<List<String>> data) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: rojoMuni,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: data.map((row) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 120,
                        child: pw.Text(row[0],
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Expanded(
                        child: pw.Text(row[1]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
