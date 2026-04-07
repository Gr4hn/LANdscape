import 'dart:async';

import 'package:flutter/material.dart';

import 'package:landscape/features/dashboard/models/device.dart';
import 'package:landscape/features/dashboard/mqtt_manager.dart';

class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage({
    super.key,
    required this.device,
    required this.mqttManager,
  });

  final Device device;
  final MqttManager mqttManager;

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.mqttManager.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.mqttManager.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  DeviceState? get _state =>
      widget.mqttManager.deviceStates[widget.device.statusTopic];

  Future<void> _onDeleteDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort enhet?'),
        content: Text('Vill du ta bort "${widget.device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await widget.mqttManager.deleteDevice(widget.device);
    if (mounted) Navigator.of(context).pop();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final state = _state;
    final isConnected = widget.mqttManager.isConnected;
    final isOn = state?.enabled == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Ta bort enhet',
            onPressed: _onDeleteDevice,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Anslutningsstatus ──────────────────────────────────────
            Row(
              children: [
                Icon(
                  isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  size: 18,
                  color: isConnected
                      ? const Color(0xFF0A8F6A)
                      : colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected
                      ? widget.mqttManager.brokerHost
                      : widget.mqttManager.connectionStatusText,
                  style: textTheme.bodySmall?.copyWith(
                    color: isConnected
                        ? const Color(0xFF0A8F6A)
                        : colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Temp + Fuktighet ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.thermostat_rounded,
                    label: 'Temperatur',
                    value: state?.temperature != null
                        ? '${state!.temperature!.toStringAsFixed(1)}°C'
                        : '--°C',
                    color: const Color(0xFF2A4D8F),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.water_drop_rounded,
                    label: 'Luftfuktighet',
                    value: state?.humidity != null
                        ? '${state!.humidity!.toStringAsFixed(0)}%'
                        : '--%',
                    color: const Color(0xFF0E7C66),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── On/Off toggle ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isOn
                    ? const Color(0xFF0E7C66).withValues(alpha: 0.1)
                    : colorScheme.surfaceContainerLow,
                border: Border.all(
                  color: isOn
                      ? const Color(0xFF0E7C66).withValues(alpha: 0.35)
                      : colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.power_settings_new_rounded,
                    color: isOn ? const Color(0xFF0A8F6A) : colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isOn ? 'Sensor aktiv' : 'Sensor avstängd',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isOn
                            ? const Color(0xFF0A8F6A)
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Switch(
                    value: isOn,
                    onChanged: isConnected
                        ? (v) => widget.mqttManager
                            .publishControl(widget.device, v)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Senast hämtad ──────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 16, color: colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  state?.lastUpdated != null
                      ? 'Senast hämtad: ${_formatTime(state!.lastUpdated!)}'
                      : 'Ingen data hämtad än',
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Teknisk vy ─────────────────────────────────────────────
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Teknisk vy',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                leading: const Icon(Icons.manage_search_rounded),
                collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                collapsedBackgroundColor: colorScheme.surfaceContainerLow,
                backgroundColor: colorScheme.surfaceContainerLow,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        _DetailRow(
                            label: 'Statustopic',
                            value: widget.device.statusTopic),
                        _DetailRow(
                            label: 'Kontrolltopic',
                            value: widget.device.controlTopic),
                        _DetailRow(
                            label: 'Broker',
                            value: widget.mqttManager.brokerHost.isEmpty
                                ? '-'
                                : widget.mqttManager.brokerHost),
                        _DetailRow(
                            label: 'Rådata',
                            value: state?.lastRawPayload ?? '-'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Historik (placeholder) ─────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historik',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Historisk data kommer i en framtida version.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
