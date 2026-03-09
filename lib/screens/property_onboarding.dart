import 'package:flutter/material.dart';

import 'package:vdb_realtek/widgets/add_devices_widget.dart';

class PropertyOnboarding extends StatefulWidget {
  const PropertyOnboarding({super.key});

  @override
  State<PropertyOnboarding> createState() => _PropertyOnboardingState();
}

class _PropertyOnboardingState extends State<PropertyOnboarding> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AddDevicesWidget(),
          ],
        ),
      ),
    );
  }
}
