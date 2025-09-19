import 'dart:convert';
import 'dart:io';
import 'package:app_fiscalizacion/models/boleta_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import '../services/pdf_generator.dart'; // La ruta a tu nuevo archivo

// Paleta de colores personalizada
const Color fondoNegro = Color(0xFF181818);
const Color grisOscuro = Color(0xFF232323);
const Color blancoDiia = Color(0xFFFFFFFF);
const Color rojoDiia = Color(0xFFE60000);
const Color azulClaroDiia = Color(0xFFB2C2FF);
const Color celesteDiia = Color(0xFF8ECDF7);
const Color grisClaroDiia = Color(0xFFE0E0E0);

class FiscalizacionFormScreen extends StatefulWidget {
  const FiscalizacionFormScreen({super.key});

  @override
  State<FiscalizacionFormScreen> createState() =>
      _FiscalizacionFormScreenState();
}

class _FiscalizacionFormScreenState extends State<FiscalizacionFormScreen> {
  final _placaController = TextEditingController();
  final _empresaController = TextEditingController();
  final _fiscalizadorController = TextEditingController();
  final _motivoController = TextEditingController();
  final List<String> _opcionesConforme = ['Sí', 'No', 'Parcialmente'];
  File? _fotoLicencia;
  final _descripcionesController = TextEditingController();
  final _observacionesInspectorController = TextEditingController();
  final _licenciaController = TextEditingController();
  final _conductorController = TextEditingController();
  String _fechaHoraActual = "";
  String? _conformeSeleccionado;

  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _actualizarFechaHora();
    _cargarDatosFiscalizador(); // <-- HACK UX: Cargar datos guardados al iniciar
  }

  @override
  void dispose() {
    _placaController.dispose();
    _empresaController.dispose();
    _fiscalizadorController.dispose();
    _motivoController.dispose();
    _descripcionesController.dispose();
    _observacionesInspectorController.dispose();
    _licenciaController.dispose();
    _conductorController.dispose();
    super.dispose();
  }

  // --- HACK UX 1: Cargar y Guardar Código del Fiscalizador ---
  Future<void> _cargarDatosFiscalizador() async {
    final prefs = await SharedPreferences.getInstance();
    final codigo = prefs.getString('codigo_fiscalizador');
    if (codigo != null) {
      _fiscalizadorController.text = codigo;
    }
  }

  Future<void> _guardarDatosFiscalizador() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('codigo_fiscalizador', _fiscalizadorController.text);
  }

  Future<void> _mostrarPdf() async {
    // 1. Recolectamos los datos del formulario
    final data = {
      'actaNro': '7003004138',
      'fechaHora': DateFormat('dd/MM/yy HH:mm').format(DateTime.now()),
      'placa': _placaController.text.toUpperCase(),
      'conductor': _conductorController.text.toUpperCase(),
      'licencia': _licenciaController.text.toUpperCase(),
      'empresa': _empresaController.text.toUpperCase(),
      'fiscalizador': _fiscalizadorController.text.toUpperCase(),
      'motivo': _motivoController.text.isNotEmpty
          ? _motivoController.text
          : 'Ninguno.',
      'conforme': _conformeSeleccionado ?? 'No especificado',
      'observaciones': _observacionesInspectorController.text.isNotEmpty
          ? _observacionesInspectorController.text
          : 'Ninguna.',
      'boletaId': 'test-id-para-preview', // Usamos un ID de prueba
    };

    // 2. Generamos el PDF usando nuestro nuevo servicio
    final pdfBytes = await PdfGenerator.generateBoletaPdf(data);

    // 3. Mostramos la pantalla de vista previa
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }
  // -----------------------------------------------------------

  void _actualizarFechaHora() {
    final now = DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy HH:mm:ss', 'es_PE');
    setState(() {
      _fechaHoraActual = formatter.format(now);
    });
  }

  void _limpiarCampos() {
    _placaController.clear();
    _empresaController.clear();
    _motivoController.clear();
    // No limpiamos el fiscalizador para que persista
    _licenciaController.clear();
    _conductorController.clear();
    setState(() {
      _conformeSeleccionado = null;
      _fotoLicencia = null;
    });
    _descripcionesController.clear();
    _observacionesInspectorController.clear();
  }

  // --- OPTIMIZACIÓN DE COSTOS: Redimensionar imagen antes de subir ---
  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      final fileBytes = await pickedFile.readAsBytes();
      final image = img.decodeImage(fileBytes);

      if (image != null) {
        // Redimensiona la imagen a un ancho máximo de 800px
        final resizedImage = img.copyResize(image, width: 800);
        final resizedBytes = img.encodeJpg(resizedImage, quality: 85);

        // Guarda la imagen redimensionada en un archivo temporal
        final tempDir = await getTemporaryDirectory();
        final tempPath =
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final resizedFile = File(tempPath)..writeAsBytesSync(resizedBytes);

        setState(() {
          _fotoLicencia = resizedFile; // Usamos el archivo redimensionado
        });
      }
    }
  }
  // --------------------------------------------------------------------

  final TextStyle _estiloTextoCampo = const TextStyle(
    color: blancoDiia,
    fontFamily: 'Inter',
    fontSize: 16,
  );

  InputDecoration _decoracionCampo({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: celesteDiia,
        fontFamily: 'Inter',
        fontWeight: FontWeight.bold,
      ),
      hintText: hint,
      hintStyle: const TextStyle(color: grisClaroDiia, fontFamily: 'Inter'),
      prefixIcon: Icon(icon, color: celesteDiia),
      filled: true,
      fillColor: fondoNegro,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: celesteDiia, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: azulClaroDiia, width: 1.5),
      ),
    );
  }

  Future<void> _finalizarEImprimir() async {
    if (_isPrinting) return;
    setState(() {
      _isPrinting = true;
    });

    if (_placaController.text.isEmpty ||
        _empresaController.text.isEmpty ||
        _licenciaController.text.isEmpty ||
        _conductorController.text.isEmpty ||
        _motivoController.text.isEmpty ||
        _fiscalizadorController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Por favor, complete todos los campos.')));
      }
      setState(() {
        _isPrinting = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final printerId = prefs.getString('printer_id');
    if (printerId == null || printerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay impresora configurada.')));
      }
      setState(() {
        _isPrinting = false;
      });
      return;
    }

    String? boletaId;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Usuario no autenticado.");

      // HACK UX: Guardamos el código del fiscalizador para la próxima vez
      await _guardarDatosFiscalizador();

      // --- OPTIMIZACIÓN: Usando el modelo de datos ---
      final nuevaBoleta = Boleta(
        placa: _placaController.text,
        empresa: _empresaController.text,
        numeroLicencia: _licenciaController.text,
        nombreConductor: _conductorController.text,
        codigoFiscalizador: _fiscalizadorController.text,
        motivo: _motivoController.text,
        conforme: _conformeSeleccionado ?? 'No especificado',
        descripciones: _descripcionesController.text,
        observaciones: _observacionesInspectorController.text,
        inspectorId: user.uid,
        inspectorEmail: user.email,
      );

      final docRef = await FirebaseFirestore.instance
          .collection('boletas')
          .add(nuevaBoleta.toFirestore());
      boletaId = docRef.id;

      String urlFotoLicencia = '';
      if (_fotoLicencia != null) {
        final ref = FirebaseStorage.instance.ref('licencias/$boletaId.jpg');
        await ref.putFile(_fotoLicencia!);
        urlFotoLicencia = await ref.getDownloadURL();
      }

      if (urlFotoLicencia.isNotEmpty) {
        await docRef.update({'urlFotoLicencia': urlFotoLicencia});
      }

      final bool connected =
          await PrintBluetoothThermal.connect(macPrinterAddress: printerId);
      if (connected) {
        List<int> bytes = await _crearBoletaBytes(boletaId);

        const int chunkSize = 512;
        for (int i = 0; i < bytes.length; i += chunkSize) {
          int end =
              (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
          await PrintBluetoothThermal.writeBytes(bytes.sublist(i, end));
          await Future.delayed(const Duration(milliseconds: 80));
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Impresión y guardado exitosos')));
          _limpiarCampos();
        }
      } else {
        throw Exception("No se pudo conectar a la impresora.");
      }
    } catch (e) {
      if (boletaId != null) {
        await FirebaseFirestore.instance
            .collection('boletas')
            .doc(boletaId)
            .delete();
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      await PrintBluetoothThermal.disconnect;
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  Future<List<int>> _crearBoletaBytes(String boletaId) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    List<int> textToBytes(String text, {PosStyles styles = const PosStyles()}) {
      text = text.replaceAll('Ñ', 'N').replaceAll('ñ', 'n');
      return generator.textEncoded(Uint8List.fromList(latin1.encode(text)),
          styles: styles);
    }

    String sanitize(String text) {
      return text
          .replaceAll('Á', 'A')
          .replaceAll('á', 'a')
          .replaceAll('É', 'E')
          .replaceAll('é', 'e')
          .replaceAll('Í', 'I')
          .replaceAll('í', 'i')
          .replaceAll('Ó', 'O')
          .replaceAll('ó', 'o')
          .replaceAll('Ú', 'U')
          .replaceAll('ú', 'u')
          .replaceAll('Ñ', 'N')
          .replaceAll('ñ', 'n');
    }

    List<String> wrapText(String text) {
      List<String> lines = [];
      List<String> words = text.split(' ');
      String currentLine = '';
      for (var word in words) {
        if ((currentLine + ' ' + word).trim().length <= 32) {
          currentLine += ' $word';
        } else {
          lines.add(currentLine.trim());
          currentLine = word;
        }
      }
      if (currentLine.isNotEmpty) {
        lines.add(currentLine.trim());
      }
      return lines;
    }

    // --- HACK #3: SEPARADOR PERFECTO DE 32 CARACTERES ---
    final separator = generator.text('--------------------------------');

    // Seleccionamos la tabla de caracteres que mejor soporte español.
    bytes += generator.setGlobalCodeTable('CP437');

    List<int> buildRow(String left, String right,
        {PosStyles? leftStyle, PosStyles? rightStyle}) {
      return generator.row([
        PosColumn(
            text: left,
            width: 5,
            styles: leftStyle ?? const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: right,
            width: 7,
            styles: rightStyle ?? const PosStyles(align: PosAlign.right)),
      ]);
    }

    // Componente para un bloque de texto justificado
    List<int> buildTextBlock(String text) {
      List<int> blockBytes = [];
      final words = text.split(' ');
      String currentLine = '';
      for (var word in words) {
        if ((currentLine + ' ' + word).trim().length > 32) {
          blockBytes += textToBytes(currentLine);
          currentLine = word;
        } else {
          currentLine += ' $word';
        }
      }
      if (currentLine.isNotEmpty) {
        blockBytes += textToBytes(currentLine.trim());
      }
      return blockBytes;
    }

    // --- SECCIÓN 1: ENCABEZADO INSTITUCIONAL ---
    final ByteData data =
        await rootBundle.load('assets/images/logo_muni_joya.png');
    final Uint8List assetBytes = data.buffer.asUint8List();
    final img.Image? image = img.decodeImage(assetBytes);
    if (image != null) {
      bytes += generator.image(image, align: PosAlign.center);
    }
    bytes += generator.feed(1);
    // SECCIÓN 1: ENCABEZADO
    bytes += textToBytes('MUNICIPALIDAD DISTRITAL DE LA JOYA',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += textToBytes('GERENCIA DE TRANSPORTE',
        styles: const PosStyles(align: PosAlign.center));
    bytes += separator;
    // SECCIÓN 2: TÍTULO DEL DOCUMENTO
    bytes += textToBytes('BOLETA DE FISCALIZACION',
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.feed(1);

    bytes += generator.text('ACTA DE CONTROL Nro 7003004138',
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += textToBytes('D.S. 017-2009-MTC',
        styles: const PosStyles(align: PosAlign.center));
    bytes += separator;

    // --- SECCIÓN 3: DETALLE DE LA INFRACCIÓN (CORREGIDO Y JUSTIFICADO) ---
    bytes += buildRow('F.1', 'Infraccion',
        leftStyle: const PosStyles(bold: true),
        rightStyle: const PosStyles(align: PosAlign.left, bold: true));
    bytes += generator.feed(1);
    bytes += buildTextBlock(
        'INFRACCION DE QUIEN REALIZA ACTIVIDAD DE TRANSPORTE SIN AUTORIZACION CON RESPONSABILIDAD SOLIDARIA DEL PROPIETARIO DEL VEHICULO. Prestar el servicio de transporte de personas, de mercancias o mixto, sin contar con autorizacion otorgada por la autoridad competente.');
    bytes += separator;
/*
    List<String> wrappedLines = wrapText(sanitize(infraccionText));
    for (var line in wrappedLines) {
      bytes +=
          generator.text(line, styles: const PosStyles(align: PosAlign.center));
    }
    bytes += separator;*/

    // --- SECCIÓN 4: DATOS DE LA INTERVENCIÓN (CON FILAS SIMÉTRICAS) ---
    bytes += buildRow('Fecha y Hora Ini.:',
        DateFormat('dd/MM/yy HH:mm').format(DateTime.now()));
    bytes += buildRow('Placa:', _placaController.text.toUpperCase());
    bytes += buildRow('Conductor:', _conductorController.text.toUpperCase());
    bytes += buildRow('N° Licencia:', _licenciaController.text.toUpperCase());
    bytes += buildRow('Empresa:', _empresaController.text.toUpperCase());
    bytes +=
        buildRow('Fiscalizador:', _fiscalizadorController.text.toUpperCase());
    bytes += separator;

    // SECCIÓN 4: DESCRIPCIÓN DE HECHOS Y OBSERVACIONES
    bytes += textToBytes('MOTIVO:', styles: const PosStyles(bold: true));
    bytes += buildTextBlock(_motivoController.text.isNotEmpty
        ? _motivoController.text
        : 'Ninguno.');
    bytes += generator.feed(1);

    bytes += textToBytes('CONFORME:', styles: const PosStyles(bold: true));
    bytes += buildTextBlock(_conformeSeleccionado ?? 'No especificado');
    bytes += generator.feed(1);

    bytes += textToBytes('OBSERVACIONES DEL INSPECTOR:',
        styles: const PosStyles(bold: true));
    bytes += buildTextBlock(_observacionesInspectorController.text.isNotEmpty
        ? _observacionesInspectorController.text
        : 'Ninguna.');
    bytes += separator;

    // SECCIÓN 5: CÓDIGO QR Y FIRMAS
    bytes += generator.feed(1);
    final String qrData =
        'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/verificarBoleta?id=$boletaId';
    bytes += generator.qrcode(qrData, size: QRSize.size4);
    bytes += textToBytes('Escanee para verificar boleta',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);

    bytes += textToBytes('_________________________',
        styles: const PosStyles(align: PosAlign.center));
    bytes += textToBytes('Firma del Conductor',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);

    bytes += textToBytes('_________________________',
        styles: const PosStyles(align: PosAlign.center));
    bytes += textToBytes('Firma del Inspector',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(3);

    bytes += generator.cut();

    return bytes;
  }

  // --- OPTIMIZACIÓN DE UI: Dividir el método build ---
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF181818), Color(0xFF8ECDF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Material(
              elevation: 12.0,
              borderRadius: BorderRadius.circular(28.0),
              color: grisOscuro,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderInfo(),
                    const SizedBox(height: 18),
                    const Divider(color: grisClaroDiia, thickness: 1.2),
                    const SizedBox(height: 18),
                    _buildPlacaField(),
                    const SizedBox(height: 20),
                    _buildEmpresaField(),
                    const SizedBox(height: 20),
                    _buildConductorField(),
                    const SizedBox(height: 20),
                    _buildLicenciaField(),
                    const SizedBox(height: 20),
                    _buildFechaHoraField(),
                    const SizedBox(height: 20),
                    _buildFiscalizadorField(),
                    const SizedBox(height: 20),
                    _buildMotivoField(),
                    const SizedBox(height: 20),
                    _buildConformeDropdown(),
                    const SizedBox(height: 20),
                    _buildDescripcionesField(),
                    const SizedBox(height: 20),
                    _buildObservacionesField(),
                    const SizedBox(height: 20),
                    _buildFotoButton(),
                    const SizedBox(height: 30),
                    _buildPdfButton(),
                    const SizedBox(height: 20),
                    _buildBotonFinalizar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.assignment_turned_in,
              color: azulClaroDiia, size: 32),
          const SizedBox(width: 10),
          Text(
            'Fiscalización',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: blancoDiia,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                  fontSize: 26,
                ),
          ),
        ],
      ),
      // --- HACK UX 2: Botón para limpiar el formulario ---
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep, color: azulClaroDiia),
          onPressed: _limpiarCampos,
          tooltip: 'Limpiar Formulario',
        ),
      ],
    );
  }

  Widget _buildHeaderInfo() {
    return Row(
      children: [
        const Icon(Icons.info_outline, color: celesteDiia, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Completa todos los campos con precisión',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: celesteDiia,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPlacaField() {
    return TextField(
      controller: _placaController,
      decoration: _decoracionCampo(
        label: 'Número de Placa',
        hint: 'Ejemplo: V1A-123',
        icon: Icons.directions_car_outlined,
      ),
      style: _estiloTextoCampo,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildEmpresaField() {
    return TextField(
      controller: _empresaController,
      decoration: _decoracionCampo(
        label: 'Nombre de la Empresa',
        hint: 'Ejemplo: Transportes Perú S.A.',
        icon: Icons.business_outlined,
      ),
      style: _estiloTextoCampo,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildConductorField() {
    return TextField(
      controller: _conductorController,
      decoration: _decoracionCampo(
        label: 'Nombre del Conductor',
        hint: 'Ejemplo: Juan Pérez Ramírez',
        icon: Icons.person_outline,
      ),
      style: _estiloTextoCampo,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildLicenciaField() {
    return TextField(
      controller: _licenciaController,
      decoration: _decoracionCampo(
        label: 'Número de Licencia',
        hint: 'Ejemplo: B1234567',
        icon: Icons.credit_card_outlined,
      ),
      style: _estiloTextoCampo,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildFechaHoraField() {
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined, color: celesteDiia),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Fecha y Hora: $_fechaHoraActual',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: blancoDiia,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: celesteDiia),
          onPressed: _actualizarFechaHora,
          tooltip: 'Actualizar Hora',
        ),
      ],
    );
  }

  Widget _buildFiscalizadorField() {
    return TextField(
      controller: _fiscalizadorController,
      decoration: _decoracionCampo(
        label: 'Código del Fiscalizador',
        hint: 'Ejemplo: FISC1234',
        icon: Icons.badge_outlined,
      ),
      style: _estiloTextoCampo,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildMotivoField() {
    return TextField(
      controller: _motivoController,
      decoration: _decoracionCampo(
        label: 'Motivo',
        hint: 'Ejemplo: Falta de documentos',
        icon: Icons.report_problem_outlined,
      ),
      style: _estiloTextoCampo,
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildConformeDropdown() {
    return DropdownButtonFormField<String>(
      value: _conformeSeleccionado,
      decoration: _decoracionCampo(
        label: 'Conforme',
        hint: 'Ejemplo: Sí / No',
        icon: Icons.check_circle_outline,
      ),
      items: _opcionesConforme.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value,
              style: const TextStyle(
                  color: blancoDiia,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _conformeSeleccionado = newValue;
        });
      },
    );
  }

  Widget _buildDescripcionesField() {
    return TextField(
      controller: _descripcionesController,
      decoration: _decoracionCampo(
        label: 'Descripciones',
        hint: 'Ejemplo: Vehículo sin SOAT',
        icon: Icons.description_outlined,
      ),
      style: _estiloTextoCampo,
      maxLines: 3,
    );
  }

  Widget _buildObservacionesField() {
    return TextField(
      controller: _observacionesInspectorController,
      decoration: _decoracionCampo(
        label: 'Observaciones del Inspector',
        hint: 'Ejemplo: El conductor mostró actitud colaborativa',
        icon: Icons.comment_outlined,
      ),
      style: _estiloTextoCampo,
      maxLines: 3,
    );
  }

  Widget _buildFotoButton() {
    return OutlinedButton.icon(
      icon: Icon(
          _fotoLicencia == null
              ? Icons.camera_alt_outlined
              : Icons.check_circle,
          color: celesteDiia),
      label: Text(
          _fotoLicencia == null ? 'Tomar Foto de Licencia' : 'Foto Capturada',
          style: const TextStyle(color: celesteDiia)),
      onPressed: _tomarFoto,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: celesteDiia),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _buildPdfButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Ver Boleta (PDF)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: celesteDiia, // Usa tu color personalizado
          side: const BorderSide(color: celesteDiia), // Usa tu color personalizado
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        // Asegúrate de que la función _mostrarPdf exista en tu clase
        onPressed: _mostrarPdf, 
      ),
    );
  }
  

  Widget _buildBotonFinalizar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: _isPrinting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: blancoDiia, strokeWidth: 2))
            : const Icon(Icons.print, color: blancoDiia),
        label: Text(_isPrinting ? 'Imprimiendo...' : 'Finalizar e Imprimir',
            style: const TextStyle(
                fontFamily: 'Inter Italic',
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        style: ElevatedButton.styleFrom(
          backgroundColor: rojoDiia,
          foregroundColor: blancoDiia,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 4,
        ),
        onPressed: _finalizarEImprimir,
      ),
    );
  }
}
