import 'package:flutter/material.dart';
import 'package:vdb_realtek/widgets/wifi_config_form.dart';

class WifiConfigurationScreen extends StatefulWidget {
  const WifiConfigurationScreen({super.key});

  @override
  State<WifiConfigurationScreen> createState() => _WifiConfigurationScreenState();
}

class _WifiConfigurationScreenState extends State<WifiConfigurationScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const WifiConfigForm(),
      ),
    );
  }
}
