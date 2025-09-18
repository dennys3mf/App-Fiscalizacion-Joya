import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

// Tu paleta de colores personalizada
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
  final _licenciaController = TextEditingController(); // <-- NUEVO
  final _conductorController = TextEditingController(); // <-- NUEVO
  String _fechaHoraActual = "";
  String? _conformeSeleccionado;

  bool _isPrinting = false;

  @override
  void dispose() {
    _placaController.dispose();
    _empresaController.dispose();
    _fiscalizadorController.dispose();
    _motivoController.dispose();
    _descripcionesController.dispose();
    _observacionesInspectorController.dispose();
    _licenciaController.dispose(); // <-- NUEVO
    _conductorController.dispose(); // <-- NUEVO
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _actualizarFechaHora();
  }

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
    _fiscalizadorController.clear();
    _licenciaController.clear(); // <-- NUEVO
    _conductorController.clear(); // <-- NUEVO
    setState(() {
      _conformeSeleccionado = null;
      _fotoLicencia = null; // <-- NUEVO
    });
    _descripcionesController.clear();
    _observacionesInspectorController.clear();
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50, // Comprime la imagen para que no sea tan pesada
    );

    if (pickedFile != null) {
      setState(() {
        _fotoLicencia = File(pickedFile.path);
      });
    }
  }
  final TextStyle _estiloTextoCampo = const TextStyle(
    color: blancoDiia,
    fontFamily: 'Inter',
    fontSize: 16,
  );

  /// 📌 Método que decora los campos
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
      hintStyle: const TextStyle(
        color: grisClaroDiia,
        fontFamily: 'Inter',
      ),
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

// En lib/screens/fiscalizacion_form_screen.dart

  Future<void> _finalizarEImprimir() async {
    if (_isPrinting) return;
    setState(() {
      _isPrinting = true;
    });

    // 1. Validar campos
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
      // --- PASO CLAVE 1: GUARDAR EN FIRESTORE PRIMERO PARA OBTENER EL ID ---
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Usuario no autenticado.");

      final boletaData = {
        'placa': _placaController.text,
        'empresa': _empresaController.text,
        'numeroLicencia': _licenciaController.text, // <-- NUEVO
        'nombreConductor': _conductorController.text, // <-- NUEVO
        'codigoFiscalizador': _fiscalizadorController.text,
        'motivo': _motivoController.text,
        'conforme': _conformeSeleccionado ?? 'No especificado',
        'descripciones': _descripcionesController.text,
        'observaciones': _observacionesInspectorController.text,
        'fecha': FieldValue.serverTimestamp(),
        'inspectorId': user.uid,
        'inspectorEmail': user.email,
        'urlFotoLicencia': '', // Dejamos el campo listo
      };

      final docRef = await FirebaseFirestore.instance
          .collection('boletas')
          .add(boletaData);
      boletaId = docRef.id; // ¡Aquí obtenemos el ID único!

      String urlFotoLicencia = '';
      if (_fotoLicencia != null) {
        final ref = FirebaseStorage.instance.ref('licencias/$boletaId.jpg');
        await ref.putFile(_fotoLicencia!);
        urlFotoLicencia = await ref.getDownloadURL();
      }

      // 4. Actualizamos la boleta en Firestore con la URL de la foto
      if (urlFotoLicencia.isNotEmpty) {
        await docRef.update({'urlFotoLicencia': urlFotoLicencia});
      }

      // --- PASO CLAVE 2: CONECTAR E IMPRIMIR ---
      final bool connected =
          await PrintBluetoothThermal.connect(macPrinterAddress: printerId);
      if (connected) {
        // --- PASO CLAVE 3: PASAR EL ID A LA FUNCIÓN ---
        // Esta es la llamada corregida a la línea 119
        List<int> bytes = await _crearBoletaBytes(boletaId);

        const int chunkSize = 512;
        bool allChunksSent = true;
        for (int i = 0; i < bytes.length; i += chunkSize) {
          int end =
              (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
          List<int> chunk = bytes.sublist(i, end);

          final bool result = await PrintBluetoothThermal.writeBytes(chunk);
          if (!result) {
            allChunksSent = false;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 80));
        }

        if (mounted) {
          final message = allChunksSent
              ? 'Impresión y guardado exitosos'
              : 'Error al imprimir';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
          if (allChunksSent) _limpiarCampos();
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
    // <-- 1. AÑADIMOS EL PARÁMETRO AQUÍ
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Logo y Títulos
    final ByteData data =
        await rootBundle.load('assets/images/logo_muni_joya.png');
    final Uint8List assetBytes = data.buffer.asUint8List();
    final img.Image? image = img.decodeImage(assetBytes);
    if (image != null) {
      bytes += generator.image(image, align: PosAlign.center);
    }

    bytes += generator.text('BOLETA DE FISCALIZACION',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2));
    bytes += generator.text('MUNICIPALIDAD DE LA JOYA',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    // --- NUEVO ENCABEZADO ---
    bytes += generator.text('ACTA DE CONTROL N° 7003004138',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('D.S. 017-2009-MTC',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    bytes +=
        generator.text('F.1 Infraccion', styles: const PosStyles(bold: true));
    bytes += generator.text(
      'INFRACCIÓN DE QUIEN REALIZA ACTIVIDAD DE TRANSPORTE SIN AUTORIZACIÓN CON RESPONSABILIDAD SOLIDARIA DEL PROPIETARIO DEL VEHÍCULO. Prestar el servicio de transporte de personas, de mercancías o mixto, sin contar con autorización otorgada por la autoridad competente o utilizando una modalidad o ámbito distinto del autorizado.',
      styles: PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Quien subvencione la prestacion no autorizada incurrira en la misma infraccion...',
      styles: PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.hr();

    // Datos Principales
    bytes += generator.row([
      PosColumn(text: 'Fecha:', width: 4),
      PosColumn(
          text: DateFormat('dd/MM/yy HH:mm').format(DateTime.now()),
          width: 8,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Placa:', width: 4),
      PosColumn(
          text: _placaController.text.toUpperCase(),
          width: 8,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Conductor:', width: 5),
      PosColumn(
          text: _conductorController.text.toUpperCase(),
          width: 7,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'N Licencia:', width: 5),
      PosColumn(
          text: _licenciaController.text.toUpperCase(),
          width: 7,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Empresa:', width: 4),
      PosColumn(
          text: _empresaController.text.toUpperCase(),
          width: 8,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Fiscalizador:', width: 7),
      PosColumn(
          text: _fiscalizadorController.text.toUpperCase(),
          width: 5,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();
    bytes += generator.text('MOTIVO:', styles: const PosStyles(bold: true));
    bytes += generator.text(_motivoController.text, linesAfter: 1);
    bytes += generator.text('CONFORME:', styles: const PosStyles(bold: true));
    bytes += generator.text(_conformeSeleccionado ?? 'No especificado',
        linesAfter: 1);
    bytes +=
        generator.text('DESCRIPCIONES:', styles: const PosStyles(bold: true));
    bytes += generator.text(
        _descripcionesController.text.isNotEmpty
            ? _descripcionesController.text
            : 'Ninguna.',
        linesAfter: 1);
    bytes += generator.text('OBSERVACIONES DEL INSPECTOR:',
        styles: const PosStyles(bold: true));
    bytes += generator.text(_observacionesInspectorController.text.isNotEmpty
        ? _observacionesInspectorController.text
        : 'Ninguna.');
    bytes += generator.feed(2);

    // --- 2. CÓDIGO QR CORREGIDO ---
    // Usamos el boletaId que recibimos para crear la URL completa
    final String qrData =
        'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/verificarBoleta?id=$boletaId';

    bytes += generator.qrcode(qrData);
    bytes += generator.text('Escanee para verificar boleta',
        styles: const PosStyles(align: PosAlign.center));

    bytes += generator.feed(2);
    bytes += generator.text('___________________',
        styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Firma del Conductor',
        styles: const PosStyles(align: PosAlign.left));
    bytes += generator.feed(2);
    bytes += generator.text('------------------',
        styles: const PosStyles(align: PosAlign.right));
    bytes += generator.text('Firma Inspector',
        styles: const PosStyles(align: PosAlign.right));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.assignment_turned_in,
                  color: azulClaroDiia, size: 32),
              const SizedBox(width: 10),
              Text(
                'Fiscalización',
                style: textTheme.headlineMedium?.copyWith(
                  color: blancoDiia,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                  fontSize: 26,
                ),
              ),
            ],
          ),
          centerTitle: false,
        ),
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: celesteDiia, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Completa todos los campos con precisión',
                            style: textTheme.bodyLarge?.copyWith(
                              color: celesteDiia,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: grisClaroDiia, thickness: 1.2),
                    const SizedBox(height: 18),

                    // 🚗 Placa
                    TextField(
                      controller: _placaController,
                      decoration: _decoracionCampo(
                        label: 'Número de Placa',
                        hint: 'Ejemplo: V1A-123',
                        icon: Icons.directions_car_outlined,
                      ),
                      style: _estiloTextoCampo,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    // 🏢 Empresa
                    TextField(
                      controller: _empresaController,
                      decoration: _decoracionCampo(
                        label: 'Nombre de la Empresa',
                        hint: 'Ejemplo: Transportes Perú S.A.',
                        icon: Icons.business_outlined,
                      ),
                      style: _estiloTextoCampo,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    // 👤 Nombre del Conductor
                    TextField(
                      controller: _conductorController,
                      decoration: _decoracionCampo(
                        label: 'Nombre del Conductor',
                        hint: 'Ejemplo: Juan Pérez Ramírez',
                        icon: Icons.person_outline,
                      ),
                      style: _estiloTextoCampo,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    // 🔑 Nro. Licencia
                    TextField(
                      controller: _licenciaController,
                      decoration: _decoracionCampo(
                        label: 'Número de Licencia',
                        hint: 'Ejemplo: B1234567',
                        icon: Icons.credit_card_outlined,
                      ),
                      style: _estiloTextoCampo,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    

                    // 📅 Fecha y hora
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: celesteDiia),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Fecha y Hora: $_fechaHoraActual',
                              style: textTheme.bodyLarge?.copyWith(
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
                    ),
                    const SizedBox(height: 20),

                    // 👮 Fiscalizador
                    TextField(
                      controller: _fiscalizadorController,
                      decoration: _decoracionCampo(
                        label: 'Código del Fiscalizador',
                        hint: 'Ejemplo: FISC1234',
                        icon: Icons.badge_outlined,
                      ),
                      style: _estiloTextoCampo,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    // ❗ Motivo
                    TextField(
                      controller: _motivoController,
                      decoration: _decoracionCampo(
                        label: 'Motivo',
                        hint: 'Ejemplo: Falta de documentos',
                        icon: Icons.report_problem_outlined,
                      ),
                      style: _estiloTextoCampo,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),

                    // ✅ Conforme
                    DropdownButtonFormField<String>(
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
                    ),
                    const SizedBox(height: 20),

                    // 📝 Descripciones
                    TextField(
                      controller: _descripcionesController,
                      decoration: _decoracionCampo(
                        label: 'Descripciones',
                        hint: 'Ejemplo: Vehículo sin SOAT',
                        icon: Icons.description_outlined,
                      ),
                      style: _estiloTextoCampo,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // 💬 Observaciones
                    TextField(
                      controller: _observacionesInspectorController,
                      decoration: _decoracionCampo(
                        label: 'Observaciones del Inspector',
                        hint:
                            'Ejemplo: El conductor mostró actitud colaborativa',
                        icon: Icons.comment_outlined,
                      ),
                      style: _estiloTextoCampo,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // 📸 Foto de Licencia
                    Row(
                      children: [
                        OutlinedButton.icon(
                    icon: Icon(_fotoLicencia == null ? Icons.camera_alt_outlined : Icons.check_circle, color: celesteDiia),
                          label: Text(_fotoLicencia == null ? 'Tomar Foto de Licencia' : 'Foto Capturada', style: TextStyle(color: celesteDiia)),
                          onPressed: _tomarFoto,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: celesteDiia),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                      ],
                    ),

                    // 🔴 Botón Finalizar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: blancoDiia, strokeWidth: 2))
                            : const Icon(Icons.print, color: blancoDiia),
                        label: Text(
                            _isPrinting
                                ? 'Imprimiendo...'
                                : 'Finalizar e Imprimir',
                            style: const TextStyle(
                                fontFamily: 'Inter Italic',
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rojoDiia,
                          foregroundColor: blancoDiia,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 4,
                        ),
                        onPressed: _finalizarEImprimir,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
