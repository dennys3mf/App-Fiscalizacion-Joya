import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/boleta_model.dart';
import '../services/print_service.dart';

class HistorialScreen extends StatefulWidget {
  final VoidCallback onBack;

  const HistorialScreen({super.key, required this.onBack});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  late AnimationController _refreshAnimationController;

  // ✅ COLORES SEGUROS: Definidos directamente sin dependencias
  static const Color primaryRed = Color(0xFFDC143C);
  static const Color backgroundLight = Color.fromARGB(211, 7, 7, 7);
  static const Color foregroundDark = Color.fromARGB(255, 82, 79, 79);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color mutedGray = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  void _refreshData() {
    _refreshAnimationController.forward().then((_) {
      _refreshAnimationController.reset();
    });
    setState(() {});
  }

  // ✅ CORREGIDO: Función segura para manejar valores null
  Widget _getConformeWidget(String? conforme) {
    final conformeValue = conforme?.trim() ?? 'No especificado';
    
    Color color;
    IconData icon;
    String text;

    switch (conformeValue.toLowerCase()) {
      case 'sí':
      case 'si':
        color = Colors.green.shade600;
        icon = Icons.check_circle;
        text = 'Conforme';
        break;
      case 'no':
        color = primaryRed;
        icon = Icons.cancel;
        text = 'No Conforme';
        break;
      case 'parcial':
      case 'parcialmente':
        color = Colors.orange.shade600;
        icon = Icons.warning;
        text = 'Parcial';
        break;
      default:
        color = mutedForeground;
        icon = Icons.help;
        text = conformeValue.isEmpty ? 'No especificado' : conformeValue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ OPTIMIZACIÓN: Función segura y optimizada para convertir datos
  BoletaModel _safeBoletaFromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Documento sin datos');
      }
      
      data['id'] = doc.id;
      return BoletaModel.fromMap(data);
    } catch (e) {
      // Crear boleta con datos por defecto en caso de error
      return BoletaModel(
        id: doc.id,
        placa: 'ERROR-${doc.id.substring(0, 6)}',
        empresa: 'Error al cargar datos',
        numeroLicencia: '',
        conductor: 'Error',
        codigoFiscalizador: '',
        inspectorNombre: 'Error',
        motivo: 'Error al cargar',
        conforme: 'No especificado',
        inspectorId: '',
        fecha: DateTime.now(), nombreConductor: '',
      );
    }
  }

  // ✅ OPTIMIZACIÓN: Widget de tarjeta optimizado
  Widget _buildBoletaCard(BoletaModel boleta, int index) {
    // ✅ CORREGIDO: Usar colores seguros y definidos
    final List<Color> cardColors = [
      const Color.fromARGB(255, 255, 255, 255),
      const Color.fromARGB(255, 255, 255, 255),
      const Color.fromARGB(255, 255, 255, 255),
    ];

    final backgroundColor = cardColors[index % cardColors.length];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: primaryRed.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: backgroundColor,
      child: InkWell(
        onTap: () => _showBoletaDetail(boleta),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Número de boleta
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8ECDF7), Color(0xFFDC143C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Información principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Placa y estado
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Placa: ${boleta.placa.toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: foregroundDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _getConformeWidget(boleta.conforme),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Empresa
                    Text(
                      boleta.empresa,
                      style: const TextStyle(
                        color: mutedForeground,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Fecha
                    Text(
                      DateFormat('dd/MM/yyyy - HH:mm').format(boleta.fecha),
                      style: const TextStyle(
                        color: mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Icono de ver detalles
              const Icon(
                Icons.visibility_outlined,
                size: 20,
                color: primaryRed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ OPTIMIZACIÓN: Diálogo de detalles optimizado
  void _showBoletaDetail(BoletaModel boleta) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8ECDF7), Color(0xFFDC143C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detalle de Boleta',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: foregroundDark,
                            ),
                          ),
                          Text(
                            'Placa: ${boleta.placa.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: mutedForeground,
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Información básica
                _buildDetailSection(
                  'Información del Vehículo',
                  Icons.directions_car,
                  primaryRed,
                  [
                    _buildDetailRow('Placa', boleta.placa.toUpperCase()),
                    _buildDetailRow('Empresa', boleta.empresa),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Conductor
                _buildDetailSection(
                  'Conductor',
                  Icons.person,
                  Colors.blue.shade600,
                  [
                    _buildDetailRow('Nombre', boleta.conductor),
                    _buildDetailRow('Nro. Licencia', boleta.numeroLicencia),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Fiscalización
                _buildDetailSection(
                  'Fiscalización',
                  Icons.assignment,
                  Colors.orange.shade600,
                  [
                    _buildDetailRow('Motivo', boleta.motivo),
                    _buildDetailRow('Inspector', boleta.inspectorNombre ?? 'No especificado'),
                    _buildDetailRow('Código Fiscalizador', boleta.codigoFiscalizador),
                    _buildConformeRow('Estado', boleta.conforme),
                    _buildDetailRow('Fecha', DateFormat('dd/MM/yyyy - HH:mm').format(boleta.fecha)),
                    if (boleta.observaciones?.isNotEmpty == true)
                      _buildDetailRow('Observaciones', boleta.observaciones!),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Botón de imprimir
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _printBoleta(boleta);
                    },
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text(
                      'Imprimir Boleta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
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
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(color: mutedForeground)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: foregroundDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConformeRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(color: mutedForeground)),
          _getConformeWidget(value),
        ],
      ),
    );
  }

  Future<void> _printBoleta(BoletaModel boleta) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Historial de Boletas'),
        backgroundColor: backgroundLight,
        foregroundColor: const Color.fromARGB(255, 126, 124, 124),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: AnimatedBuilder(
              animation: _refreshAnimationController,
              builder: (context, child) => Transform.rotate(
                angle: _refreshAnimationController.value * 2 * 3.14159,
                child: const Icon(Icons.refresh, color: primaryRed),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Container(
            color: backgroundLight,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchTerm = value.toUpperCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por placa...',
                prefixIcon: const Icon(Icons.search, color: primaryRed),
                filled: true,
                fillColor: mutedGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundLight, Color.fromARGB(255, 53, 49, 49)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _searchTerm.isEmpty
              ? FirebaseFirestore.instance
                  .collection('boletas')
                  .orderBy('fecha', descending: true)
                  .limit(50)
                  .snapshots()
              : FirebaseFirestore.instance
                  .collection('boletas')
                  .where('placa', isGreaterThanOrEqualTo: _searchTerm)
                  .where('placa', isLessThanOrEqualTo: '$_searchTerm\uf8ff')
                  .limit(20)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: primaryRed),
                    SizedBox(height: 16),
                    Text(
                      'Cargando boletas...',
                      style: TextStyle(color: mutedForeground),
                    ),
                  ],
                ),
              );
            }
            
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: primaryRed),
                    const SizedBox(height: 16),
                    const Text(
                      'Error al cargar datos',
                      style: TextStyle(
                        fontSize: 18,
                        color: primaryRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Por favor, intenta nuevamente',
                      style: TextStyle(
                        fontSize: 14,
                        color: mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshData,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: mutedForeground,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No se encontraron boletas',
                      style: TextStyle(
                        fontSize: 18,
                        color: mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            final boletas = snapshot.data!.docs
                .map((doc) => _safeBoletaFromFirestore(doc))
                .where((boleta) => !boleta.placa.startsWith('ERROR'))
                .toList();

            if (_searchTerm.isNotEmpty) {
              boletas.sort((a, b) => b.fecha.compareTo(a.fecha));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: boletas.length,
              itemExtent: 120,
              itemBuilder: (context, index) {
                return _buildBoletaCard(boletas[index], index);
              },
            );
          },
        ),
      ),
    );
  }
}
