import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart'; // <-- MEJORA: Importamos el modelo de usuario

class HomeScreen extends StatefulWidget { // <-- MEJORA: Convertido a StatefulWidget
  final void Function(String) onNavigate;
  final String username; // Este campo ya no es tan necesario, pero lo mantenemos por compatibilidad

  const HomeScreen({super.key, required this.onNavigate, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- MEJORA: Lógica para obtener y guardar los datos del usuario actual ---
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _currentUser = UserModel.fromMap(doc.data()!);
          _isLoading = false;
        });
      } else {
         if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      // Opcional: mostrar un error si no se pueden cargar los datos del perfil
    }
  }
  // --- FIN DE LA MEJORA ---

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // El AuthWrapper se encargará de redirigir
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- MEJORA: Muestra un indicador de carga mientras se obtienen los datos ---
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryRed)),
      );
    }
    // --- FIN DE LA MEJORA ---

    // --- MEJORA: Usa el nombre real del perfil del usuario ---
    final userName = _currentUser?.nombreCompleto ?? "Inspector";
    // --- FIN DE LA MEJORA ---

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 50,
              height: 35,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryRed.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset('assets/images/eslogan.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            const Text('Fiscalización', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.mutedForeground),
            onPressed: () => _logout(context),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline, color: AppTheme.primaryRed),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hola, $userName', style: Theme.of(context).textTheme.titleLarge),
                        const Text(
                          '¿Qué necesitas hacer hoy?',
                          style: TextStyle(color: AppTheme.mutedForeground, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildActionCard(
                  context: context,
                  title: 'Nueva Fiscalización',
                  subtitle: 'Iniciar inspección vehicular',
                  icon: Icons.add,
                  iconColor: Colors.white,
                  iconBackgroundColor: AppTheme.primaryGradient,
                  onTap: () => widget.onNavigate('/fiscalizacion_form'),
                  isPrimary: true,
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  context: context,
                  title: 'Configurar Impresora',
                  subtitle: 'Configurar dispositivo',
                  icon: Icons.print_outlined,
                  iconColor: AppTheme.foregroundDark,
                  iconBackgroundColor: LinearGradient(colors: [Colors.grey.shade200, Colors.grey.shade300]),
                  onTap: () => widget.onNavigate('/impresoras'),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  context: context,
                  title: 'Historial de Boletas',
                  subtitle: 'Ver boletas emitidas',
                  icon: Icons.article_outlined,
                  iconColor: AppTheme.primaryRed,
                  iconBackgroundColor: LinearGradient(colors: [AppTheme.primaryRed.withOpacity(0.1), AppTheme.primaryRed.withOpacity(0.2)]),
                  onTap: () => widget.onNavigate('/historial'),
                ),

                // --- MEJORA: Botón de administrador condicional ---
                if (_currentUser?.rol == 'gerente') ...[
                  const SizedBox(height: 16),
                  _buildActionCard(
                    context: context,
                    title: 'Gestionar Inspectores',
                    subtitle: 'Añadir o ver personal',
                    icon: Icons.admin_panel_settings_outlined,
                    iconColor: AppTheme.primaryRed,
                    iconBackgroundColor: LinearGradient(colors: [AppTheme.primaryRed.withOpacity(0.1), AppTheme.primaryRed.withOpacity(0.2)]),
                    onTap: () => widget.onNavigate('/dashboard'),
                  ),
                ],
                // --- FIN DE LA MEJORA ---

                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryRed.withOpacity(0.1)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estado del sistema', style: TextStyle(color: AppTheme.mutedForeground)),
                      Row(
                        children: [
                          BlinkingDot(),
                          SizedBox(width: 8),
                          Text('Operativo', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Gradient iconBackgroundColor,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Card(
      elevation: 8,
      shadowColor: AppTheme.primaryRed.withOpacity(0.1),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: isPrimary ? LinearGradient(colors: [Colors.white, AppTheme.primaryRed.withOpacity(0.05)]) : null,
            color: isPrimary ? null : Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: iconBackgroundColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, color: iconColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: AppTheme.mutedForeground, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right, color: AppTheme.mutedForeground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BlinkingDot extends StatefulWidget {
  const BlinkingDot({super.key});

  @override
  State<BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}