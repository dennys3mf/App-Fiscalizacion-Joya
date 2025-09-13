// lib/screens/historial_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Boletas (Nube)'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Nos conectamos a la colección 'boletas' en Firestore
        stream: FirebaseFirestore.instance
            .collection('boletas')
            .orderBy('fecha',
                descending: true) // Mostramos las más recientes primero
            .snapshots(),

        builder: (context, snapshot) {
          // Mientras carga los datos
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Si hay un error
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los datos.'));
          }

          // Si no hay boletas guardadas
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hay boletas guardadas en la nube.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          // Si todo está bien, mostramos la lista
          final boletas = snapshot.data!.docs;

          return ListView.builder(
            itemCount: boletas.length,
            itemBuilder: (context, index) {
              final boletaData = boletas[index].data() as Map<String, dynamic>;

              // Firestore guarda la fecha como 'Timestamp', la convertimos a DateTime
              final fecha = (boletaData['fecha'] as Timestamp?)?.toDate() ??
                  DateTime.now();

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                      'Placa: ${boletaData['placa']?.toUpperCase() ?? 'S/P'}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(boletaData['empresa'] ?? 'Sin Empresa'),
                  trailing: Text(DateFormat('dd/MM/yy').format(fecha)),
                  onTap: () {
                    // Diálogo de detalles (lee del mapa de datos de Firestore)
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Detalles de Boleta (Nube)'),
                        content: SingleChildScrollView(
                          child: Text(
                              'Placa: ${boletaData['placa']?.toUpperCase()}\n'
                              'Empresa: ${boletaData['empresa']}\n'
                              'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}\n'
                              'Fiscalizador: ${boletaData['fiscalizador']}\n'
                              'Motivo: ${boletaData['motivo']}\n'
                              'Conforme: ${boletaData['conforme']}\n'
                              'Descripciones: ${boletaData['descripciones'] ?? 'Ninguna'}\n'
                              'Observaciones: ${boletaData['observaciones'] ?? 'Ninguna'}'),
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Cerrar'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
