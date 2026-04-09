import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:landscape/features/dashboard/models/device.dart';

class MqttManager {
  static const int _brokerPort = 1883;
  static const Duration _topicScanWindow = Duration(seconds: 6);
  static const int _maxDiscoveredTopics = 24;

  static const String _brokerHostPrefsKey = 'brokerHost';
  static const String _clientIdPrefsKey = 'clientId';
  static const String _devicesPrefsKey = 'devices';

  static const String _defaultClientId = 'home_dashboard_android';

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;

  String brokerHost = '';
  String clientId = '';
  List<Device> devices = [];
  final Map<String, DeviceState> deviceStates = {};

  bool isConnected = false;
  bool isConnecting = false;
  String connectionStatusText = 'Frånkopplad';

  bool isScanning = false;
  List<String> discoveredTopics = [];

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  Future<void> initialize() async {
    await _loadFromPrefs();
    if (brokerHost.isEmpty) {
      _notifyListeners();
      return;
    }
    await connect();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    brokerHost = prefs.getString(_brokerHostPrefsKey) ?? '';
    clientId = prefs.getString(_clientIdPrefsKey) ?? _defaultClientId;

    final rawDevices = prefs.getStringList(_devicesPrefsKey) ?? const <String>[];
    devices = rawDevices
        .map((raw) {
          try {
            return Device.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Device>()
        .toList();

    for (final device in devices) {
      deviceStates.putIfAbsent(device.statusTopic, DeviceState.new);
    }
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _devicesPrefsKey,
      devices.map((d) => jsonEncode(d.toJson())).toList(growable: false),
    );
  }

  Future<void> saveGlobalSettings({
    required String newBrokerHost,
    required String newClientId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_brokerHostPrefsKey, newBrokerHost),
      prefs.setString(_clientIdPrefsKey, newClientId),
    ]);

    final brokerChanged = newBrokerHost != brokerHost;
    brokerHost = newBrokerHost;
    clientId = newClientId;

    if (brokerChanged && brokerHost.isNotEmpty) {
      await connect();
    }
  }

  Future<void> connect() async {
    if (isConnecting) return;
    if (brokerHost.isEmpty) return;

    isConnecting = true;
    connectionStatusText = 'Ansluter till $brokerHost...';
    _notifyListeners();

    try {
      await _subscription?.cancel();
      _subscription = null;
      _client?.disconnect();

      final effectiveClientId = clientId.isEmpty ? _defaultClientId : clientId;

      final client = MqttServerClient.withPort(brokerHost, effectiveClientId, _brokerPort)
        ..keepAlivePeriod = 30
        ..autoReconnect = true
        ..logging(on: false)
        ..onConnected = _onConnected
        ..onDisconnected = _onDisconnected;

      final connectMessage = MqttConnectMessage()
          .withClientIdentifier(effectiveClientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      client.connectionMessage = connectMessage;

      await client.connect();

      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError('Anslutning misslyckades: ${client.connectionStatus?.state}');
      }

      _client = client;
      _subscribeAll();

      _subscription = client.updates?.listen(_onMessageReceived);

      isConnected = true;
      connectionStatusText = 'Uppkopplad';
    } catch (error) {
      _client?.disconnect();
      isConnected = false;
      connectionStatusText = 'Anslutningsfel: $error';
    } finally {
      isConnecting = false;
      _notifyListeners();
    }
  }

  void _subscribeAll() {
    final client = _client;
    if (client == null) return;
    for (final device in devices) {
      client.subscribe(device.statusTopic, MqttQos.atMostOnce);
      client.subscribe(device.controlTopic, MqttQos.atMostOnce);
    }
  }

  void _onConnected() {
    isConnected = true;
    connectionStatusText = 'Uppkopplad';
    _subscribeAll();
    _notifyListeners();
  }

  void _onDisconnected() {
    isConnected = false;
    connectionStatusText = 'Frånkopplad';
    _notifyListeners();
  }

  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final publishMessage = event.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        publishMessage.payload.message,
      );

      // Statustopic — sensordata
      final state = deviceStates[event.topic];
      if (state != null) {
        state.lastRawPayload = payload;
        state.lastUpdated = DateTime.now();
        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          final temp = json['temperature'];
          final humidity = json['humidity'];
          if (temp != null) state.temperature = (temp as num).toDouble();
          if (humidity != null) state.humidity = (humidity as num).toDouble();
        } catch (_) {
          // Rådata är sparad, temperatur/fuktighet förblir oförändrade
        }
      }

      // Kontrolltopic — on/off-tillstånd (inkl. retain vid återanslutning)
      for (final device in devices) {
        if (device.controlTopic == event.topic) {
          final controlState = deviceStates[device.statusTopic];
          if (controlState != null) {
            controlState.enabled = payload.trim() == 'on';
          }
          break;
        }
      }
    }
    _notifyListeners();
  }

  void publishControl(Device device, bool enabled) {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }

    final payload = enabled ? 'on' : 'off';
    final builder = MqttClientPayloadBuilder()..addString(payload);
    client.publishMessage(
      device.controlTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: true,
    );

    final state = deviceStates[device.statusTopic];
    if (state != null) {
      state.enabled = enabled;
    }
    _notifyListeners();
  }

  Future<void> addDevice(Device device) async {
    devices = [...devices, device];
    deviceStates[device.statusTopic] = DeviceState();
    await _saveDevices();
    if (isConnected) {
      _client?.subscribe(device.statusTopic, MqttQos.atMostOnce);
      _client?.subscribe(device.controlTopic, MqttQos.atMostOnce);
    }
    _notifyListeners();
  }

  Future<void> deleteDevice(Device device) async {
    devices = devices.where((d) => d.id != device.id).toList(growable: false);
    deviceStates.remove(device.statusTopic);
    await _saveDevices();
    _notifyListeners();
  }

  Future<void> scanTopics({
    required String scanBrokerHost,
    required String scanClientId,
    required void Function(List<String> topics, String? error) onResult,
  }) async {
    if (isScanning) return;
    if (scanBrokerHost.isEmpty) {
      onResult(const [], 'Serveradress saknas');
      return;
    }

    isScanning = true;
    _notifyListeners();

    final foundTopics = <String>{};
    MqttServerClient? scanClient;
    StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? scanSubscription;
    String? scanError;

    try {
      final scanId =
          '${scanClientId.isEmpty ? _defaultClientId : scanClientId}_scan_${DateTime.now().millisecondsSinceEpoch}';

      scanClient =
          MqttServerClient.withPort(scanBrokerHost, scanId, _brokerPort)
            ..keepAlivePeriod = 15
            ..autoReconnect = false
            ..logging(on: true);

      final connectMessage = MqttConnectMessage()
          .withClientIdentifier(scanId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      scanClient.connectionMessage = connectMessage;

      await scanClient.connect();

      if (scanClient.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError('Kunde inte ansluta för topicsökning');
      }

      scanClient.subscribe('#', MqttQos.atMostOnce);
      scanClient.subscribe(r'$SYS/#', MqttQos.atMostOnce);

      if (scanClient.updates == null) {
        scanError = 'updates-stream är null efter anslutning';
      } else {
        var eventCount = 0;
        scanSubscription = scanClient.updates!.listen((events) {
          eventCount += events.length;
          for (final event in events) {
            final topic = event.topic.trim();
            if (topic.isNotEmpty) foundTopics.add(topic);
          }
        });

        await Future<void>.delayed(_topicScanWindow);

        if (foundTopics.isEmpty) {
          scanError = 'Ansluten men 0 topics på ${_topicScanWindow.inSeconds}s (events: $eventCount)';
        }
      }
    } catch (error) {
      scanError = error.toString();
    } finally {
      await scanSubscription?.cancel();
      scanClient?.disconnect();
    }

    final allTopics = foundTopics.toList()..sort();
    final sorted = [
      ...allTopics.where((t) => !t.startsWith(r'$')),
      ...allTopics.where((t) => t.startsWith(r'$')),
    ].take(_maxDiscoveredTopics).toList(growable: false);

    isScanning = false;
    discoveredTopics = sorted;
    _notifyListeners();
    onResult(sorted, scanError);
  }

  void dispose() {
    _subscription?.cancel();
    _client?.disconnect();
    _listeners.clear();
  }
}
