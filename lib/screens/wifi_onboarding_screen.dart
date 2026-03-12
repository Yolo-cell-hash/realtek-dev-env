import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_service.dart';
import 'package:permission_handler/permission_handler.dart';


class WifiOnboardingScreen extends StatefulWidget {
  const WifiOnboardingScreen({super.key});

  @override
  State<WifiOnboardingScreen> createState() => _WifiOnboardingScreenState();
}

// Represents the overall screen state
enum _ScreenPhase {
  idle,           // waiting to start
  checkingBt,     // checking bluetooth adapter
  btOff,          // bluetooth is off
  requestingPerms,// requesting permissions
  scanning,       // scanning for device
  connecting,     // connecting to device
  connected,      // ready to send credentials
  sending,        // writing to characteristic
  done,           // result received
  error,          // unrecoverable error
}

class _WifiOnboardingScreenState extends State<WifiOnboardingScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _ble = BleService();

  bool _obscurePassword = true;
  _ScreenPhase _phase = _ScreenPhase.idle;
  String _statusMessage = 'Tap "Complete Configuration" to begin.';
  String? _errorMessage;

  StreamSubscription? _btStateSubscription;

  static const Color _primary = Color(0xFF800053);
  static const Color _secondary = Color(0xFFF1F2ED);

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermissionsOnInit());

  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _btStateSubscription?.cancel();
    _ble.disconnect();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // State helpers
  // ─────────────────────────────────────────────
  void _setPhase(_ScreenPhase phase, {String? message, String? error}) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      if (message != null) _statusMessage = message;
      if (error != null) _errorMessage = error;
    });
  }

  Future<void> _requestPermissionsOnInit() async {
    final granted = await _ble.requestPermissions();
    if (!granted && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
            'Bluetooth and location permissions are needed to find and connect to your device.\n\nPlease grant them in App Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await openAppSettings();
              },
              child: const Text(
                'Open Settings',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }
  // ─────────────────────────────────────────────
  // Main flow
  // ─────────────────────────────────────────────
  Future<void> _startProvisioningFlow() async {
    if (!_formKey.currentState!.validate()) return;

    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    _setPhase(_ScreenPhase.checkingBt, message: 'Checking Bluetooth…');

    // 1. Permissions
    _setPhase(_ScreenPhase.requestingPerms, message: 'Requesting permissions…');
    final granted = await _ble.requestPermissions();
    if (!granted) {
      _setPhase(_ScreenPhase.error,
          error: 'Bluetooth permissions are required. Please grant them in App Settings.');
      if (mounted) await openAppSettings();
      return;
    }

    // 2. Bluetooth state
    final btState = await _ble.getAdapterState();
    if (btState != BluetoothAdapterState.on) {
      _setPhase(_ScreenPhase.btOff,
          message: 'Bluetooth is off. Please enable it to continue.');
      final enabled = await _ble.enableBluetooth();
      if (!enabled) {
        // Show a dialog asking user to turn on BT manually (mainly for iOS)
        if (mounted) await _showBtOffDialog();
        // Re-check
        final newState = await _ble.getAdapterState();
        if (newState != BluetoothAdapterState.on) {
          _setPhase(_ScreenPhase.error,
              error: 'Bluetooth must be enabled to proceed.');
          return;
        }
      }
    }

    // 3. Scan
    _setPhase(_ScreenPhase.scanning, message: 'Scanning for "Godrej VDB"…');
    ScanResult scanResult;
    try {
      scanResult = await _ble.scanForDevice(timeout: const Duration(seconds: 20));
    } on TimeoutException {
      _setPhase(_ScreenPhase.error,
          error: '"Godrej VDB" was not found nearby. Make sure the device is powered on and in range.');
      return;
    } catch (e) {
      _setPhase(_ScreenPhase.error, error: 'Scan failed: $e');
      return;
    }

    // 4. Connect
    _setPhase(_ScreenPhase.connecting,
        message: 'Found device! Connecting…');
    try {
      await _ble.connectAndPrepare(scanResult.device);
    } catch (e) {
      _setPhase(_ScreenPhase.error, error: 'Connection failed: $e');
      return;
    }

    _setPhase(_ScreenPhase.connected, message: 'Connected! Sending WiFi credentials…');

    // 5. Send credentials & await result
    _setPhase(_ScreenPhase.sending, message: 'Sending WiFi credentials to device…');
    WifiProvisionResult result;
    try {
      result = await _ble.sendWifiCredentials(
        ssid: ssid,
        password: password,);
    } catch (e) {
      _setPhase(_ScreenPhase.error, error: 'Failed to send credentials: $e');
      return;
    }

    _setPhase(_ScreenPhase.done, message: 'Done');

    // 6. Show result
    if (!mounted) return;
    switch (result) {
      case WifiProvisionResult.success:
        _showResultSnackbar(success: true, message: 'WiFi connected successfully!');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pushNamed(context, '/vdbLanding');
        break;
      case WifiProvisionResult.failure:
        _showResultSnackbar(success: false, message: 'WiFi connection failed. Check your credentials.');
        _setPhase(_ScreenPhase.idle, message: 'Tap "Complete Configuration" to try again.');
        break;
      case WifiProvisionResult.timeout:
        _showResultSnackbar(success: false, message: 'Device did not respond. Please try again.');
        _setPhase(_ScreenPhase.idle, message: 'Tap "Complete Configuration" to try again.');
        break;
      case WifiProvisionResult.unknown:
        _showResultSnackbar(success: false, message: 'Unexpected response from device.');
        _setPhase(_ScreenPhase.idle, message: 'Tap "Complete Configuration" to try again.');
        break;
    }

    await _ble.disconnect();
  }

  void _showResultSnackbar({required bool success, required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showBtOffDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Bluetooth Required'),
        content: const Text('Please enable Bluetooth in your device settings to configure the doorbell.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool get _isBusy =>
      _phase == _ScreenPhase.checkingBt ||
          _phase == _ScreenPhase.requestingPerms ||
          _phase == _ScreenPhase.scanning ||
          _phase == _ScreenPhase.connecting ||
          _phase == _ScreenPhase.connected ||
          _phase == _ScreenPhase.sending;

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF230F1C) : theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isDark),
                          _buildProgressSection(isDark),
                          _buildFormSection(isDark),
                          if (_isBusy || _phase == _ScreenPhase.error)
                            _buildStatusCard(isDark),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI sections
  // ─────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _isBusy ? null : () => Navigator.of(context).pop(),
              child: Icon(
                Icons.arrow_back,
                color: _isBusy ? Colors.grey : _primary,
                size: 28,
              ),
            ),
          ),
          Text(
            'Device Configuration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STEP 3 OF 3',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Finalizing Setup',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 1.0,
              minHeight: 8,
              backgroundColor: _primary.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(_primary),
            ),
          ),const SizedBox(height: 12),
          Text(
            'Connecting your Video Doorbell to secure network',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WiFi Setup',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your device needs access to your local network to stream video and send alerts.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 24),

          // SSID Field
          _buildInputLabel('WiFi Name (SSID)', isDark),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _ssidController,
            hint: 'Enter your network name',
            isDark: isDark,
            enabled: !_isBusy,
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'SSID cannot be empty' : null,
            suffixIcon: const Icon(Icons.wifi_find, color: _primary),
          ),
          const SizedBox(height: 16),

          // Password Field
          _buildInputLabel('Network Password', isDark),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _passwordController,
            hint: 'Enter password',
            isDark: isDark,
            enabled: !_isBusy,
            obscureText: _obscurePassword,
            validator: (v) =>
            (v == null || v.isEmpty) ? 'Password cannot be empty' : null,
            suffixIcon: GestureDetector(
              onTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Security Hint
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? _primary.withOpacity(0.05)
                  : _secondary.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primary.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Connections are encrypted using WPA3. Your password is never shared with third parties and stays locally on the device.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Status / error card shown below the form during operation
  Widget _buildStatusCard(bool isDark) {
    final isError = _phase == _ScreenPhase.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError
              ? Colors.red.withOpacity(isDark ? 0.15 : 0.07)
              : _primary.withOpacity(isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isError
                ? Colors.red.withOpacity(0.3)
                : _primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            if (_isBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(_primary),
                ),
              )
            else
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.red : Colors.green,
                size: 20,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isError ? (_errorMessage ?? 'An error occurred.') : _statusMessage,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isError
                      ? Colors.red.shade300
                      : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark
              ? const Color(0xFFCBD5E1)
              : const Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required Widget suffixIcon,
    bool obscureText = false,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? _primary.withOpacity(0.3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: obscureText,
              enabled: enabled,
              validator: validator,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                errorStyle: const TextStyle(height: 0.01),
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),Padding(
            padding: const EdgeInsets.only(right: 16),
            child: suffixIcon,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    final theme = Theme.of(context);
    return Container(
      color: isDark ? const Color(0xFF230F1C) : theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isBusy ? null : _startProvisioningFlow,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            disabledBackgroundColor: _primary.withOpacity(0.5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: _primary.withOpacity(0.3),
          ),
          child: _isBusy
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
              AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Text(
            'Complete Configuration',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,),
          ),
        ),
      ),
    );
  }
}
