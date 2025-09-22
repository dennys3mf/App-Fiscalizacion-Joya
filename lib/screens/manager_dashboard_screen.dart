// Wrapper que reutiliza el AdminDashboardScreen (diseño React) para gerentes
import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';

class ManagerDashboardScreen extends StatelessWidget {
  final VoidCallback onBack;
  const ManagerDashboardScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return AdminDashboardScreen(onBack: onBack);
  }
}
