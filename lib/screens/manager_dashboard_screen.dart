import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ManagerDashboardScreen extends StatefulWidget {
  @override
  _ManagerDashboardScreenState createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  String _selectedInspector = 'Todos';
  String _selectedEstado = 'Todos';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 163, 141, 141),
      appBar: AppBar(
        title: Text("Panel Administrativo", style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Colors.grey[800],
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Actualizar datos',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen General
            _buildSectionTitle("Resumen General"),
            SizedBox(height: 16),
            _buildMetricsCards(),
            
            SizedBox(height: 32),
            
            // Estadísticas con Gráficos
            _buildSectionTitle("Estadísticas"),
            SizedBox(height: 16),
            _buildChartsSection(),
            
            SizedBox(height: 32),
            
            // Filtros y Búsqueda
            _buildSectionTitle("Historial de Boletas"),
            SizedBox(height: 16),
            _buildFiltersSection(),
            
            SizedBox(height: 16),
            
            // Tabla de Boletas
            _buildBoletasTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildMetricsCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('boletas').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCards();
        }
        if (snapshot.hasError) {
          return _buildErrorCard('Error cargando métricas', snapshot.error);
        }
        if (!snapshot.hasData) {
          return _buildEmptyCard();
        }

        final docs = snapshot.data!.docs;
        final totalBoletas = docs.length;
        final totalMultas = docs.fold<double>(0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          final multa = data['multa'];
          if (multa is num) return sum + multa.toDouble();
          return sum;
        });
        
        final boletasActivas = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['estado'] ?? 'Activa').toString().toLowerCase() == 'activa';
        }).length;
        
        final boletasCerradas = totalBoletas - boletasActivas;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'inspector').snapshots(),
          builder: (context, inspectorSnapshot) {
            final totalInspectores = inspectorSnapshot.hasData ? inspectorSnapshot.data!.docs.length : 0;
            
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return Wrap(
                  spacing: 16.0,
                  runSpacing: 16.0,
                  children: [
                    _buildMetricCard(
                      'Total de Boletas',
                      totalBoletas.toString(),
                      Icons.receipt_long,
                      Colors.blue,
                      isWide ? 200 : constraints.maxWidth / 2 - 24,
                    ),
                    _buildMetricCard(
                      'Total de Multas',
                      'S/ ${totalMultas.toStringAsFixed(2)}',
                      Icons.monetization_on,
                      Colors.green,
                      isWide ? 200 : constraints.maxWidth / 2 - 24,
                    ),
                    _buildMetricCard(
                      'Boletas Activas',
                      boletasActivas.toString(),
                      Icons.pending_actions,
                      Colors.orange,
                      isWide ? 200 : constraints.maxWidth / 2 - 24,
                    ),
                    _buildMetricCard(
                      'Boletas Cerradas',
                      boletasCerradas.toString(),
                      Icons.check_circle,
                      Colors.teal,
                      isWide ? 200 : constraints.maxWidth / 2 - 24,
                    ),
                    _buildMetricCard(
                      'Total Inspectores',
                      totalInspectores.toString(),
                      Icons.people,
                      Colors.purple,
                      isWide ? 200 : constraints.maxWidth / 2 - 24,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 28),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('boletas').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCharts();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildErrorCard('Error cargando gráficos', snapshot.error);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1000;
            
            if (isWide) {
              return Row(
                children: [
                  Expanded(child: _buildInspectorChart(snapshot.data!.docs)),
                  SizedBox(width: 16),
                  Expanded(child: _buildEstadoChart(snapshot.data!.docs)),
                  SizedBox(width: 16),
                  Expanded(child: _buildFechaChart(snapshot.data!.docs)),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildInspectorChart(snapshot.data!.docs),
                  SizedBox(height: 16),
                  _buildEstadoChart(snapshot.data!.docs),
                  SizedBox(height: 16),
                  _buildFechaChart(snapshot.data!.docs),
                ],
              );
            }
          },
        );
      },
    );
  }

  Widget _buildInspectorChart(List<QueryDocumentSnapshot> docs) {
    final inspectorCounts = <String, int>{};
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final inspector = (data['inspectorNombre'] ?? data['inspectorName'] ?? 'Sin asignar').toString();
      inspectorCounts[inspector] = (inspectorCounts[inspector] ?? 0) + 1;
    }

    final sortedEntries = inspectorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Boletas por Inspector',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: sortedEntries.isNotEmpty ? sortedEntries.first.value.toDouble() + 2 : 10,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < sortedEntries.length) {
                            final name = sortedEntries[value.toInt()].key;
                            return Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                name.length > 8 ? '${name.substring(0, 8)}...' : name,
                                style: TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: sortedEntries.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          color: Colors.blue,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoChart(List<QueryDocumentSnapshot> docs) {
    final estadoCounts = <String, int>{'Activa': 0, 'Cerrada': 0};
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final estado = (data['estado'] ?? 'Activa').toString();
      if (estado.toLowerCase() == 'activa') {
        estadoCounts['Activa'] = estadoCounts['Activa']! + 1;
      } else {
        estadoCounts['Cerrada'] = estadoCounts['Cerrada']! + 1;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribución por Estado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: Colors.orange,
                      value: estadoCounts['Activa']!.toDouble(),
                      title: '${estadoCounts['Activa']}',
                      radius: 60,
                      titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    PieChartSectionData(
                      color: Colors.teal,
                      value: estadoCounts['Cerrada']!.toDouble(),
                      title: '${estadoCounts['Cerrada']}',
                      radius: 60,
                      titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Activas', Colors.orange, estadoCounts['Activa']!),
                _buildLegendItem('Cerradas', Colors.teal, estadoCounts['Cerrada']!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFechaChart(List<QueryDocumentSnapshot> docs) {
    final fechaCounts = <String, int>{};
    final now = DateTime.now();
    
    // Inicializar últimos 7 días
    for (int i = 6; i >= 0; i--) {
      final fecha = now.subtract(Duration(days: i));
      final key = DateFormat('dd/MM').format(fecha);
      fechaCounts[key] = 0;
    }
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final fecha = data['fecha'];
      DateTime? fechaDoc;
      
      if (fecha is Timestamp) {
        fechaDoc = fecha.toDate();
      } else if (fecha is String) {
        fechaDoc = DateTime.tryParse(fecha);
      }
      
      if (fechaDoc != null) {
        final key = DateFormat('dd/MM').format(fechaDoc);
        if (fechaCounts.containsKey(key)) {
          fechaCounts[key] = fechaCounts[key]! + 1;
        }
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evolución Últimos 7 Días',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final keys = fechaCounts.keys.toList();
                          if (value.toInt() >= 0 && value.toInt() < keys.length) {
                            return Text(keys[value.toInt()], style: TextStyle(fontSize: 10));
                          }
                          return Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: fechaCounts.entries.toList().asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.purple,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.purple.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4),
        Text('$label ($count)', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros y Búsqueda',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                
                if (isWide) {
                  return Row(
                    children: [
                      Expanded(flex: 2, child: _buildSearchField()),
                      SizedBox(width: 16),
                      Expanded(child: _buildInspectorFilter()),
                      SizedBox(width: 16),
                      Expanded(child: _buildEstadoFilter()),
                      SizedBox(width: 16),
                      Expanded(child: _buildDateFilter()),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildSearchField(),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildInspectorFilter()),
                          SizedBox(width: 12),
                          Expanded(child: _buildEstadoFilter()),
                        ],
                      ),
                      SizedBox(height: 12),
                      _buildDateFilter(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Buscar por placa o conductor...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: const Color.fromARGB(255, 83, 80, 80),
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildInspectorFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('boletas').snapshots(),
      builder: (context, snapshot) {
        final inspectores = <String>{'Todos'};
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final inspector = data['inspectorNombre'] ?? data['inspectorName'] ?? '';
            if (inspector.toString().isNotEmpty) {
              inspectores.add(inspector.toString());
            }
          }
        }
        
        return DropdownButtonFormField<String>(
          value: _selectedInspector,
          decoration: InputDecoration(
            labelText: 'Inspector',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: const Color.fromARGB(255, 80, 78, 78),
          ),
          items: inspectores.map((inspector) {
            return DropdownMenuItem(value: inspector, child: Text(inspector));
          }).toList(),
          onChanged: (value) => setState(() => _selectedInspector = value!),
        );
      },
    );
  }

  Widget _buildEstadoFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedEstado,
      decoration: InputDecoration(
        labelText: 'Estado',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: const Color.fromARGB(255, 71, 69, 69),
      ),
      items: ['Todos', 'Activa', 'Cerrada'].map((estado) {
        return DropdownMenuItem(value: estado, child: Text(estado));
      }).toList(),
      onChanged: (value) => setState(() => _selectedEstado = value!),
    );
  }

  Widget _buildDateFilter() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectDateRange(),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Rango de fechas',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: const Color.fromARGB(255, 73, 70, 70),
                suffixIcon: Icon(Icons.date_range),
              ),
              child: Text(
                _fechaInicio != null && _fechaFin != null
                    ? '${DateFormat('dd/MM/yy').format(_fechaInicio!)} - ${DateFormat('dd/MM/yy').format(_fechaFin!)}'
                    : 'Seleccionar rango',
                style: TextStyle(
                  color: _fechaInicio != null ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
        if (_fechaInicio != null)
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () => setState(() {
              _fechaInicio = null;
              _fechaFin = null;
            }),
          ),
      ],
    );
  }

  Widget _buildBoletasTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredBoletasStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingTable();
        }
        if (snapshot.hasError) {
          return _buildErrorCard('Error cargando boletas', snapshot.error);
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyTable();
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Resultados (${snapshot.data!.docs.length})',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Última actualización: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowColor: MaterialStateProperty.all(const Color.fromARGB(255, 65, 62, 62)),
                    columns: [
                      DataColumn(label: Text('Inspector', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Placa', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Conductor', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Motivo', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Multa', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                    rows: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DataRow(
                        cells: [
                          DataCell(Text(_getFieldValue(data, ['inspectorNombre', 'inspectorName']))),
                          DataCell(Text(_getFieldValue(data, ['placa']))),
                          DataCell(Text(_getFieldValue(data, ['nombreConductor', 'conductor']))),
                          DataCell(Text(_getFieldValue(data, ['motivo', 'infraccion']))),
                          DataCell(Text(_formatFecha(data['fecha']))),
                          DataCell(_buildEstadoBadge(data['estado'])),
                          DataCell(Text('S/ ${_getFieldValue(data, ['multa'], '0')}')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.photo, color: Colors.blue),
                                  onPressed: () => _showPhotoModal(data),
                                  tooltip: 'Ver foto',
                                ),
                                IconButton(
                                  icon: Icon(Icons.info, color: Colors.green),
                                  onPressed: () => _showDetailModal(doc.id, data),
                                  tooltip: 'Ver detalles',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEstadoBadge(dynamic estado) {
    final estadoStr = (estado ?? 'Activa').toString();
    final isActiva = estadoStr.toLowerCase() == 'activa';
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActiva ? Colors.orange.withOpacity(0.1) : Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActiva ? Colors.orange : Colors.teal,
          width: 1,
        ),
      ),
      child: Text(
        estadoStr,
        style: TextStyle(
          color: isActiva ? Colors.orange[700] : Colors.teal[700],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Métodos auxiliares
  String _getFieldValue(Map<String, dynamic> data, List<String> fields, [String defaultValue = 'N/A']) {
    for (final field in fields) {
      if (data.containsKey(field) && data[field] != null) {
        return data[field].toString();
      }
    }
    return defaultValue;
  }

  String _formatFecha(dynamic fecha) {
    try {
      if (fecha is Timestamp) {
        return DateFormat('dd/MM/yyyy HH:mm').format(fecha.toDate());
      }
      if (fecha is String) {
        final parsedDate = DateTime.tryParse(fecha);
        if (parsedDate != null) {
          return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
        }
      }
    } catch (e) {
      // Ignorar errores de formato
    }
    return 'N/A';
  }

  Stream<QuerySnapshot> _getFilteredBoletasStream() {
    Query query = FirebaseFirestore.instance.collection('boletas');
    
    // Filtro por inspector
    if (_selectedInspector != 'Todos') {
      query = query.where('inspectorNombre', isEqualTo: _selectedInspector);
    }
    
    // Filtro por estado
    if (_selectedEstado != 'Todos') {
      query = query.where('estado', isEqualTo: _selectedEstado);
    }
    
    // Filtro por fecha
    if (_fechaInicio != null && _fechaFin != null) {
      query = query
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(_fechaInicio!))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(_fechaFin!));
    }
    
    return query.orderBy('fecha', descending: true).limit(50).snapshots();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fechaInicio != null && _fechaFin != null
          ? DateTimeRange(start: _fechaInicio!, end: _fechaFin!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
      });
    }
  }

  void _showPhotoModal(Map<String, dynamic> data) {
    final photoUrl = data['urlFotoLicencia'] ?? data['photoUrl'];
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Foto de Licencia - ${data['placa'] ?? 'N/A'}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: photoUrl != null
                      ? InteractiveViewer(
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                                    SizedBox(height: 16),
                                    Text('Error al cargar la imagen'),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported, size: 64, color: Colors.grey[400]),
                              SizedBox(height: 16),
                              Text('No hay foto disponible'),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailModal(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detalle de Boleta',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Inspector', _getFieldValue(data, ['inspectorNombre', 'inspectorName'])),
                      _buildDetailRow('Placa', _getFieldValue(data, ['placa'])),
                      _buildDetailRow('Conductor', _getFieldValue(data, ['nombreConductor', 'conductor'])),
                      _buildDetailRow('Empresa', _getFieldValue(data, ['empresa'])),
                      _buildDetailRow('Número de Licencia', _getFieldValue(data, ['numeroLicencia'])),
                      _buildDetailRow('Motivo', _getFieldValue(data, ['motivo', 'infraccion'])),
                      _buildDetailRow('Observaciones', _getFieldValue(data, ['observaciones'])),
                      _buildDetailRow('Fecha', _formatFecha(data['fecha'])),
                      _buildDetailRow('Estado', _getFieldValue(data, ['estado'], 'Activa')),
                      _buildDetailRow('Multa', 'S/ ${_getFieldValue(data, ['multa'], '0')}'),
                      
                      SizedBox(height: 20),
                      
                      if (data['urlFotoLicencia'] != null) ...[
                        Text(
                          'Foto de Licencia:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 8),
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['urlFotoLicencia'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(child: Text('Error al cargar imagen'));
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      // Botón para cambiar estado
                      if (data['estado']?.toString().toLowerCase() == 'activa')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _updateEstado(docId),
                            icon: Icon(Icons.check_circle),
                            label: Text('Marcar como Cerrada'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEstado(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('boletas')
          .doc(docId)
          .update({'estado': 'Cerrada'});
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar estado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Widgets de carga y error
  Widget _buildLoadingCards() {
    return Wrap(
      spacing: 16.0,
      runSpacing: 16.0,
      children: List.generate(5, (index) => _buildSkeletonCard()),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      width: 200,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 16),
              Container(
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 4),
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCharts() {
    return Row(
      children: List.generate(3, (index) => 
        Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 2 ? 16 : 0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorCard(String title, Object? error) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(error?.toString() ?? 'Error desconocido', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('No hay datos disponibles', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text('No se encontraron boletas con los filtros aplicados'),
            ],
          ),
        ),
      ),
    );
  }
}
