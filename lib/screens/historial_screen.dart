import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/boleta_model.dart';
import '../services/pdf_service.dart';
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

  Future<void> _refreshData() async {
    _refreshAnimationController.forward(from: 0);
    setState(() {}); // Forzar reconstrucción del StreamBuilder
    await Future.delayed(const Duration(seconds: 1));
  }

  // --- Widgets de UI ---

  Widget _getConformeWidget(String conforme) {
    IconData iconData;
    Color color;
    Color bgColor;

    switch (conforme.toLowerCase()) {
      case 'sí':
        iconData = Icons.check_circle;
        color = Colors.green.shade800;
        bgColor = Colors.green.shade50;
        break;
      case 'no':
        iconData = Icons.cancel;
        color = Colors.red.shade800;
        bgColor = Colors.red.shade50;
        break;
      case 'parcialmente':
        iconData = Icons.warning;
        color = Colors.orange.shade800;
        bgColor = Colors.orange.shade50;
        break;
      default:
        iconData = Icons.help;
        color = Colors.grey.shade800;
        bgColor = Colors.grey.shade50;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            conforme,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yy').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Future<void> _showBoletaDetail(BoletaModel boleta) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Detalles de Boleta', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection('Información del Vehículo', Icons.directions_car, [_buildDetailRow('Placa', boleta.placa.toUpperCase()), _buildDetailRow('Empresa', boleta.empresa)]),
                    const SizedBox(height: 24),
                    _buildDetailSection('Información del Conductor', Icons.person, [_buildDetailRow('Conductor', boleta.conductor), _buildDetailRow('N° Licencia', boleta.numeroLicencia)]),
                    const SizedBox(height: 24),
                    _buildDetailSection('Detalles de Fiscalización', Icons.assignment, [
                      _buildDetailRow('Fecha y Hora', _formatDateTime(boleta.fecha)),
                      _buildDetailRow('Fiscalizador', boleta.codigoFiscalizador),
                      _buildDetailRow('Motivo', boleta.motivo),
                      _buildConformeRow('Conforme', boleta.conforme),
                      if (boleta.descripciones != null && boleta.descripciones!.isNotEmpty) _buildDetailRow('Descripciones', boleta.descripciones!),
                      if (boleta.observaciones != null && boleta.observaciones!.isNotEmpty) _buildDetailRow('Observaciones', boleta.observaciones!),
                    ]),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                         try {
                          await PDFService.generateAndSharePDF(boleta);
                        } catch (e) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red));
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                         try {
                          await PrintService.printBoleta(boleta);
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviando a la impresora...'), backgroundColor: Colors.blue));
                        } catch (e) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al imprimir: $e'), backgroundColor: Colors.red));
                        }
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimir'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: AppTheme.primaryRed, size: 18),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.foregroundDark)),
        ]),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.only(left: 26), child: Column(children: children)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.mutedForeground))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.foregroundDark))),
      ]),
    );
  }

    Widget _buildConformeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.mutedForeground))),
        _getConformeWidget(value),
      ]),
    );
  }

  Widget _buildBoletaCard(BoletaModel boleta, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: AppTheme.primaryRed.withOpacity(0.1),
      child: InkWell(
        onTap: () => _showBoletaDetail(boleta),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(16)),
                  child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Placa: ${boleta.placa.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 12),
                    _getConformeWidget(boleta.conforme),
                  ]),
                  const SizedBox(height: 4),
                  Text(boleta.empresa, style: const TextStyle(color: AppTheme.mutedForeground, fontSize: 14), overflow: TextOverflow.ellipsis),
                ]),
              ),
              const Icon(Icons.visibility_outlined, size: 20, color: AppTheme.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: const Text('Historial de Boletas'),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: AnimatedBuilder(
              animation: _refreshAnimationController,
              builder: (context, child) => Transform.rotate(angle: _refreshAnimationController.value * 2 * 3.14159, child: const Icon(Icons.refresh)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(hintText: 'Buscar por placa, empresa o conductor...', prefixIcon: const Icon(Icons.search)),
              onChanged: (value) => setState(() => _searchTerm = value.toLowerCase()),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('boletas').orderBy('fecha', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryRed));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay boletas guardadas'));

            final boletas = snapshot.data!.docs
                .map((doc) => BoletaModel.fromMap({'id': doc.id, ...doc.data() as Map<String, dynamic>}))
                .where((boleta) {
                  if (_searchTerm.isEmpty) return true;
                  return boleta.placa.toLowerCase().contains(_searchTerm) ||
                         boleta.empresa.toLowerCase().contains(_searchTerm) ||
                         boleta.conductor.toLowerCase().contains(_searchTerm);
                }).toList();

            if (boletas.isEmpty) return const Center(child: Text('No se encontraron resultados'));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: boletas.length,
              itemBuilder: (context, index) => _buildBoletaCard(boletas[index], index),
            );
          },
        ),
      ),
    );
  }
}