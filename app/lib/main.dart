import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

// Must match firmware/include/config.h + docs/firmware/ble-protocol.md
final Guid kCartServiceUuid = Guid('A1B2C3D4-E5F6-7890-ABCD-EF1234567890');
final Guid kTelemetryCharUuid = Guid('A1B2C3D4-E5F6-7890-ABCD-EF1234567891');
final Guid kControlCharUuid = Guid('A1B2C3D4-E5F6-7890-ABCD-EF1234567892');

const int kCtrlStop = 0x00;
const int kCtrlFollow = 0x01;
const int kCtrlHalt = 0x02;
const int kCtrlDrive = 0x10; // [0x10, left_i8, right_i8]

bool _isCartScanHit(ScanResult r) {
  final name = r.device.platformName.toLowerCase();
  final advName = r.advertisementData.advName.toLowerCase();
  final blob = '$name $advName';
  if (blob.contains('nn-follow') ||
      blob.contains('nn-cart') ||
      blob.contains('follow-cart') ||
      blob.contains('followcart')) {
    return true;
  }
  for (final u in r.advertisementData.serviceUuids) {
    if (u.str128.toLowerCase() == kCartServiceUuid.str128.toLowerCase()) {
      return true;
    }
  }
  return false;
}

class CartState extends ChangeNotifier {
  double estimatedDistance = 0.0;
  int batteryPercent = 100;
  double rssi = -100.0;
  bool isFollowing = false;
  bool isManual = false;
  bool isConnected = false;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? controlChar;
  String status = 'Disconnected';
  String lastError = '';

  void updateTelemetry({double? distance, int? battery, double? rssiVal}) {
    if (distance != null) estimatedDistance = distance;
    if (battery != null) batteryPercent = battery;
    if (rssiVal != null) rssi = rssiVal;
    notifyListeners();
  }

  void setFollowing(bool following) {
    isFollowing = following;
    if (following) isManual = false;
    if (isConnected) {
      if (isManual) {
        status = 'MANUAL';
      } else {
        status = following ? 'FOLLOWING' : 'PAUSED';
      }
    }
    notifyListeners();
  }

  void setManual(bool manual) {
    isManual = manual;
    if (manual) isFollowing = false;
    if (isConnected) {
      status = manual ? 'MANUAL' : (isFollowing ? 'FOLLOWING' : 'PAUSED');
    }
    notifyListeners();
  }

  void setHalted() {
    isFollowing = false;
    isManual = false;
    if (isConnected) status = 'HALTED';
    notifyListeners();
  }

  void setConnection(
    bool connected, {
    BluetoothDevice? device,
    BluetoothCharacteristic? control,
  }) {
    isConnected = connected;
    connectedDevice = device;
    controlChar = control;
    if (!connected) {
      isFollowing = false;
      isManual = false;
      status = 'Disconnected';
      controlChar = null;
    } else {
      status = 'Connected';
    }
    notifyListeners();
  }

  void setError(String msg) {
    lastError = msg;
    notifyListeners();
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBluePlus.setLogLevel(LogLevel.info, color: false);
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
  final Map<String, ScanResult> _hits = {};
  List<ScanResult> _otherBle = [];
  bool isScanning = false;
  bool showAllBle = false;
  String scanStatus = '';
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _telemSub;
  Timer? _driveTimer;
  double _joyX = 0; // −1…1 right
  double _joyY = 0; // −1…1 forward (screen up = +)
  bool _joyActive = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    _driveTimer?.cancel();
    _scanSub?.cancel();
    _connSub?.cancel();
    _telemSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final denied = statuses.entries.where((e) => !e.value.isGranted).toList();
    if (denied.isNotEmpty && mounted) {
      setState(() {
        scanStatus =
            'Permissions needed: ${denied.map((e) => e.key).join(", ")}. '
            'Settings → Apps → NN Follow Cart → Permissions.';
      });
    }
  }

  Future<void> _startScan() async {
    final cart = Provider.of<CartState>(context, listen: false);

    if (await FlutterBluePlus.isSupported == false) {
      _snack('BLE not supported on this device');
      return;
    }

    // Adapter on?
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _snack('Turn Bluetooth ON, then scan again');
      setState(() => scanStatus = 'Bluetooth adapter is OFF');
      return;
    }

    await _requestPermissions();

    // If OS already holds a GATT link, system Settings can hide ads.
    // Prefer app-owned connection: disconnect stale links we own.
    if (cart.isConnected && cart.connectedDevice != null) {
      try {
        await cart.connectedDevice!.disconnect();
      } catch (_) {}
      cart.setConnection(false);
    }

    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();

    setState(() {
      isScanning = true;
      _hits.clear();
      _otherBle = [];
      scanStatus = 'Scanning… look for NN-Follow-Cart';
    });

    // IMPORTANT: subscribe BEFORE startScan (old code listened after await — empty forever)
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      final others = <ScanResult>[];
      for (final r in results) {
        if (_isCartScanHit(r)) {
          _hits[r.device.remoteId.str] = r;
        } else if (showAllBle) {
          others.add(r);
        }
      }
      setState(() {
        _otherBle = others;
        scanStatus = _hits.isEmpty
            ? 'Scanning… ${results.length} BLE device(s) seen, no cart match yet'
            : 'Found ${_hits.length} cart candidate(s)';
      });
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      setState(() {
        isScanning = false;
        scanStatus = 'Scan failed: $e';
      });
      _snack('Scan failed: $e');
      return;
    }

    // startScan with timeout completes when done
    if (mounted) {
      setState(() {
        isScanning = false;
        if (_hits.isEmpty) {
          scanStatus =
              'No cart found. Tips: leave system BT Settings (don\'t stay on device page), '
              'power-cycle ESP32, grant Location + Nearby devices, scan again. '
              'Toggle "Show all BLE" to debug.';
        }
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    final cart = Provider.of<CartState>(context, listen: false);
    final label = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.str;
    setState(() => scanStatus = 'Connecting to $label…');

    try {
      await FlutterBluePlus.stopScan();

      // Stale Android LE bonds (esp. ble_enc_key_size=0) drop the link during
      // post-connect MTU and surface as PlatformException(requestMtu, device is disconnected).
      try {
        final bond = await device.bondState.first
            .timeout(const Duration(seconds: 2));
        if (bond == BluetoothBondState.bonded) {
          if (mounted) {
            setState(() => scanStatus = 'Clearing stale BT bond…');
          }
          await device.removeBond();
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      } catch (_) {
        // Best-effort: some stacks lack bond APIs; connect retries still run.
        try {
          await device.removeBond();
        } catch (_) {}
      }

      try {
        if (device.isConnected) {
          await device.disconnect();
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      } catch (_) {}

      try {
        await device.clearGattCache();
      } catch (_) {}

      // mtu: null disables FBP auto requestMtu(512) which races on some Androids.
      Object? lastErr;
      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          if (mounted) {
            setState(() => scanStatus = 'Connecting to $label… ($attempt/3)');
          }
          await device.connect(
            timeout: const Duration(seconds: 20),
            autoConnect: false,
            mtu: null,
          );
          lastErr = null;
          break;
        } catch (e) {
          lastErr = e;
          try {
            await device.disconnect();
          } catch (_) {}
          // One more bond wipe after first failure (bond may reappear mid-attempt).
          if (attempt == 1) {
            try {
              await device.removeBond();
            } catch (_) {}
          }
          await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
        }
      }
      if (lastErr != null) {
        throw lastErr;
      }

      // Let the ATT layer settle before discovery (Android + NimBLE).
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!device.isConnected) {
        throw Exception(
          'Link dropped right after connect. Forget NN-Follow-Cart in system '
          'Bluetooth settings, power-cycle the cart, then SCAN again.',
        );
      }

      cart.setConnection(true, device: device);

      await _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          cart.setConnection(false);
          _telemSub?.cancel();
          if (mounted) setState(() => scanStatus = 'Disconnected');
        }
      });

      final services = await device.discoverServices();
      BluetoothCharacteristic? telem;
      BluetoothCharacteristic? ctrl;

      for (final s in services) {
        if (s.uuid == kCartServiceUuid ||
            s.uuid.str128.toLowerCase() ==
                kCartServiceUuid.str128.toLowerCase()) {
          for (final c in s.characteristics) {
            final id = c.uuid.str128.toLowerCase();
            if (id == kTelemetryCharUuid.str128.toLowerCase()) telem = c;
            if (id == kControlCharUuid.str128.toLowerCase()) ctrl = c;
          }
        }
      }

      // Fallback: match by short compare if Guid equality quirks
      if (telem == null || ctrl == null) {
        for (final s in services) {
          for (final c in s.characteristics) {
            final id = c.uuid.str.toUpperCase();
            if (id.contains('EF1234567891') || id.endsWith('7891')) {
              telem ??= c;
            }
            if (id.contains('EF1234567892') || id.endsWith('7892')) {
              ctrl ??= c;
            }
          }
        }
      }

      if (ctrl == null) {
        cart.setConnection(true, device: device);
        setState(() => scanStatus =
            'Connected but cart GATT service not found. Services: ${services.map((s) => s.uuid).join(", ")}');
        _snack('Connected — GATT service missing (wrong firmware?)');
        return;
      }

      cart.setConnection(true, device: device, control: ctrl);

      if (telem != null) {
        await telem.setNotifyValue(true);
        await _telemSub?.cancel();
        _telemSub = telem.onValueReceived.listen((data) {
          _parseTelemetry(cart, data);
        });
        if (telem.lastValue.isNotEmpty) {
          _parseTelemetry(cart, telem.lastValue);
        }
      }

      // Optional larger MTU after GATT is up (best-effort; not required for 8-byte telem).
      try {
        if (device.isConnected) {
          await device.requestMtu(185);
        }
      } catch (_) {}

      setState(() => scanStatus = 'Connected to cart — real telemetry');
      _snack('Connected');
    } catch (e) {
      cart.setConnection(false);
      cart.setError('$e');
      setState(() => scanStatus = 'Connection failed: $e');
      _snack('Connection failed: $e');
    }
  }

  void _parseTelemetry(CartState cart, List<int> data) {
    if (data.length < 8) return;
    final bytes = Uint8List.fromList(data);
    final bd = ByteData.sublistView(bytes);
    final rssi = bd.getInt8(0);
    final distCm = bd.getUint16(1, Endian.little);
    final batt = bytes[3];
    final status = bytes[4];
    final following = (status & 0x01) != 0;

    cart.updateTelemetry(
      distance: distCm / 100.0,
      battery: batt,
      rssiVal: rssi.toDouble(),
    );
    if (cart.isFollowing != following) {
      cart.setFollowing(following);
    }
  }

  Future<void> _toggleFollowMe(CartState state) async {
    if (!state.isConnected) {
      _snack('Connect to cart first');
      return;
    }

    final newState = !state.isFollowing;
    final op = newState ? kCtrlFollow : kCtrlStop;

    try {
      _stopManualStream();
      final c = state.controlChar;
      if (c != null) {
        await c.write([op], withoutResponse: c.properties.writeWithoutResponse);
      } else {
        _snack('No control characteristic — reconnect');
        return;
      }
      state.setManual(false);
      state.setFollowing(newState);
    } catch (e) {
      _snack('FOLLOW write failed: $e');
    }
  }

  Future<void> _writeDrive(CartState state, int left, int right) async {
    final c = state.controlChar;
    if (c == null || !state.isConnected) return;
    left = left.clamp(-100, 100);
    right = right.clamp(-100, 100);
    int i8(int v) => v < 0 ? (256 + v) : v;
    final pkt = <int>[kCtrlDrive, i8(left), i8(right)];
    try {
      await c.write(pkt, withoutResponse: c.properties.writeWithoutResponse);
    } catch (_) {}
  }

  void _joystickToTracks(double x, double y, void Function(int l, int r) out) {
    // Arcade mix: y forward, x turn (skid-steer)
    final v = y.clamp(-1.0, 1.0);
    final w = x.clamp(-1.0, 1.0);
    var left = (v - w) * 100.0;
    var right = (v + w) * 100.0;
    final peak = [left.abs(), right.abs(), 100.0].reduce((a, b) => a > b ? a : b);
    if (peak > 100) {
      left = left * 100 / peak;
      right = right * 100 / peak;
    }
    // deadzone
    if (left.abs() < 8) left = 0;
    if (right.abs() < 8) right = 0;
    out(left.round(), right.round());
  }

  void _onJoyChanged(Offset normalized) {
    _joyX = normalized.dx.clamp(-1.0, 1.0);
    _joyY = (-normalized.dy).clamp(-1.0, 1.0); // screen up = forward
  }

  void _startManualStream(CartState state) {
    if (!state.isConnected) {
      _snack('Connect to cart first');
      return;
    }
    _joyActive = true;
    state.setManual(true);
    state.setFollowing(false);
    _driveTimer?.cancel();
    _driveTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      if (!_joyActive || !mounted) return;
      final cart = Provider.of<CartState>(context, listen: false);
      if (!cart.isConnected) {
        _stopManualStream();
        return;
      }
      var l = 0;
      var r = 0;
      _joystickToTracks(_joyX, _joyY, (a, b) {
        l = a;
        r = b;
      });
      await _writeDrive(cart, l, r);
    });
  }

  Future<void> _stopManualStream({bool sendZero = true}) async {
    _joyActive = false;
    _driveTimer?.cancel();
    _driveTimer = null;
    _joyX = 0;
    _joyY = 0;
    if (!mounted) return;
    final cart = Provider.of<CartState>(context, listen: false);
    if (sendZero && cart.isConnected) {
      await _writeDrive(cart, 0, 0);
    }
    if (cart.isManual) {
      cart.setManual(false);
      if (cart.isConnected && !cart.isFollowing) {
        // keep PAUSED; user can FOLLOW again
      }
    }
  }

  Future<void> _halt(CartState state) async {
    if (!state.isConnected) return;
    await _stopManualStream(sendZero: false);
    try {
      final c = state.controlChar;
      if (c != null) {
        await c.write([kCtrlHalt], withoutResponse: c.properties.writeWithoutResponse);
      }
      state.setManual(false);
      state.setHalted();
    } catch (e) {
      _snack('HALT failed: $e');
    }
  }

  Future<void> _disconnect(CartState cart) async {
    await _stopManualStream(sendZero: false);
    try {
      await cart.connectedDevice?.disconnect();
    } catch (_) {}
    cart.setConnection(false);
    await _telemSub?.cancel();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _displayName(ScanResult r) {
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    if (r.advertisementData.advName.isNotEmpty) {
      return r.advertisementData.advName;
    }
    return r.device.remoteId.str;
  }

  @override
  Widget build(BuildContext context) {
    final cartHits = _hits.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('STATUS',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          cartState.status,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cartState.isFollowing
                                ? Colors.green
                                : cartState.isManual
                                    ? Colors.deepPurple
                                    : Colors.orange,
                          ),
                        ),
                        Text('RSSI: ${cartState.rssi.toStringAsFixed(0)} dBm'),
                        if (scanStatus.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            scanStatus,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                              Text('DISTANCE',
                                  style:
                                      Theme.of(context).textTheme.labelLarge),
                              Text(
                                '${cartState.estimatedDistance.toStringAsFixed(1)} m',
                                style: const TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.bold),
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
                              Text('BATTERY',
                                  style:
                                      Theme.of(context).textTheme.labelLarge),
                              Text(
                                '${cartState.batteryPercent}%',
                                style: const TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                              LinearProgressIndicator(
                                value: cartState.batteryPercent / 100,
                                backgroundColor: Colors.grey.shade300,
                                color: cartState.batteryPercent > 20
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _toggleFollowMe(cartState),
                  icon: Icon(
                      cartState.isFollowing ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    cartState.isFollowing ? 'STOP FOLLOWING' : 'FOLLOW ME',
                    style: const TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    backgroundColor:
                        cartState.isFollowing ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.deepPurple.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('MANUAL DRIVE',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          cartState.isConnected
                              ? 'Hold stick · release to stop · overrides FOLLOW'
                              : 'Connect first',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        IgnorePointer(
                          ignoring: !cartState.isConnected,
                          child: Opacity(
                            opacity: cartState.isConnected ? 1 : 0.4,
                            child: DriveJoystick(
                              size: 200,
                              onChanged: _onJoyChanged,
                              onActive: () => _startManualStream(cartState),
                              onReleased: () => _stopManualStream(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: cartState.isConnected
                                ? () => _halt(cartState)
                                : null,
                            icon: const Icon(Icons.warning_amber),
                            label: const Text('E-STOP / HALT'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade800,
                              side: BorderSide(color: Colors.red.shade400),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isScanning ? null : _startScan,
                        icon: const Icon(Icons.search),
                        label: Text(isScanning ? 'SCANNING…' : 'SCAN FOR CART'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: cartState.isConnected
                            ? () => _disconnect(cartState)
                            : null,
                        icon: const Icon(Icons.bluetooth_disabled),
                        label: const Text('DISCONNECT'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Show all BLE (debug)'),
                  value: showAllBle,
                  onChanged: (v) => setState(() => showAllBle = v),
                ),
                if (cartHits.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Carts', style: Theme.of(context).textTheme.titleMedium),
                  ...cartHits.map((result) => ListTile(
                        leading: const Icon(Icons.shopping_cart),
                        title: Text(_displayName(result)),
                        subtitle: Text(
                            'RSSI: ${result.rssi} dBm  ·  ${result.device.remoteId}'),
                        trailing: ElevatedButton(
                          onPressed: () => _connectToDevice(result.device),
                          child: const Text('Connect'),
                        ),
                      )),
                ],
                if (showAllBle && _otherBle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Other BLE',
                      style: Theme.of(context).textTheme.titleMedium),
                  ..._otherBle.take(20).map((result) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.bluetooth, size: 20),
                        title: Text(_displayName(result),
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text('RSSI ${result.rssi}'),
                        trailing: TextButton(
                          child: const Text('Connect'),
                          onPressed: () => _connectToDevice(result.device),
                        ),
                      )),
                ],
                const SizedBox(height: 16),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Board advertises as NN-Follow-Cart (control primary only).\n'
                      'Joystick sends CTRL_DRIVE; firmware stops if packets pause >400 ms.\n'
                      'Do not keep the cart open in system Bluetooth settings while scanning.',
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

/// Virtual stick: center = stop, up = forward, left/right = skid turn.
class DriveJoystick extends StatefulWidget {
  const DriveJoystick({
    super.key,
    required this.size,
    required this.onChanged,
    required this.onActive,
    required this.onReleased,
  });

  final double size;
  final ValueChanged<Offset> onChanged;
  final VoidCallback onActive;
  final VoidCallback onReleased;

  @override
  State<DriveJoystick> createState() => _DriveJoystickState();
}

class _DriveJoystickState extends State<DriveJoystick> {
  Offset _knob = Offset.zero; // pixels from center
  bool _down = false;

  double get _r => widget.size * 0.5;
  double get _knobR => widget.size * 0.16;

  void _update(Offset local) {
    final c = Offset(_r, _r);
    var d = local - c;
    final max = _r - _knobR;
    if (d.distance > max) {
      d = Offset.fromDirection(d.direction, max);
    }
    setState(() => _knob = d);
    widget.onChanged(Offset(d.dx / max, d.dy / max));
  }

  void _reset() {
    setState(() {
      _knob = Offset.zero;
      _down = false;
    });
    widget.onChanged(Offset.zero);
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) {
        _down = true;
        widget.onActive();
        _update(d.localPosition);
      },
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _JoyPainter(
            knob: _knob,
            down: _down,
            knobR: _knobR,
          ),
        ),
      ),
    );
  }
}

class _JoyPainter extends CustomPainter {
  _JoyPainter({required this.knob, required this.down, required this.knobR});
  final Offset knob;
  final bool down;
  final double knobR;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final pad = Paint()
      ..color = Colors.deepPurple.shade100
      ..style = PaintingStyle.fill;
    final ring = Paint()
      ..color = Colors.deepPurple.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(c, size.width / 2, pad);
    canvas.drawCircle(c, size.width / 2 - 1.5, ring);

    // crosshair
    final grid = Paint()
      ..color = Colors.deepPurple.shade200
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx, 12), Offset(c.dx, size.height - 12), grid);
    canvas.drawLine(Offset(12, c.dy), Offset(size.width - 12, c.dy), grid);

    final knobPaint = Paint()
      ..color = down ? Colors.deepPurple : Colors.deepPurple.shade400;
    canvas.drawCircle(c + knob, knobR, knobPaint);
    canvas.drawCircle(
      c + knob,
      knobR,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _JoyPainter old) =>
      old.knob != knob || old.down != down;
}
