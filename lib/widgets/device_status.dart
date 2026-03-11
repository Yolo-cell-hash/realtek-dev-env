import 'package:flutter/material.dart';
import 'package:vdb_realtek/widgets/device_status_card.dart';

class DeviceStatus extends StatefulWidget {
  const DeviceStatus({super.key});

  @override
  State<DeviceStatus> createState() => _DeviceStatusState();
}

class _DeviceStatusState extends State<DeviceStatus> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DeviceStatusCard(
                  icon: Icons.wifi_rounded,
                  iconBgColor: const Color(0xFFDCFCE7),
                  iconColor: const Color(0xFF16A34A),
                  label: 'Connection',
                  value: 'Excellent',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DeviceStatusCard(
                  icon: Icons.battery_5_bar_rounded,
                  iconBgColor: primary.withOpacity(0.1),
                  iconColor: primary,
                  label: 'Battery',
                  value: 'Healthy',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
