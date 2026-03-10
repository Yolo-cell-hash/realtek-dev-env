import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:vdb_realtek/screens/wifi_configuration_screen.dart';
import 'package:vdb_realtek/providers/user_provider.dart';


class Addpropertywidget extends StatefulWidget {
  const Addpropertywidget({super.key});

  @override
  State<Addpropertywidget> createState() => _AddpropertywidgetState();
}

class _AddpropertywidgetState extends State<Addpropertywidget> {

  final _formKey = GlobalKey<FormState>();
  final _propertyIdController = TextEditingController();
  final _deviceNameController = TextEditingController();

  @override
  void dispose() {
    _deviceNameController.dispose();
    _propertyIdController.dispose();
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
                      controller: _propertyIdController,
                      keyboardType: TextInputType.text,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: InputDecoration(
                        labelText: 'Property Name',
                        hintText: 'Enter your Property Name',
                        labelStyle: const TextStyle(color: Colors.black),
                        prefixIcon:
                        Icon(Icons.home_outlined, color: theme.colorScheme.primary),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextFormField(
                      style: const TextStyle(color: Colors.black),
                      controller: _deviceNameController,
                      keyboardType: TextInputType.text,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: InputDecoration(
                        labelText: 'Device Name',
                        hintText: 'Enter your Device Name',
                        labelStyle: const TextStyle(color: Colors.black),
                        prefixIcon:
                        Icon(Icons.drive_file_rename_outline, color: theme.colorScheme.primary),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          context.read<UserProvider>().setPropertyName(
                            _propertyIdController.text.trim(),
                          );
                          context.read<UserProvider>().setDeviceName(
                            _deviceNameController.text.trim(),
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const WifiConfigurationScreen()),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Proceed to WiFi Configuration',
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
