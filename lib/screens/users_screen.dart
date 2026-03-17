import 'package:flutter/material.dart';
import 'package:vdb_realtek/widgets/bottom_nav.dart';
import 'package:vdb_realtek/widgets/security_note.dart';
import 'package:vdb_realtek/widgets/build_users_list.dart';
import 'package:vdb_realtek/widgets/register_new_face.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(theme),
      body: _buildBody(theme),
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
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: Color(0x1A810055), width: 1),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: theme.colorScheme.primary,
          size: 26,
        ),
        onPressed: () => Navigator.pushReplacementNamed(context, '/vdbLanding'),
      ),
      centerTitle: true,
      titleSpacing: 0,
      title: const Text(
        'Manage Authorized Users',
        style: TextStyle(
          fontFamily: 'GEG-Bold',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: Color(0xFF0F172A),
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_horiz, color: theme.colorScheme.primary),
          onPressed: () {},
        ),
      ],
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RegisterNewFace(),
          BuildUsersList(),
          SecurityNote(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
