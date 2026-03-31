import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:landscape/features/dashboard/widgets/dashboard_widgets.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  static const String _defaultBrokerHost = '192.168.1.100';
  static const int _brokerPort = 1883;
  static const String _defaultTopic = 'home/lan/status';
  static const String _defaultClientId = 'home_dashboard_android';
  static const String _brokerHostPrefsKey = 'mqtt_broker_host';
  static const String _topicPrefsKey = 'mqtt_topic';
  static const String _clientIdPrefsKey = 'mqtt_client_id';

  bool _isConnectingMqtt = false;
  bool _isDisposing = false;
  String _mqttStatus = 'Disconnected';
  String _lastMqttMessage = 'No message received yet';

  late final TextEditingController _brokerHostController;
  late final TextEditingController _topicController;
  late final TextEditingController _clientIdController;

  MqttServerClient? _mqttClient;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
  _mqttUpdatesSubscription;

  @override
  void initState() {
    super.initState();

    _brokerHostController = TextEditingController(text: _defaultBrokerHost);
    _topicController = TextEditingController(text: _defaultTopic);
    _clientIdController = TextEditingController(text: _defaultClientId);

    unawaited(_initializeMqtt());
  }

  Future<void> _initializeMqtt() async {
    await _loadSavedMqttSettings();
    if (!mounted) {
      return;
    }
    await _connectAndSubscribeMqtt();
  }

  @override
  void dispose() {
    _isDisposing = true;
    _mqttUpdatesSubscription?.cancel();
    _mqttClient?.disconnect();
    _brokerHostController.dispose();
    _topicController.dispose();
    _clientIdController.dispose();
    super.dispose();
  }

  String get _brokerHostValue => _brokerHostController.text.trim();
  String get _topicValue => _topicController.text.trim();
  String get _clientIdValue => _clientIdController.text.trim();

  Future<void> _loadSavedMqttSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _brokerHostController.text =
        prefs.getString(_brokerHostPrefsKey) ?? _defaultBrokerHost;
    _topicController.text = prefs.getString(_topicPrefsKey) ?? _defaultTopic;
    _clientIdController.text =
        prefs.getString(_clientIdPrefsKey) ?? _defaultClientId;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveMqttSettings({
    required String brokerHost,
    required String topic,
    required String clientId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_brokerHostPrefsKey, brokerHost),
      prefs.setString(_topicPrefsKey, topic),
      prefs.setString(_clientIdPrefsKey, clientId),
    ]);
  }

  MqttServerClient _buildMqttClient({
    required String brokerHost,
    required String clientId,
  }) {
    return MqttServerClient.withPort(brokerHost, clientId, _brokerPort)
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..logging(on: false)
      ..onConnected = _onMqttConnected
      ..onDisconnected = _onMqttDisconnected
      ..onSubscribed = _onMqttSubscribed;
  }

  Future<void> _connectAndSubscribeMqtt() async {
    if (_isConnectingMqtt) {
      return;
    }

    final brokerHost = _brokerHostValue;
    final topic = _topicValue;
    final clientId = _clientIdValue;

    if (brokerHost.isEmpty || topic.isEmpty || clientId.isEmpty) {
      setState(() {
        _mqttStatus = 'Fill in broker host, topic and clientId first';
      });
      return;
    }

    unawaited(
      _saveMqttSettings(
        brokerHost: brokerHost,
        topic: topic,
        clientId: clientId,
      ),
    );

    setState(() {
      _isConnectingMqtt = true;
      _mqttStatus = 'Connecting to $brokerHost...';
    });

    try {
      await _mqttUpdatesSubscription?.cancel();
      _mqttUpdatesSubscription = null;
      _mqttClient?.disconnect();

      final client = _buildMqttClient(
        brokerHost: brokerHost,
        clientId: clientId,
      );
      _mqttClient = client;

      final connectMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      client.connectionMessage = connectMessage;
      await client.connect();

      final state = client.connectionStatus?.state;
      if (state != MqttConnectionState.connected) {
        throw StateError('MQTT connection failed. State: $state');
      }

      client.subscribe(topic, MqttQos.atMostOnce);
      _mqttUpdatesSubscription = client.updates?.listen((events) {
        if (events.isEmpty) {
          return;
        }

        final publishMessage = events.first.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          publishMessage.payload.message,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _lastMqttMessage = payload;
        });
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _mqttStatus = 'Connected and subscribed to $topic';
      });
    } catch (error) {
      _mqttClient?.disconnect();
      if (!mounted) {
        return;
      }
      setState(() {
        _mqttStatus = 'MQTT error: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingMqtt = false;
        });
      }
    }
  }

  void _onMqttConnected() {
    if (!mounted || _isDisposing) {
      return;
    }
    setState(() {
      _mqttStatus = 'Connected';
    });
  }

  void _onMqttDisconnected() {
    if (!mounted || _isDisposing) {
      return;
    }
    setState(() {
      _mqttStatus = 'Disconnected';
    });
  }

  void _onMqttSubscribed(String topic) {
    if (!mounted || _isDisposing) {
      return;
    }
    setState(() {
      _mqttStatus = 'Subscribed: $topic';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MQTT Dashboard')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: MqttStatusCard(
            brokerHost: _brokerHostValue,
            brokerPort: _brokerPort,
            topic: _topicValue,
            brokerHostController: _brokerHostController,
            topicController: _topicController,
            clientIdController: _clientIdController,
            status: _mqttStatus,
            lastMessage: _lastMqttMessage,
            isConnecting: _isConnectingMqtt,
            onReconnectTap: _connectAndSubscribeMqtt,
          ),
        ),
      ),
    );
  }
}
