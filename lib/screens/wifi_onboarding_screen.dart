import 'package:flutter/material.dart';

class WifiOnboardingScreen extends StatefulWidget {
  const WifiOnboardingScreen({super.key});

  @override
  State<WifiOnboardingScreen> createState() => _WifiOnboardingScreenState();
}

class _WifiOnboardingScreenState extends State<WifiOnboardingScreen> {
  final _ssidController = TextEditingController(text: 'Home_Secure_5G');
  final _passwordController = TextEditingController(text: '············');
  bool _obscurePassword = true;

  static const Color _primary = Color(0xFF800053);
  static const Color _secondary = Color(0xFFF1F2ED);

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);


    return Scaffold(

    backgroundColor: isDark ? const Color(0xFF230F1C) : theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isDark),
                        _buildProgressSection(isDark),
                        _buildFormSection(isDark),
                      ],
                    ),
                  ),
                ),
                _buildFooter(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.arrow_back,
                  color: _primary,
                  size: 28,
                ),
              ),
            ),
          ),
          Text(
            'Device Configuration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(bool isDark) {
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
                  const Text(
                    'STEP 3 OF 3',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Finalizing Setup',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 1.0,
              minHeight: 8,
              backgroundColor:
                  isDark ? _primary.withOpacity(0.2) : _primary.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(_primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connecting your Video Doorbell to secure network',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFormSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WiFi Setup',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your device needs access to your local network to stream video and send alerts.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 24),
          // SSID Field
          _buildInputLabel('WiFi Name (SSID)', isDark),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _ssidController,
            hint: 'Select your network',
            isDark: isDark,
            suffixIcon: const Icon(Icons.wifi_find, color: _primary),
          ),
          const SizedBox(height: 16),
          // Password Field
          _buildInputLabel('Network Password', isDark),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _passwordController,
            hint: 'Enter password',
            isDark: isDark,
            obscureText: _obscurePassword,
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Security Hint
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? _primary.withOpacity(0.05)
                  : _secondary.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primary.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Connections are encrypted using WPA3. Your password is never shared with third parties and stays locally on the device.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required Widget suffixIcon,
    bool obscureText = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? _primary.withOpacity(0.3)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
            ),
          ),Padding(
            padding: const EdgeInsets.only(right: 16),
            child: suffixIcon,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    final theme = Theme.of(context);

    return Container(
      color: isDark ? const Color(0xFF230F1C) : theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/vdbLanding');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: _primary.withOpacity(0.3),
              ),
              child: const Text(
                'Complete Configuration',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Icon(widget.icon, color: widget.color, size: 24),
    );
  }
}