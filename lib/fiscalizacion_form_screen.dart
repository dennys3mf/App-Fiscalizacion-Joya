import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/boleta_model.dart';
import '../models/user_model.dart';
import '../services/print_service.dart';
import '../services/camera_service.dart';
// import '../widgets/image_preview_widget.dart' hide ImagePreviewWidget;

class FiscalizacionFormScreen extends StatefulWidget {
  final UserModel currentUser;

  const FiscalizacionFormScreen({super.key, required this.currentUser});

  @override
  State<FiscalizacionFormScreen> createState() => _FiscalizacionFormScreenState();
}

class _FiscalizacionFormScreenState extends State<FiscalizacionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placaController = TextEditingController();
  final _conductorController = TextEditingController();
  final _licenciaController = TextEditingController();
  final _empresaController = TextEditingController();
  final _motivoController = TextEditingController();
  final _descripcionesController = TextEditingController(); // ✅ NUEVO: Campo descripciones
  final _observacionesController = TextEditingController();
  final _multaController = TextEditingController();
  
  String _conforme = 'No';
  String _estado = 'Activa';
  bool _isLoading = false;
  String? _urlFotoLicencia; // ✅ NUEVO: URL de la foto de licencia
  DateTime _fechaHora = DateTime.now();

  final List<String> _conformeOptions = ['Sí', 'No', 'Parcial'];
  final List<String> _estadoOptions = ['Activa', 'Pagada', 'Anulada'];

  @override
  void initState() {
    super.initState();
    // Actualizar la fecha y hora cada minuto
    _updateDateTime();
  }

  void _updateDateTime() {
    if (mounted) {
      setState(() {
        _fechaHora = DateTime.now();
      });
      // Programar la siguiente actualización
      Future.delayed(const Duration(minutes: 1), _updateDateTime);
    }
  }

  @override
  void dispose() {
    _placaController.dispose();
    _conductorController.dispose();
    _licenciaController.dispose();
    _empresaController.dispose();
    _motivoController.dispose();
    _descripcionesController.dispose(); // ✅ NUEVO: Dispose del campo descripciones
    _observacionesController.dispose();
    _multaController.dispose();
    super.dispose();
  }

  Future<void> _guardarBoleta() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      
      final boleta = BoletaModel(
        id: '', // Se asignará automáticamente por Firestore
        placa: _placaController.text.trim().toUpperCase(),
        conductor: _conductorController.text.trim(),
        numeroLicencia: _licenciaController.text.trim(),
        empresa: _empresaController.text.trim(),
        motivo: _motivoController.text.trim(),
        conforme: _conforme.isEmpty ? null : _conforme,
        observaciones: _observacionesController.text.trim().isEmpty 
            ? null 
            : _observacionesController.text.trim(),
        fecha: now,
        inspectorId: widget.currentUser.uid,
        inspectorEmail: widget.currentUser.email,
        inspectorNombre: widget.currentUser.name,
        codigoFiscalizador: widget.currentUser.code,
        estado: _estado,
        multa: _multaController.text.trim().isEmpty 
            ? null 
            : double.tryParse(_multaController.text.trim()),
        descripciones: _descripcionesController.text.trim().isEmpty // ✅ CORREGIDO: Campo separado
            ? null 
            : _descripcionesController.text.trim(),
        urlFotoLicencia: _urlFotoLicencia, nombreConductor: '', // ✅ NUEVO: URL de la foto de licencia
      );

      // Guardar en Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('boletas')
          .add(boleta.toFirestore());

      // Actualizar el ID de la boleta
      final boletaConId = boleta.copyWith(id: docRef.id);

      setState(() => _isLoading = false);

      if (mounted) {
        // Mostrar diálogo de éxito con opciones
        _showPrintOptions(boletaConId);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPrintOptions(BoletaModel boleta) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de éxito
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade200, width: 2),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 40,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Título
              const Text(
                'Boleta Guardada',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D29),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Subtítulo
              const Text(
                '¿Qué deseas hacer ahora?',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Botones principales
              Row(
                children: [
                  // Botón PDF
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          // TODO: Implementar generación de PDF
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Función PDF en desarrollo'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                        label: const Text(
                          'PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Botón Imprimir
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC143C), Color(0xFFB91C1C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC143C).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _imprimirBoleta(boleta);
                        },
                        icon: const Icon(Icons.print, color: Colors.white),
                        label: const Text(
                          'Imprimir',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Botones secundarios
              Row(
                children: [
                  // Botón Crear Nueva
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _limpiarFormulario();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Crear Nueva\nBoleta',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Botón Cerrar
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cerrar',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _imprimirBoleta(BoletaModel boleta) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enviando a impresora...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      await PrintService.printBoleta(boleta);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impresión enviada correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al imprimir: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _limpiarFormulario() {
    _formKey.currentState?.reset();
    _placaController.clear();
    _conductorController.clear();
    _licenciaController.clear();
    _empresaController.clear();
    _motivoController.clear();
    _descripcionesController.clear(); // ✅ NUEVO: Limpiar descripciones
    _observacionesController.clear();
    _multaController.clear();
    setState(() {
      _conforme = 'No';
      _estado = 'Activa';
      _urlFotoLicencia = null; // ✅ NUEVO: Limpiar foto de licencia
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Fiscalización'),
        backgroundColor: const Color.fromARGB(255, 5, 5, 5),
        foregroundColor: const Color(0xFF1A1D29),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _limpiarFormulario,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Limpiar formulario',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 19, 13, 13), Color.fromARGB(255, 39, 17, 17)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarjeta del inspector
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8ECDF7), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_pin,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '👤 Inspector de Fiscalización',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nombre: ${widget.currentUser.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Código: ${widget.currentUser.code}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd/MM/yy HH:mm').format(_fechaHora),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Sección: Datos del Vehículo
                _buildSectionHeader('🚗 Datos del Vehículo', const Color(0xFF059669)),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _placaController,
                  decoration: const InputDecoration(
                    labelText: 'Placa del Vehículo',
                    hintText: 'Ej: ABC-123',
                    prefixIcon: Icon(Icons.directions_car),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'La placa es obligatoria';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _empresaController,
                  decoration: const InputDecoration(
                    labelText: 'Empresa de Transporte',
                    hintText: 'Nombre de la empresa',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'La empresa es obligatoria';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Sección: Datos del Conductor
                _buildSectionHeader('👤 Datos del Conductor', const Color(0xFF7C3AED)),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _conductorController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Conductor',
                    hintText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre del conductor es obligatorio';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _licenciaController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Licencia',
                    hintText: 'Número de licencia de conducir',
                    prefixIcon: Icon(Icons.credit_card),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El número de licencia es obligatorio';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Sección: Detalles de la Fiscalización
                _buildSectionHeader('📋 Detalles de la Fiscalización', const Color(0xFFDC143C)),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo de la Fiscalización',
                    hintText: 'Describe el motivo',
                    prefixIcon: Icon(Icons.assignment),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El motivo es obligatorio';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ✅ NUEVO: Campo Descripciones
                TextFormField(
                  controller: _descripcionesController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción Detallada',
                    hintText: 'Descripción específica de la infracción o situación',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'La descripción es obligatoria';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // ✅ NUEVO: Sección de Foto de Licencia
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.camera_alt, color: Color(0xFFDC143C)),
                          const SizedBox(width: 8),
                          const Text(
                            'Foto de Licencia',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1D29),
                            ),
                          ),
                          const Spacer(),
                          if (_urlFotoLicencia == null)
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _capturarFotoLicencia,
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: const Text('Capturar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC143C),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: const Size(0, 36),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ImagePreviewWidget(
                        imageUrl: _urlFotoLicencia,
                        onRetake: _isLoading ? null : _capturarFotoLicencia,
                        onRemove: _isLoading ? null : _eliminarFotoLicencia,
                      ),
                      if (_urlFotoLicencia == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Opcional: Captura una foto de la licencia del conductor para adjuntar a la boleta.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Estado de Conformidad
                DropdownButtonFormField<String>(
                  value: _conforme,
                  decoration: const InputDecoration(
                    labelText: 'Estado de Conformidad',
                    prefixIcon: Icon(Icons.check_circle),
                    border: OutlineInputBorder(),
                  ),
                  items: _conformeOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _conforme = newValue);
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Estado de la Boleta
                DropdownButtonFormField<String>(
                  value: _estado,
                  decoration: const InputDecoration(
                    labelText: 'Estado de la Boleta',
                    prefixIcon: Icon(Icons.flag),
                    border: OutlineInputBorder(),
                  ),
                  items: _estadoOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _estado = newValue);
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Observaciones (opcional)
                TextFormField(
                  controller: _observacionesController,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (Opcional)',
                    hintText: 'Observaciones adicionales',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                
                const SizedBox(height: 16),
                
                // Multa (opcional)
                TextFormField(
                  controller: _multaController,
                  decoration: const InputDecoration(
                    labelText: 'Multa (Opcional)',
                    hintText: 'Monto de la multa en soles',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 32),

                // Botón de guardar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDC143C), Color(0xFFB91C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC143C).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _guardarBoleta,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        _isLoading ? 'Guardando...' : '💾 Guardar Boleta',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Función para capturar foto de licencia
  Future<void> _capturarFotoLicencia() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Generar un ID temporal para la boleta (se usará para nombrar la imagen)
      final String tempBoletaId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final String? urlFoto = await CameraService.capturarFotoLicencia(
        boletaId: tempBoletaId,
        context: context,
      );

      if (urlFoto != null && mounted) {
        setState(() {
          _urlFotoLicencia = urlFoto;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Foto de licencia capturada exitosamente'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error al capturar foto: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ NUEVO: Función para eliminar foto de licencia
  Future<void> _eliminarFotoLicencia() async {
    if (_urlFotoLicencia == null || _isLoading) return;

    // Mostrar confirmación
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Eliminar Foto'),
        content: const Text('¿Estás seguro de que deseas eliminar la foto de la licencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);

    try {
      // Eliminar de Firebase Storage
      if (_urlFotoLicencia != null) {
        await CameraService.eliminarFotoLicencia(_urlFotoLicencia!);
      }

      setState(() {
        _urlFotoLicencia = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Foto eliminada exitosamente'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error al eliminar foto: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
