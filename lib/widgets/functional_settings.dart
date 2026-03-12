import 'package:flutter/material.dart';

class FunctionalSettings extends StatefulWidget {
  const FunctionalSettings({super.key});

  @override
  State<FunctionalSettings> createState() => _FunctionalSettingsState();
}

class _FunctionalSettingsState extends State<FunctionalSettings> {

  bool motionAlerts = true;
  bool nightVision = true;
  bool twoWayAudio = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Functional Settings',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildToggleTile(
            icon: Icons.notifications_active,
            title: 'Motion Alerts',
            subtitle: 'Notify me on every movement',
            value: motionAlerts,
            onChanged: (v) => setState(() => motionAlerts = v),
          ),
          const SizedBox(height: 8),
          _buildToggleTile(
            icon: Icons.dark_mode,
            title: 'Night Vision',
            subtitle: 'Infrared mode for low light',
            value: nightVision,
            onChanged: (v) => setState(() => nightVision = v),
          ),
          const SizedBox(height: 8),
          _buildToggleTile(
            icon: Icons.record_voice_over,
            title: 'Two-Way Audio',
            subtitle: 'Talk through the doorbell speaker',
            value: twoWayAudio,
            onChanged: (v) => setState(() => twoWayAudio = v),
          ),],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:  theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color:theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF800053),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }

}
