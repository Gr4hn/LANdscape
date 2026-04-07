import 'dart:async';

import 'package:flutter/material.dart';

import 'package:landscape/features/dashboard/models/device.dart';
import 'package:landscape/features/dashboard/mqtt_manager.dart';

class AddDevicePage extends StatefulWidget {
  const AddDevicePage({super.key, required this.mqttManager});

  final MqttManager mqttManager;

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  bool _isScanning = false;
  List<String> _discoveredTopics = [];
  String? _scanError;
  bool _showForm = false;

  final _nameController = TextEditingController();
  final _statusTopicController = TextEditingController();
  final _controlTopicController = TextEditingController();
  late final TextEditingController _brokerHostController;
  late final TextEditingController _clientIdController;

  @override
  void initState() {
    super.initState();
    _brokerHostController =
        TextEditingController(text: widget.mqttManager.brokerHost);
    _clientIdController =
        TextEditingController(text: widget.mqttManager.clientId);
    unawaited(_startScan());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusTopicController.dispose();
    _controlTopicController.dispose();
    _brokerHostController.dispose();
    _clientIdController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    await widget.mqttManager.scanTopics(
      scanBrokerHost: _brokerHostController.text.trim(),
      scanClientId: _clientIdController.text.trim(),
      onResult: (topics, error) {
        if (!mounted) return;
        setState(() {
          _discoveredTopics =
              topics.where((t) => !t.startsWith(r'$')).toList(growable: false);
          _scanError = error;
          _isScanning = false;
        });
      },
    );
  }

  void _onTopicTapped(String topic) {
    _statusTopicController.text = topic;
    // Föreslå kontrolltopic baserat på statustopic
    final suggested = topic
        .replaceAll('/status', '/control')
        .replaceAll('/sensor', '/control');
    _controlTopicController.text =
        suggested != topic ? suggested : 'home/mobile/switch';
    setState(() => _showForm = true);
  }

  Future<void> _onAddDevice() async {
    final name = _nameController.text.trim();
    final statusTopic = _statusTopicController.text.trim();
    final controlTopic = _controlTopicController.text.trim();
    final brokerHost = _brokerHostController.text.trim();
    final clientId = _clientIdController.text.trim();

    if (name.isEmpty || statusTopic.isEmpty || controlTopic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fyll i enhetsnamn, statustopic och kontrolltopic'),
        ),
      );
      return;
    }

    final duplicate = widget.mqttManager.devices
        .any((d) => d.statusTopic == statusTopic);
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En enhet med samma statustopic finns redan'),
        ),
      );
      return;
    }

    if (brokerHost != widget.mqttManager.brokerHost ||
        clientId != widget.mqttManager.clientId) {
      await widget.mqttManager.saveGlobalSettings(
        newBrokerHost: brokerHost,
        newClientId: clientId,
      );
    }

    final device = Device(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      statusTopic: statusTopic,
      controlTopic: controlTopic,
    );

    await widget.mqttManager.addDevice(device);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Lägg till enhet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Serverinställningar ──────────────────────────────────────
          Text(
            'Serverinställningar',
            style: textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _brokerHostController,
                  decoration: const InputDecoration(
                    labelText: 'Serveradress',
                    hintText: '192.168.1.100',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _clientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Enhetsnamn',
                    hintText: 'min_mobil',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _isScanning ? null : _startScan,
              icon: _isScanning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.radar_rounded, size: 18),
              label: Text(_isScanning ? 'Söker...' : 'Sök topics'),
            ),
          ),
          const SizedBox(height: 20),

          // ── Hittade topics ───────────────────────────────────────────
          Text(
            'Hittade topics',
            style: textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_isScanning)
            const LinearProgressIndicator()
          else if (_discoveredTopics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _scanError != null
                    ? 'Fel: $_scanError'
                    : 'Inga topics hittades. Kontrollera serveradressen och prova igen.',
                style: textTheme.bodySmall?.copyWith(
                  color: _scanError != null
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            )
          else
            ...(_discoveredTopics.map(
              (topic) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  dense: true,
                  title: Text(topic, style: textTheme.bodyMedium),
                  trailing: const Icon(Icons.add_circle_outline_rounded),
                  onTap: () => _onTopicTapped(topic),
                ),
              ),
            )),
          const SizedBox(height: 12),

          // ── Manuellt formulär ────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => setState(() => _showForm = !_showForm),
            icon: Icon(_showForm ? Icons.expand_less : Icons.edit_rounded,
                size: 18),
            label: Text(_showForm ? 'Dölj formulär' : 'Lägg till manuellt'),
          ),
          if (_showForm) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Enhetsnamn',
                hintText: 't.ex. Vardagsrum',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _statusTopicController,
              decoration: const InputDecoration(
                labelText: 'Statustopic',
                hintText: 't.ex. home/lan/status',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controlTopicController,
              decoration: const InputDecoration(
                labelText: 'Kontrolltopic',
                hintText: 't.ex. home/mobile/switch',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _onAddDevice,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Lägg till'),
            ),
          ],
        ],
      ),
    );
  }
}
