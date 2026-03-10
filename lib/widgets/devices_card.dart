import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:vdb_realtek/providers/user_provider.dart';

class DevicesCard extends StatefulWidget {
  const DevicesCard({super.key});

  @override
  State<DevicesCard> createState() => _DevicesCardState();
}

class _DevicesCardState extends State<DevicesCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceName = context.watch<UserProvider>().deviceName ?? 'Device';


    return GestureDetector(
      onTap: (){
        Navigator.pushNamed(context, '/deviceLanding');

      },
      child: Card(
        color: theme.colorScheme.primary,
        elevation: 4.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.wifi, size: 30.0),
            SizedBox(width: 5.0),
            Text(deviceName.toString(),),
          ],
        ),
      ),
    );
  }
}
