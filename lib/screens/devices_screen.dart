import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:vdb_realtek/widgets/devices_card.dart';
import 'package:vdb_realtek/providers/user_provider.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertyName = context.watch<UserProvider>().propertyName ?? 'Your Property';

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(propertyName.toString()),
          actions: [Icon(Icons.doorbell)],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 10.0),
            DevicesCard(),
            SizedBox(height: 10.0),
          ],
        ),
      ),
    );
  }
}
