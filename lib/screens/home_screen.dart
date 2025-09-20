import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart'; // Asegúrate de que la ruta a tu tema es correcta

class HomeScreen extends StatelessWidget {
  final void Function(String) onNavigate;

  const HomeScreen({super.key, required this.onNavigate, required String username});

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // El AuthWrapper se encargará de redirigir a la pantalla de login
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email ?? "Inspector";

    return Scaffold(
      // --- AppBar estilo Figma ---
      appBar: AppBar(
        automaticallyImplyLeading: false, // Oculta el botón de retroceso
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
              child: Image.asset(
                'assets/images/eslogan.png', // Logo del eslogan
                fit: BoxFit.contain,
              ),
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
          top: false, // La AppBar ya gestiona el safe area superior
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Saludo al Usuario ---
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
                         Text(
                          '¿Qué necesitas hacer hoy?',
                          style: TextStyle(color: AppTheme.mutedForeground, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // --- Tarjetas de Acción ---
                _buildActionCard(
                  context: context,
                  title: 'Nueva Fiscalización',
                  subtitle: 'Iniciar inspección vehicular',
                  icon: Icons.add,
                  iconColor: Colors.white,
                  iconBackgroundColor: AppTheme.primaryGradient,
                  onTap: () => onNavigate('/fiscalizacion_form'),
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
                  onTap: () => onNavigate('/impresoras'),
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  context: context,
                  title: 'Historial de Boletas',
                  subtitle: 'Ver boletas emitidas',
                  icon: Icons.article_outlined,
                  iconColor: AppTheme.primaryRed,
                  iconBackgroundColor: LinearGradient(colors: [AppTheme.primaryRed.withOpacity(0.1), AppTheme.primaryRed.withOpacity(0.2)]),
                  onTap: () => onNavigate('/historial'),
                ),

                const SizedBox(height: 40),

                // --- Información de Estado ---
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

  // --- Widget Reutilizable para Tarjetas de Acción ---
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

// Widget para el punto parpadeante
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