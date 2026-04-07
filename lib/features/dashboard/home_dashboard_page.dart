import 'dart:async';

import 'package:flutter/material.dart';

import 'package:landscape/features/dashboard/models/device.dart';
import 'package:landscape/features/dashboard/mqtt_manager.dart';
import 'package:landscape/features/dashboard/pages/add_device_page.dart';
import 'package:landscape/features/dashboard/pages/device_detail_page.dart';
import 'package:landscape/features/dashboard/widgets/dashboard_widgets.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  late final MqttManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = MqttManager();
    _manager.addListener(_onManagerStateChanged);
    unawaited(_manager.initialize());
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerStateChanged);
    _manager.dispose();
    super.dispose();
  }

  void _onManagerStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _navigateToAddDevice() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddDevicePage(mqttManager: _manager),
      ),
    );
  }

  Future<void> _navigateToDeviceDetail(Device device) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeviceDetailPage(device: device, mqttManager: _manager),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = _manager.devices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mina enheter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Lägg till enhet',
            onPressed: _navigateToAddDevice,
          ),
        ],
      ),
      body: devices.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DeviceCard(
                    device: device,
                    state: _manager.deviceStates[device.statusTopic],
                    isConnected: _manager.isConnected,
                    onToggle: (enabled) => _manager.publishControl(device, enabled),
                    onTap: () => _navigateToDeviceDetail(device),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sensors_off_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Inga enheter tillagda',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tryck på + i övre hörnet för att lägga till en enhet.',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
