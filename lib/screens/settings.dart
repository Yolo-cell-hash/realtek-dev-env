import 'package:flutter/material.dart';
import 'package:vdb_realtek/widgets/bottom_nav.dart';
import 'package:vdb_realtek/widgets/device_information.dart';
import 'package:vdb_realtek/widgets/functional_settings.dart';
import 'package:vdb_realtek/widgets/pulsing_dot_widget.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool motionAlerts = true;
  bool nightVision = true;
  bool twoWayAudio = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(),
      bottomNavigationBar: BottomNav(
        currentIndex: 3,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/vdbLanding');
            case 1:
              Navigator.pushReplacementNamed(context, '/live');
            case 2:
              Navigator.pushReplacementNamed(context, '/events');
            case 3:
              break;
          }
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceStatus(),
            FunctionalSettings(),
            DeviceInformation(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  Widget _buildDeviceStatus() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                'Device Status',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Online',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Battery Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.battery_6_bar_sharp,
                              color:theme.colorScheme.primary, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Battery',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                       Text(
                        'Healthy',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                       Text(
                        'PLUGGED IN',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Signal Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children:  [
                          Icon(Icons.signal_cellular_alt,
                              color:theme.colorScheme.primary, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Wi-Fi',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Strong',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'RSSI -45dBm',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon:  Icon(Icons.chevron_left, color: theme.colorScheme.primary, size: 28),
        onPressed: () => Navigator.pushReplacementNamed(context, '/vdbLanding'),
      ),
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: Color(0x1A810055), width: 1),
      ),
      titleSpacing: 0,
      title: const Text(
        'Settings',
        style: TextStyle(
          fontFamily: 'GEG-Bold',
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      actions: [
        IconButton(
          icon:  Icon(Icons.more_horiz, color: theme.colorScheme.primary),
          onPressed: () {},
        ),
      ],
    );
  }
}
