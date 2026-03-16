import 'package:flutter/material.dart';
import 'package:vdb_realtek/widgets/quick_action_button.dart';
import 'package:provider/provider.dart';
import 'package:vdb_realtek/services/mqtt_service.dart';

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_kinesis_video_webrtc/flutter_kinesis_video_webrtc.dart';

class LiveFeed extends StatefulWidget {
  const LiveFeed({super.key});

  @override
  State<LiveFeed> createState() => _LiveFeedState();
}

class _LiveFeedState extends State<LiveFeed>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final RTCVideoRenderer _rtcVideoRenderer = RTCVideoRenderer();
  RTCPeerConnection? _rtcPeerConnection;
  late SignalingClient _signalingClient;
  bool _isLoading = false;
  bool _feedActive = false;
  bool sendAudio = false;
  bool sendVideo = false;
  MediaStream? _localStream;
  SimpleWebSocket? _webSocket;
  late Timer _clockTimer;
  String currentTime = '';

  @override
  void initState() {
    super.initState();
    currentTime = _getISTTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        currentTime = _getISTTime();
      });
    });
    _rtcVideoRenderer.initialize();
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
    _clockTimer.cancel();
    _pulseController.dispose();
    _rtcVideoRenderer.dispose();
    _rtcPeerConnection?.dispose();
    _localStream?.dispose();
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
    setState(() {
      _isLoading = true;
      _feedActive = true;
    });
    context.read<MqttService>().sendStart();
    await _peerConnection();
  }

  Future<void> _stopFeed() async {
    context.read<MqttService>().sendStop();

    await _webSocket?.close();
    _webSocket = null;
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;
    await _rtcPeerConnection?.close();
    _rtcPeerConnection = null;
    _rtcVideoRenderer.srcObject = null;

    setState(() {
      _feedActive = false;
      _isLoading = false;
    });
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
      setState(() {
        _rtcVideoRenderer.srcObject = event.streams[0];
        _isLoading = false;
      });
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
      RTCSessionDescription? localDescription =
      await _rtcPeerConnection?.getLocalDescription();

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
            // Show RTCVideoView only when feed is active and not loading
            (!_feedActive || _isLoading)
                ? Image.asset('images/bg_feed.png', fit: BoxFit.cover)
                : RTCVideoView(
              _rtcVideoRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
                  ],
                  stops: [0.0, 0.4, 1.0],
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
                            Shadow(blurRadius: 4, color: Colors.black38),
                          ],
                        ),
                      ),
                      Text(
                        currentTime,
                        style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 11,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  // Show spinner while connecting
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    const SizedBox.shrink(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.volume_up_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
            ),],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final theme = Theme.of(context);
    final mqttFeedActive = context.watch<MqttService>().feedActive;

    final actions = [
      {'icon': Icons.mic_outlined, 'label': 'Talk', 'active': false, 'onTap': null},
      {'icon': Icons.video_camera_back_outlined, 'label': 'Surveillance', 'active': false, 'onTap': null},
      {'icon': Icons.fiber_manual_record, 'label': 'Record', 'active': false, 'onTap': null},
      {
        'icon': mqttFeedActive ? Icons.stop_circle_outlined : Icons.play_arrow,
        'label': mqttFeedActive ? 'Stop Feed' : 'View Feed',
        'active': mqttFeedActive,
        'onTap': mqttFeedActive ? _stopFeed : _startFeed,
      },
    ];

    return Row(
      children: actions.map((action) {
        final isActive = action['active'] as bool;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: QuickActionButton(
              icon: action['icon'] as IconData,
              label: action['label'] as String,
              isActive: isActive,
              primaryColor: theme.colorScheme.primary,
              onTap: action['onTap'] as VoidCallback?,
            ),
          ),
        );
      }).toList(),
    );
  }
}
