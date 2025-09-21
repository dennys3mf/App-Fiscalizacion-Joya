// lib/screens/manager_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; // Añade fl_chart a tu pubspec.yaml

class ManagerDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Panel Administrativo de Gerente"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // Lógica de logout
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Resumen General", style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: 16),
            // Fila de Tarjetas con Métricas
            _buildMetricsCards(),
            SizedBox(height: 32),
            Text("Historial de Boletas", style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: 16),
            // Tabla de datos
            _buildBoletasTable(),
          ],
        ),
      ),
    );
  }

  // Widget para las tarjetas de métricas
  Widget _buildMetricsCards() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('boletas').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();
          int totalBoletas = snapshot.data!.docs.length;
          // Aquí puedes agregar más lógicas para otras métricas
          return Wrap( // Wrap es genial para la responsividad
            spacing: 16.0,
            runSpacing: 16.0,
            children: [
              MetricCard(title: "Total de Boletas", value: totalBoletas.toString()),
              MetricCard(title: "Inspectores Activos", value: "5"), // Valor de ejemplo
            ],
          );
        });
  }

  // Widget para la tabla de datos
  Widget _buildBoletasTable() {
    return SizedBox(
      width: double.infinity,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('boletas').orderBy('fecha', descending: true).limit(10).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          return DataTable(
            columns: [
              DataColumn(label: Text('Inspector')),
              DataColumn(label: Text('Placa')),
              DataColumn(label: Text('Infracción')),
              DataColumn(label: Text('Fecha')),
            ],
            rows: snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return DataRow(cells: [
                DataCell(Text(data['inspectorName'] ?? 'N/A')),
                DataCell(Text(data['placa'] ?? 'N/A')),
                DataCell(Text(data['infraccion'] ?? 'N/A')),
                DataCell(Text( (data['fecha'] as Timestamp).toDate().toString().substring(0, 10) )),
              ]);
            }).toList(),
          );
        },
      ),
    );
  }
}

// Un widget simple para las tarjetas
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  const MetricCard({Key? key, required this.title, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(16),
        width: 250, // Ancho fijo para las tarjetas
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}