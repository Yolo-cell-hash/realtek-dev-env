import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// UUIDs for the target characteristics
const String kWriteCharUUID = '0000ff02-0000-1000-8000-00805f9b34fb';
const String kNotifyCharUUID = '0000ff03-0000-1000-8000-00805f9b34fb';

const String kTargetDeviceName = 'Godrej VDB';

enum WifiProvisionResult { success, failure, timeout, unknown }

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _notifySubscription;

  bool get isConnected => _connectedDevice != null;

  // ─────────────────────────────────────────────
  // 1. Permissions
  // ─────────────────────────────────────────────
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 12+ (API 31+) needs the new BT permissions
      // Android 11 and below needs location + legacy BT
      final List<Permission> permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
      ];

      final results = await permissions.request();

      final allGranted = results.values.every(
        (status) =>
            status == PermissionStatus.granted ||
            status == PermissionStatus.limited,
      );

      if (!allGranted) {
        debugPrint('❌ Not all permissions granted: $results');
      }
      return allGranted;
    }

    // iOS
    final results = await [
      Permission.bluetooth,
      Permission.locationWhenInUse,
    ].request();

    return results.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }


  // ─────────────────────────────────────────────
  // 2. Bluetooth state check
  // ─────────────────────────────────────────────
  Future<BluetoothAdapterState> getAdapterState() async {
    return await FlutterBluePlus.adapterState.first;
  }

  /// Returns a stream so the UI can react to state changes
  Stream<BluetoothAdapterState> get adapterStateStream =>
      FlutterBluePlus.adapterState;

  /// Attempts to turn BT on (Android only).
  /// Returns false if not supported or not Android.
  Future<bool> enableBluetooth() async {
    if (!await FlutterBluePlus.isSupported) return false;
    if (!kIsWeb && Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
      // Wait up to 10 s for BT to come on
      final state = await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 10), onTimeout: () => BluetoothAdapterState.unknown);
      return state == BluetoothAdapterState.on;
    }
    return false; // iOS — user must enable manually
  }

  // ─────────────────────────────────────────────
  // 3. Scan for target device
  // ─────────────────────────────────────────────
  /// Scans and resolves with the first matching [ScanResult].
  /// Throws a [TimeoutException] if not found within [timeout].
  Future<ScanResult> scanForDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final completer = Completer<ScanResult>();

    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first;

    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        if ((r.advertisementData.advName == kTargetDeviceName ||
            r.device.platformName == kTargetDeviceName) &&
            !completer.isCompleted) {
          completer.complete(r);
        }
      }
    }, onError: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    });

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
      androidScanMode: AndroidScanMode.lowLatency,
      continuousUpdates: true,
      continuousDivisor: 1,
      withNames: [kTargetDeviceName],
    );

    try {
      final result = await completer.future.timeout(timeout);
      return result;
    } finally {
      await _scanSubscription?.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  // ─────────────────────────────────────────────
  // 4. Connect & discover characteristics
  // ─────────────────────────────────────────────
  Future<void> connectAndPrepare(BluetoothDevice device) async {
    if (_connectedDevice?.remoteId == device.remoteId) return;

    await device.connect(autoConnect: false, license: License.free);
    await Future.delayed(const Duration(milliseconds: 100));
    await device.requestConnectionPriority(
      connectionPriorityRequest: ConnectionPriority.high,
    );
    await device.requestMtu(512);

    _connectedDevice = device;
    await _discoverCharacteristics(device);
  }

  Future<void> _discoverCharacteristics(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        // Match both short (ff02) and full 128-bit UUID forms
        if (uuid == kWriteCharUUID || uuid.contains('ff02')) {
          _writeCharacteristic = char;
          debugPrint('✅ Write characteristic found: $uuid');
        } else if (uuid == kNotifyCharUUID || uuid.contains('ff03')) {
          _notifyCharacteristic = char;
          debugPrint('✅ Notify characteristic found: $uuid');
        }
      }
    }

    if (_writeCharacteristic == null) {
      throw Exception('Write characteristic (0xFF02) not found on device.');
    }
    if (_notifyCharacteristic == null) {
      throw Exception('Notify characteristic (0xFF03) not found on device.');
    }
  }


  // ─────────────────────────────────────────────
  // 5. Send WiFi credentials & listen for result
  // ─────────────────────────────────────────────
  Future<WifiProvisionResult> sendWifiCredentials({
    required String ssid,
    required String password,
    Duration responseTimeout = const Duration(seconds: 20),
  }) async {
    if (_writeCharacteristic == null || _notifyCharacteristic == null) {
      throw StateError('Characteristics not ready. Call connectAndPrepare first.');
    }

    // Subscribe to 0xFF03 BEFORE writing
    final resultCompleter = Completer<WifiProvisionResult>();

    await _notifyCharacteristic!.setNotifyValue(true);
    _notifySubscription = _notifyCharacteristic!.onValueReceived.listen((value) {
      if (resultCompleter.isCompleted) return;
      final response = utf8.decode(value).trim();
      debugPrint('📩 BLE notify received: $response');
      if (response.contains("WIFI_OK")) {
        resultCompleter.complete(WifiProvisionResult.success);
      } else if (response.contains("WIFI_Fail")) {
        resultCompleter.complete(WifiProvisionResult.failure);
      } else {
        resultCompleter.complete(WifiProvisionResult.unknown);
      }
    }, onError: (e) {
      if (!resultCompleter.isCompleted) {
        resultCompleter.completeError(e);
      }
    });

    // Write "SSID:Password" to 0xFF02
    final payload = utf8.encode('$ssid:$password');
    await _writeCharacteristic!.write(payload, withoutResponse: false);
    debugPrint('📤 Sent WiFi payload: $ssid:***');

    try {
      return await resultCompleter.future.timeout(
        responseTimeout,
        onTimeout: () => WifiProvisionResult.timeout,
      );
    } finally {
      await _notifySubscription?.cancel();
      await _notifyCharacteristic!.setNotifyValue(false).catchError((_) {});
    }
  }

  // ─────────────────────────────────────────────
  // 6. Disconnect & cleanup
  // ─────────────────────────────────────────────
  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    await _scanSubscription?.cancel();
    try {
      await _connectedDevice?.disconnect();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
    _connectedDevice = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
  }
}
