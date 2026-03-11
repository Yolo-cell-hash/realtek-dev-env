import 'package:flutter/material.dart';
import 'package:vdb_realtek/widgets/quick_action_button.dart';

class LiveFeed extends StatefulWidget {
  const LiveFeed({super.key});

  @override
  State<LiveFeed> createState() => _LiveFeedState();
}

class _LiveFeedState extends State<LiveFeed> with SingleTickerProviderStateMixin {

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;


  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Feed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    FadeTransition(
                      opacity: _pulseAnimation,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildVideoPlayer(),
          const SizedBox(height: 12),
          _buildQuickActions(),
        ],
      ),
    );
  }


  Widget _buildVideoPlayer() {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'images/bg_feed.png',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Colors.transparent,
                    Color(0x99000000),
                  ],stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Front Porch • 1080p',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black38)
                            ]),
                      ),
                      const Text(
                        '12:45:08 PM',
                        style: TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 11,
                            fontFeatures: [
                              FontFeature.tabularFigures()
                            ]),
                      ),
                    ],
                  ),
                  Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration:  BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4))
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 4,
                            color: Colors.white30,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 1 / 3,
                              child: Container(color: theme.colorScheme.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.fullscreen,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      const Icon(Icons.volume_up_outlined,
                          color: Colors.white, size: 22),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final theme = Theme.of(context);

    final actions = [
      {'icon': Icons.mic_outlined, 'label': 'Talk', 'active': false},
      {'icon': Icons.camera_alt_outlined, 'label': 'Snapshot', 'active': false},
      {'icon': Icons.flashlight_on_outlined, 'label': 'Light', 'active': false},
      {'icon': Icons.shield_outlined, 'label': 'Armed', 'active': true},
    ];

    return Row(
      children: actions.map((action) {
        final isActive = action['active'] as bool;
        return Expanded(
          child: Padding(
            padding:  EdgeInsets.symmetric(horizontal: 3),
            child: QuickActionButton(
              icon: action['icon'] as IconData,
              label: action['label'] as String,
              isActive: isActive,
              primaryColor: theme.colorScheme.primary,
            ),
          ),
        );
      }).toList(),
    );
  }
}
