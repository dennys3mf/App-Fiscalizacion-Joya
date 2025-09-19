// lib/services/pdf_generator.dart

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGenerator {
  static Future<Uint8List> generateBoletaPdf(Map<String, String> data) async {
    final pdf = pw.Document();

    // --- ARREGLO 2: CARGAR FUENTES UNICODE ---
    final fontData = await rootBundle.load("assets/fonts/Roboto-Italic-VariableFont_wdth,wght.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-VariableFont_wdth,wght.ttf");
    final boldTtf = pw.Font.ttf(boldFontData);

    final logoImage = pw.MemoryImage(
      (await rootBundle.load('assets/images/logo_muni_joya.png'))
          .buffer
          .asUint8List(),
    );

    // Definimos estilos reutilizables CON LA NUEVA FUENTE
    final headerStyle = pw.TextStyle(font: boldTtf, fontSize: 10);
    final bodyStyle = pw.TextStyle(font: ttf, fontSize: 9);
    final smallStyle = pw.TextStyle(font: ttf, fontSize: 8);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll57,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logoImage, height: 40),
              pw.SizedBox(height: 5),
              pw.Text('MUNICIPALIDAD DISTRITAL DE LA JOYA', style: headerStyle),
              pw.Text('GERENCIA DE TRANSPORTE', style: bodyStyle),
              pw.Divider(height: 10),
              pw.Text('BOLETA DE FISCALIZACIÓN', style: bodyStyle.copyWith(fontSize: 14)),
              pw.SizedBox(height: 5),
              pw.Divider(height: 10),
              pw.Text('ACTA DE CONTROL N° ${data['actaNro']}', style: headerStyle.copyWith(fontSize: 12)),
              pw.Text('D.S. 017-2009-MTC', style: bodyStyle),
              pw.Divider(height: 10),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('F.1', style: headerStyle),
                  pw.Text('Infracción', style: headerStyle), // Ortografía corregida
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'INFRACCION DE QUIEN REALIZA ACTIVIDAD DE TRANSPORTE SIN AUTORIZACION CON RESPONSABILIDAD SOLIDARIA DEL PROPIETARIO DEL VEHICULO.',
                style: smallStyle,
                textAlign: pw.TextAlign.justify,
              ),
              pw.Divider(height: 10),
              
              _buildPdfRow('Fecha y Hora:', data['fechaHora']!, ttf, boldTtf),
              _buildPdfRow('Placa:', data['placa']!, ttf, boldTtf),
              _buildPdfRow('Conductor:', data['conductor']!, ttf, boldTtf),
              _buildPdfRow('N° Licencia:', data['licencia']!, ttf, boldTtf), // 'N°' funcionará ahora
              _buildPdfRow('Empresa:', data['empresa']!, ttf, boldTtf),
              _buildPdfRow('Fiscalizador:', data['fiscalizador']!, ttf, boldTtf),
              pw.Divider(height: 10),
              
              _buildPdfSection('MOTIVO:', data['motivo']!, ttf, boldTtf),
              _buildPdfSection('CONFORME:', data['conforme']!, ttf, boldTtf),
              _buildPdfSection('OBSERVACIONES:', data['observaciones']!, ttf, boldTtf),
              
              // --- ARREGLO 1: REEMPLAZAR SPACER POR SIZEDBOX ---
              // Esto le da a la columna una altura fija y evita el error.
              pw.SizedBox(height: 20), 
              
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'https://.../verificarBoleta?id=${data['boletaId']}',
                width: 70,
                height: 70,
              ),
              pw.SizedBox(height: 2),
              pw.Text('Escanee para verificar', style: smallStyle),
              pw.SizedBox(height: 20),
              pw.Text('_________________________', style: bodyStyle),
              pw.Text('Firma del Conductor', style: bodyStyle),
              pw.SizedBox(height: 20),
              pw.Text('_________________________', style: bodyStyle),
              pw.Text('Firma del Inspector', style: bodyStyle),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- MÉTODOS AUXILIARES ACTUALIZADOS PARA ACEPTAR LAS FUENTES ---
  static pw.Widget _buildPdfRow(String title, String value, pw.Font ttf, pw.Font boldTtf) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(font: boldTtf, fontSize: 9)),
          pw.Text(value, style: pw.TextStyle(font: ttf, fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfSection(String title, String content, pw.Font ttf, pw.Font boldTtf) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(font: boldTtf, fontSize: 9)),
        pw.Text(content, style: pw.TextStyle(font: ttf, fontSize: 9)),
        pw.SizedBox(height: 5),
      ],
    );
  }
}