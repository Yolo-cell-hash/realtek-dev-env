import 'package:flutter/material.dart';
import 'package:vdb_realtek/widgets/activity_item.dart';

class RecentActivity extends StatefulWidget {
  const RecentActivity({super.key});

  @override
  State<RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<RecentActivity> {
  @override
  Widget build(BuildContext context) {


    final theme = Theme.of(context);


    final activities = [
      {
        'icon': Icons.sensors,
        'bgColor': const Color(0xFFDBEAFE),
        'iconColor': const Color(0xFF2563EB),
        'title': 'Motion Detected',
        'subtitle': '2 minutes ago • Front Door',
      },
      {
        'icon': Icons.doorbell_outlined,
        'bgColor': const Color(0xFFFFEDD5),
        'iconColor': const Color(0xFFEA580C),
        'title': 'Doorbell Pressed',
        'subtitle': '1 hour ago • Front Door',
      },
      {
        'icon': Icons.person_outlined,
        'bgColor': const Color(0xFFF1F5F9),
        'iconColor': const Color(0xFF475569),
        'title': 'Person Spotted',
        'subtitle': '3 hours ago • Side Entrance',
      },
    ];


    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {},
                child:  Text(
                  'See All',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...activities.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ActivityItem(
                icon: item['icon'] as IconData,
                bgColor: item['bgColor'] as Color,
                iconColor: item['iconColor'] as Color,
                title: item['title'] as String,
                subtitle: item['subtitle'] as String,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
