import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:vdb_realtek/providers/user_provider.dart';

import 'package:flutter_kinesis_video_webrtc/flutter_kinesis_video_webrtc.dart';

class DeviceLandingScreen extends StatefulWidget {
  const DeviceLandingScreen({super.key});

  @override
  State<DeviceLandingScreen> createState() => _DeviceLandingScreenState();
}

class _DeviceLandingScreenState extends State<DeviceLandingScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isConnected = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  Future<void> _initializeStream() async {
    try {
      await _remoteRenderer.initialize();
      // TODO: Connect to KVS signaling channel and establish WebRTC peer connection
      // 1. Get signaling channel endpoint
      // 2. Connect to WSS endpoint as VIEWER
      // 3. Exchange SDP offer/answer via signaling
      // 4. Set remote stream to _remoteRenderer.srcObject
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertyName =
        context.watch<UserProvider>().propertyName ?? 'Your Property';

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(propertyName.toString()),
          actions: [
            IconButton(
              icon: Icon(_isConnected ? Icons.videocam : Icons.videocam_off),
              onPressed: _isConnected ? null : _initializeStream,
            ),
          ],
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to stream...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeStream,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                placeholderBuilder: (context) => const Center(
                  child: Text(
                    'Waiting for video...',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.refresh,
                label: 'Reconnect',
                onPressed: _initializeStream,
              ),
              _buildControlButton(
                icon: _isConnected ? Icons.stop : Icons.play_arrow,
                label: _isConnected ? 'Stop' : 'Start',
                onPressed: _isConnected ? _stopStream : _initializeStream,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label,
          onPressed: onPressed,
          child: Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _stopStream() {
    _remoteRenderer.srcObject = null;
    setState(() {
      _isConnected = false;
    });
  }
}
