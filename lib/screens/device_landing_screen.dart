import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_kinesis_video_webrtc/flutter_kinesis_video_webrtc.dart';

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
  MediaStream? _localStream;

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
          print("-------------------- receiving ${objectOfData['messageType']} --------------------");
        }

        if (objectOfData['messageType'] == "SDP_ANSWER") {
          var decodedAns = jsonDecode(
              utf8.decode(base64.decode(objectOfData['messagePayload'])));
          await _rtcPeerConnection?.setRemoteDescription(RTCSessionDescription(
            decodedAns["sdp"],
            decodedAns["type"],
          ));
        } else if (objectOfData['messageType'] == "ICE_CANDIDATE") {
          var decodedCandidate = jsonDecode(
              utf8.decode(base64.decode(objectOfData['messagePayload'])));
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
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
        'optional': [],
      });

      await _rtcPeerConnection!.setLocalDescription(offer);
      RTCSessionDescription? localDescription =
      await _rtcPeerConnection?.getLocalDescription();

      var request = {};
      request["action"] = "SDP_OFFER";
      request["messagePayload"] =
          base64.encode(jsonEncode(localDescription?.toMap()).codeUnits);
      webSocket.send(jsonEncode(request));
    };

    _rtcPeerConnection!.onIceCandidate = (dynamic candidate) {
      if (kDebugMode) {
        print("-------------------- sending 'ICE_CANDIDATE' --------------------");
      }

      var request = {};
      request["action"] = "ICE_CANDIDATE";
      request["messagePayload"] =
          base64.encode(jsonEncode(candidate.toMap()).codeUnits);
      webSocket.send(jsonEncode(request));
    };

    await webSocket.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Stream'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Connecting to the server...',
                style: TextStyle(fontSize: 16,color: Colors.black),
              ),
            ],
          ),
        )
            : Center(
          child: AspectRatio(
            aspectRatio: _rtcVideoRenderer.value.aspectRatio,
            child: RTCVideoView(_rtcVideoRenderer),
          ),
        ),
      ),
    );
  }
}
