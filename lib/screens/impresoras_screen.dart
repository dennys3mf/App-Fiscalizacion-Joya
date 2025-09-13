import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; // <-- Se añade el import

// Paleta y gradiente inspirados en Diia
const Color fondoGradienteInicio = Color(0xFFB2E2E2); // Verde-azul pastel
const Color fondoGradienteFin = Color(0xFFFFE2E2); // Rosa pastel
const Color cardColor = Color(0xFFEAF6FB); // Celeste muy claro
const Color cardShadow = Color(0x22000000); // Sombra sutil
const Color textoPrincipal = Color(0xFF181818); // Negro profundo
const Color textoSecundario = Color(0xFF6B6B6B); // Gris oscuro
const Color acento = Color(0xFFE60000); // Rojo vibrante
const Color azulDiia = Color(0xFF007AFF); // Azul acento

class ImpresorasScreen extends StatefulWidget {
  const ImpresorasScreen({super.key});

  @override
  State<ImpresorasScreen> createState() => _ImpresorasScreenState();
}

class _ImpresorasScreenState extends State<ImpresorasScreen> {
  bool _isLoading = true;
  List<BluetoothInfo> _dispositivos = [];
  String? _dispositivoGuardadoId;

  @override
  void initState() {
    super.initState();
    _solicitarPermisosYCargarDispositivos();
  }

  /// Pide los permisos de Bluetooth y luego carga los dispositivos vinculados.
  Future<void> _solicitarPermisosYCargarDispositivos() async {
    setState(() {
      _isLoading = true;
    });

    // Solicitar permisos de Bluetooth Scan y Connect
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // Verificar si los permisos fueron concedidos
    if (statuses[Permission.bluetoothScan] == PermissionStatus.granted &&
        statuses[Permission.bluetoothConnect] == PermissionStatus.granted) {
      // Si se concedieron, procedemos a cargar los dispositivos
      await _cargarDispositivos();
    } else {
      // Si se negaron, mostramos un mensaje al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Se requieren permisos de dispositivos cercanos para encontrar impresoras.')));
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Carga la lista de dispositivos Bluetooth que ya están vinculados al teléfono.
  Future<void> _cargarDispositivos() async {
    final prefs = await SharedPreferences.getInstance();
    _dispositivoGuardadoId = prefs.getString('printer_id');

    try {
      _dispositivos = await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al obtener dispositivos: $e')));
      }
    }
  }

  /// Guarda el dispositivo seleccionado en las preferencias.
  Future<void> _seleccionarDispositivo(BluetoothInfo device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_id', device.macAdress);
    await prefs.setString('printer_name', device.name);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impresora "${device.name}" guardada.')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Impresoras',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8ECDF7), Color(0xFFB2E2E2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Material(
                elevation: 12.0,
                borderRadius: BorderRadius.circular(28.0),
                color: cardColor,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: azulDiia, size: 24),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selecciona y gestiona tus impresoras Bluetooth o WiFi para imprimir boletas.',
                                style: TextStyle(
                                  color: azulDiia,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: azulDiia, thickness: 1.2),
                      const SizedBox(height: 18),
                      const Text('Configura tu impresora',
                          style: TextStyle(
                            color: textoPrincipal,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          )),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _dispositivos.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No se encontraron impresoras vinculadas.',
                                    style: TextStyle(
                                      color: textoSecundario,
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _dispositivos.length,
                                  itemBuilder: (context, index) {
                                    final device = _dispositivos[index];
                                    final isSelected = device.macAdress ==
                                        _dispositivoGuardadoId;
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Material(
                                        color: isSelected
                                            ? azulDiia.withOpacity(0.12)
                                            : cardColor,
                                        elevation: isSelected ? 6 : 2,
                                        borderRadius: BorderRadius.circular(18),
                                        child: ListTile(
                                          leading: Icon(Icons.print,
                                              color: isSelected
                                                  ? azulDiia
                                                  : textoSecundario,
                                              size: 28),
                                          title: Text(
                                            device.name,
                                            style: const TextStyle(
                                              color: textoPrincipal,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Text(
                                            device.macAdress,
                                            style: const TextStyle(
                                              color: textoSecundario,
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                            ),
                                          ),
                                          trailing: isSelected
                                              ? const Icon(Icons.check_circle,
                                                  color: azulDiia, size: 28)
                                              : null,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18)),
                                          onTap: () =>
                                              _seleccionarDispositivo(device),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
