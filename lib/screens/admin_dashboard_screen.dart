// lib/screens/admin_dashboard_screen.dart (diseño adaptado estilo Manager)
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:cloud_firestore/cloud_firestore.dart'; // Evitamos lecturas directas en Web
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/boleta_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onBack;
  const AdminDashboardScreen({super.key, required this.onBack});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Opcional: URLs de funciones v2 (run.app) si tu proyecto las usa.
  // Deja en blanco si usas cloudfunctions.net. Si migraste a v2, pega aquí
  // el URL exacto desde Firebase Console por función.
  static const String _runAppListBoletasUrl = '';
  static const String _runAppGetDashboardUrl = '';

  // Estados para filtros
  String _searchTerm = '';
  String _photoSearchTerm = '';
  String _selectedInspector = 'Todos los inspectores';
  String _selectedEstado = 'Todos los estados';
  // Estados para modales
  BoletaModel? _selectedPhoto;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // (Se eliminó formateo de fecha no utilizado)

  // Normalizador simple para comparar valores de texto (case-insensible)
  String _norm(String? v) => (v ?? '').trim().toLowerCase();

  String _formatMoney(num? v) {
    if (v == null || v == 0) return 'Sin multa';
    return 'S/ ${v.toStringAsFixed(2)}';
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';
  String _formatDateFromMillis(dynamic millis) {
    if (millis == null) return '';
    final m = millis is int ? millis : int.tryParse(millis.toString());
    if (m == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(m);
    final h12 = ((d.hour + 11) % 12) + 1;
    final ampm = d.hour < 12 ? 'a. m.' : 'p. m.';
    return '${d.day}/${d.month}, ${h12}:${_two(d.minute)} $ampm';
  }

  // Helpers CF

  // Intenta GET con Authorization Bearer sobre la primera URL que responda 200.
  Future<Map<String, dynamic>> _getJsonFromFirstAvailable(
      List<String> urls) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null) throw Exception('Usuario no autenticado');
    Object? lastErr;
    for (final u in urls) {
      try {
        final resp = await http.get(Uri.parse(u), headers: {
          'Authorization': 'Bearer $token',
        });
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
          return Map<String, dynamic>.from(decoded as Map);
        }
        lastErr = Exception('HTTP ${resp.statusCode}: ${resp.body} ($u)');
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? Exception('No hubo respuesta válida');
  }

  Future<Map<String, dynamic>> _loadDashboardDataCF() async {
    // On web, use the HTTP+CORS endpoint to avoid callable protocol hiccups
    if (kIsWeb) {
      return _getJsonFromFirstAvailable([
        'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/getDashboardDataHttp',
        if (_runAppGetDashboardUrl.isNotEmpty) _runAppGetDashboardUrl,
      ]);
    } else {
      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-west1')
          .httpsCallable('getDashboardData');
      final res = await fn.call<Map<String, dynamic>>({});
      return Map<String, dynamic>.from(res.data as Map);
    }
  }

  Color _getConformeColor(String conforme) {
    final n = _norm(conforme);
    if (n == 'sí' || n == 'si') return const Color(0xFFDCFCE7);
    if (n == 'no') return const Color(0xFFFEE2E2);
    if (n.startsWith('parcial')) return const Color(0xFFFEF3C7);
    return const Color(0xFFF3F4F6);
  }

  Color _getConformeTextColor(String conforme) {
    final n = _norm(conforme);
    if (n == 'sí' || n == 'si') return const Color(0xFF166534);
    if (n == 'no') return const Color(0xFF991B1B);
    if (n.startsWith('parcial')) return const Color(0xFF92400E);
    return const Color(0xFF374151);
  }

  Color _getEstadoColor(String estado) {
    final n = _norm(estado);
    if (n == 'activa' || n == 'activo') return const Color(0xFFDBEAFE);
    if (n == 'pagada' || n == 'pagado') return const Color(0xFFDCFCE7);
    if (n == 'anulada' || n == 'anulado') return const Color(0xFFFEE2E2);
    return const Color(0xFFF3F4F6);
  }

  Color _getEstadoTextColor(String estado) {
    final n = _norm(estado);
    if (n == 'activa' || n == 'activo') return const Color(0xFF1E40AF);
    if (n == 'pagada' || n == 'pagado') return const Color(0xFF166534);
    if (n == 'anulada' || n == 'anulado') return const Color(0xFF991B1B);
    return const Color(0xFF374151);
  }

  IconData _getConformeIcon(String conforme) {
    final n = _norm(conforme);
    if (n == 'sí' || n == 'si') return Icons.check_circle;
    if (n == 'no') return Icons.cancel;
    if (n.startsWith('parcial')) return Icons.warning;
    return Icons.help;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryRed.withOpacity(0.05),
              const Color(0xFFFDEDED).withOpacity(0.5),
              AppTheme.primaryRed.withOpacity(0.10),
            ],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                children: [
                  // Header igual que React
                  _buildHeader(),

                  // Stats Cards igual que React
                  _buildStatsCards(),

                  // Tabs igual que React
                  Expanded(child: _buildTabsContent()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryRed.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo y título igual que React
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 24,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo_muni_joya.png',
                    color: AppTheme.primaryRed,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Panel Administrativo',
                      style: TextStyle(
                        color: AppTheme.primaryRed,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Gestión de Fiscalización - Gerente Municipal',
                      style: TextStyle(
                        color: AppTheme.mutedForeground,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions igual que React
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield,
                      color: Color(0xFF166534),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Administrador',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _exportBoletasCsv,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Exportar'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                color: AppTheme.mutedForeground,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _loadDashboardDataCF(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorBox(
              title: 'Error cargando métricas (CF)',
              error: snapshot.error,
            );
          }
          final data = snapshot.data ?? const {};
          final totalBoletas = (data['totalBoletas'] ?? 0) as int;
          final totalConformes = (data['totalConformes'] ?? 0) as int;
          final totalNoConformes = (data['totalNoConformes'] ?? 0) as int;
          final totalParciales = (data['totalParciales'] ?? 0) as int;
          final totalMultas = (data['totalMultas'] ?? 0).toDouble();
          final inspectoresActivos = (data['inspectoresActivos'] ?? 0) as int;
          final totalInspectores = (data['totalInspectores'] ?? 0) as int;

          return LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 1100
                  ? 5
                  : constraints.maxWidth > 800
                      ? 3
                      : constraints.maxWidth > 600
                          ? 2
                          : 1;

              // Make tiles a bit taller when many columns to avoid overflow
              final childAspectRatio =
                  crossAxisCount >= 5 ? 2.0 : (crossAxisCount == 3 ? 2.4 : 2.0);

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
                children: [
                  _buildStatCard(
                      'Total Boletas',
                      '$totalBoletas',
                      Icons.description,
                      const Color(0xFF3B82F6),
                      const Color(0xFFEFF6FF)),
                  _buildStatCard(
                      'Conformes',
                      '$totalConformes',
                      Icons.check_circle,
                      const Color(0xFF10B981),
                      const Color(0xFFECFDF5)),
                  _buildStatCard(
                      'No Conformes',
                      '$totalNoConformes',
                      Icons.cancel,
                      const Color(0xFFEF4444),
                      const Color(0xFFFEF2F2)),
                  _buildStatCard('Parciales', '$totalParciales', Icons.warning,
                      const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
                  _buildStatCard(
                      'Inspectores',
                      '$inspectoresActivos/$totalInspectores',
                      Icons.people,
                      const Color(0xFF8B5CF6),
                      const Color(0xFFF5F3FF)),
                  _buildStatCard(
                      'Total Multas',
                      'S/ ${totalMultas.toInt()}',
                      Icons.trending_up,
                      const Color(0xFFF59E0B),
                      const Color(0xFFFFFBEB)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color iconColor, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            backgroundColor.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRed.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [iconColor, iconColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsContent() {
    return Column(
      children: [
        // Tab Bar igual que React
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.primaryRed.withOpacity(0.1),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppTheme.primaryRed,
            unselectedLabelColor: AppTheme.mutedForeground,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Gestión de Boletas'),
              Tab(text: 'Fotos de Licencias'),
              Tab(text: 'Gestión de Inspectores'),
              Tab(text: 'Reportes y Análisis'),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBoletasTab(),
                _buildFotosTab(),
                _buildInspectoresTab(),
                _buildReportesTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoletasTab() {
    return Column(
      children: [
        // Filtros igual que React
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryRed.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Buscador
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por placa, empresa, conductor...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.mutedGray.withOpacity(0.3),
                      ),
                      onChanged: (value) => setState(() => _searchTerm = value),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Botón Nueva Boleta
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nueva Boleta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Lista de boletas igual que React
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FutureBuilder<Map<String, dynamic>>(
              future: () async {
                if (kIsWeb) {
                  return _getJsonFromFirstAvailable([
                    'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/listBoletasHttp?limit=500',
                    if (_runAppListBoletasUrl.isNotEmpty)
                      '$_runAppListBoletasUrl?limit=500',
                  ]);
                } else {
                  final res = await FirebaseFunctions.instanceFor(
                          region: 'southamerica-west1')
                      .httpsCallable('listBoletas')
                      .call(<String, dynamic>{'limit': 500});
                  return Map<String, dynamic>.from(res.data as Map);
                }
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorBox(
                    title: 'Error cargando boletas (CF)',
                    error: snapshot.error,
                  );
                }
                final data = snapshot.data ?? const <String, dynamic>{};
                final items = (data['items'] as List<dynamic>? ?? []);
                if (items.isEmpty) {
                  return const Center(
                      child: Text('No hay boletas para mostrar'));
                }

                // Filtro de búsqueda en memoria
                var filtered = items.where((raw) {
                  final m = raw as Map<String, dynamic>;
                  final placa = (m['placa'] ?? '').toString().toLowerCase();
                  final empresa = (m['empresa'] ?? '').toString().toLowerCase();
                  final conductor =
                      (m['conductor'] ?? m['nombreConductor'] ?? '')
                          .toString()
                          .toLowerCase();
                  final s = _searchTerm.toLowerCase();
                  return s.isEmpty ||
                      placa.contains(s) ||
                      empresa.contains(s) ||
                      conductor.contains(s);
                }).toList();

                // Opciones de inspector para filtro
                final inspectorSet = <String>{'Todos los inspectores'};
                for (final raw in items) {
                  final mm = raw as Map<String, dynamic>;
                  final ins =
                      (mm['inspectorNombre'] ?? mm['inspectorEmail'] ?? '')
                          .toString();
                  if (ins.isNotEmpty) inspectorSet.add(ins);
                }

                // Aplicar filtros seleccionados
                if (_selectedInspector != 'Todos los inspectores') {
                  filtered = filtered.where((raw) {
                    final m = raw as Map<String, dynamic>;
                    final ins =
                        (m['inspectorNombre'] ?? m['inspectorEmail'] ?? '')
                            .toString();
                    return ins == _selectedInspector;
                  }).toList();
                }
                if (_selectedEstado != 'Todos los estados') {
                  filtered = filtered.where((raw) {
                    final m = raw as Map<String, dynamic>;
                    final est = (m['estado'] ?? '').toString();
                    return est == _selectedEstado;
                  }).toList();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      PopupMenuButton<String>(
                        tooltip: 'Filtrar por inspector',
                        onSelected: (v) =>
                            setState(() => _selectedInspector = v),
                        child: _FilterChipLike(label: _selectedInspector),
                        itemBuilder: (context) => inspectorSet
                            .map((e) =>
                                PopupMenuItem<String>(value: e, child: Text(e)))
                            .toList(),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Filtrar por estado',
                        onSelected: (v) => setState(() => _selectedEstado = v),
                        child: _FilterChipLike(label: _selectedEstado),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                              value: 'Todos los estados',
                              child: Text('Todos los estados')),
                          PopupMenuItem(value: 'Activa', child: Text('Activa')),
                          PopupMenuItem(value: 'Pagada', child: Text('Pagada')),
                          PopupMenuItem(
                              value: 'Anulada', child: Text('Anulada')),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final m = filtered[index] as Map<String, dynamic>;
                          return _buildBoletaCardFromMap(m);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFotosTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryRed.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por placa, empresa o conductor...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppTheme.mutedGray.withOpacity(0.3),
                  ),
                  onChanged: (v) => setState(() => _photoSearchTerm = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FutureBuilder<Map<String, dynamic>>(
              future: () async {
                if (kIsWeb) {
                  return _getJsonFromFirstAvailable([
                    'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/listBoletasHttp?limit=500&withPhotos=true',
                    if (_runAppListBoletasUrl.isNotEmpty)
                      '$_runAppListBoletasUrl?limit=500&withPhotos=true',
                  ]);
                } else {
                  final res = await FirebaseFunctions.instanceFor(
                          region: 'southamerica-west1')
                      .httpsCallable('listBoletas')
                      .call(
                          <String, dynamic>{'limit': 500, 'withPhotos': true});
                  return Map<String, dynamic>.from(res.data as Map);
                }
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorBox(
                    title: 'Error cargando fotos (CF)',
                    error: snapshot.error,
                  );
                }
                final items = (snapshot.data?['items'] as List<dynamic>? ?? []);
                if (items.isEmpty) {
                  return const Center(child: Text('No hay fotos disponibles'));
                }

                final filtered = items.where((raw) {
                  final m = raw as Map<String, dynamic>;
                  final url = ((m['fotoLicencia'] ?? m['urlFotoLicencia'])
                          ?.toString() ??
                      '');
                  if (url.isEmpty) return false;
                  final placa = (m['placa'] ?? '').toString().toLowerCase();
                  final empresa = (m['empresa'] ?? '').toString().toLowerCase();
                  final conductor =
                      (m['conductor'] ?? m['nombreConductor'] ?? '')
                          .toString()
                          .toLowerCase();
                  final s = _photoSearchTerm.toLowerCase();
                  return s.isEmpty ||
                      placa.contains(s) ||
                      empresa.contains(s) ||
                      conductor.contains(s);
                }).toList();

                return LayoutBuilder(builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  int cross = width > 1200
                      ? 5
                      : width > 900
                          ? 4
                          : width > 600
                              ? 3
                              : 2;
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final m = filtered[i] as Map<String, dynamic>;
                      return _buildPhotoCardFromMap(m);
                    },
                  );
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // Helper para card de boleta basado en Map (datos desde Cloud Functions)
  Widget _buildBoletaCardFromMap(Map<String, dynamic> m) {
    final placa = (m['placa'] ?? 'N/A').toString();
    final empresa = (m['empresa'] ?? 'N/A').toString();
    final conductor =
        (m['conductor'] ?? m['nombreConductor'] ?? 'N/A').toString();
    final conforme = (m['conforme'] ?? 'No').toString();
    final estado = (m['estado'] ?? 'Activa').toString();
    final multa = m['multa'];
    final motivo = (m['motivo'] ?? m['infraccion'] ?? 'N/A').toString();
    final inspector =
        (m['inspectorNombre'] ?? m['inspectorEmail'] ?? 'N/A').toString();
    final fotoLicencia = (m['fotoLicencia'] ?? m['urlFotoLicencia']);
    final numeroLicencia = (m['numeroLicencia'] ?? '—').toString();
    final fechaTxt = _formatDateFromMillis(m['fecha']);
    final id = (m['id'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.mutedGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long,
                    color: AppTheme.primaryRed, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Placa: $placa',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(empresa,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.mutedForeground)),
                  ],
                ),
              ),
              _Pill(
                  text: conforme,
                  bg: _getConformeColor(conforme),
                  fg: _getConformeTextColor(conforme),
                  icon: _getConformeIcon(conforme)),
              const SizedBox(width: 8),
              _Pill(
                  text: estado,
                  bg: _getEstadoColor(estado),
                  fg: _getEstadoTextColor(estado)),
              const SizedBox(width: 8),
              Row(children: [
                IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.visibility, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints()),
                IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints()),
                IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints()),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLine(label: 'Conductor', value: conductor),
                    _FieldLine(label: 'Motivo', value: motivo),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLine(label: 'Licencia', value: numeroLicencia),
                    _FieldLine(label: 'Inspector', value: inspector),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLine(label: 'Fecha', value: fechaTxt),
                    _FieldLine(
                        label: 'Multa',
                        value: _formatMoney(multa is num ? multa : null),
                        valueColor: (multa is num && multa > 0)
                            ? Colors.red
                            : const Color(0xFF10B981)),
                  ],
                ),
              ),
            ],
          ),
          if (fotoLicencia != null && fotoLicencia.toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                final boleta = BoletaModel(
                  id: id,
                  placa: placa,
                  empresa: empresa,
                  numeroLicencia: numeroLicencia,
                  conductor: conductor,
                  codigoFiscalizador:
                      (m['codigoFiscalizador'] ?? inspector ?? 'N/A')
                          .toString(),
                  motivo: motivo,
                  conforme: conforme,
                  descripciones: m['descripciones']?.toString(),
                  observaciones: m['observaciones']?.toString(),
                  inspectorId: (m['inspectorId'] ?? 'unknown').toString(),
                  inspectorEmail: m['inspectorEmail']?.toString(),
                  inspectorNombre: inspector,
                  multa: multa is num ? multa.toDouble() : null,
                  estado: estado,
                  fecha: DateTime.now(),
                  urlFotoLicencia: fotoLicencia?.toString(),
                );
                _showPhotoViewer(boleta);
              },
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Ver Foto de Licencia'),
            ),
          ],
        ],
      ),
    );
  }

  // Inspectores tab (CF)
  Widget _buildInspectoresTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.groups, color: AppTheme.primaryRed),
            const SizedBox(width: 8),
            const Text('Gestión de Inspectores',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showCreateInspectorDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nuevo Inspector'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _loadDashboardDataCF(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _ErrorBox(
                    title: 'Error cargando inspectores (CF)',
                    error: snap.error);
              }
              final data = snap.data ?? const {};
              final list = List<Map<String, dynamic>>.from(
                  data['inspectores'] ?? const []);
              if (list.isEmpty)
                return const Center(child: Text('No hay inspectores'));

              return LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                int cross = w > 1200
                    ? 3
                    : w > 800
                        ? 2
                        : 1;
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.7,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final m = list[i];
                    final nombre =
                        (m['nombreCompleto'] ?? 'Inspector').toString();
                    final email = (m['email'] ?? '').toString();
                    final telefono = (m['telefono'] ?? '').toString();
                    final codigo = (m['codigoFiscalizador'] ?? '').toString();
                    final estado = (m['estado'] ?? 'Inactivo').toString();
                    final boletas = (m['boletas'] ?? 0) as int;
                    final conformes = (m['conformes'] ?? 0) as int;
                    final noConformes = (m['noConformes'] ?? 0) as int;
                    final tasa = boletas == 0 ? 0.0 : (conformes / boletas);
                    final initials = nombre.trim().isEmpty
                        ? 'IN'
                        : nombre
                            .split(RegExp(r"\s+"))
                            .map((p) => p.isNotEmpty ? p[0] : '')
                            .take(2)
                            .join()
                            .toUpperCase();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: AppTheme.primaryRed.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4)),
                          ]),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              CircleAvatar(
                                  backgroundColor:
                                      AppTheme.primaryRed.withOpacity(0.15),
                                  foregroundColor: AppTheme.primaryRed,
                                  child: Text(initials)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(nombre,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text(codigo,
                                        style: TextStyle(
                                            color: AppTheme.mutedForeground,
                                            fontSize: 12)),
                                  ])),
                              _Pill(
                                  text: estado,
                                  bg: estado == 'Activo'
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEE2E2),
                                  fg: estado == 'Activo'
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF991B1B)),
                            ]),
                            const SizedBox(height: 12),
                            _FieldLine(label: 'Email', value: email),
                            _FieldLine(label: 'Teléfono', value: telefono),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: _FieldLine(
                                      label: 'Boletas:', value: '$boletas')),
                              Expanded(
                                  child: _FieldLine(
                                      label: 'Conformes:',
                                      value: '$conformes')),
                              Expanded(
                                  child: _FieldLine(
                                      label: 'No Conformes:',
                                      value: '$noConformes')),
                            ]),
                            const SizedBox(height: 8),
                            Text('Tasa de Conformidad',
                                style: TextStyle(
                                    color: AppTheme.mutedForeground,
                                    fontSize: 12)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                  value: tasa.clamp(0, 1),
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  color: AppTheme.primaryRed),
                            ),
                            const SizedBox(height: 8),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                      onPressed: () {},
                                      icon: const Icon(Icons.edit, size: 18)),
                                  IconButton(
                                      onPressed: () {},
                                      icon: const Icon(Icons.delete,
                                          size: 18, color: Colors.red)),
                                ]),
                          ]),
                    );
                  },
                );
              });
            },
          ),
        ),
      ],
    );
  }

  void _showCreateInspectorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String nombre = '';
        String codigo = '';
        String email = '';
        String telefono = '';
        String estado = 'Activo';
        String password = '';
        bool loading = false;
        return StatefulBuilder(builder: (context, setS) {
          Future<void> submit() async {
            if (loading) return;
            setS(() => loading = true);
            try {
              final fn =
                  FirebaseFunctions.instanceFor(region: 'southamerica-west1')
                      .httpsCallable('crearInspector');
              await fn.call({
                'nombreCompleto': nombre,
                'email': email,
                'password': password,
                'codigoFiscalizador': codigo,
                'telefono': telefono,
                'estado': estado,
              });
              if (context.mounted) Navigator.of(context).pop();
              if (mounted) setState(() {});
            } catch (e) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Error: $e')));
            } finally {
              setS(() => loading = false);
            }
          }

          InputDecoration deco(String hint) => InputDecoration(
                hintText: hint,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              );

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Crear Nuevo Inspector',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            onChanged: (v) => nombre = v,
                            decoration: deco('Nombre completo'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            onChanged: (v) => codigo = v,
                            decoration: deco('Código de Inspector'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            onChanged: (v) => email = v,
                            decoration: deco('Correo electrónico'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            onChanged: (v) => telefono = v,
                            decoration: deco('Teléfono'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            onChanged: (v) => password = v,
                            decoration: deco('Contraseña'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: estado,
                        decoration: deco('Estado'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Activo', child: Text('Activo')),
                          DropdownMenuItem(
                              value: 'Inactivo', child: Text('Inactivo')),
                        ],
                        onChanged: (v) => setS(() => estado = v ?? 'Activo'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: loading ? null : submit,
                      icon: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save, size: 16),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white),
                    ),
                  ]),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // Helper para card de foto basado en Map
  Widget _buildPhotoCardFromMap(Map<String, dynamic> m) {
    final url = ((m['fotoLicencia'] ?? m['urlFotoLicencia'])?.toString() ?? '');
    final placa = (m['placa'] ?? 'N/A').toString();
    final empresa = (m['empresa'] ?? 'N/A').toString();
    final conductor =
        (m['conductor'] ?? m['nombreConductor'] ?? 'N/A').toString();
    final conforme = (m['conforme'] ?? 'No').toString();
    final id = (m['id'] ?? '').toString();

    return InkWell(
      onTap: () {
        final boleta = BoletaModel(
          id: id,
          placa: placa,
          empresa: empresa,
          numeroLicencia: (m['numeroLicencia'] ?? 'N/A').toString(),
          conductor: conductor,
          codigoFiscalizador: (m['codigoFiscalizador'] ?? '').toString(),
          motivo: (m['motivo'] ?? m['infraccion'] ?? 'N/A').toString(),
          conforme: conforme,
          inspectorId: (m['inspectorId'] ?? 'unknown').toString(),
          fecha: DateTime.now(),
          urlFotoLicencia: url,
        );
        if (boleta.urlFotoLicencia != null &&
            boleta.urlFotoLicencia!.isNotEmpty) {
          _showPhotoViewer(boleta);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryRed.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Placa: $placa',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getConformeColor(conforme),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(conforme,
                            style: TextStyle(
                                fontSize: 10,
                                color: _getConformeTextColor(conforme))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(empresa,
                      style: TextStyle(
                          color: AppTheme.mutedForeground, fontSize: 12)),
                  Text('Conductor: $conductor',
                      style: TextStyle(
                          color: AppTheme.mutedForeground, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // (Tab de Inspectores se cubre usando AdminInspectoresScreen)

  Widget _buildReportesTab() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _loadDashboardDataCF(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorBox(
              title: 'Error cargando reportes (CF)',
              error: snapshot.error,
            );
          }
          final data = snapshot.data ?? const {};
          final si = (data['totalConformes'] ?? 0) as int;
          final no = (data['totalNoConformes'] ?? 0) as int;
          final parcial = (data['totalParciales'] ?? 0) as int;
          final estados =
              Map<String, dynamic>.from((data['estados'] ?? const {}));
          final activa = (estados['activa'] ?? 0) as int;
          final pagada = (estados['pagada'] ?? 0) as int;
          final totalMultas = (data['totalMultas'] ?? 0).toDouble();
          final multasActivas = (data['multasActivas'] ?? activa) as int;
          final multasPagadas = (data['multasPagadas'] ?? pagada) as int;
          final promedioMulta = (data['promedioMulta'] ?? 0).toDouble();
          final inspectores = List<Map<String, dynamic>>.from(
              (data['inspectores'] ?? const []));
          final byInspector = <String, int>{
            for (final i in inspectores)
              (i['nombreCompleto'] ?? i['email'] ?? 'N/D').toString():
                  (i['boletas'] ?? 0) as int,
          };

          // Helper para barras simples
          Widget bar(String label, int value, int max, Color color) {
            final ratio = max == 0 ? 0.0 : value / max;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label: $value'),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio.clamp(0, 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final maxConf =
              [si, no, parcial].fold<int>(0, (p, c) => c > p ? c : p);
          final inspectorMax =
              byInspector.values.fold<int>(0, (p, c) => c > p ? c : p);

          return SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distribución de Conformidad (izquierda)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryRed.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: const [
                              Icon(Icons.bar_chart, color: AppTheme.primaryRed),
                              SizedBox(width: 8),
                              Text('Distribución de Conformidad',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 12),
                            bar('Conforme', si, maxConf,
                                const Color(0xFF10B981)),
                            const SizedBox(height: 8),
                            bar('No Conforme', no, maxConf,
                                const Color(0xFFEF4444)),
                            const SizedBox(height: 8),
                            bar('Parcialmente', parcial, maxConf,
                                const Color(0xFFF59E0B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Estadísticas de Multas (derecha)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryRed.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: const [
                              Icon(Icons.trending_up,
                                  color: AppTheme.primaryRed),
                              SizedBox(width: 8),
                              Text('Estadísticas de Multas',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 12),
                            _statRow('Total Recaudado',
                                'S/ ${totalMultas.toStringAsFixed(2)}',
                                color: const Color(0xFFEF4444)),
                            const SizedBox(height: 8),
                            _statRow('Multas Activas', '$multasActivas',
                                color: const Color(0xFF60A5FA)),
                            const SizedBox(height: 8),
                            _statRow('Multas Pagadas', '$multasPagadas',
                                color: const Color(0xFF34D399)),
                            const SizedBox(height: 8),
                            _statRow('Promedio por Multa',
                                'S/ ${promedioMulta.toStringAsFixed(2)}',
                                color: const Color(0xFFF59E0B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Boletas por inspector (opcional)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryRed.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Boletas por inspector',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      ...byInspector.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: bar(e.key, e.value, inspectorMax,
                                AppTheme.primaryRed.withOpacity(0.8)),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statRow(String label, String value, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showPhotoViewer(BoletaModel boleta) {
    setState(() {
      _selectedPhoto = boleta;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _buildPhotoViewerDialog(),
    );
  }

  Future<void> _exportBoletasCsv() async {
    try {
      List<Map<String, dynamic>> items;

      if (kIsWeb) {
        // Usa HTTP+CORS en Web, con fallback a run.app si está configurado
        final data = await _getJsonFromFirstAvailable([
          'https://southamerica-west1-app-fiscalizacion-joya.cloudfunctions.net/listBoletasHttp?limit=2000',
          if (_runAppListBoletasUrl.isNotEmpty)
            '$_runAppListBoletasUrl?limit=2000',
        ]);
        items = (data['items'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        final callable =
            FirebaseFunctions.instanceFor(region: 'southamerica-west1')
                .httpsCallable('listBoletas');
        final res = await callable.call<Map<String, dynamic>>({'limit': 2000});
        items = (res.data['items'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay boletas para exportar')),
          );
        }
        return;
      }

      String esc(dynamic v) {
        final s = (v ?? '').toString();
        // CSV escape
        final needsQuotes = s.contains(',') ||
            s.contains('"') ||
            s.contains('\n') ||
            s.contains('\r');
        final q = s.replaceAll('"', '""');
        return needsQuotes ? '"$q"' : q;
      }

      String millis(dynamic v) {
        if (v == null) return '';
        if (v is int) return v.toString();
        return int.tryParse(v.toString())?.toString() ?? '';
      }

      final header = [
        'id',
        'placa',
        'empresa',
        'conductor',
        'numeroLicencia',
        'conforme',
        'estado',
        'multa',
        'motivo',
        'inspectorNombre',
        'inspectorEmail',
        'fechaMillis',
        'fecha',
        'urlFotoLicencia'
      ];
      final lines = <String>[];
      lines.add(header.join(','));
      for (final m in items) {
        final fechaM = m['fecha'];
        final fechaHumana = _formatDateFromMillis(fechaM);
        final row = [
          esc(m['id']),
          esc(m['placa']),
          esc(m['empresa']),
          esc(m['conductor'] ?? m['nombreConductor']),
          esc(m['numeroLicencia']),
          esc(m['conforme']),
          esc(m['estado']),
          esc(m['multa']),
          esc(m['motivo'] ?? m['infraccion']),
          esc(m['inspectorNombre']),
          esc(m['inspectorEmail']),
          millis(fechaM),
          esc(fechaHumana),
          esc(m['fotoLicencia'] ?? m['urlFotoLicencia']),
        ];
        lines.add(row.join(','));
      }

      // Add UTF-8 BOM for better Excel compatibility
      final csv = lines.join('\r\n');
      final csvWithBom = '\uFEFF$csv';

      if (kIsWeb) {
        final uri = Uri.dataFromString(csvWithBom,
            mimeType: 'text/csv', encoding: utf8);
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Exportar CSV disponible en Web por ahora')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exportando CSV: $e')),
        );
      }
    }
  }

  Widget _buildPhotoViewerDialog() {
    if (_selectedPhoto == null) return const SizedBox();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            // Header del modal igual que React
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt, color: AppTheme.primaryRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Licencia de Conducir - ${_selectedPhoto!.conductor}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Imagen y contenido igual que React
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Imagen
                    Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          _selectedPhoto!.urlFotoLicencia!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.image_not_supported, size: 48),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Información igual que React
                    Text(
                      'Información completa de: ${_selectedPhoto!.conductor}',
                      style: const TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 24),

                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final url = _selectedPhoto!.urlFotoLicencia;
                            if (url != null && url.isNotEmpty) {
                              final uri = Uri.tryParse(url);
                              if (uri != null) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            }
                          },
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Descargar Foto'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget de error igual que tu código original
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

// Small UI helpers
class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  const _Pill(
      {required this.text, required this.bg, required this.fg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
        ],
        Text(text,
            style: TextStyle(
                fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _FieldLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _FieldLine({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: TextStyle(color: AppTheme.mutedForeground, fontSize: 12)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12, color: valueColor ?? Colors.black87)),
          ),
        ],
      ),
    );
  }
}

class _FilterChipLike extends StatelessWidget {
  final String label;
  const _FilterChipLike({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.mutedGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.tune, size: 16, color: AppTheme.primaryRed),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.primaryRed),
      ]),
    );
  }
}
