import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Models for cart state
class CartState extends ChangeNotifier {
  double estimatedDistance = 0.0; // meters
  int batteryPercent = 100;
  double rssi = -100.0;
  bool isFollowing = false;
  bool isConnected = false;
  BluetoothDevice? connectedDevice;
  String status = "Disconnected";

  void updateTelemetry({double? distance, int? battery, double? rssiVal}) {
    if (distance != null) estimatedDistance = distance;
    if (battery != null) batteryPercent = battery;
    if (rssiVal != null) rssi = rssiVal;
    notifyListeners();
  }

  void setFollowing(bool following) {
    isFollowing = following;
    status = following ? "FOLLOWING" : "PAUSED";
    notifyListeners();
  }

  void setConnection(bool connected, {BluetoothDevice? device}) {
    isConnected = connected;
    connectedDevice = device;
    if (!connected) {
      isFollowing = false;
      status = "Disconnected";
    } else {
      status = "Connected";
    }
    notifyListeners();
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => CartState(),
      child: const NnFollowCartApp(),
    ),
  );
}

class NnFollowCartApp extends StatelessWidget {
  const NnFollowCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NN Follow Cart',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const CartDashboard(),
    );
  }
}

class CartDashboard extends StatefulWidget {
  const CartDashboard({super.key});

  @override
  State<CartDashboard> createState() => _CartDashboardState();
}

class _CartDashboardState extends State<CartDashboard> {
  FlutterBluePlus flutterBlue = FlutterBluePlus();
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _startScan() async {
    final cartState = Provider.of<CartState>(context, listen: false);
    setState(() => isScanning = true);
    scanResults.clear();

    // TODO: Filter for ESP32 cart by service UUID or name "NN-CART"
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results.where((r) =>
          r.device.platformName.contains('NN-CART') ||
          r.advertisementData.serviceUuids.isNotEmpty
        ).toList();
      });
    });

    await Future.delayed(const Duration(seconds: 10));
    await FlutterBluePlus.stopScan();
    setState(() => isScanning = false);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    final cartState = Provider.of<CartState>(context, listen: false);
    try {
      await device.connect();
      cartState.setConnection(true, device: device);

      // TODO: Discover services, subscribe to RSSI telemetry characteristic
      // Foundation for BLE: Listen for notifications on distance/battery
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          cartState.setConnection(false);
        }
      });

      // Placeholder: Simulate telemetry updates (replace with real BLE reads)
      _simulateTelemetry(cartState);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  void _simulateTelemetry(CartState state) {
    // TODO: Replace with actual BLE characteristic notifications
    // For now, mock data to demonstrate UI foundation
    Future.doWhile(() async {
      if (!state.isConnected) return false;
      await Future.delayed(const Duration(seconds: 2));
      state.updateTelemetry(
        distance: 1.8 + (DateTime.now().millisecond % 400) / 1000,
        battery: 85 + (DateTime.now().second % 10),
        rssiVal: -65.0 + (DateTime.now().millisecond % 20),
      );
      return state.isConnected;
    });
  }

  Future<void> _toggleFollowMe(CartState state) async {
    if (!state.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to cart first')),
      );
      return;
    }

    final newState = !state.isFollowing;
    state.setFollowing(newState);

    // TODO: Send GATT command to ESP32 to start/stop FOLLOW ME mode
    // e.g., write to control characteristic: 0x01 = follow, 0x00 = stop
    print('FOLLOW ME toggled: $newState');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NN Follow Cart'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<CartState>(
        builder: (context, cartState, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('STATUS', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          cartState.status,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cartState.isFollowing ? Colors.green : Colors.orange,
                          ),
                        ),
                        Text('RSSI: ${cartState.rssi.toStringAsFixed(0)} dBm'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Telemetry Row: Distance + Battery
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.straighten, size: 40),
                              const SizedBox(height: 8),
                              Text('DISTANCE', style: Theme.of(context).textTheme.labelLarge),
                              Text(
                                '${cartState.estimatedDistance.toStringAsFixed(1)} m',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                              const Text('Target: ~2.0 m'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(Icons.battery_full, size: 40),
                              const SizedBox(height: 8),
                              Text('BATTERY', style: Theme.of(context).textTheme.labelLarge),
                              Text(
                                '${cartState.batteryPercent}%',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                              LinearProgressIndicator(
                                value: cartState.batteryPercent / 100,
                                backgroundColor: Colors.grey.shade300,
                                color: cartState.batteryPercent > 20 ? Colors.green : Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // FOLLOW ME Button - Core functionality
                ElevatedButton.icon(
                  onPressed: () => _toggleFollowMe(cartState),
                  icon: Icon(cartState.isFollowing ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    cartState.isFollowing ? 'STOP FOLLOWING' : 'FOLLOW ME',
                    style: const TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    backgroundColor: cartState.isFollowing ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),

                // BLE Controls
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isScanning ? null : _startScan,
                        icon: const Icon(Icons.search),
                        label: Text(isScanning ? 'SCANNING...' : 'SCAN FOR CART'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: cartState.isConnected
                            ? () async {
                                await cartState.connectedDevice?.disconnect();
                                cartState.setConnection(false);
                              }
                            : null,
                        icon: const Icon(Icons.bluetooth_disabled),
                        label: const Text('DISCONNECT'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Scan Results
                if (scanResults.isNotEmpty) ...[
                  Text('Nearby Carts', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...scanResults.map((result) => ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(result.device.platformName.isEmpty
                        ? result.device.remoteId.toString()
                        : result.device.platformName),
                    subtitle: Text('RSSI: ${result.rssi} dBm'),
                    trailing: ElevatedButton(
                      onPressed: () => _connectToDevice(result.device),
                      child: const Text('Connect'),
                    ),
                  )),
                ],

                const SizedBox(height: 24),

                // Placeholder for future: Manual override joystick, settings
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Future: Virtual Joystick Override • Calibration • OTA Updates\n'
                      'BLE foundation established. Replace simulation with real GATT reads.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
