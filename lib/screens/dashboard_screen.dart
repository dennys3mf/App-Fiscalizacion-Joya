// lib/screens/dashboard_screen.dart - Versión móvil mejorada

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onBack;
  const DashboardScreen({super.key, required this.onBack});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final functions =
          FirebaseFunctions.instanceFor(region: 'southamerica-west1');
      final result = await functions.httpsCallable('getDashboardStats').call();
      setState(() {
        _data = result.data;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text("Dashboard de Gerencia"),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _fetchData();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando datos...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error al cargar datos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!.contains('permission-denied')
                    ? 'No tiene permisos para acceder a estos datos'
                    : 'Verifique su conexión a internet',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _fetchData();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_data == null) {
      return const Center(
        child: Text('No hay datos disponibles'),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _buildChartSection(),
            const SizedBox(height: 24),
            _buildInspectorSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final totalBoletas = (_data!['totalBoletas'] as num?)?.toInt() ?? 0;
    final totalConformes = (_data!['totalConformes'] as num?)?.toInt() ?? 0;
    final totalNoConformes = (_data!['totalNoConformes'] as num?)?.toInt() ?? 0;
    final totalParciales = (_data!['totalParciales'] as num?)?.toInt() ?? 0;
    final totalInspectores = (_data!['totalInspectores'] as num?)?.toInt() ?? 0;
    final totalMultas = (_data!['totalMultas'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen General',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // ✅ MEJORADO: Grid con mejor proporción para evitar overflow
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4, // ✅ AUMENTADO: Más altura para las tarjetas
          children: [
            _buildStatCard(
              'Total Boletas',
              totalBoletas.toString(),
              Icons.description,
              Colors.blue,
            ),
            _buildStatCard(
              'Conformes',
              totalConformes.toString(),
              Icons.check_circle,
              Colors.green,
            ),
            _buildStatCard(
              'No Conformes',
              totalNoConformes.toString(),
              Icons.cancel,
              Colors.red,
            ),
            _buildStatCard(
              'Parciales',
              totalParciales.toString(),
              Icons.remove_circle,
              Colors.orange,
            ),
            _buildStatCard(
              'Inspectores',
              totalInspectores.toString(),
              Icons.people,
              Colors.purple,
            ),
            _buildStatCard(
              'Total Multas',
              'S/ ${totalMultas.toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.teal,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12), // ✅ REDUCIDO: Padding más pequeño
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24), // ✅ REDUCIDO: Icono más pequeño
            const SizedBox(height: 6), // ✅ REDUCIDO: Menos espacio
            Flexible( // ✅ AGREGADO: Flexible para evitar overflow
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18, // ✅ REDUCIDO: Texto más pequeño
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4), // ✅ REDUCIDO: Menos espacio
            Flexible( // ✅ AGREGADO: Flexible para evitar overflow
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 11, // ✅ REDUCIDO: Texto más pequeño
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // ✅ AGREGADO: Máximo 2 líneas
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    final totalConformes = (_data!['totalConformes'] as num?)?.toDouble() ?? 0;
    final totalNoConformes = (_data!['totalNoConformes'] as num?)?.toDouble() ?? 0;
    final totalParciales = (_data!['totalParciales'] as num?)?.toDouble() ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribución de Conformidad',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (totalConformes == 0 && totalNoConformes == 0 && totalParciales == 0)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No hay datos para mostrar'),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      if (totalConformes > 0)
                        PieChartSectionData(
                          value: totalConformes,
                          color: Colors.green,
                          title: '${totalConformes.toInt()}',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      if (totalNoConformes > 0)
                        PieChartSectionData(
                          value: totalNoConformes,
                          color: Colors.red,
                          title: '${totalNoConformes.toInt()}',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      if (totalParciales > 0)
                        PieChartSectionData(
                          value: totalParciales,
                          color: Colors.orange,
                          title: '${totalParciales.toInt()}',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (totalConformes > 0 || totalNoConformes > 0 || totalParciales > 0) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                children: [
                  if (totalConformes > 0) _buildLegendItem('Sí', Colors.green),
                  if (totalParciales > 0) _buildLegendItem('Parcial', Colors.orange),
                  if (totalNoConformes > 0) _buildLegendItem('No', Colors.red),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInspectorSection() {
    final List inspectores = (_data!['inspectores'] as List?) ?? [];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rendimiento de Inspectores',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (inspectores.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No hay datos de inspectores'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: inspectores.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final inspector = inspectores[index];
                  final name = (inspector['nombreCompleto'] ?? 
                               inspector['nombre'] ?? 
                               inspector['email'] ?? 
                               'Inspector').toString();
                  final initials = name.length >= 2
                      ? name.substring(0, 2).toUpperCase()
                      : name.substring(0, 1).toUpperCase();
                  final total = (inspector['boletas'] as num?)?.toInt() ?? 0;
                  final conformes = (inspector['conformes'] as num?)?.toInt() ?? 0;
                  final tasa = total > 0 ? ((conformes / total) * 100).round() : 0;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: tasa >= 80 ? Colors.green : 
                                     tasa >= 60 ? Colors.orange : Colors.red,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Boletas: $total',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$tasa%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: tasa >= 80 ? Colors.green : 
                                   tasa >= 60 ? Colors.orange : Colors.red,
                          ),
                        ),
                        const Text(
                          'conformidad',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
