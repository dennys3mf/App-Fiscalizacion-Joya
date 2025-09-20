import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ImpresorasScreen extends StatefulWidget {
  final VoidCallback onBack;

  const ImpresorasScreen({super.key, required this.onBack});

  @override
  State<ImpresorasScreen> createState() => _ImpresorasScreenState();
}

class _ImpresorasScreenState extends State<ImpresorasScreen> {
  bool _isLoading = true;
  bool _isScanning = false;
  List<BluetoothInfo> _devices = [];
  String? _savedPrinterId;
  String? _savedPrinterName;

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _getBluetoothDevices();
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPrinterId = prefs.getString('printer_id');
      _savedPrinterName = prefs.getString('printer_name');
    });
  }

  Future<void> _getBluetoothDevices() async {
    setState(() {
      _isScanning = true;
      _isLoading = _devices.isEmpty;
    });
    
    await Future.delayed(const Duration(seconds: 1));
    _devices = await PrintBluetoothThermal.pairedBluetooths;

    setState(() {
      _isLoading = false;
      _isScanning = false;
    });
  }

  Future<void> _selectDevice(BluetoothInfo device) async {
    final prefs = await SharedPreferences.getInstance();
    
    // --- CORRECCIÓN DEFINITIVA ---
    // Usamos 'macAdress' con una 'd', que es el nombre correcto de la propiedad en la librería.
    await prefs.setString('printer_id', device.macAdress);
    await prefs.setString('printer_name', device.name);
    
    setState(() {
      // --- CORRECCIÓN DEFINITIVA ---
      _savedPrinterId = device.macAdress;
      _savedPrinterName = device.name;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Impresora "${device.name}" configurada.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Configurar Impresora'),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
            onPressed: _isScanning ? null : _getBluetoothDevices,
            tooltip: 'Buscar Dispositivos',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildInfoCard(),
              const SizedBox(height: 24),
              _buildDeviceListCard(),
              const SizedBox(height: 24),
              if (_savedPrinterId != null && _savedPrinterName != null) _buildCurrentSelectionCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primaryBlue.withOpacity(0.1), AppTheme.primaryBlue.withOpacity(0.2)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.info_outline, color: AppTheme.primaryBlue),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Configuración de Impresora',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                   SizedBox(height: 4),
                  Text(
                    'Selecciona una impresora Bluetooth para emitir las boletas. Asegúrate de que esté encendida y vinculada a tu teléfono.',
                    style: TextStyle(color: AppTheme.mutedForeground, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Impresoras Disponibles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_isScanning)
                  const Text('Buscando...', style: TextStyle(color: AppTheme.mutedForeground))
                else
                  Text('${_devices.length} encontradas', style: const TextStyle(color: AppTheme.mutedForeground)),
              ],
            ),
            const SizedBox(height: 16),
            _isLoading
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 32.0), child: CircularProgressIndicator())
              : _devices.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 32.0), child: Text('No se encontraron impresoras'))
                : Column(
                    children: _devices.map((device) {
                      // --- CORRECCIÓN DEFINITIVA ---
                      final isSelected = device.macAdress == _savedPrinterId;
                      return Card(
                        elevation: isSelected ? 2 : 0,
                        shadowColor: isSelected ? AppTheme.primaryRed.withOpacity(0.2) : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isSelected ? const BorderSide(color: AppTheme.primaryRed) : BorderSide.none
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryRed.withOpacity(0.1) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.bluetooth, color: isSelected ? AppTheme.primaryRed : AppTheme.mutedForeground),
                          ),
                          title: Text(device.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          // --- CORRECCIÓN DEFINITIVA ---
                          subtitle: Text(device.macAdress),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryRed) : null,
                          onTap: () => _selectDevice(device),
                        ),
                      );
                    }).toList(),
                  )
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSelectionCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.green),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Impresora Configurada', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('"${_savedPrinterName ?? 'N/A'}" está lista para usar.', style: TextStyle(color: Colors.green.shade800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}