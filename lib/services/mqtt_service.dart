import 'dart:convert';
import 'dart:io';
import 'dart:async';
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

  static const String _subscribeTopic = '$_baseTopic/evt';

  MqttServerClient? _client;
  MqttPayloadSchema mqttPayloadSchema = MqttPayloadSchema();

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _feedActive = false;
  bool _listenerAttached = false;
  StreamSubscription? _updatesSubscription;
  String _lastReceivedTopic = '';
  String _lastReceivedPayload = '';

  /// Incremented ONLY when a real MQTT message arrives.
  /// Listeners should compare this to their saved version to know
  /// if a new message arrived vs. a connection state change.
  int _messageVersion = 0;
  int get messageVersion => _messageVersion;

  bool get isConnected => _isConnected;
  bool get feedActive => _feedActive;
  String get lastReceivedTopic => _lastReceivedTopic;
  String get lastReceivedPayload => _lastReceivedPayload;

  // ---------- Connect ----------
  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    // ── Load certs once ──
    final ByteData rootCA =
        await rootBundle.load('credentials/AmazonRootCA1.pem');
    final ByteData deviceCert =
        await rootBundle.load('credentials/flutter-app-sandbox-001.cert.pem');
    final ByteData privateKey = await rootBundle
        .load('credentials/flutter-app-sandbox-001.private.key');

    // ── Use a FRESH SecurityContext — never defaultContext ──
    final secCtx = SecurityContext(withTrustedRoots: true);
    secCtx.setTrustedCertificatesBytes(rootCA.buffer.asUint8List());
    secCtx.useCertificateChainBytes(deviceCert.buffer.asUint8List());
    secCtx.usePrivateKeyBytes(privateKey.buffer.asUint8List());

    _client = MqttServerClient.withPort(_endpoint, _clientId, _port);
    _client!.secure = true;
    _client!.securityContext = secCtx;
    _client!.keepAlivePeriod = 60;
    _client!.logging(on: false);
    _client!.setProtocolV311();

    // ── Auto-reconnect ──
    _client!.autoReconnect = true;
    // DISABLED — we subscribe ourselves in _onConnected.
    // When enabled, the library re-subscribes on every auto-reconnect;
    // if the IoT policy rejects the subscribe, broker disconnects →
    // auto-reconnect → resubscribe → disconnect → infinite loop.
    _client!.resubscribeOnAutoReconnect = false;

    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;

    _client!.onAutoReconnect = () {
      print('[MQTT] 🔄 Auto-reconnecting...');
      _isConnected = false;
    };
    _client!.onAutoReconnected = () {
      print('[MQTT] ✅ Auto-reconnected successfully');
      _isConnected = true;
      // _onConnected will also fire — it handles resubscription.
    };

    // ── Subscription diagnostics ──
    _client!.onSubscribed = (String topic) {
      print('[MQTT] ✅ Successfully subscribed to: $topic');
    };
    _client!.onSubscribeFail = (String topic) {
      print('[MQTT] ❌ FAILED to subscribe to: $topic');
    };

    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        // .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    print('[MQTT] Attempting connection to $_endpoint:$_port as $_clientId...');

    try {
      await _client!.connect();
      print('[MQTT] connect() returned, connectionStatus: ${_client!.connectionStatus}');
    } catch (e) {
      print('[MQTT] ❌ Connection error: $e');
      _client!.disconnect();
      _isConnected = false;
    } finally {
      _isConnecting = false;
    }
  }

  // ---------- Subscribe ----------
  void _subscribeToAll() {
    print('[MQTT] Subscribing to: $_subscribeTopic');
    final sub = _client!.subscribe(_subscribeTopic, MqttQos.atLeastOnce);
    print('[MQTT] subscribe() returned: $sub');
  }

  // ---------- Publish ----------
  Future<void> publish(String topic, String payload) async {
    if (_client == null) {
      print('[MQTT] ❌ Client not initialised — call connect() first');
      return;
    }

    if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
      print('[MQTT] ⚠️ Not connected — waiting for reconnect...');
      final connected = await _waitForConnection();
      if (!connected) {
        print('[MQTT] ❌ Timed out waiting for connection — skipping publish');
        return;
      }
    }

    try {
      final builder = MqttClientPayloadBuilder()..addString(payload);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('[MQTT] Published → $topic');
      print('[MQTT] Payload: $payload');
    } catch (e) {
      print('[MQTT] ❌ Publish error: $e');
    }
  }

  /// Wait up to 10 seconds for a connected state
  Future<bool> _waitForConnection() async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        return true;
      }
    }
    return false;
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
    if (_listenerAttached) {
      print('[MQTT] Message listener already active — skipping');
      return;
    }

    print('[MQTT] Setting up message listener on _client.updates...');

    if (_client!.updates == null) {
      print('[MQTT] ⚠️ _client.updates is NULL — no messages will be received!');
      return;
    }

    _updatesSubscription = _client!.updates!.listen(
      (List<MqttReceivedMessage<MqttMessage>> messages) {
        print('[MQTT] ── Received ${messages.length} message(s) ──');
        for (final msg in messages) {
          final pub = msg.payload as MqttPublishMessage;
          final payload =
              MqttPublishPayload.bytesToStringAsString(pub.payload.message);

          print('══════════════════════════════════════════════════');
          print('[MQTT RAW] Topic: ${msg.topic}');
          print('[MQTT RAW] Payload: $payload');
          print('══════════════════════════════════════════════════');

          _lastReceivedTopic = msg.topic;
          _lastReceivedPayload = payload;
          _messageVersion++;  // signal: a REAL message arrived
          notifyListeners();
        }
      },
      onError: (error) {
        print('[MQTT] ❌ updates stream error: $error');
        _listenerAttached = false;
      },
      onDone: () {
        print('[MQTT] ⚠️ updates stream closed (onDone)');
        _listenerAttached = false;
      },
    );

    _listenerAttached = true;
    print('[MQTT] Message listener attached successfully');
  }

  void _onConnected() {
    _isConnected = true;
    _isConnecting = false;
    print('[MQTT] ✅ Connected to broker');
    print('[MQTT] Connection status: ${_client!.connectionStatus}');

    if (!_listenerAttached) {
      _subscribeToAll();
      _listenToMessages();
    } else {
      // Auto-reconnect: resubscribe manually since we disabled
      // resubscribeOnAutoReconnect to avoid the policy-reject loop.
      _subscribeToAll();
      print('[MQTT] Reconnected — re-subscribed, listener still active');
    }
    // Do NOT call notifyListeners() here — it fires enrollment listeners
    // with empty payloads. Only notifyListeners() when a message arrives.
  }

  void _onDisconnected() {
    _isConnected = false;
    // Log detailed disconnect reason for diagnostics
    final status = _client?.connectionStatus;
    print('[MQTT] ⚠️ Disconnected from broker');
    print('[MQTT]   returnCode: ${status?.returnCode}');
    print('[MQTT]   disconnectionOrigin: ${status?.disconnectionOrigin}');
    // Do NOT call notifyListeners() here — avoids empty-payload listener spam.
  }

  Future<void> disconnect() async {
    _updatesSubscription?.cancel();
    _listenerAttached = false;
    _client?.disconnect();
  }
}

