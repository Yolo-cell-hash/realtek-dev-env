import 'package:flutter/material.dart';

class BuildUsersList extends StatefulWidget {
  const BuildUsersList({super.key});

  @override
  State<BuildUsersList> createState() => _BuildUsersListState();
}

class _BuildUsersListState extends State<BuildUsersList> {
  @override

  final List<_UserEntry> _users = const [
    _UserEntry(
      name: 'Sarah Jenkins',
      role: 'Owner - Full Access',
      isOwner: true,
      isOnline: true,
      isExpired: false,
      avatarUrl:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDjJ-AhN9r_6An4AvMRbgiYwZi0mwd0JufYGRq6DHzefWyGM3V-8rC_Xleh1T8lRakCBFgdZ9NtyPpHEnWqhsp8pdX3duxvo8M5gr4pSSNAaQpKIKo-nS3LSscAddwLjrAlFIU-cKzO2toncJzRF6mzE089eN3JMCRFm3WhX_OP3FCafcM0vt26BPVfG0zejZax9Yd-1CYJysfPvyxoFJBY6TWhBK13clzfrTcMd0SAD9VT8V1uHUf1yFezy1JdSULlgP5eoHnjNdtG',
    ),
    _UserEntry(
      name: 'Marcus Thompson',
      role: 'Family - Scheduled Access',
      isOwner: false,
      isOnline: false,
      isExpired: false,
      avatarUrl:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCuNjEsHZ7DcoalQcNVqUn5dLy-d_m03DbsxD__58TH_op_Kkq8nopj3my8lskkLKz6HoVMn7AyuUvcjAUdkYXLssFbIaphGE8FFS_Sa6Kj0aAV4HsJ4IXVrO6TDrWSmBI0xQhcZ4CYqUqq7rkOKZeUwBal2jm1lRC-ydUn1agJDOK6hIiwwivCuXw4XGdhip_ps4mXkIRim6EILw8l2g_0IAjk44GCTK5MiM4hacfHpdvmEjrpjzqdvUQ9d2P6DjWmEzUyiMfR8SPf',
    ),
    _UserEntry(
      name: 'David Chen',
      role: 'Guest - One-time Pass',
      isOwner: false,
      isOnline: false,
      isExpired: false,
      avatarUrl:
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBIVYihfwFROEJZSckdXlMWSIX-ppGs5fdfyTG6abmqJ1qnY1iUxZLZs5jobNuNiSlh60n-ryKUVZkXKHJyl5UzTob56iQNsqjo14FPm_U-ZVjyeSsJEJDR_U9DDbwdCuCc4U077v4wLQjRa6tvAR08y9cvNsBe-GQ0wjOZgGaCpPImPdO77aB-NOPX-AuABFAOM3MJa7o3m-Dm5yuIQGGjn8ytK8cXx0vDL3wa6_ugxGRhNNfCO3oL1GSKiAsk5vAPVx-Ik12AKRxL',
    ),
    _UserEntry(
      name: 'Expired Access',
      role: 'Technician - Maintenance',
      isOwner: false,
      isOnline: false,
      isExpired: true,
      avatarUrl: null,
    ),
  ];

  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'AUTHORIZED PERSONNEL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ),
          ),
          ...List.generate(
            _users.length,
                (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildUserTile(_users[i], theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(_UserEntry user, ThemeData theme) {
    return Opacity(
      opacity: user.isExpired ? 0.7 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(user),
            const SizedBox(width: 14),
            // Name & role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: user.isExpired
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                      fontStyle: user.isExpired
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.role,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: user.isOwner ? theme.colorScheme.primary : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            // Trailing icon
            Icon(
              user.isExpired ? Icons.history : Icons.chevron_right,
              color: user.isExpired
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF94A3B8),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildAvatar(_UserEntry user) {
    if (user.isExpired) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Color(0xFF94A3B8), size: 28),
      );
    }

    return Stack(
      children: [
        ClipOval(
          child: Image.network(
            user.avatarUrl!,
            width: 54,
            height: 54,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 54,
              height: 54,
              color: const Color(0xFFE2E8F0),
              child: const Icon(
                Icons.person,
                color: Color(0xFF94A3B8),
                size: 28,
              ),
            ),
          ),
        ),
        if (user.isOnline)
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}



class _UserEntry {
  final String name;
  final String role;
  final bool isOwner;
  final bool isOnline;
  final bool isExpired;
  final String? avatarUrl;

  const _UserEntry({
    required this.name,
    required this.role,
    required this.isOwner,
    required this.isOnline,
    required this.isExpired,
    required this.avatarUrl,
  });
}