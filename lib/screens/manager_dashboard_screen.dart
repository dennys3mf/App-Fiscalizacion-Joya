// lib/screens/manager_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Resumen General",
                style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: 16),
            // Fila de Tarjetas con Métricas
            _buildMetricsCards(),
            SizedBox(height: 32),
            Text("Historial de Boletas",
                style: Theme.of(context).textTheme.headlineMedium),
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
    final stream = FirebaseFirestore.instance.collection('boletas').snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          // Mostrar el error para diagnosticar reglas/App Check
          return _ErrorBox(
            title: 'Error cargando métricas',
            error: snapshot.error,
          );
        }
        if (!snapshot.hasData) {
          return const Text('Sin datos');
        }

        final totalBoletas = snapshot.data!.docs.length;
        return Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          children: [
            MetricCard(
                title: 'Total de Boletas', value: totalBoletas.toString()),
            // Podríamos calcular Inspectores Activos desde colección users si se requiere
          ],
        );
      },
    );
  }

  // Widget para la tabla de datos
  Widget _buildBoletasTable() {
    return SizedBox(
      width: double.infinity,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('boletas')
            .orderBy('fecha', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorBox(
              title: 'Error cargando boletas',
              error: snapshot.error,
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay boletas para mostrar'));
          }

          String formatFecha(dynamic value) {
            try {
              if (value is Timestamp)
                return value.toDate().toString().substring(0, 16);
              if (value is DateTime) return value.toString().substring(0, 16);
              if (value is num) {
                final d = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return d.toString().substring(0, 16);
              }
              if (value is String) {
                final d = DateTime.tryParse(value);
                if (d != null) return d.toString().substring(0, 16);
              }
            } catch (_) {}
            return '--';
          }

          return DataTable(
            columns: const [
              DataColumn(label: Text('Inspector')),
              DataColumn(label: Text('Placa')),
              DataColumn(label: Text('Infracción')),
              DataColumn(label: Text('Fecha')),
            ],
            rows: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final inspector = (data['inspectorNombre'] ??
                      data['inspectorName'] ??
                      data['inspectorEmail'] ??
                      'N/A')
                  .toString();
              final placa = (data['placa'] ?? 'N/A').toString();
              final infraccion =
                  (data['motivo'] ?? data['infraccion'] ?? 'N/A').toString();
              final fecha = formatFecha(data['fecha']);
              return DataRow(cells: [
                DataCell(Text(inspector)),
                DataCell(Text(placa)),
                DataCell(Text(infraccion)),
                DataCell(Text(fecha)),
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
  const MetricCard({Key? key, required this.title, required this.value})
      : super(key: key);

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

// Caja de error reutilizable para mostrar detalles cuando Firestore falla
class _ErrorBox extends StatelessWidget {
  final String title;
  final Object? error;
  const _ErrorBox({required this.title, this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(error?.toString() ?? 'Error desconocido',
                    style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
