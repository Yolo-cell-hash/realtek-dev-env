import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_kinesis_video_webrtc/flutter_kinesis_video_webrtc.dart';
import 'package:vdb_realtek/services/mqtt_service.dart';

enum _EnrollmentResult { none, success, failure }

class NewUserOnboardingScreen extends StatefulWidget {
  const NewUserOnboardingScreen({super.key});

  @override
  State<NewUserOnboardingScreen> createState() =>
      _NewUserOnboardingScreenState();
}

class _NewUserOnboardingScreenState extends State<NewUserOnboardingScreen>
    with TickerProviderStateMixin {
  // ─── KVS WebRTC ────────────────────────────────────────────────────────────
  final RTCVideoRenderer _rtcVideoRenderer = RTCVideoRenderer();
  RTCPeerConnection? _rtcPeerConnection;
  late SignalingClient _signalingClient;
  bool _isLoading = false;
  bool _isConnected = false;
  bool sendAudio = false;
  bool sendVideo = false;
  MediaStream? _localStream;
  SimpleWebSocket? _webSocket;

  // ─── Animations ────────────────────────────────────────────────────────────
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ─── Registration state ───────────────────────────────────────────────────
  bool _isRegistering = false;
  _EnrollmentResult _enrollmentResult = _EnrollmentResult.none;

  // ─── Progress simulation ──────────────────────────────────────────────────
  double _progress = 0.0;
  Timer? _progressTimer;
  String _statusText = 'Initializing...';
  String _statusSubText = 'Connecting to video feed';

  // ─── MQTT listener ────────────────────────────────────────────────────────
  VoidCallback? _mqttListener;

  @override
  void initState() {
    super.initState();

    // Scan line animation — created stopped; starts on confirm
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    // Ring pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize renderer then start KVS feed
    _rtcVideoRenderer.initialize().then((_) => _startFeed());
  }

  @override
  void dispose() {
    // Remove MQTT listener
    if (_mqttListener != null) {
      MqttService.instance.removeListener(_mqttListener!);
    }
    _progressTimer?.cancel();
    _scanLineController.dispose();
    _pulseController.dispose();
    _rtcVideoRenderer.dispose();
    _rtcPeerConnection?.dispose();
    _localStream?.dispose();
    _webSocket?.close();
    super.dispose();
  }

  // ─── KVS Feed lifecycle ───────────────────────────────────────────────────

  Future<void> _startFeed() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Connecting...';
      _statusSubText = 'Establishing video connection';
    });
    await _peerConnection();
  }

  Future<void> _stopFeed() async {
    _progressTimer?.cancel();

    await _webSocket?.close();
    _webSocket = null;

    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;

    await _rtcPeerConnection?.close();
    _rtcPeerConnection = null;

    _rtcVideoRenderer.srcObject = null;

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isConnected = false;
      });
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
          _isConnected = true;
          _statusText = 'Ready';
          _statusSubText = 'Tap Confirm to begin face registration';
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

  // ─── Confirm Registration ─────────────────────────────────────────────────

  void _confirmRegistration() {
    final mqttService = context.read<MqttService>();

    // Send MQTT enroll face command
    mqttService.publish(
      'vdb/sandbox_001/vdb-sandbox-001/cmd',
      jsonEncode(mqttService.mqttPayloadSchema.messageEnrollFace),
    );

    setState(() {
      _isRegistering = true;
      _enrollmentResult = _EnrollmentResult.none;
      _statusText = 'Scanning...';
      _statusSubText = 'Keep still, detecting features';
    });

    // Start the scan line animation
    _scanLineController.repeat();

    // Start progress simulation
    _startProgressSimulation();

    // Listen for enrollment result from MQTT
    _startMqttListener(mqttService);
  }

  // ─── MQTT enrollment result listener ──────────────────────────────────────

  int _lastSeenVersion = -1;

  void _startMqttListener(MqttService mqttService) {
    // Remove any previous listener
    if (_mqttListener != null) {
      mqttService.removeListener(_mqttListener!);
    }

    _lastSeenVersion = mqttService.messageVersion;

    _mqttListener = () {
      if (!mounted) return;

      // Only process when a REAL message arrived (version incremented),
      // not on connection state changes.
      if (mqttService.messageVersion == _lastSeenVersion) return;
      _lastSeenVersion = mqttService.messageVersion;

      final topic = mqttService.lastReceivedTopic;
      final payload = mqttService.lastReceivedPayload;

      print('──────────────────────────────────────────────────');
      print('[Enrollment] New message v${mqttService.messageVersion}');
      print('[Enrollment] Topic: $topic');
      print('[Enrollment] Payload: $payload');
      print('──────────────────────────────────────────────────');

      if (payload.isEmpty) return;

      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;

        final source = data['source'] as String? ?? '';
        final msgType = data['msg_type'] as String? ?? '';

        print('[Enrollment] source="$source", msg_type="$msgType"');

        if (source == 'vdb') {
          if (msgType == 'enroll.success') {
            print('[Enrollment] ✅ MATCH: enroll.success from vdb');
            _onEnrollmentSuccess();
          } else if (msgType == 'enroll.fail') {
            print('[Enrollment] ❌ MATCH: enroll.fail from vdb');
            _onEnrollmentFailure();
          }
        }
      } catch (e) {
        print('[Enrollment] Error parsing MQTT payload: $e');
      }
    };

    mqttService.addListener(_mqttListener!);
  }

  void _onEnrollmentSuccess() {
    _progressTimer?.cancel();
    _scanLineController.stop();

    setState(() {
      _enrollmentResult = _EnrollmentResult.success;
      _progress = 1.0;
      _statusText = 'Registration Complete!';
      _statusSubText = 'Face enrolled successfully';
    });
  }

  void _onEnrollmentFailure() {
    _progressTimer?.cancel();
    _scanLineController.stop();

    setState(() {
      _enrollmentResult = _EnrollmentResult.failure;
      _progress = _progress; // freeze at current value
      _statusText = 'Registration Failed';
      _statusSubText = 'Could not enroll face, please try again';
    });
  }

  void _retryRegistration() {
    setState(() {
      _isRegistering = false;
      _enrollmentResult = _EnrollmentResult.none;
      _progress = 0.0;
      _statusText = 'Ready';
      _statusSubText = 'Tap Confirm to begin face registration';
    });
  }

  // ─── Progress simulation ──────────────────────────────────────────────────

  void _startProgressSimulation() {
    _progressTimer?.cancel();
    _progress = 0.0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress += 0.015;
        if (_progress >= 0.65) {
          _progress = 0.65; // Hold at 65% as shown in the HTML design
          _statusText = 'Scanning...';
          _statusSubText = 'Keep still, detecting features';
        } else if (_progress >= 0.4) {
          _statusText = 'Scanning...';
          _statusSubText = 'Analyzing facial geometry';
        } else if (_progress >= 0.2) {
          _statusText = 'Scanning...';
          _statusSubText = 'Face detected, aligning';
        }
      });
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(theme),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildInstructionsHeader(theme),
              _buildBiometricScanner(theme),
              if (_isRegistering || _enrollmentResult != _EnrollmentResult.none)
                _buildProgressSection(theme),
              _buildActionFeedback(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────

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
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      titleSpacing: 0,
      title: const Text(
        'Face Registration',
        style: TextStyle(
          fontFamily: 'GEG-Bold',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: Color(0xFF0F172A),
          letterSpacing: -0.3,
        ),
      ),
      actions: const [SizedBox(width: 48)], // Spacer to balance leading icon
    );
  }

  // ─── Instructions Header ─────────────────────────────────────────────────

  Widget _buildInstructionsHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        children: [
          Text(
            'Center your face in the frame',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF0F172A),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Position your head within the circle and follow the on-screen instructions for biometric verification.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.brightness == Brightness.dark
                  ? Colors.grey[400]
                  : const Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.normal,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Biometric Scanner ────────────────────────────────────────────────────

  Widget _buildBiometricScanner(ThemeData theme) {
    const double outerSize = 280;
    const double innerSize = 256;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: outerSize + 16,
          height: outerSize + 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer decorative ring (pulsing) — changes color on result
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, child) =>
                    Transform.scale(scale: _pulseAnimation.value, child: child),
                child: Container(
                  width: outerSize + 12,
                  height: outerSize + 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _ringColor(theme).withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),
              ),

              // Inner decorative ring
              Container(
                width: outerSize - 4,
                height: outerSize - 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _ringColor(theme).withOpacity(0.4),
                    width: 2,
                  ),
                ),
              ),

              // Circular video preview
              Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _ringColor(theme), width: 4),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video feed or placeholder
                      _isConnected
                          ? RTCVideoView(
                              _rtcVideoRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            )
                          : Container(
                              color: theme.brightness == Brightness.dark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                              child: Center(
                                child: _isLoading
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(
                                            color: theme.colorScheme.primary,
                                            strokeWidth: 3,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Connecting...',
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Icon(
                                        Icons.face,
                                        size: 72,
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.3),
                                      ),
                              ),
                            ),

                      // Scanning line overlay (only while actively scanning)
                      if (_isConnected &&
                          _isRegistering &&
                          _enrollmentResult == _EnrollmentResult.none)
                        AnimatedBuilder(
                          animation: _scanLineAnimation,
                          builder: (_, child) {
                            return Positioned(
                              top: _scanLineAnimation.value * innerSize,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      theme.colorScheme.primary.withOpacity(
                                        0.8,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.6),
                                      blurRadius: 12,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      // Success / failure overlay on the video circle
                      if (_enrollmentResult != _EnrollmentResult.none)
                        Container(
                          color: _enrollmentResult == _EnrollmentResult.success
                              ? const Color(0xCC16A34A) // green overlay
                              : const Color(0xCCDC2626), // red overlay
                          child: Center(
                            child: Icon(
                              _enrollmentResult == _EnrollmentResult.success
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: Colors.white,
                              size: 72,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Corner brackets — top-left
              Positioned(
                top: 0,
                left: 0,
                child: _cornerBracket(
                  theme,
                  borderTop: true,
                  borderLeft: true,
                  radiusTL: 16,
                ),
              ),
              // Corner brackets — top-right
              Positioned(
                top: 0,
                right: 0,
                child: _cornerBracket(
                  theme,
                  borderTop: true,
                  borderRight: true,
                  radiusTR: 16,
                ),
              ),
              // Corner brackets — bottom-left
              Positioned(
                bottom: 0,
                left: 0,
                child: _cornerBracket(
                  theme,
                  borderBottom: true,
                  borderLeft: true,
                  radiusBL: 16,
                ),
              ),
              // Corner brackets — bottom-right
              Positioned(
                bottom: 0,
                right: 0,
                child: _cornerBracket(
                  theme,
                  borderBottom: true,
                  borderRight: true,
                  radiusBR: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cornerBracket(
    ThemeData theme, {
    bool borderTop = false,
    bool borderBottom = false,
    bool borderLeft = false,
    bool borderRight = false,
    double radiusTL = 0,
    double radiusTR = 0,
    double radiusBL = 0,
    double radiusBR = 0,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: borderTop
              ? BorderSide(color: theme.colorScheme.primary, width: 4)
              : BorderSide.none,
          bottom: borderBottom
              ? BorderSide(color: theme.colorScheme.primary, width: 4)
              : BorderSide.none,
          left: borderLeft
              ? BorderSide(color: theme.colorScheme.primary, width: 4)
              : BorderSide.none,
          right: borderRight
              ? BorderSide(color: theme.colorScheme.primary, width: 4)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radiusTL),
          topRight: Radius.circular(radiusTR),
          bottomLeft: Radius.circular(radiusBL),
          bottomRight: Radius.circular(radiusBR),
        ),
      ),
    );
  }

  // ─── Ring color helper ────────────────────────────────────────────────────

  Color _ringColor(ThemeData theme) {
    switch (_enrollmentResult) {
      case _EnrollmentResult.success:
        return const Color(0xFF16A34A); // green
      case _EnrollmentResult.failure:
        return const Color(0xFFDC2626); // red
      case _EnrollmentResult.none:
        return theme.colorScheme.primary;
    }
  }

  // ─── Progress Section ─────────────────────────────────────────────────────

  Widget _buildProgressSection(ThemeData theme) {
    final int progressPercent = (_progress * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusText,
                    style: TextStyle(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusSubText,
                    style: TextStyle(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[400]
                          : const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
              backgroundColor: _ringColor(theme).withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_ringColor(theme)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Action / Status Feedback ─────────────────────────────────────────────

  Widget _buildActionFeedback(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Column(
        children: [
          // Info / result banner
          _buildInfoBanner(theme),
          const SizedBox(height: 20),
          // Buttons based on state
          ..._buildActionButtons(theme),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(ThemeData theme) {
    final Color bannerColor;
    final IconData bannerIcon;
    final String bannerText;

    switch (_enrollmentResult) {
      case _EnrollmentResult.success:
        bannerColor = const Color(0xFF16A34A);
        bannerIcon = Icons.check_circle_outline;
        bannerText = 'Face registered successfully!';
        break;
      case _EnrollmentResult.failure:
        bannerColor = const Color(0xFFDC2626);
        bannerIcon = Icons.warning_amber_rounded;
        bannerText = 'Enrollment failed. Please try again.';
        break;
      case _EnrollmentResult.none:
        bannerColor = theme.colorScheme.primary;
        bannerIcon = Icons.info_outline;
        bannerText = _isRegistering
            ? 'Keep still while scanning is in progress'
            : 'Ensure you are in a well-lit environment';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bannerText,
              style: TextStyle(
                color: bannerColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(ThemeData theme) {
    // ── Success state: "Done" button
    if (_enrollmentResult == _EnrollmentResult.success) {
      return [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await _stopFeed();
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.check, size: 20),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: const Color(0x4D16A34A),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ];
    }

    // ── Failure state: "Retry" + "Cancel"
    if (_enrollmentResult == _EnrollmentResult.failure) {
      return [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _retryRegistration,
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('Retry Registration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: theme.colorScheme.primary.withOpacity(0.3),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await _stopFeed();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
      ];
    }

    // ── Pre-confirm: "Confirm" + "Cancel" (outlined)
    // ── Scanning in progress: just "Cancel" (filled)
    return [
      if (_isConnected && !_isRegistering)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: theme.colorScheme.primary.withOpacity(0.3),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('Confirm Registration'),
          ),
        ),
      if (_isConnected && !_isRegistering) const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            await _stopFeed();
            if (mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRegistering
                ? theme.colorScheme.primary
                : Colors.transparent,
            foregroundColor: _isRegistering
                ? Colors.white
                : theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _isRegistering
                  ? BorderSide.none
                  : BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
            elevation: _isRegistering ? 4 : 0,
            shadowColor: theme.colorScheme.primary.withOpacity(0.3),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: const Text('Cancel Registration'),
        ),
      ),
    ];
  }
}
