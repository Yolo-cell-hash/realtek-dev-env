import 'package:flutter/material.dart';

import 'package:vdb_realtek/widgets/add_property_widget.dart';

class PropertyConfigurationScreen extends StatefulWidget {
  const PropertyConfigurationScreen({super.key});

  @override
  State<PropertyConfigurationScreen> createState() => _PropertyConfigurationScreenState();
}

class _PropertyConfigurationScreenState extends State<PropertyConfigurationScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Addpropertywidget(),
      ),
    );
  }
}
