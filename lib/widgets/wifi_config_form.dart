import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:vdb_realtek/providers/user_provider.dart';
import 'package:vdb_realtek/screens/devices_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            color: theme.colorScheme.secondary,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Device Configuration',
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
                      onPressed: () {

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Device Configuration Successful',
                                style: TextStyle(color: Colors.white, fontFamily: "GEG")),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        );

                        Navigator.pushNamed(context, '/vdbLanding');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Finish Device Onboarding',
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
