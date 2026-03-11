import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_kinesis_video_webrtc/flutter_kinesis_video_webrtc.dart';
import 'package:provider/provider.dart';

import 'package:vdb_realtek/providers/user_provider.dart';

class DeviceLandingScreen extends StatefulWidget {
  const DeviceLandingScreen({super.key});

  @override
  State<DeviceLandingScreen> createState() => _DeviceLandingScreenState();
}

class _DeviceLandingScreenState extends State<DeviceLandingScreen> {
  final RTCVideoRenderer _rtcVideoRenderer = RTCVideoRenderer();
  RTCPeerConnection? _rtcPeerConnection;
  late SignalingClient _signalingClient;
  bool _isLoading = true;
  bool sendAudio = false;
  bool sendVideo = false;
  double _sliderValue = 0.0;
  bool _sliderCompleted = false;
  MediaStream? _localStream;
  Timer? _resetTimer;
  @override
  void initState() {
    super.initState();
    _initializeAndConnect();
  }

  Future<void> _initializeAndConnect() async {
    await _rtcVideoRenderer.initialize();
    await peerConnection();
  }

  @override
  void dispose() {
    _rtcVideoRenderer.dispose();
    _rtcPeerConnection?.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> peerConnection() async {
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

    var webSocket = SimpleWebSocket(
      _signalingClient.domain ?? '',
      _signalingClient.signedQueryParams ?? <String, dynamic>{},
    );

    webSocket.onMessage = (data) async {
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

    webSocket.onOpen = () async {
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
      webSocket.send(jsonEncode(request));
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
      webSocket.send(jsonEncode(request));
    };

    await webSocket.connect();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceName = context.watch<UserProvider>().deviceName ?? 'Your Device';


    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title:  Text(deviceName.toString())),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Connecting to the server...',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _rtcVideoRenderer.value.aspectRatio,
                        child: RTCVideoView(_rtcVideoRenderer),
                      ),
                    ),
                    SizedBox(height: 35.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30.0),
                            color: theme.colorScheme.primary,
                          ),
                          child: IconButton(
                            tooltip: 'Press to Speak',
                            onPressed: () {
                              print('Clicked Mic Button');
                            },
                            icon: Icon(
                              Icons.mic_off_outlined,
                              size: 40.0,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30.0),
                            color: theme.colorScheme.primary,
                          ),
                          child: IconButton(
                            tooltip: 'Press to Capture Image',
                            onPressed: () {
                              print('Clicked Capture Image Button');
                            },
                            icon: Icon(
                              Icons.camera_alt_outlined,
                              size: 40.0,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30.0),
                            color: theme.colorScheme.primary,
                          ),
                          child: IconButton(
                            tooltip: 'Press to End Call',
                            onPressed: () {
                              print('Clicked Hang Up Button');
                            },
                            icon: Icon(
                              Icons.call_end_outlined,
                              size: 40.0,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 50.0),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth;
                        const thumbSize = 45.0;
                        final trackWidth = maxWidth;

                        return GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            if (_sliderCompleted) return;
                            setState(() {
                              _sliderValue = (_sliderValue + details.delta.dx)
                                  .clamp(0.0, trackWidth - thumbSize);
                            });
                          },
                          onHorizontalDragEnd: (details) {
                            if (_sliderValue >= trackWidth - thumbSize - 10) {
                              setState(() {
                                _sliderCompleted = true;
                                _sliderValue = trackWidth - thumbSize;
                              });
                              // TODO: Add your action here when slider is fully dragged
                              print('Slider completed!');

                              // Reset after 7 seconds
                              _resetTimer?.cancel();
                              _resetTimer = Timer(const Duration(seconds: 7), () {
                                setState(() {
                                  _sliderCompleted = false;
                                  _sliderValue = 0.0;
                                });
                              });
                            } else {
                              // Snap back to start
                              setState(() {
                                _sliderValue = 0.0;
                              });
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: thumbSize + 10,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Stack(
                              children: [
                                // Fill progress
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  width: _sliderValue + thumbSize,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                                // Label text
                                Center(
                                  child: Text(
                                    _sliderCompleted ? 'Unlocked!' : 'Slide to unlock',
                                    style: TextStyle(
                                      color: theme.colorScheme.secondary.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                // Thumb
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 100),
                                  left: _sliderValue,
                                  top: 5,
                                  child: Container(
                                    width: thumbSize,
                                    height: thumbSize,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: Icon(
                                      _sliderCompleted
                                          ? Icons.check
                                          : Icons.chevron_right,
                                      color: theme.colorScheme.primary,
                                      size: 30.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
