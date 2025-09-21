// lib/screens/dashboard_screen.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onBack;
  const DashboardScreen({super.key, required this.onBack});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final functions =
          FirebaseFunctions.instanceFor(region: 'southamerica-west1');
      final result = await functions.httpsCallable('getDashboardData').call();
      setState(() {
        _data = result.data;
        _isLoading = false;
      });
    } catch (e) {
      // Manejo de errores
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _data == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(LucideIcons.arrow_left), onPressed: widget.onBack),
        title: const Text("Dashboard de Gerencia"),
        actions: [
          IconButton(icon: const Icon(LucideIcons.download), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildCharts(),
          const SizedBox(height: 24),
          _buildInspectorPerformance(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2,
      children: [
        _StatCard(
            title: 'Total Boletas',
            value: _data!['totalBoletas'].toString(),
            icon: LucideIcons.file_text,
            color: Colors.blue),
        _StatCard(
            title: 'Conformes',
            value: _data!['totalConformes'].toString(),
            // Icono válido en flutter_lucide (evita usar check_circle)
            icon: LucideIcons.circle_check,
            color: Colors.green),
        _StatCard(
            title: 'No Conformes',
            value: _data!['totalNoConformes'].toString(),
            icon: LucideIcons.circle_x,
            color: Colors.red),
        _StatCard(
            title: 'Tasa Conformidad',
            value:
                '${(_data!['totalBoletas'] > 0 ? (_data!['totalConformes'] / _data!['totalBoletas'] * 100).round() : 0)}%',
            icon: LucideIcons.trending_up,
            color: Colors.orange),
      ],
    );
  }

  Widget _buildCharts() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Distribución de Conformidad",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                        value: (_data!['totalConformes'] as int).toDouble(),
                        color: Colors.green,
                        title: '${_data!['totalConformes']}',
                        radius: 50),
                    PieChartSectionData(
                        value: (_data!['totalNoConformes'] as int).toDouble(),
                        color: Colors.red,
                        title: '${_data!['totalNoConformes']}',
                        radius: 50),
                    PieChartSectionData(
                        value: (_data!['totalParciales'] as int).toDouble(),
                        color: Colors.orange,
                        title: '${_data!['totalParciales']}',
                        radius: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectorPerformance() {
    final List inspectores = (_data!['inspectores'] as List?) ?? const [];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rendimiento de Inspectores",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...inspectores.map((inspector) {
              final dynamic rawName = inspector['nombreCompleto'] ??
                  inspector['nombre'] ??
                  inspector['email'];
              final String name =
                  (rawName is String && rawName.trim().isNotEmpty)
                      ? rawName
                      : 'Inspector';
              final String initials = name.length >= 2
                  ? name.substring(0, 2).toUpperCase()
                  : name.substring(0, 1).toUpperCase();
              final int total = (inspector['boletas'] is num)
                  ? (inspector['boletas'] as num).toInt()
                  : 0;
              final int conformes = (inspector['conformes'] is num)
                  ? (inspector['conformes'] as num).toInt()
                  : 0;
              final int tasa =
                  total > 0 ? ((conformes / total) * 100).round() : 0;
              return ListTile(
                leading: CircleAvatar(child: Text(initials)),
                title: Text(name),
                subtitle: Text("Boletas: $total"),
                trailing: Text("$tasa% conformidad"),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
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
                Text(title,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
