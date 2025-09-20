import 'dart:io';
import 'package:app_fiscalizacion/models/boleta_model.dart';
import 'package:app_fiscalizacion/services/print_service.dart';
import 'package:app_fiscalizacion/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FiscalizacionFormScreen extends StatefulWidget {
  final VoidCallback onBack;

  const FiscalizacionFormScreen({super.key, required this.onBack});

  @override
  State<FiscalizacionFormScreen> createState() =>
      _FiscalizacionFormScreenState();
}

class _FiscalizacionFormScreenState extends State<FiscalizacionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placaController = TextEditingController();
  final _empresaController = TextEditingController();
  final _fiscalizadorController = TextEditingController();
  final _motivoController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _licenciaController = TextEditingController();
  final _conductorController = TextEditingController();
  final _descripcionesController = TextEditingController();

  final List<String> _opcionesConforme = ['Sí', 'No', 'Parcialmente'];
  File? _fotoLicencia;
  String? _conformeSeleccionado;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosFiscalizador();
  }

  @override
  void dispose() {
    _placaController.dispose();
    _empresaController.dispose();
    _fiscalizadorController.dispose();
    _motivoController.dispose();
    _observacionesController.dispose();
    _licenciaController.dispose();
    _conductorController.dispose();
    _descripcionesController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE NEGOCIO ---

  Future<void> _cargarDatosFiscalizador() async {
    final prefs = await SharedPreferences.getInstance();
    final codigo = prefs.getString('codigo_fiscalizador');
    if (codigo != null && mounted) {
      setState(() {
        _fiscalizadorController.text = codigo;
      });
    }
  }

  Future<void> _guardarDatosFiscalizador() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('codigo_fiscalizador', _fiscalizadorController.text);
  }

  Future<void> _limpiarCampos() async {
    _formKey.currentState?.reset();
    _placaController.clear();
    _empresaController.clear();
    _motivoController.clear();
    _licenciaController.clear();
    _conductorController.clear();
    _observacionesController.clear();
    _descripcionesController.clear();
    setState(() {
      _conformeSeleccionado = null;
      _fotoLicencia = null;
    });
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (pickedFile == null) return;

    final imageBytes = await pickedFile.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) return;

    final resizedImage = img.copyResize(image, width: 800);
    final resizedBytes = img.encodeJpg(resizedImage, quality: 85);
    final tempDir = await getTemporaryDirectory();
    final tempPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final resizedFile = File(tempPath)..writeAsBytesSync(resizedBytes);

    if (mounted) {
      setState(() => _fotoLicencia = resizedFile);
    }
  }

  Future<void> _finalizarEImprimir() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Por favor, complete todos los campos obligatorios.')),
      );
      return;
    }
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error: Usuario no autenticado.'),
            backgroundColor: Colors.red),
      );
      setState(() => _isProcessing = false);
      return;
    }

    try {
      await _guardarDatosFiscalizador();

      final boleta = BoletaModel(
        id: '',
        placa: _placaController.text.trim().toUpperCase(),
        empresa: _empresaController.text.trim(),
        numeroLicencia: _licenciaController.text.trim(),
        conductor: _conductorController.text.trim(),
        codigoFiscalizador: _fiscalizadorController.text.trim(),
        motivo: _motivoController.text.trim(),
        conforme: _conformeSeleccionado!,
        descripciones: _descripcionesController.text.trim(),
        observaciones: _observacionesController.text.trim(),
        inspectorId: user.uid,
        inspectorEmail: user.email,
        fecha: DateTime.now(),
      );

      final docRef = await FirebaseFirestore.instance
          .collection('boletas')
          .add(boleta.toFirestore());

      String? url;
      if (_fotoLicencia != null) {
        final ref = FirebaseStorage.instance.ref('licencias/${docRef.id}.jpg');
        await ref.putFile(_fotoLicencia!);
        url = await ref.getDownloadURL();
        await docRef.update({'urlFotoLicencia': url});
      }

      final boletaFinal = BoletaModel(
        id: docRef.id,
        placa: boleta.placa,
        empresa: boleta.empresa,
        numeroLicencia: boleta.numeroLicencia,
        conductor: boleta.conductor,
        codigoFiscalizador: boleta.codigoFiscalizador,
        motivo: boleta.motivo,
        conforme: boleta.conforme,
        descripciones: boleta.descripciones,
        observaciones: boleta.observaciones,
        inspectorId: boleta.inspectorId,
        inspectorEmail: boleta.inspectorEmail,
        fecha: boleta.fecha,
        urlFotoLicencia: url,
      );

      await PrintService.printBoleta(boletaFinal);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fiscalización completada e impresa exitosamente.'),
            backgroundColor: Colors.green),
      );
      await _limpiarCampos();
    } catch (e) {
      // --- MEJORA EN EL MANEJO DE ERRORES ---
      // Si el error es de conexión, mostramos un diálogo útil.
      if (e.toString().contains('No se pudo conectar')) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error de Impresión'),
            content: const Text(
                'No se pudo conectar a la impresora. Por favor, verifica que esté encendida, vinculada por Bluetooth y seleccionada en "Configurar Impresora".'),
            actions: [
              TextButton(
                child: const Text('Ir a Configuración'),
                onPressed: () {
                  Navigator.of(context).pop(); // Cierra el diálogo
                  Navigator.pushNamed(
                      context, '/impresoras'); // Va a la pantalla de impresoras
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      } else {
        // Para otros errores, mostramos el mensaje genérico.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al procesar: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // --- WIDGETS DE LA UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: const Text('Formulario de Fiscalización'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _limpiarCampos,
            tooltip: 'Limpiar Formulario',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildVehicleCard(),
                const SizedBox(height: 16),
                _buildDriverCard(),
                const SizedBox(height: 16),
                _buildInspectionCard(),
                const SizedBox(height: 24),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryRed),
          ),
          const SizedBox(width: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Column(
        children: [
          _buildCardHeader(
              'Información General', Icons.assignment_ind_outlined),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: AppTheme.primaryRed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fecha y Hora Actual',
                                style: TextStyle(
                                    color: AppTheme.mutedForeground,
                                    fontSize: 12)),
                            Text(
                                DateFormat('dd/MM/yyyy HH:mm:ss', 'es_PE')
                                    .format(DateTime.now()),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fiscalizadorController,
                  decoration: const InputDecoration(
                    labelText: 'Código del Fiscalizador *',
                    hintText: 'FISC1234',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) =>
                      value!.isEmpty ? 'Campo requerido' : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard() {
    return Card(
      child: Column(
        children: [
          _buildCardHeader('Datos del Vehículo', Icons.directions_car_outlined),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextFormField(
                  controller: _placaController,
                  decoration: const InputDecoration(
                      labelText: 'Número de Placa *', hintText: 'V1A-123'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) =>
                      value!.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _empresaController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Empresa *',
                    hintText: 'Transportes Perú S.A.',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      value!.isEmpty ? 'Campo requerido' : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    return Card(
      child: Column(
        children: [
          _buildCardHeader('Información del Conductor', Icons.person_outline),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextFormField(
                  controller: _conductorController,
                  decoration: const InputDecoration(
                      labelText: 'Nombre Completo del Conductor *',
                      hintText: 'Juan Pérez Ramírez'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      value!.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _licenciaController,
                        decoration: const InputDecoration(
                            labelText: 'Número de Licencia *',
                            hintText: 'B1234567'),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) =>
                            value!.isEmpty ? 'Campo requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _tomarFoto,
                      icon: Icon(_fotoLicencia == null
                          ? Icons.camera_alt_outlined
                          : Icons.check_circle),
                      color: _fotoLicencia == null
                          ? AppTheme.mutedForeground
                          : Colors.green,
                      tooltip: 'Tomar foto de licencia',
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionCard() {
    return Card(
      child: Column(
        children: [
          _buildCardHeader(
              'Detalles de la Fiscalización', Icons.warning_amber_outlined),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextFormField(
                  controller: _motivoController,
                  decoration: const InputDecoration(
                      labelText: 'Motivo *',
                      hintText: 'Falta de documentos, exceso de velocidad...'),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      value!.isEmpty ? 'Campo requerido' : null,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _conformeSeleccionado,
                  decoration: const InputDecoration(
                      labelText: '¿Conforme? *',
                      prefixIcon: Icon(Icons.check_circle_outline)),
                  items: _opcionesConforme
                      .map((opcion) =>
                          DropdownMenuItem(value: opcion, child: Text(opcion)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _conformeSeleccionado = value),
                  validator: (value) =>
                      value == null ? 'Seleccione una opción' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionesController,
                  decoration: const InputDecoration(
                      labelText: 'Descripciones Adicionales',
                      hintText: 'Vehículo sin SOAT, etc.'),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _observacionesController,
                  decoration: const InputDecoration(
                      labelText: 'Observaciones del Inspector',
                      hintText: 'El conductor mostró actitud colaborativa...'),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.print_outlined),
          label: Text(_isProcessing ? 'Procesando...' : 'Finalizar e Imprimir'),
          onPressed: _finalizarEImprimir,
        ),
      ],
    );
  }
}
