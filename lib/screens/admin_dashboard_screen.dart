// lib/screens/admin_dashboard_screen.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../theme/app_theme.dart';
// ¡Reutilizaremos la pantalla que ya creamos como una pestaña!
import 'admin_inspectores_screen.dart'; 

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onBack;
  const AdminDashboardScreen({super.key, required this.onBack});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-west1');
      final callable = functions.httpsCallable('getDashboardStats');
      final result = await callable.call();
      setState(() {
        _stats = result.data;
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Ocurrió un error inesperado.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text("Error: $_error")));
    }
    if (_stats == null) {
      return const Scaffold(body: Center(child: Text("No se pudieron cargar los datos.")));
    }

    return DefaultTabController(
      length: 2, // Por ahora 2 pestañas: Resumen y Gestionar
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(LucideIcons.arrow_left), onPressed: widget.onBack),
          title: const Text('Dashboard de Gerencia'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(LucideIcons.layout_dashboard), text: 'Resumen'),
              Tab(icon: Icon(LucideIcons.users), text: 'Gestionar Inspectores'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildResumenTab(),
            // Reutilizamos la pantalla que ya tenías para la gestión
            AdminInspectoresScreen(onBack: () {}), 
          ],
        ),
      ),
    );
  }

  Widget _buildResumenTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Tarjetas de Estadísticas (KPIs) ---
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _buildStatCard('Total Boletas', _stats!['totalBoletas'].toString(), LucideIcons.file_text, Colors.blue),
              _buildStatCard('Conformes', _stats!['totalConformes'].toString(), LucideIcons.check, Colors.green),
              _buildStatCard('No Conformes', _stats!['totalNoConformes'].toString(), LucideIcons.circle, Colors.red),
              _buildStatCard('Inspectores', _stats!['totalInspectores'].toString(), LucideIcons.users, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // --- Gráfico de Torta ---
          const Text('Distribución de Conformidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(value: (_stats!['totalConformes'] as int).toDouble(), color: Colors.green, title: 'Sí', radius: 80),
                  PieChartSectionData(value: (_stats!['totalNoConformes'] as int).toDouble(), color: Colors.red, title: 'No', radius: 80),
                  PieChartSectionData(value: (_stats!['totalParciales'] as int).toDouble(), color: Colors.orange, title: 'Parcial', radius: 80),
                ],
              ),
            ),
          ),
           const SizedBox(height: 24),

          // --- Tabla de Rendimiento de Inspectores ---
          const Text('Rendimiento por Inspector', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Inspector')),
                DataColumn(label: Text('Boletas'), numeric: true),
              ],
              rows: (_stats!['inspectores'] as List).map<DataRow>((inspector) {
                return DataRow(
                  cells: [
                    DataCell(Text(inspector['nombre'] ?? 'N/A')),
                    DataCell(Text(inspector['boletas'].toString())),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}