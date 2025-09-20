import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/boleta_model.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

class PrintService {
  /// Conecta, imprime la boleta en paquetes y desconecta.
  /// Este es el método más estable para impresoras térmicas.
  static Future<void> printBoleta(BoletaModel boleta) async {
    final prefs = await SharedPreferences.getInstance();
    final printerId = prefs.getString('printer_id');
    final printerName = prefs.getString('printer_name');
    if (printerId == null || printerId.isEmpty) {
      throw Exception('No hay impresora configurada.');
    }

    final bool connected =
        await PrintBluetoothThermal.connect(macPrinterAddress: printerId);
    if (!connected) {
      throw Exception('No se pudo conectar a la impresora.');
    }

    try {
      final List<int> bytes = await _formatBoletaForPrinting(boleta);

      // --- LÓGICA DE IMPRESIÓN POR PAQUETES (CHUNKED) ---
      final upperName = printerName?.toUpperCase() ?? '';
      final bool isBixolonR310 =
          upperName.contains('BIXOLON') && upperName.contains('R310');
      final int chunkSize = isBixolonR310 ? 256 : 512;
      final int delayMs = isBixolonR310 ? 120 : 80;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
        // Pausa crucial para no saturar el buffer de la impresora
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    } finally {
      // Nos aseguramos de desconectar siempre, incluso si hay un error
      await PrintBluetoothThermal.disconnect;
    }
  }

  /// Formatea la boleta en un stream de bytes para la impresora térmica.
  static Future<List<int>> _formatBoletaForPrinting(BoletaModel boleta) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    // Forzar tabla de códigos CP1252 (acentos/ñ) a nivel global
    bytes += generator.setGlobalCodeTable('CP1252');

    // Detectar nombre de impresora (si está guardado) para ajustar ancho de línea y comportamiento
    final prefs = await SharedPreferences.getInstance();
    final printerName = prefs.getString('printer_name')?.toUpperCase() ?? '';
    final bool isBixolonR310 =
        printerName.contains('BIXOLON') && printerName.contains('R310');
    // Nota: si necesitas ajustar más adelante por 58mm, podemos usar 32 col.

    // --- SECCIÓN 1: Encabezado Institucional ---
    try {
      final ByteData data =
          await rootBundle.load('assets/images/logo_muni_joya.png');
      final Uint8List assetBytes = data.buffer.asUint8List();
      final img.Image? image = img.decodeImage(assetBytes);
      if (image != null) {
        bytes += generator.image(image, align: PosAlign.center);
        bytes += generator.feed(1);
      }
    } catch (e) {
      print('Error al cargar el logo: $e');
    }

    bytes += generator.text('MUNICIPALIDAD DISTRITAL DE LA JOYA',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('GERENCIA DE TRANSPORTE',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    // --- SECCIÓN 2: Título del Documento ---
    // Hacerlo grande y que ocupe todo el ancho.
    // Usamos doble ancho/alto y dos líneas para evitar truncamientos en cualquier modelo
    {
      bytes += generator.text(
        'BOLETA DE',
        styles: const PosStyles(
          align: PosAlign.center,
          fontType: PosFontType.fontA,
          width: PosTextSize.size2,
          height: PosTextSize.size2,
          bold: true,
        ),
      );
      bytes += generator.text(
        'FISCALIZACIÓN',
        styles: const PosStyles(
          align: PosAlign.center,
          fontType: PosFontType.fontA,
          width: PosTextSize.size2,
          height: PosTextSize.size2,
          bold: true,
        ),
      );
    }
    bytes += generator.text(
        'ACTA DE CONTROL Nro: ${boleta.id.substring(0, 6).toUpperCase()}',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('D.S. 017-2009-MTC',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    // --- SECCIÓN 3: Infracción (Texto Específico) ---
    bytes += generator.text('F.1',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            width: PosTextSize.size2,
            height: PosTextSize.size2));
    bytes += generator.text('INFRACCIÓN',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            width: PosTextSize.size2,
            height: PosTextSize.size1));

    bytes += generator.text(
        'INFRACCION DE QUIEN REALIZA ACTIVIDAD DE TRANSPORTE SIN AUTORIZACION CON RESPONSABILIDAD SOLIDARIA DEL PROPIETARIO DEL VEHICULO. Prestar el servicio de transporte de personas, de mercancías o mixto, sin contar con autorización otorgada por la autoridad competente o utilizando una modalidad o ámbito distinto del autorizado',
        styles: const PosStyles(align: PosAlign.left));

    bytes += generator.hr();
    bytes += generator.feed(1);

    // --- SECCIÓN 4: Datos de la Intervención ---
    bytes += generator.row([
      PosColumn(
          text: 'Fecha y Hora:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: DateFormat('dd/MM/yy HH:mm').format(boleta.fecha),
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.row([
      PosColumn(text: 'Placa:', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(
          text: boleta.placa.toUpperCase(),
          width: 7,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.row([
      PosColumn(
          text: 'Conductor:', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(
          text: boleta.conductor,
          width: 7,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(
          text: 'Nro Licencia:', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(
          text: boleta.numeroLicencia,
          width: 7,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(
          text: 'Empresa:', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(
          text: boleta.empresa,
          width: 7,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(
          text: 'Fiscalizador:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: boleta.codigoFiscalizador,
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();

    // --- SECCIÓN 5: Detalles de la Fiscalización ---
    bytes += generator.text('MOTIVO:', styles: const PosStyles(bold: true));
    for (var line in _wrapText(boleta.motivo, 32)) {
      bytes += generator.text(line);
    }
    bytes += generator.feed(1);
    bytes += generator.text('CONFORME: ${boleta.conforme}',
        styles: const PosStyles(bold: true));
    bytes += generator.feed(1);

    bytes += generator.text('DESCRIPCION: ${boleta.descripciones}',
        styles: const PosStyles(bold: true));
    bytes += generator.feed(1);

    if (boleta.observaciones != null && boleta.observaciones!.isNotEmpty) {
      bytes += generator.text('OBSERVACIONES DEL INSPECTOR:',
          styles: const PosStyles(bold: true));
      for (var line in _wrapText(boleta.observaciones!, 32)) {
        bytes += generator.text(line);
      }
    }
    bytes += generator.hr();

    // --- SECCIÓN 6: QR y Firmas ---
    bytes += generator.feed(1);
    final String qrData =
        'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/verificarBoleta?id=${boleta.id}';
    bytes +=
        generator.qrcode(qrData, size: QRSize.size4, align: PosAlign.center);
    bytes += generator.text('Escanee para verificar boleta',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);

    bytes += generator.text('_________________________',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Firma del Conductor',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);

    bytes += generator.text('_________________________',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Firma del Inspector',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(4);

    // Evitar cutter en móviles como R310; usar sólo alimentación extra
    if (isBixolonR310) {
      bytes += generator.feed(6);
    } else {
      bytes += generator.cut();
    }

    return bytes;
  }

  /// Función auxiliar para dividir texto largo en líneas de ancho fijo.
  static List<String> _wrapText(String text, int width) {
    final List<String> lines = [];
    final List<String> words = text.split(RegExp(r'\s+'));
    String currentLine = '';

    for (String word in words) {
      if ((currentLine + ' ' + word).trim().length <= width) {
        currentLine += '$word ';
      } else {
        lines.add(currentLine.trim());
        currentLine = '$word ';
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine.trim());
    }
    return lines;
  }
}
