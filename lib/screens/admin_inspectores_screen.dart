import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AdminInspectoresScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AdminInspectoresScreen({super.key, required this.onBack});

  @override
  State<AdminInspectoresScreen> createState() => _AdminInspectoresScreenState();
}

class _AdminInspectoresScreenState extends State<AdminInspectoresScreen> {
  // --- INICIO DE LA MEJORA: Añadimos controlador para el código ---
  final _codigoController = TextEditingController();
  // --- FIN DE LA MEJORA ---
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController();
  String _estadoSeleccionado = 'Activo'; // Para el dropdow
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _codigoController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _crearInspector() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Obtenemos la instancia de las Cloud Functions
      final functions =
          FirebaseFunctions.instanceFor(region: 'southamerica-west1');
      // Obtenemos una referencia a nuestra función 'crearInspector'
      final callable = functions.httpsCallable('crearInspector');

      // Enviamos los datos del formulario a la función
      final result = await callable.call<Map<String, dynamic>>({
        'nombreCompleto': _nombreController.text.trim(),
        'codigoFiscalizador': _codigoController.text.trim().toUpperCase(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
      });

      // Mostramos el mensaje de éxito que nos devuelve la función
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.data['message'] ?? 'Operación completada'),
          backgroundColor: Colors.green,
        ),
      );

      // Limpiamos los campos después de la operación
      _nombreController.clear();
      _codigoController.clear();
      _emailController.clear();
      _passwordController.clear();
      _formKey.currentState?.reset();
    } on FirebaseFunctionsException catch (e) {
      // Mostramos un mensaje de error detallado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // Manejamos cualquier otro tipo de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocurrió un error inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
        title: const Text('Gestionar Inspectores'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Añadir Nuevo Inspector',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _codigoController,
                        decoration: const InputDecoration(
                            labelText: 'Código de Fiscalizador'),
                        validator: (value) =>
                            value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nombreController,
                        decoration:
                            const InputDecoration(labelText: 'Nombre Completo'),
                        validator: (value) =>
                            value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                            labelText: 'Correo Electrónico'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      // --- INICIO DE MEJORAS ---
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _telefonoController,
                        decoration:
                            const InputDecoration(labelText: 'Teléfono'),
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value!.isEmpty ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _estadoSeleccionado,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: ['Activo', 'Inactivo']
                            .map((estado) => DropdownMenuItem(
                                value: estado, child: Text(estado)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _estadoSeleccionado = value;
                            });
                          }
                        },
                      ),
                      // --- FIN DE MEJORAS ---
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                            labelText: 'Contraseña Temporal'),
                        validator: (value) => (value?.length ?? 0) < 6
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _crearInspector,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.add),
                          label: Text(
                              _isLoading ? 'Creando...' : 'Crear Inspector'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 2,
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No hay inspectores registrados.'));
                  }

                  final inspectores = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: inspectores.length,
                    itemBuilder: (context, index) {
                      final inspector =
                          inspectores[index].data() as Map<String, dynamic>;
                      final rol = inspector['rol'] ?? 'N/A';
                      // --- INICIO DE LA MEJORA: Mostrar el código ---
                      final codigo =
                          inspector['codigoFiscalizador'] ?? 'Sin código';
                      // --- FIN DE LA MEJORA ---

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: rol == 'gerente'
                                ? AppTheme.primaryRed
                                : Colors.grey.shade300,
                            child: Icon(
                              rol == 'gerente' ? Icons.shield : Icons.person,
                              color: rol == 'gerente'
                                  ? Colors.white
                                  : AppTheme.foregroundDark,
                            ),
                          ),
                          title:
                              Text(inspector['nombreCompleto'] ?? 'Sin nombre'),
                          // --- INICIO DE LA MEJORA: Mostrar el código ---
                          subtitle: Text(inspector['email'] ?? 'Sin email'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                rol.toString().toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: rol == 'gerente'
                                      ? AppTheme.primaryRed
                                      : AppTheme.mutedForeground,
                                ),
                              ),
                              Text(codigo),
                            ],
                          ),
                          // --- FIN DE LA MEJORA ---
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
