// lib/screens/admin_dashboard_screen.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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
      final functions =
          FirebaseFunctions.instanceFor(region: 'southamerica-west1');
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
      return const Scaffold(
          body: Center(child: Text("No se pudieron cargar los datos.")));
    }

    return DefaultTabController(
      length: 2, // Resumen + Gestionar Inspectores
      child: Scaffold(
        body: Container(
          decoration:
              const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                // Contenido de tabs
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TabBarView(
                      children: [
                        _buildResumenTab(),
                        AdminInspectoresScreen(onBack: () {}),
                      ],
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra superior con volver, título y acciones
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Dashboard de Gerencia',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 12),
                  Icon(Icons.share_outlined, size: 20),
                ],
              )
            ],
          ),

          const SizedBox(height: 12),

          // Tab bar estilizada
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppTheme.primaryRed,
              unselectedLabelColor: AppTheme.mutedForeground,
              tabs: [
                Tab(
                    icon: Icon(Icons.dashboard_customize_outlined),
                    text: 'Resumen'),
                Tab(
                    icon: Icon(Icons.groups_outlined),
                    text: 'Gestionar Inspectores'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenTab() {
    // Extraemos contadores con seguridad
    int asInt(dynamic v) =>
        (v is int) ? v : int.tryParse(v?.toString() ?? '0') ?? 0;
    final totalBoletas = asInt(_stats!['totalBoletas']);
    final conformes = asInt(_stats!['totalConformes']);
    final noConformes = asInt(_stats!['totalNoConformes']);
    final parciales = asInt(_stats!['totalParciales']);
    final totalInspectores = asInt(_stats!['totalInspectores']);
    final totalMultas = (_stats!['totalMultas'] is num)
        ? (_stats!['totalMultas'] as num).toDouble()
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjetas de KPIs con estilo
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final crossAxisCount = isWide ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 2.4 : 1.8,
                children: [
                  _KpiCard(
                    title: 'Total Boletas',
                    value: '$totalBoletas',
                    icon: Icons.receipt_long,
                    color: const Color(0xFF1E40AF),
                  ),
                  _KpiCard(
                    title: 'Conformes',
                    value: '$conformes',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF16A34A),
                  ),
                  _KpiCard(
                    title: 'No Conformes',
                    value: '$noConformes',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFDC2626),
                  ),
                  _KpiCard(
                    title: 'Parciales',
                    value: '$parciales',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                  _KpiCard(
                    title: 'Inspectores',
                    value: '$totalInspectores',
                    icon: Icons.group_outlined,
                    color: const Color(0xFF7C3AED),
                  ),
                  _KpiCard(
                    title: 'Total Multas',
                    value: 'S/. ${totalMultas.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFFB91C1C),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Gráfico de torta
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Distribución de Conformidad',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        sections: [
                          PieChartSectionData(
                            value: conformes.toDouble(),
                            color: const Color(0xFF10B981),
                            title: 'Sí',
                            radius: 80,
                          ),
                          PieChartSectionData(
                            value: noConformes.toDouble(),
                            color: const Color(0xFFEF4444),
                            title: 'No',
                            radius: 80,
                          ),
                          PieChartSectionData(
                            value: parciales.toDouble(),
                            color: const Color(0xFFF59E0B),
                            title: 'Parcial',
                            radius: 80,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Tabla de rendimiento por inspector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rendimiento por Inspector',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Inspector')),
                        DataColumn(label: Text('Boletas'), numeric: true),
                        DataColumn(label: Text('Conformes'), numeric: true),
                        DataColumn(label: Text('No Conformes'), numeric: true),
                        DataColumn(label: Text('Última Actividad')),
                      ],
                      rows: (_stats!['inspectores'] as List)
                          .map<DataRow>((inspector) {
                        final dynamic rawName = inspector['nombreCompleto'] ??
                            inspector['nombre'] ??
                            inspector['email'];
                        final String name =
                            (rawName is String && rawName.trim().isNotEmpty)
                                ? rawName
                                : 'N/A';
                        String formatFecha(dynamic v) {
                          try {
                            if (v is int) {
                              return DateTime.fromMillisecondsSinceEpoch(v)
                                  .toString()
                                  .substring(0, 16);
                            }
                          } catch (_) {}
                          return '--';
                        }

                        return DataRow(cells: [
                          DataCell(Text(name)),
                          DataCell(Text('${inspector['boletas'] ?? 0}')),
                          DataCell(Text('${inspector['conformes'] ?? 0}')),
                          DataCell(Text('${inspector['noConformes'] ?? 0}')),
                          DataCell(
                              Text(formatFecha(inspector['ultimaActividad']))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tarjeta KPI con estilo moderno
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: AppTheme.mutedForeground)),
                const SizedBox(height: 6),
                Text(value,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
