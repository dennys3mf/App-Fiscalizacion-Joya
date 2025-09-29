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
  List<BluetoothInfo> _filteredDevices = [];
  String? _savedPrinterId;
  String? _savedPrinterName;
  bool _showAllDevices = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Lista ampliada de palabras clave para detectar impresoras
  final List<String> _printerKeywords = [
    'printer', 'print', 'pos', 'thermal', 'receipt', 'bt', 'tm', 'rp',
    'star', 'epson', 'bixolon', 'citizen', 'zebra', 'tsc', 'godex',
    '58mm', '80mm', 'mtp', 'zj', 'xp', 'rpp', 'spp', 'mobile',
    'portable', 'handheld', 'label', 'barcode', 'qr', 'ticket',
    'r310', 'r200', 'r400', 'spp-r200', 'spp-r310', 'spp-r400'
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _getBluetoothDevices();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterDevices();
    });
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
    
    try {
      await Future.delayed(const Duration(seconds: 1));
      _devices = await PrintBluetoothThermal.pairedBluetooths;
      _filterDevices();
    } catch (e) {
      print('Error al obtener dispositivos Bluetooth: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al buscar dispositivos: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    setState(() {
      _isLoading = false;
      _isScanning = false;
    });
  }

  void _filterDevices() {
    List<BluetoothInfo> filtered = [];
    
    if (_showAllDevices) {
      // Mostrar todos los dispositivos
      filtered = _devices;
    } else {
      // Filtrar por palabras clave de impresoras
      filtered = _devices.where((device) {
        String name = device.name.toLowerCase();
        return _printerKeywords.any((keyword) => name.contains(keyword));
      }).toList();
      
      // Si no se encuentran impresoras específicas, mostrar todos
      if (filtered.isEmpty && _devices.isNotEmpty) {
        filtered = _devices;
      }
    }
    
    // Aplicar filtro de búsqueda si hay texto
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((device) {
        String name = device.name.toLowerCase();
        String mac = device.macAdress.toLowerCase();
        return name.contains(_searchQuery) || mac.contains(_searchQuery);
      }).toList();
    }
    
    // Ordenar: primero las impresoras conocidas, luego por nombre
    filtered.sort((a, b) {
      String nameA = a.name.toLowerCase();
      String nameB = b.name.toLowerCase();
      
      bool isKnownPrinterA = _printerKeywords.any((keyword) => nameA.contains(keyword));
      bool isKnownPrinterB = _printerKeywords.any((keyword) => nameB.contains(keyword));
      
      if (isKnownPrinterA && !isKnownPrinterB) return -1;
      if (!isKnownPrinterA && isKnownPrinterB) return 1;
      
      return nameA.compareTo(nameB);
    });
    
    setState(() {
      _filteredDevices = filtered;
    });
  }

  Future<void> _selectDevice(BluetoothInfo device) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('printer_id', device.macAdress);
    await prefs.setString('printer_name', device.name);
    
    setState(() {
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

  Future<void> _testPrinter(BluetoothInfo device) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enviando prueba de impresión...'),
          backgroundColor: Colors.blue,
        ),
      );

      // Conectar a la impresora
      bool connected = await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);
      
      if (connected) {
        // Comando de prueba simple
        String testData = '\n--- PRUEBA DE IMPRESION ---\n';
        testData += 'App Fiscalizacion Joya\n';
        testData += DateTime.now().toString().substring(0, 19);
        testData += '\nDispositivo: ${device.name}\n';
        testData += 'MAC: ${device.macAdress}\n';
        testData += '\nSi puede leer este texto,\nla impresora funciona correctamente.\n\n\n';
        
        await PrintBluetoothThermal.writeBytes(testData.codeUnits);
        await PrintBluetoothThermal.disconnect;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Prueba de impresión enviada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('No se pudo conectar a la impresora');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al probar impresora: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDeviceTypeIcon(BluetoothInfo device) {
    String name = device.name.toLowerCase();
    
    // Iconos específicos para tipos de impresoras conocidas
    if (name.contains('bixolon')) return '🖨️ BIXOLON';
    if (name.contains('epson')) return '🖨️ EPSON';
    if (name.contains('star')) return '🖨️ STAR';
    if (name.contains('citizen')) return '🖨️ CITIZEN';
    if (name.contains('zebra')) return '🖨️ ZEBRA';
    
    // Tipos generales
    if (_printerKeywords.any((keyword) => name.contains(keyword))) {
      return '🖨️ IMPRESORA';
    }
    
    return '📱 DISPOSITIVO';
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
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    _buildSearchCard(),
                    const SizedBox(height: 16),
                    _buildFilterCard(),
                    const SizedBox(height: 16),
                    _buildDeviceListCard(),
                    const SizedBox(height: 24),
                    if (_savedPrinterId != null && _savedPrinterName != null) 
                      _buildCurrentSelectionCard(),
                  ],
                ),
              ),
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
                    'Selecciona una impresora Bluetooth para emitir las boletas. Compatible con BIXOLON, EPSON, STAR y otras impresoras térmicas. Asegúrate de que esté encendida y vinculada a tu teléfono.',
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

  Widget _buildSearchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buscar Dispositivo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o dirección MAC...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Opciones de Filtrado',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Mostrar todos los dispositivos'),
                    subtitle: Text(_showAllDevices 
                        ? 'Mostrando todos los dispositivos vinculados'
                        : 'Solo mostrando impresoras detectadas'),
                    value: _showAllDevices,
                    onChanged: (bool? value) {
                      setState(() {
                        _showAllDevices = value ?? false;
                        _filterDevices();
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
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
                const Text('Dispositivos Disponibles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_isScanning)
                  const Text('Buscando...', style: TextStyle(color: AppTheme.mutedForeground))
                else
                  Text('${_filteredDevices.length} encontrados', style: const TextStyle(color: AppTheme.mutedForeground)),
              ],
            ),
            const SizedBox(height: 16),
            _isLoading
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 32.0), child: CircularProgressIndicator())
              : _filteredDevices.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: _filteredDevices.map((device) {
                      final isSelected = device.macAdress == _savedPrinterId;
                      final deviceType = _getDeviceTypeIcon(device);
                      
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
                              color: isSelected ? AppTheme.primaryRed.withOpacity(0.1) : const Color.fromARGB(255, 58, 56, 56),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.bluetooth, color: isSelected ? AppTheme.primaryRed : AppTheme.mutedForeground),
                          ),
                          title: Text(
                            device.name.isNotEmpty ? device.name : 'Dispositivo sin nombre',
                            style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(device.macAdress),
                              Text(
                                deviceType,
                                style: TextStyle(
                                  color: deviceType.contains('IMPRESORA') || deviceType.contains('BIXOLON') || deviceType.contains('EPSON') || deviceType.contains('STAR') || deviceType.contains('CITIZEN') || deviceType.contains('ZEBRA')
                                      ? Colors.green 
                                      : Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow, color: Colors.blue),
                                onPressed: () => _testPrinter(device),
                                tooltip: 'Probar impresora',
                              ),
                              IconButton(
                                icon: isSelected 
                                    ? const Icon(Icons.check_circle, color: AppTheme.primaryRed)
                                    : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                                onPressed: () => _selectDevice(device),
                                tooltip: 'Seleccionar impresora',
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        children: [
          const Icon(Icons.devices, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No se encontraron dispositivos que coincidan con "$_searchQuery"'
                : 'No se encontraron dispositivos',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Asegúrate de que la impresora esté:\n• Encendida\n• Vinculada en Configuración Bluetooth\n• Cerca del dispositivo',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _getBluetoothDevices,
            icon: const Icon(Icons.refresh),
            label: const Text('Buscar nuevamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSelectionCard() {
    return Card(
      color: const Color.fromARGB(255, 0, 165, 14),
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
                  Text('MAC: ${_savedPrinterId ?? 'N/A'}', style: TextStyle(color: const Color.fromARGB(255, 212, 238, 213), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
