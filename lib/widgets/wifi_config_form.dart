import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:vdb_realtek/providers/user_provider.dart';

class WifiConfigForm extends StatefulWidget {
  const WifiConfigForm({super.key});

  @override
  State<WifiConfigForm> createState() => _WifiConfigFormState();
}

class _WifiConfigFormState extends State<WifiConfigForm> {
  final _formKey = GlobalKey<FormState>();
  final _wifiSSIDController = TextEditingController();
  final _wifiPasswordController = TextEditingController();

  @override
  void dispose() {
    _wifiSSIDController.dispose();
    _wifiPasswordController.dispose();
    super.dispose();
  }

  void _generateQR(String userId) {
    if (_wifiPasswordController.text.isNotEmpty &&
        _wifiSSIDController.text.isNotEmpty) {
      final ssid = _wifiSSIDController.text;
      final password = _wifiPasswordController.text;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Onboarding QR Code',
              style: TextStyle(
                fontFamily: 'GEG-Bold',
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            content: SizedBox(
              width: 260,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scan to connect to $ssid',
                    style: const TextStyle(fontFamily: 'GEG'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: 'UU-$userId;;SS-$ssid;;PP-$password;;',
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = context.watch<UserProvider>().userId;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            color: theme.colorScheme.secondary,
            elevation: 4.0,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'WiFi Configuration',
                    style: TextStyle(
                      fontSize: 30.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'GEG-Bold',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      style: const TextStyle(color: Colors.black),
                      controller: _wifiSSIDController,
                      keyboardType: TextInputType.text,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: InputDecoration(
                        labelText: 'WiFi SSID',
                        hintText: 'Enter your WiFi SSID',
                        labelStyle: const TextStyle(color: Colors.black),
                        prefixIcon:
                        Icon(Icons.wifi, color: theme.colorScheme.primary),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      style: const TextStyle(color: Colors.black),
                      controller: _wifiPasswordController,
                      obscureText: true,
                      keyboardType: TextInputType.text,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your WiFi Password',
                        labelStyle: const TextStyle(color: Colors.black),
                        prefixIcon: Icon(Icons.lock_outline,
                            color: theme.colorScheme.primary),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // Pass userId from provider to _generateQR
                      onPressed: () => _generateQR(userId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Generate QR Code',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
