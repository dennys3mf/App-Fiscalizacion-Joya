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

      // --- LÓGICA DE IMPRESIÓN POR PAQUETES MEJORADA ---
      final upperName = printerName?.toUpperCase() ?? '';
      final PrinterConfig config = _getPrinterConfig(upperName);
      
      for (int i = 0; i < bytes.length; i += config.chunkSize) {
        int end = (i + config.chunkSize < bytes.length) ? i + config.chunkSize : bytes.length;
        await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
        // Pausa crucial para no saturar el buffer de la impresora
        await Future.delayed(Duration(milliseconds: config.delayMs));
      }
    } finally {
      // Nos aseguramos de desconectar siempre, incluso si hay un error
      await PrintBluetoothThermal.disconnect;
    }
  }

  /// Obtiene la configuración específica para diferentes modelos de impresoras
  static PrinterConfig _getPrinterConfig(String printerName) {
    // Configuraciones específicas para diferentes marcas y modelos
    if (printerName.contains('BIXOLON')) {
      if (printerName.contains('R310') || printerName.contains('SPP-R310')) {
        return PrinterConfig(chunkSize: 256, delayMs: 120, paperWidth: 58);
      } else if (printerName.contains('R200') || printerName.contains('SPP-R200')) {
        return PrinterConfig(chunkSize: 256, delayMs: 100, paperWidth: 58);
      } else if (printerName.contains('R400') || printerName.contains('SPP-R400')) {
        return PrinterConfig(chunkSize: 512, delayMs: 80, paperWidth: 80);
      } else {
        // BIXOLON genérico
        return PrinterConfig(chunkSize: 256, delayMs: 100, paperWidth: 58);
      }
    } else if (printerName.contains('EPSON')) {
      return PrinterConfig(chunkSize: 512, delayMs: 60, paperWidth: 80);
    } else if (printerName.contains('STAR')) {
      return PrinterConfig(chunkSize: 512, delayMs: 70, paperWidth: 80);
    } else if (printerName.contains('CITIZEN')) {
      return PrinterConfig(chunkSize: 256, delayMs: 90, paperWidth: 58);
    } else if (printerName.contains('ZEBRA')) {
      return PrinterConfig(chunkSize: 512, delayMs: 80, paperWidth: 80);
    } else {
      // Configuración por defecto para impresoras desconocidas
      return PrinterConfig(chunkSize: 512, delayMs: 80, paperWidth: 80);
    }
  }

  /// Método para probar la conexión con la impresora
  static Future<bool> testPrinterConnection(String printerId, String printerName) async {
    try {
      final bool connected = await PrintBluetoothThermal.connect(macPrinterAddress: printerId);
      if (!connected) {
        return false;
      }

      // Enviar comando de prueba simple
      String testData = '\n--- PRUEBA DE CONEXION ---\n';
      testData += 'App Fiscalizacion Joya\n';
      testData += DateTime.now().toString().substring(0, 19);
      testData += '\nImpresora: $printerName\n';
      testData += 'Conexion exitosa!\n\n\n';
      
      await PrintBluetoothThermal.writeBytes(testData.codeUnits);
      await PrintBluetoothThermal.disconnect;
      
      return true;
    } catch (e) {
      print('Error en prueba de conexión: $e');
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
      return false;
    }
  }

  /// Formatea la boleta en un stream de bytes para la impresora térmica.
  static Future<List<int>> _formatBoletaForPrinting(BoletaModel boleta) async {
    final profile = await CapabilityProfile.load();
    
    // Obtener configuración de la impresora
    final prefs = await SharedPreferences.getInstance();
    final printerName = prefs.getString('printer_name')?.toUpperCase() ?? '';
    final PrinterConfig config = _getPrinterConfig(printerName);
    
    // Determinar el tamaño de papel y columnas
    final PaperSize paperSize = config.paperWidth == 58 ? PaperSize.mm58 : PaperSize.mm80;
    final int maxColumns = config.paperWidth == 58 ? 32 : 48;
    
    final generator = Generator(paperSize, profile);

    List<int> bytes = [];

    // Forzar tabla de códigos CP1252 (acentos/ñ) a nivel global
    bytes += generator.setGlobalCodeTable('CP1252');

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
    // Ajustar tamaño según el ancho del papel
    final PosTextSize titleSize = config.paperWidth == 58 ? PosTextSize.size1 : PosTextSize.size2;
    
    bytes += generator.text(
      'BOLETA DE',
      styles: PosStyles(
        align: PosAlign.center,
        fontType: PosFontType.fontA,
        width: titleSize,
        height: titleSize,
        bold: true,
      ),
    );
    bytes += generator.text(
      'FISCALIZACIÓN',
      styles: PosStyles(
        align: PosAlign.center,
        fontType: PosFontType.fontA,
        width: titleSize,
        height: titleSize,
        bold: true,
      ),
    );
    
    bytes += generator.text(
        'ACTA DE CONTROL Nro: ${boleta.id.substring(0, 6).toUpperCase()}',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('D.S. 017-2009-MTC',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    // --- SECCIÓN 3: Infracción (Texto Específico) ---
    bytes += generator.text('F.1',
        styles: PosStyles(
            align: PosAlign.center,
            bold: true,
            width: titleSize,
            height: titleSize));
    bytes += generator.text('INFRACCIÓN',
        styles: PosStyles(
            align: PosAlign.center,
            bold: true,
            width: titleSize,
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
    
    // ✅ CORREGIDO: Asegurar que el conductor se imprima correctamente
    bytes += generator.row([
      PosColumn(
          text: 'Conductor:', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(
          text: boleta.conductor.isNotEmpty ? boleta.conductor : 'No especificado',
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
    
    // ✅ SOLO CÓDIGO DEL FISCALIZADOR (sin nombre del inspector)
    bytes += generator.row([
      PosColumn(
          text: 'Fiscalizador:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: boleta.codigoFiscalizador,
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    
    // ❌ REMOVIDO: Ya no se imprime el nombre del inspector
    // ❌ REMOVIDO: Ya no se imprime la multa
    
    bytes += generator.hr();

    // --- SECCIÓN 5: Detalles de la Fiscalización ---
    bytes += generator.text('MOTIVO:', styles: const PosStyles(bold: true));
    for (var line in _wrapText(boleta.motivo, maxColumns)) {
      bytes += generator.text(line);
    }
    bytes += generator.feed(1);
    bytes += generator.text('CONFORME: ${boleta.conforme}',
        styles: const PosStyles(bold: true));
    bytes += generator.feed(1);
    if (boleta.descripciones != null && boleta.descripciones!.isNotEmpty) {
      bytes += generator.text('DESCRIPCIÓN DETALLADA:',
          styles: const PosStyles(bold: true));
      for (var line in _wrapText(boleta.descripciones!, maxColumns)) {
        bytes += generator.text(line);
      }
      bytes += generator.feed(1);
    }
    
    if (boleta.observaciones != null && boleta.observaciones!.isNotEmpty) {
      bytes += generator.text('OBSERVACIONES DEL INSPECTOR:',
          styles: const PosStyles(bold: true));
      for (var line in _wrapText(boleta.observaciones!, maxColumns)) {
        bytes += generator.text(line);
      }
    }
    
    bytes += generator.hr();
    // --- SECCIÓN 6: QR y Firmas ---
    bytes += generator.feed(1);
    final String qrData =
        'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/verificarBoleta?id=${boleta.id}';
    
    // Ajustar tamaño del QR según el ancho del papel
    final QRSize qrSize = config.paperWidth == 58 ? QRSize.size3 : QRSize.size4;
    bytes += generator.qrcode(qrData, size: qrSize, align: PosAlign.center);
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

    // Configuración específica para el corte según el modelo
    if (config.paperWidth == 58 || printerName.contains('R310') || printerName.contains('MOBILE')) {
      // Para impresoras móviles pequeñas, usar solo alimentación extra
      bytes += generator.feed(6);
    } else {
      // Para impresoras de escritorio, usar corte
      bytes += generator.cut();
    }

    return bytes;
  }

  /// Divide un texto largo en líneas que caben en el ancho de la impresora.
  static List<String> _wrapText(String text, int maxColumns) {
    final List<String> lines = [];
    final words = text.split(' ');
    String currentLine = '';

    for (final word in words) {
      if ((currentLine + word).length <= maxColumns) {
        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
          currentLine = word;
        } else {
          // Palabra muy larga, dividirla
          for (int i = 0; i < word.length; i += maxColumns) {
            lines.add(word.substring(i, 
                i + maxColumns > word.length ? word.length : i + maxColumns));
          }
          currentLine = '';
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }
}

/// Configuración específica para cada modelo de impresora
class PrinterConfig {
  final int chunkSize;
  final int delayMs;
  final int paperWidth; // 58mm o 80mm

  PrinterConfig({
    required this.chunkSize,
    required this.delayMs,
    required this.paperWidth,
  });
}
