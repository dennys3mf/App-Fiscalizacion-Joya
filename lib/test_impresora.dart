import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class TestImpresoraScreen extends StatefulWidget {
  const TestImpresoraScreen({super.key});

  @override
  State<TestImpresoraScreen> createState() => _TestImpresoraScreenState();
}

class _TestImpresoraScreenState extends State<TestImpresoraScreen> {
  String _info = "Presiona 'Buscar Dispositivos' para empezar.";
  List<BluetoothInfo> _printers = [];
  BluetoothInfo? _selectedPrinter;

  // Busca dispositivos Bluetooth vinculados
  Future<void> _getBluetoothDevices() async {
    setState(() {
      _info = "Buscando dispositivos...";
      _printers = [];
      _selectedPrinter = null;
    });

    try {
      _printers = await PrintBluetoothThermal.pairedBluetooths;
      setState(() {
        _info = "Dispositivos encontrados. Por favor, selecciona uno.";
      });
    } catch (e) {
      setState(() {
        _info = "Error al buscar dispositivos: $e";
      });
    }
  }

  // Intenta conectar y enviar una prueba de impresión
  Future<void> _testPrint() async {
    if (_selectedPrinter == null) {
      setState(() {
        _info = "Por favor, selecciona una impresora primero.";
      });
      return;
    }

    setState(() {
      _info = "Intentando conectar con ${_selectedPrinter!.name}...";
    });

    // Intenta conectar a la impresora seleccionada
    final bool connected = await PrintBluetoothThermal.connect(macPrinterAddress: _selectedPrinter!.macAdress);

    if (!connected) {
      setState(() {
        _info = "¡FALLÓ LA CONEXIÓN! Verifica que la impresora esté encendida y cerca.";
      });
      return;
    }

    setState(() {
      _info = "¡CONEXIÓN EXITOSA! Enviando datos de prueba...";
    });

    // Si la conexión fue exitosa, prepara un ticket de prueba
    List<int> bytes = await _generateTestTicket();
    final result = await PrintBluetoothThermal.writeBytes(bytes);

    if (result == true) {
      setState(() {
        _info = "¡IMPRESIÓN DE PRUEBA ENVIADA CORRECTAMENTE!";
      });
    } else {
      setState(() {
        _info = "Error al enviar los datos de impresión.";
      });
    }

    // Siempre desconectar al final
    await PrintBluetoothThermal.disconnect;
  }

  // Genera un ticket simple para la prueba
  Future<List<int>> _generateTestTicket() async {
    List<int> bytes = [];
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    bytes += generator.text('PRUEBA DE IMPRESION', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('--------------------------------');
    bytes += generator.text('Si lees esto, la conexion funciona.');
    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Impresora Bluetooth'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('1. Buscar Dispositivos Vinculados'),
              onPressed: _getBluetoothDevices,
            ),
            const SizedBox(height: 24),
            Text('Estado:', style: Theme.of(context).textTheme.titleMedium),
            Text(_info, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text('Dispositivos Encontrados:', style: Theme.of(context).textTheme.titleMedium),
            Expanded(
              child: _printers.isEmpty
                  ? const Center(child: Text('Ningún dispositivo encontrado. Asegúrate de vincular la impresora en los ajustes de Bluetooth de Android.'))
                  : ListView.builder(
                      itemCount: _printers.length,
                      itemBuilder: (context, index) {
                        final printer = _printers[index];
                        final isSelected = printer.macAdress == _selectedPrinter?.macAdress;
                        return Card(
                          color: isSelected ? Colors.blue.shade100 : null,
                          child: ListTile(
                            leading: const Icon(Icons.print),
                            title: Text(printer.name),
                            subtitle: Text(printer.macAdress),
                            onTap: () {
                              setState(() {
                                _selectedPrinter = printer;
                                _info = "Seleccionaste: ${printer.name}. Ahora presiona el botón de prueba.";
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: const Text('2. Conectar y Probar Impresión'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: _testPrint,
            ),
          ],
        ),
      ),
    );
  }
}