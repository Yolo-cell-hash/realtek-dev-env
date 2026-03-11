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
      onTap: () {
        Navigator.pushNamed(context, '/deviceLanding');
      },
      child: Card(
        color: theme.colorScheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(
            color: theme.colorScheme.primary.withOpacity(0.3),
            width: 2.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10.0),
              child: Text(
                deviceName.toString(),
                style: TextStyle(
                  color: theme.colorScheme.surface,
                  fontFamily: 'GEG-Bold',
                  fontSize: 20.0,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_outlined,
              color: theme.colorScheme.primary,)
          ],
        ),
      ),
    );
  }
}
