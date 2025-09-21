import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// Removed unused: printing, intl, boleta_model

class PdfGenerator {
  // ================== INICIO DE LA MEJORA ==================

  // 2. Definimos los colores del logo para usarlos en el PDF
  static const PdfColor rojoMuni =
      PdfColor.fromInt(0xffD32F2F); // Un rojo similar al del logo
  static const PdfColor doradoMuni =
      PdfColor.fromInt(0xffFBC02D); // Un dorado/amarillo similar

  static Future<Uint8List> generateBoletaPdf(Map<String, dynamic> data,
      {String municipalidadNombre = 'MUNICIPALIDAD DISTRITAL DE LA JOYA',
      String gerenciaNombre = 'GERENCIA DE TRANSPORTE'}) async {
    final pdf = pw.Document();
    final boletaId = data['boletaId'] ?? 'N/A';

    // 3. Cargamos la imagen del logo desde los assets
    final logoBytes = await rootBundle.load('assets/images/logo_muni_joya.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // =================== FIN DE LA MEJORA ===================

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ================== INICIO DEL NUEVO ENCABEZADO ==================
              // 4. Creamos un encabezado con el logo y el texto estilizado
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: rojoMuni, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(logoImage, width: 80, height: 80),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            municipalidadNombre.toUpperCase(),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 18,
                              color: rojoMuni,
                            ),
                          ),
                          pw.Text(
                            gerenciaNombre.toUpperCase(),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Divider(
                              color: doradoMuni, height: 10, thickness: 2),
                          pw.Text(
                            'BOLETA DE FISCALIZACIÓN',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // =================== FIN DEL NUEVO ENCABEZADO ===================

              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'ACTA DE CONTROL Nro: ${data['actaNro'] ?? 'N/A'}',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                ),
              ),
              pw.SizedBox(height: 20),

              // Contenido
              _buildDetailRow('Fecha y Hora:', data['fechaHora'] ?? 'N/A'),
              _buildDetailRow('Placa:', data['placa'] ?? 'N/A'),
              _buildDetailRow('Conductor:', data['conductor'] ?? 'N/A'),
              _buildDetailRow('N° Licencia:', data['licencia'] ?? 'N/A'),
              _buildDetailRow('Empresa:', data['empresa'] ?? 'N/A'),
              _buildDetailRow('Fiscalizador:', data['fiscalizador'] ?? 'N/A'),
              pw.Divider(height: 20, color: doradoMuni.shade(0.2)),
              _buildDetailRow('Motivo:', data['motivo'] ?? 'N/A'),
              _buildDetailRow('Conforme:', data['conforme'] ?? 'N/A'),
              _buildDetailRow('Observaciones:', data['observaciones'] ?? 'N/A'),

              pw.Spacer(),

              // QR Code
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data:
                      'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/verificarBoleta?id=$boletaId',
                  width: 100,
                  height: 100,
                  color: PdfColors.grey800,
                ),
              ),
              pw.Center(
                  child: pw.Text('Escanee para verificar boleta',
                      style: const pw.TextStyle(
                          color: PdfColors.grey600, fontSize: 10))),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildDetailRow(String title, String value) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Text(title,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700)),
            ),
            pw.Expanded(
              child: pw.Text(value),
            ),
          ],
        ));
  }
}
