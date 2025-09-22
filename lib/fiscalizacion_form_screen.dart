import 'dart:io';
import 'package:app_fiscalizacion/models/boleta_model.dart';
import 'package:app_fiscalizacion/models/user_model.dart'; // <-- MEJORA: Importamos el modelo de usuario
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
  final _multaController = TextEditingController();
  String _estadoBoletaSeleccionado = 'Activa';

  final List<String> _opcionesConforme = ['Sí', 'No', 'Parcialmente'];
  File? _fotoLicencia;
  String? _conformeSeleccionado;
  bool _isProcessing = false;

  // --- MEJORA: Lógica para obtener y guardar los datos del usuario actual ---
  UserModel? _currentUser;
  bool _isLoading = true;
  // --- FIN DE LA MEJORA ---

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

  // --- MEJORA: La lógica ahora carga el perfil completo desde Firestore ---
  Future<void> _cargarDatosFiscalizador() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _currentUser = UserModel.fromMap(doc.data()!);
          _fiscalizadorController.text =
              _currentUser?.codigoFiscalizador ?? 'SIN CÓDIGO';
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // --- FIN DE LA MEJORA ---

  // La función _guardarDatosFiscalizador ya no es necesaria, la podemos eliminar.

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
    // Volvemos a poner el código del fiscalizador que no debe borrarse
    _fiscalizadorController.text =
        _currentUser?.codigoFiscalizador ?? 'SIN CÓDIGO';
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
    // --- MEJORA: Usamos el perfil del usuario que ya hemos cargado ---
    if (user == null || _currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error: No se pudo cargar el perfil del usuario.'),
            backgroundColor: Colors.red),
      );
      setState(() => _isProcessing = false);
      return;
    }
    // --- FIN DE LA MEJORA ---

    try {
      final boleta = BoletaModel(
        id: '',
        placa: _placaController.text.trim().toUpperCase(),
        empresa: _empresaController.text.trim(),
        numeroLicencia: _licenciaController.text.trim(),
        conductor: _conductorController.text.trim(),
        // --- MEJORA: Guardamos los datos correctos del inspector ---
        codigoFiscalizador: _currentUser!.codigoFiscalizador ?? 'N/A',
        inspectorNombre: _currentUser!.nombreCompleto,
        // --- FIN DE LA MEJORA ---
        motivo: _motivoController.text.trim(),
        conforme: _conformeSeleccionado!,
        descripciones: _descripcionesController.text.trim(),
        observaciones: _observacionesController.text.trim(),
        //inspectorId: user.uid,
        inspectorId: _currentUser!.nombreCompleto,
        multa: double.tryParse(_multaController.text) ?? 0.0,
        estado: _estadoBoletaSeleccionado,
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

      final boletaFinal = boleta.copyWith(id: docRef.id, urlFotoLicencia: url);

      await PrintService.printBoleta(boletaFinal);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fiscalización completada e impresa exitosamente.'),
            backgroundColor: Colors.green),
      );
      await _limpiarCampos();
    } catch (e) {
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
                  Navigator.of(context).pop();
                  Navigator.pushNamed(context, '/impresoras');
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
      // --- MEJORA: Mostramos un indicador de carga mientras se obtienen los datos del inspector ---
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRed))
          : Container(
              // --- FIN DE LA MEJORA ---
              decoration:
                  const BoxDecoration(gradient: AppTheme.backgroundGradient),
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
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
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
                            const Text('Fecha y Hora Actual',
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
                // --- MEJORA: Campo de código de fiscalizador automático y de solo lectura ---
                TextFormField(
                  controller: _fiscalizadorController,
                  readOnly: true, // El inspector no puede cambiar su código
                  decoration: InputDecoration(
                    labelText: 'Código del Fiscalizador',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    filled: true,
                    fillColor: Colors.grey
                        .shade200, // Color de fondo para indicar que no es editable
                  ),
                ),
                // --- FIN DE LA MEJORA ---
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ... (El resto de los widgets _buildVehicleCard, _buildDriverCard, etc. se mantienen igual)

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
                  controller: _multaController,
                  decoration: const InputDecoration(
                    labelText: 'Monto de Multa (S/)',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _estadoBoletaSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Estado de la Boleta',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: ['Activa', 'Pagada', 'Anulada']
                      .map((estado) =>
                          DropdownMenuItem(value: estado, child: Text(estado)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _estadoBoletaSeleccionado = value;
                      });
                    }
                  },
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
