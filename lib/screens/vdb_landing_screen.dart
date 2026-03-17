import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vdb_realtek/widgets/bottom_nav.dart';
import 'package:vdb_realtek/widgets/device_status.dart';
import 'package:vdb_realtek/widgets/live_feed.dart';
import 'package:vdb_realtek/widgets/recent_activity.dart';

import 'package:vdb_realtek/providers/user_provider.dart';

class VdbLandingScreen extends StatefulWidget {
  const VdbLandingScreen({super.key});

  @override
  State<VdbLandingScreen> createState() => _VdbLandingScreenState();
}

class _VdbLandingScreenState extends State<VdbLandingScreen> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: BottomNav(currentIndex: 0, onTap: (index) {
        switch (index) {
          case 0: break;
          case 1: Navigator.pushReplacementNamed(context, '/live'); break;
          case 2: Navigator.pushReplacementNamed(context, '/events'); break;
          case 3: Navigator.pushReplacementNamed(context, '/users'); break;
        }
      }), // 0 = Home tab
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final propertyName = context.watch<UserProvider>().propertyName ?? 'Your House';
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon:  Icon(
          Icons.chevron_left,
          color: theme.colorScheme.primary,
          size: 28,
        ),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: Color(0x1A810055), width: 1),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            propertyName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon:  Icon(Icons.notifications_outlined,
              color:theme.colorScheme.primary),
          onPressed: () {},
        ),
        Padding(
          padding: EdgeInsets.only(right: 5),
          child: IconButton(icon:Icon(Icons.settings),
              color:theme.colorScheme.primary, onPressed: (){
                Navigator.pushReplacementNamed(context, '/settings');
            },)
        )
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiveFeed(),
          DeviceStatus(),
          RecentActivity(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
