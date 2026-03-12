import 'package:flutter/material.dart';
import 'package:vdb_realtek/widgets/bottom_nav.dart';

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_kinesis_video_webrtc/flutter_kinesis_video_webrtc.dart';

class LiveVideoScreen extends StatefulWidget {
  const LiveVideoScreen({super.key});

  @override
  State<LiveVideoScreen> createState() => _LiveVideoScreenState();
}

class _LiveVideoScreenState extends State<LiveVideoScreen>
    with SingleTickerProviderStateMixin {
  bool _isTalkActive = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // WebRTC / KVS
  final RTCVideoRenderer _rtcVideoRenderer = RTCVideoRenderer();
  RTCPeerConnection? _rtcPeerConnection;
  late SignalingClient _signalingClient;
  bool _isLoading = false;
  bool sendAudio = false;
  bool sendVideo = false;
  MediaStream? _localStream;
  SimpleWebSocket? _webSocket;

  // Clock
  late Timer _clockTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();

    _currentTime = _getISTTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = _getISTTime());
    });

    _rtcVideoRenderer.initialize().then((_) => _startFeed());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pulseController.dispose();
    _rtcVideoRenderer.dispose();
    _rtcPeerConnection?.dispose();
    _localStream?.dispose();
    _webSocket?.close();
    super.dispose();
  }

  String _getISTTime() {
    final utc = DateTime.now().toUtc();
    final ist = utc.add(const Duration(hours: 5, minutes: 30));
    int hour = ist.hour;
    final String period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final String hh = hour.toString().padLeft(2, '0');
    final String mm = ist.minute.toString().padLeft(2, '0');
    final String ss = ist.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss $period';
  }

  Future<void> _startFeed() async {
    setState(() => _isLoading = true);
    await _peerConnection();
  }

  Future<void> _stopFeed() async {
    await _webSocket?.close();
    _webSocket = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;

    await _rtcPeerConnection?.close();
    _rtcPeerConnection = null;

    _rtcVideoRenderer.srcObject = null;

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _peerConnection() async {
    _signalingClient = SignalingClient(
      channelName: dotenv.env['KVS_CHANNEL_NAME']!,
      accessKey: dotenv.env['AWS_ACCESS_KEY']!,
      secretKey: dotenv.env['AWS_SECRET_KEY']!,
      region: dotenv.env['AWS_REGION']!,
    );

    await _signalingClient.init();

    _rtcPeerConnection = await createPeerConnection({
      'iceServers': _signalingClient.iceServers,
      'iceTransportPolicy': 'all',
    });

    _rtcPeerConnection!.onTrack = (event) {
      if (mounted) {
        setState(() {
          _rtcVideoRenderer.srcObject = event.streams[0];
          _isLoading = false;
        });
      }
    };

    if (sendAudio || sendVideo) {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': sendAudio,
        'video': sendVideo,
      });
      _localStream!.getTracks().forEach((track) {
        _rtcPeerConnection!.addTrack(track, _localStream!);
      });
    }

    _webSocket = SimpleWebSocket(
      _signalingClient.domain ?? '',
      _signalingClient.signedQueryParams ?? <String, dynamic>{},
    );

    _webSocket!.onMessage = (data) async {
      if (data != '') {
        var objectOfData = jsonDecode(data);
        if (kDebugMode) {
          print(
            "-------------------- receiving ${objectOfData['messageType']} --------------------",
          );
        }

        if (objectOfData['messageType'] == "SDP_ANSWER") {
          var decodedAns = jsonDecode(
            utf8.decode(base64.decode(objectOfData['messagePayload'])),
          );
          await _rtcPeerConnection?.setRemoteDescription(
            RTCSessionDescription(decodedAns["sdp"], decodedAns["type"]),
          );
        } else if (objectOfData['messageType'] == "ICE_CANDIDATE") {
          var decodedCandidate = jsonDecode(
            utf8.decode(base64.decode(objectOfData['messagePayload'])),
          );
          await _rtcPeerConnection?.addCandidate(
            RTCIceCandidate(
              decodedCandidate["candidate"],
              decodedCandidate["sdpMid"],
              decodedCandidate["sdpMLineIndex"],
            ),
          );
        }
      }
    };

    _webSocket!.onOpen = () async {
      if (kDebugMode) {
        print("-------------------- socket opened --------------------");
        print("-------------------- sending 'SDP_OFFER' --------------------");
      }

      RTCSessionDescription offer = await _rtcPeerConnection!.createOffer({
        'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
        'optional': [],
      });

      await _rtcPeerConnection!.setLocalDescription(offer);
      RTCSessionDescription? localDescription = await _rtcPeerConnection
          ?.getLocalDescription();

      var request = {};
      request["action"] = "SDP_OFFER";
      request["messagePayload"] = base64.encode(
        jsonEncode(localDescription?.toMap()).codeUnits,
      );
      _webSocket!.send(jsonEncode(request));
    };

    _rtcPeerConnection!.onIceCandidate = (dynamic candidate) {
      if (kDebugMode) {
        print(
          "-------------------- sending 'ICE_CANDIDATE' --------------------",
        );
      }

      var request = {};
      request["action"] = "ICE_CANDIDATE";
      request["messagePayload"] = base64.encode(
        jsonEncode(candidate.toMap()).codeUnits,
      );
      _webSocket!.send(jsonEncode(request));
    };

    await _webSocket!.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildLiveFeedArea()),
          _buildQuickResponses(),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/vdbLanding');
            case 1:
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/events');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/settings');
              break;
          }
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: theme.colorScheme.primary,
          size: 26,
        ),
        onPressed: () => Navigator.pushReplacementNamed(context, '/vdbLanding')
      ),
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: Color(0x1A810055), width: 1),
      ),
      titleSpacing: 0,
      title: Column(
        children: [
          const Text(
            'Front Door',
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'GEG-Bold',
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isLoading
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _isLoading ? 'CONNECTING...' : 'CONNECTED',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.settings_outlined, color: theme.colorScheme.primary),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildLiveFeedArea() {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Video renderer (fills entire area)
        Positioned.fill(
          child: _isLoading
              ? Image.asset(
                  'images/filler.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey[900]),
                )
              : RTCVideoView(
                  _rtcVideoRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
        ),

        // Gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),

        // Top overlays
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              _glassChip(
                child: Text(
                  _currentTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),

        // Loading spinner (center) while connecting
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Talk active indicator (center) — only when not loading
        if (_isTalkActive && !_isLoading)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 128,
                  height: 128,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.mic,
                    color: theme.colorScheme.primary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Listening...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ],
            ),
          ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _controlButton(
                  label: 'Talk',
                  backgroundColor: Colors.white,
                  iconColor: const Color(0xFF810055),
                  icon: Icons.mic,
                  onTap: () => setState(() => _isTalkActive = !_isTalkActive),
                ),
                _controlButton(
                  label: 'Record',
                  backgroundColor: Colors.white.withOpacity(0.2),
                  iconColor: Colors.white,
                  icon: Icons.videocam_off_outlined,
                  onTap: () {},
                ),
                _controlButton(
                  label: 'Snapshot',
                  backgroundColor: Colors.white.withOpacity(0.2),
                  iconColor: Colors.white,
                  icon: Icons.photo_camera_outlined,
                  onTap: () {},
                ),
                _EndCallButton(
                  pulseController: _pulseController,
                  onEndCall: () async {
                    await _stopFeed();
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, '/vdbLanding');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickResponses() {
    final responses = [
      'Leave at door',
      'One moment',
      'No thanks',
      'Wait please',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x1A810055), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK RESPONSES',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: responses
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _quickResponseChip(r),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _quickResponseChip(String label) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F2ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x0D810055)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _glassChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _controlButton({
    required String label,
    required Color backgroundColor,
    required Color iconColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndCallButton extends StatelessWidget {
  final AnimationController pulseController;
  final VoidCallback onEndCall;

  const _EndCallButton({
    required this.pulseController,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: pulseController,
          builder: (_, child) => Transform.scale(
            scale: 0.9 + (pulseController.value * 0.1),
            child: child,
          ),
          child: GestureDetector(
            onTap: onEndCall,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x44DC2626),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'End Call',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
