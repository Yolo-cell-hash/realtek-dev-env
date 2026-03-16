class MqttPayloadSchema {

  static const String _clientId = 'flutter-app-sandbox-001';
  final int timestamp = DateTime.now().millisecondsSinceEpoch;
  final String _videoQuality = "high";
  final String _videoCodec = "h264";
  final String _resolution = "1920x1080";

  final String _cmdTypeStartStream = "stream.start";
  final String _cmdTypeStopStream = "stream.stop";
  final String _cmdTypeEnrollFace = "face.enroll";
  final String _cmdTypeDeleteFace = "face.delete";

  late final Map<String, dynamic> messageStreamStart = {
    "msg_type": _cmdTypeStartStream,
    "msg_id": "${_cmdTypeStartStream}_$timestamp",
    "timestamp": timestamp,
    "user_id": _clientId,
    "source": "app",
    "payload": {
      "session_id": "session_$timestamp",
      "quality": _videoQuality,
      "codec": _videoCodec,
      "resolution": _resolution,
      "audio_enabled": true,
      "ice_servers": <String>['dummyIceServer1']
    }
  };

  late final Map<String, dynamic> messageStreamStop = {
    "msg_type": _cmdTypeStopStream,
    "msg_id": "${_cmdTypeStopStream}_$timestamp",
    "timestamp": timestamp,
    "user_id": _clientId,
    "source": "app",
    "payload": {
      "session_id": "session_$timestamp",
      "quality": _videoQuality,
      "codec": _videoCodec,
      "resolution": _resolution,
      "audio_enabled": true,
      "ice_servers": <String>['dummyIceServer1']
    }
  };

  late final Map<String, dynamic> messageEnrollFace = {
    "msg_type": _cmdTypeEnrollFace,
    "msg_id": "${_cmdTypeEnrollFace}_$timestamp",
    "timestamp": timestamp,
    "user_id": _clientId,
    "source": "app",
    "payload": {
      "session_id": "session_$timestamp",
      "quality": _videoQuality,
      "codec": _videoCodec,
      "resolution": _resolution,
      "audio_enabled": true,
      "ice_servers": <String>['dummyIceServer1']
    }
  };

  late final Map<String, dynamic> messageDeleteFace = {
    "msg_type": _cmdTypeDeleteFace,
    "msg_id": "${_cmdTypeDeleteFace}_$timestamp",
    "timestamp": timestamp,
    "user_id": _clientId,
    "source": "app",
    "payload": {
      "session_id": "session_$timestamp",
      "quality": _videoQuality,
      "codec": _videoCodec,
      "resolution": _resolution,
      "audio_enabled": true,
      "ice_servers": <String>['dummyIceServer1']
    }
  };









}