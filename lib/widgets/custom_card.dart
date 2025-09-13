// lib/widgets/custom_card.dart

import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;

  const CustomCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Definimos el color oscuro de la superficie aquí directamente.
    const Color superficieOscura = Color(0xFF1E1E1E);

    return Card(
      // Usamos los estilos que queríamos
      color: superficieOscura,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      // Añadimos un margen estándar
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child, // Mostramos el contenido que nos pasen
      ),
    );
  }
}