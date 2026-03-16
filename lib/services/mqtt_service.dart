import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:vdb_realtek/services/mqtt_payload_schema.dart';

class MqttService extends ChangeNotifier {
  // ---------- Singleton ----------
  MqttService._internal();
  static final MqttService instance = MqttService._internal();
  factory MqttService() => instance;

  // ---------- Config ----------
  static const String _endpoint =
      'a2d7mswwxh8eti-ats.iot.ap-south-1.amazonaws.com';
  static const int _port = 8883;
  static const String _clientId = 'flutter-app-sandbox-001';
  static const String _baseTopic = 'vdb/sandbox_001/vdb-sandbox-001';
  static const String _publishTopic = '$_baseTopic/cmd';
  static const String _subscribeTopic = '$_baseTopic/#';

  late MqttServerClient _client;
  MqttPayloadSchema mqttPayloadSchema = MqttPayloadSchema();

  bool _isConnected = false;
  bool _feedActive = false;
  String _lastReceivedTopic = '';
  String _lastReceivedPayload = '';

  bool get isConnected => _isConnected;
  bool get feedActive => _feedActive;
  String get lastReceivedTopic => _lastReceivedTopic;
  String get lastReceivedPayload => _lastReceivedPayload;

  // ---------- Connect ----------
  Future<void> connect() async {
    if (_isConnected) return;

    _client = MqttServerClient.withPort(_endpoint, _clientId, _port);
    _client.secure = true;
    _client.keepAlivePeriod = 60;
    _client.logging(on: false);
    _client.setProtocolV311();

    final ByteData rootCA =
    await rootBundle.load('credentials/AmazonRootCA1.pem');
    final ByteData deviceCert =
    await rootBundle.load('credentials/flutter-app-sandbox-001.cert.pem');
    final ByteData privateKey = await rootBundle
        .load('credentials/flutter-app-sandbox-001.private.key');

    final secCtx = SecurityContext.defaultContext;
    secCtx.setTrustedCertificatesBytes(rootCA.buffer.asUint8List());
    secCtx.useCertificateChainBytes(deviceCert.buffer.asUint8List());
    secCtx.usePrivateKeyBytes(privateKey.buffer.asUint8List());

    _client.securityContext = secCtx;
    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;

    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await _client.connect();
    } catch (e) {
      debugPrint('[MQTT] Connection error: $e');
      _client.disconnect();
    }
  }

  // ---------- Subscribe ----------
  void _subscribeToAll() {
    _client.subscribe(_subscribeTopic, MqttQos.atLeastOnce);
    debugPrint('[MQTT] Subscribed to $_subscribeTopic');
  }

  // ---------- Publish ----------
  void publish(String topic, String payload) {
    if (!_isConnected) {
      debugPrint('[MQTT] Not connected – skipping publish');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('[MQTT] Published "$payload" → $topic');
  }

  // ---------- Feed helpers ----------
  void sendStart() {
    publish(_publishTopic, jsonEncode(mqttPayloadSchema.messageStreamStart));
    _feedActive = true;
    notifyListeners();
  }

  void sendStop() {
    publish(_publishTopic, jsonEncode(mqttPayloadSchema.messageStreamStop));
    _feedActive = false;
    notifyListeners();
  }

  // ---------- Internal ----------
  void _listenToMessages() {
    _client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final pub = msg.payload as MqttPublishMessage;
        final payload =
        MqttPublishPayload.bytesToStringAsString(pub.payload.message);
        debugPrint('[MQTT] ← ${msg.topic}: $payload');
        _lastReceivedTopic = msg.topic;
        _lastReceivedPayload = payload;
        notifyListeners();
      }
    });
  }

  void _onConnected() {
    _isConnected = true;
    debugPrint('[MQTT] Connected');
    _subscribeToAll();
    _listenToMessages();
    notifyListeners();
  }

  void _onDisconnected() {
    _isConnected = false;
    debugPrint('[MQTT] Disconnected');
    notifyListeners();
  }

  Future<void> disconnect() async {
    _client.disconnect();
  }
}
