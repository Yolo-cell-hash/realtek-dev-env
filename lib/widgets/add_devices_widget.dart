import 'package:flutter/material.dart';

import 'package:vdb_realtek/screens/property_configuration_screen.dart';


class AddDevicesWidget extends StatefulWidget {
  const AddDevicesWidget({super.key});

  @override
  State<AddDevicesWidget> createState() => _AddDevicesWidgetState();
}

class _AddDevicesWidgetState extends State<AddDevicesWidget> {
  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);


    return GestureDetector(
      onTap: (){
        print("Add Devices tapped");

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PropertyConfigurationScreen()),
        );

      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 30.0,),
            SizedBox(height: 5.0,),
            Text('Add Devices',style: TextStyle(color: theme.colorScheme.primary, fontSize: 30.0,fontFamily: 'GEG'),)
          ],
        ),
      ),
    );
  }
}
