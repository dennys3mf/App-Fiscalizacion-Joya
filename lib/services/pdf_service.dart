import 'package:intl/intl.dart';

import 'dart:typed_data';
import 'package:flutter/services.dart'; // <-- IMPORTANTE: Añade esta línea
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/boleta_model.dart';

class PDFService {
  // --- 1. Definimos los colores del logo para usarlos en el PDF ---
  static const PdfColor rojoMuni = PdfColor.fromInt(0xffD32F2F);
  static const PdfColor doradoMuni = PdfColor.fromInt(0xffFBC02D);

  static Future<void> generateAndSharePDF(BoletaModel boleta) async {
    final pdf = pw.Document();

    // --- 2. Cargamos la imagen del logo desde los assets ---
    final logoBytes = await rootBundle.load('assets/images/logo_muni_joya.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          // Pasamos la imagen del logo a la función que construye el contenido
          return _buildPDFContent(boleta, logoImage);
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'boleta_${boleta.placa}_${DateFormat('yyyyMMdd_HHmm').format(boleta.fecha)}.pdf',
    );
  }

  // --- 3. Actualizamos la función para que reciba el logo ---
  static pw.Widget _buildPDFContent(BoletaModel boleta, pw.ImageProvider logoImage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // --- 4. Reemplazamos el encabezado antiguo por el nuevo diseño ---
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
        
        // --- 5. Aplicamos el nuevo estilo a las secciones de datos ---
        _buildPDFSection(
          'DATOS DEL VEHÍCULO',
          [
            ['Placa:', boleta.placa.toUpperCase()],
            ['Empresa:', boleta.empresa],
          ],
        ),
        pw.SizedBox(height: 16),
        _buildPDFSection(
          'DATOS DEL CONDUCTOR',
          [
            ['Conductor:', boleta.conductor],
            ['N° Licencia:', boleta.numeroLicencia],
          ],
        ),
        pw.SizedBox(height: 16),
        _buildPDFSection(
          'DETALLES DE LA FISCALIZACIÓN',
          [
            ['Fecha y Hora:', DateFormat('dd/MM/yyyy HH:mm').format(boleta.fecha)],
            ['Inspector:', boleta.inspectorNombre ?? 'N/A'],
            ['Cód. Fiscalizador:', boleta.codigoFiscalizador],
            ['Motivo:', boleta.motivo],
            ['Conforme:', boleta.conforme],
            if (boleta.observaciones != null && boleta.observaciones!.isNotEmpty)
              ['Observaciones:', boleta.observaciones!],
          ],
        ),
      ],
    );
  }

  // --- 6. Actualizamos el widget de sección para usar los nuevos colores ---
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
                topLeft: pw.Radius.circular(7), // Radio ajustado para el borde
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
                        child: pw.Text(row[0], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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

  // Función vacía eliminada para mayor claridad
}