import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

// NOTA: Se eliminó el import conflictivo de 'esc_pos_utils_plus'
// ya que 'print_bluetooth_thermal' ya provee estas herramientas.

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
  final _descripcionesController = TextEditingController();
  final _observacionesInspectorController = TextEditingController();
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
    setState(() {
      _conformeSeleccionado = null;
    });
    _descripcionesController.clear();
    _observacionesInspectorController.clear();
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
        'codigoFiscalizador': _fiscalizadorController.text,
        'motivo': _motivoController.text,
        'conforme': _conformeSeleccionado ?? 'No especificado',
        'descripciones': _descripcionesController.text,
        'observaciones': _observacionesInspectorController.text,
        'fecha': FieldValue.serverTimestamp(),
        'inspectorId': user.uid,
        'inspectorEmail': user.email,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('boletas')
          .add(boletaData);
      boletaId = docRef.id; // ¡Aquí obtenemos el ID único!

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
    bytes += generator.text('------------------',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Firma Inspector',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    // Tu nuevo y excelente diseño visual se mantiene intacto
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
                      // ignore: deprecated_member_use
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
                    TextField(
                      controller: _placaController,
                      decoration: InputDecoration(
                        labelText: 'Número de Placa',
                        hintText: 'Ejemplo: V1A-123',
                        labelStyle: const TextStyle(
                            color: blancoDiia,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.directions_car_outlined,
                            color: azulClaroDiia),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: celesteDiia)),
                        filled: true,
                        fillColor: fondoNegro,
                        hintStyle: const TextStyle(
                            color: grisClaroDiia, fontFamily: 'Inter'),
                      ),
                      style: const TextStyle(
                          color: blancoDiia, fontFamily: 'Inter', fontSize: 16),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _empresaController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la Empresa',
                        hintText: 'Ejemplo: Transportes Perú S.A.',
                        labelStyle: const TextStyle(
                            color: blancoDiia,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.business_outlined,
                            color: azulClaroDiia),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: celesteDiia)),
                        filled: true,
                        fillColor: fondoNegro,
                        hintStyle: const TextStyle(
                            color: grisClaroDiia, fontFamily: 'Inter'),
                      ),
                      style: const TextStyle(
                          color: blancoDiia, fontFamily: 'Inter', fontSize: 16),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
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
                    TextField(
                      controller: _fiscalizadorController,
                      decoration: InputDecoration(
                        labelText: 'Código del Fiscalizador',
                        hintText: 'Ejemplo: FISC1234',
                        labelStyle: const TextStyle(
                            color: blancoDiia,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.badge_outlined,
                            color: azulClaroDiia),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: celesteDiia)),
                        filled: true,
                        fillColor: fondoNegro,
                        hintStyle: const TextStyle(
                            color: grisClaroDiia, fontFamily: 'Inter'),
                      ),
                      style: const TextStyle(
                          color: blancoDiia, fontFamily: 'Inter', fontSize: 16),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _motivoController,
                      decoration: InputDecoration(
                        labelText: 'Motivo',
                        hintText: 'Ejemplo: Falta de documentos',
                        labelStyle: const TextStyle(
                            color: blancoDiia,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.report_problem_outlined,
                            color: azulClaroDiia),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: celesteDiia)),
                        filled: true,
                        fillColor: fondoNegro,
                        hintStyle: const TextStyle(
                            color: grisClaroDiia, fontFamily: 'Inter'),
                      ),
                      style: const TextStyle(
                          color: blancoDiia, fontFamily: 'Inter', fontSize: 16),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _conformeSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Conforme',
                        hintText: 'Ejemplo: Sí / No',
                        labelStyle: const TextStyle(
                            color: blancoDiia,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.check_circle_outline,
                            color: celesteDiia),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: celesteDiia)),
                        filled: true,
                        fillColor: fondoNegro,
                        hintStyle: const TextStyle(
                            color: grisClaroDiia, fontFamily: 'Inter'),
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
                    TextField(
                      controller: _descripcionesController,
                      decoration: InputDecoration(
                        labelText: 'Descripciones',
                        hintText: 'Ejemplo: Vehículo sin SOAT',
                        labelStyle: const TextStyle(
                            color: blancoDiia,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.description_outlined,
                            color: azulClaroDiia),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: celesteDiia)),
                        filled: true,
                        fillColor: fondoNegro,
                        hintStyle: const TextStyle(
                            color: grisClaroDiia, fontFamily: 'Inter'),
                      ),
                      style: const TextStyle(
                          color: blancoDiia, fontFamily: 'Inter', fontSize: 16),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _observacionesInspectorController,
                      decoration: InputDecoration(
                        labelText: 'Observaciones del Inspector',
                        hintText:
                            'Ejemplo: El conductor mostró actitud colaborativa',
                        labelStyle: const TextStyle(
                            color: blancoDiia,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold),
                        prefixIcon: const Icon(Icons.comment_outlined,
                            color: azulClaroDiia),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: celesteDiia)),
                        filled: true,
                        fillColor: fondoNegro,
                        hintStyle: const TextStyle(
                            color: grisClaroDiia, fontFamily: 'Inter'),
                      ),
                      style: const TextStyle(
                          color: blancoDiia, fontFamily: 'Inter', fontSize: 16),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    const Divider(color: celesteDiia, thickness: 1.2),
                    const SizedBox(height: 18),
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
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rojoDiia,
                          foregroundColor: blancoDiia,
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.bold, fontFamily: 'Inter'),
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
