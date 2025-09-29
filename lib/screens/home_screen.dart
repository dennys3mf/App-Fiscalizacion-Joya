// lib/screens/home_screen.dart

import 'package:app_fiscalizacion/fiscalizacion_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'historial_screen.dart';
import 'impresoras_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.currentUser,
    required this.onLogout, required void Function(String route) onNavigate, required String username,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Map<String, int> _stats = {
    'totalBoletas': 0,
    'boletasHoy': 0,
    'conformes': 0,
    'noConformes': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Obtener estadísticas del inspector actual
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Consultar boletas del inspector
      final boletasQuery = FirebaseFirestore.instance
          .collection('boletas')
          .where('inspectorId', isEqualTo: widget.currentUser.uid);

      final boletasSnapshot = await boletasQuery.get();
      
      // Consultar boletas de hoy
      final boletasHoyQuery = FirebaseFirestore.instance
          .collection('boletas')
          .where('inspectorId', isEqualTo: widget.currentUser.uid)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('fecha', isLessThan: Timestamp.fromDate(endOfDay));

      final boletasHoySnapshot = await boletasHoyQuery.get();

      int conformes = 0;
      int noConformes = 0;

      for (var doc in boletasSnapshot.docs) {
        final data = doc.data();
        final conforme = data['conforme']?.toString().toLowerCase() ?? '';
        if (conforme == 'si' || conforme == 'sí' || conforme == 'conforme') {
          conformes++;
        } else if (conforme == 'no' || conforme == 'no conforme') {
          noConformes++;
        }
      }

      if (mounted) {
        setState(() {
          _stats = {
            'totalBoletas': boletasSnapshot.docs.length,
            'boletasHoy': boletasHoySnapshot.docs.length,
            'conformes': conformes,
            'noConformes': noConformes,
          };
        });
      }
    } catch (e) {
      print('Error al cargar estadísticas: $e');
      // No mostrar error al usuario, solo usar valores por defecto
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.currentUser.nombreCompleto}'),
        backgroundColor: AppTheme.primaryRed,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Cerrar Sesión'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          FiscalizacionFormScreen(currentUser: widget.currentUser),
          HistorialScreen(onBack: () {  },),
          ImpresorasScreen(onBack: () {  },),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppTheme.primaryRed,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Nueva Boleta',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.print),
            label: 'Impresoras',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del usuario
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.primaryRed,
                      child: Text(
                        widget.currentUser.nombreCompleto
                            .split(' ')
                            .map((name) => name.isNotEmpty ? name[0] : '')
                            .take(2)
                            .join()
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentUser.nombreCompleto,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Código: ${widget.currentUser.codigoFiscalizador}',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'Rol: ${widget.currentUser.rol.toUpperCase()}',
                            style: TextStyle(
                              color: AppTheme.primaryRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Estadísticas
            const Text(
              'Resumen de Actividad',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Grid de estadísticas - Diseño mejorado para evitar overflow
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3, // ✅ AJUSTADO: Más altura para evitar overflow
              children: [
                _buildStatCard(
                  'Total Boletas',
                  _stats['totalBoletas'].toString(),
                  Icons.description,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Boletas Hoy',
                  _stats['boletasHoy'].toString(),
                  Icons.today,
                  Colors.green,
                ),
                _buildStatCard(
                  'Conformes',
                  _stats['conformes'].toString(),
                  Icons.check_circle,
                  Colors.teal,
                ),
                _buildStatCard(
                  'No Conformes',
                  _stats['noConformes'].toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Acciones rápidas
            const Text(
              'Acciones Rápidas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildQuickActionCard(
              'Nueva Fiscalización',
              'Crear una nueva boleta de fiscalización',
              Icons.add_circle_outline,
              AppTheme.primaryRed,
              () => setState(() => _selectedIndex = 1),
            ),
            
            const SizedBox(height: 12),
            
            _buildQuickActionCard(
              'Ver Historial',
              'Consultar boletas anteriores',
              Icons.history,
              Colors.blue,
              () => setState(() => _selectedIndex = 2),
            ),
            
            const SizedBox(height: 12),
            
            _buildQuickActionCard(
              'Configurar Impresora',
              'Gestionar impresoras térmicas',
              Icons.print,
              Colors.orange,
              () => setState(() => _selectedIndex = 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12), // ✅ REDUCIDO: Menos padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28), // ✅ REDUCIDO: Icono más pequeño
            const SizedBox(height: 6), // ✅ REDUCIDO: Menos espacio
            Text(
              value,
              style: TextStyle(
                fontSize: 22, // ✅ REDUCIDO: Texto más pequeño
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2), // ✅ REDUCIDO: Menos espacio
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12, // ✅ REDUCIDO: Texto más pequeño
                color: Colors.grey,
              ),
              maxLines: 2, // ✅ AGREGADO: Máximo 2 líneas
              overflow: TextOverflow.ellipsis, // ✅ AGREGADO: Ellipsis si es muy largo
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Está seguro que desea cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}
