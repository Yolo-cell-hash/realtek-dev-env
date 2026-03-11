import 'package:flutter/material.dart';
import 'package:vdb_realtek/widgets/bottom_nav.dart';

class DeviceOnboardingScreen extends StatefulWidget {
  const DeviceOnboardingScreen({super.key});

  @override
  State<DeviceOnboardingScreen> createState() => _DeviceOnboardingScreenState();
}

class _DeviceOnboardingScreenState extends State<DeviceOnboardingScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _deviceNameController = TextEditingController();
  late AnimationController _pingController;


  @override
  void initState() {
    super.initState();
    _pingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _pingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepHeader(),
                  const SizedBox(height: 32),
                  _buildHeroSection(),
                  const SizedBox(height: 32),
                  _buildDeviceNameInput(),
                  const SizedBox(height: 32.0),
                  _buildNextButton(),

                ],
              ),
            ),
          ),
          BottomNav(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.85),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon:  Icon(Icons.arrow_back, color:theme.colorScheme.primary),
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: Colors.transparent,
        ).copyWith(
          overlayColor: WidgetStateProperty.all(theme.colorScheme.primary.withOpacity(0.1)),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Add New Device',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          letterSpacing: -0.3,
        ),
      ),actions: [
        IconButton(
          icon:  Icon(Icons.help_outline, color: theme.colorScheme.primary),
          style: IconButton.styleFrom(
            shape: const CircleBorder(),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(theme.colorScheme.primary.withOpacity(0.1)),
          ),
          onPressed: () {},
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.primary.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding:  EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient:  LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, Color(0xFF9A0066)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect your VDB',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ensure your phone is connected to Wi-Fi and the device is powered on.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.5,
                ),
              ),
            ],
          ),
          Positioned(
            top: -30,
            right: -20,
            child: Icon(
              Icons.videocam,
              size: 130,
              color: Colors.white.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceNameInput() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children:  [
            Icon(Icons.edit, color: theme.colorScheme.primary, size: 16),
            SizedBox(width: 8),
            Text(
              'Device Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _deviceNameController,
          decoration: InputDecoration(
            hintText: 'e.g. Front Door VDB',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
            ),focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:  BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
          ),),
      ],
    );
  }

  Widget _buildStepHeader() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'STEP 2 OF 3',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Property Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const Text(
                '66% Complete',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.66,
              minHeight: 8,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              valueColor:  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(context, '/wifi0nboarding');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 6,
          shadowColor: theme.colorScheme.primary.withOpacity(0.35),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Next Step',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

}
