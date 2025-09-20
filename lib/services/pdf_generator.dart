import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/boleta_model.dart'; // Asegúrate que la ruta sea correcta

class PdfGenerator {
  static Future<Uint8List> generateBoletaPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final boletaId = data['boletaId'] ?? 'N/A';
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 2),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('MUNICIPALIDAD DISTRITAL DE LA JOYA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text('GERENCIA DE TRANSPORTE'),
                    pw.Divider(),
                    pw.Text('BOLETA DE FISCALIZACIÓN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    pw.Text('ACTA DE CONTROL Nro: ${data['actaNro'] ?? 'N/A'}'),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              
              // Contenido
              _buildDetailRow('Fecha y Hora:', data['fechaHora'] ?? 'N/A'),
              _buildDetailRow('Placa:', data['placa'] ?? 'N/A'),
              _buildDetailRow('Conductor:', data['conductor'] ?? 'N/A'),
              _buildDetailRow('N° Licencia:', data['licencia'] ?? 'N/A'),
              _buildDetailRow('Empresa:', data['empresa'] ?? 'N/A'),
              _buildDetailRow('Fiscalizador:', data['fiscalizador'] ?? 'N/A'),
              pw.Divider(height: 20),
              _buildDetailRow('Motivo:', data['motivo'] ?? 'N/A'),
              _buildDetailRow('Conforme:', data['conforme'] ?? 'N/A'),
              _buildDetailRow('Observaciones:', data['observaciones'] ?? 'N/A'),
              
              pw.Spacer(),

              // QR Code
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/verificarBoleta?id=$boletaId',
                  width: 150,
                  height: 150,
                ),
              ),
               pw.Center(child: pw.Text('Escanee para verificar boleta')),
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
            child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      )
    );
  }
}