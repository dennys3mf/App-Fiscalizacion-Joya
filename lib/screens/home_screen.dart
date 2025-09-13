import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';

// Paleta y gradiente inspirados en Diia
const Color fondoGradienteInicio = Color(0xFFB2E2E2); // Verde-azul pastel
const Color fondoGradienteFin = Color(0xFFFFE2E2); // Rosa pastel
const Color cardColor = Color(0xFFEAF6FB); // Celeste muy claro
const Color cardShadow = Color(0x22000000); // Sombra sutil
const Color textoPrincipal = Color(0xFF181818); // Negro profundo
const Color textoSecundario = Color(0xFF6B6B6B); // Gris oscuro
const Color acento = Color(0xFFE60000); // Rojo vibrante
const Color azulDiia = Color(0xFF007AFF); // Azul acento

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required String username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = '';

  @override
  void initState() {
    super.initState();
    _cargarNombreUsuario();
  }

  Future<void> _cargarNombreUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Usuario';
    });
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Limpiamos todos los datos guardados

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [fondoGradienteInicio, fondoGradienteFin],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Inicio',
              style: textTheme.displayLarge?.copyWith(
                color: textoPrincipal,
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 32,
              )),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: acento, size: 28),
              tooltip: 'Salir',
              onPressed: _cerrarSesion,
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Material(
              elevation: 6.0,
              borderRadius: BorderRadius.circular(20.0),
              color: cardColor,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: const [
                    BoxShadow(
                      color: cardShadow,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido',
                      style: textTheme.headlineMedium?.copyWith(
                        color: textoPrincipal,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize:
                            28, // Ajusta el tamaño para que no sea tan grande
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                        'Gestiona y visualiza tus fiscalizaciones de manera moderna y segura.',
                        style: textTheme.bodyLarge?.copyWith(
                            color: textoSecundario, fontFamily: 'Inter')),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline,
                          color: textoPrincipal),
                      label: const Text('Nueva Fiscalización',
                          style: TextStyle(
                              fontFamily: 'Inter', color: textoPrincipal)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 218, 221, 23),
                        foregroundColor: textoPrincipal,
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed('/fiscalizacion_form');
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print, color: azulDiia),
                      label: const Text('Configurar impresora',
                          style:
                              TextStyle(fontFamily: 'Inter', color: azulDiia)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cardColor,
                        foregroundColor: azulDiia,
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        side: const BorderSide(color: azulDiia, width: 2),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed('/impresoras');
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.history, color: textoSecundario),
                      label: const Text('Historial',
                          style: TextStyle(
                              fontFamily: 'Inter', color: textoSecundario)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cardColor,
                        foregroundColor: textoSecundario,
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        side:
                            const BorderSide(color: textoSecundario, width: 2),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed('/historial');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
