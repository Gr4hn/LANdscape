import 'package:flutter/material.dart';

import 'package:landscape/features/dashboard/models/device.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.state,
    required this.isConnected,
    required this.onToggle,
    required this.onTap,
  });

  final Device device;
  final DeviceState? state;
  final bool isConnected;
  final void Function(bool) onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isOn = state?.enabled == true;
    final hasData = state?.temperature != null || state?.humidity != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isOn
          ? const Color(0xFFE8F5F1)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasData && isConnected
                                ? const Color(0xFF0A8F6A)
                                : const Color(0xFFBBBBBB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            device.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF173B33),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.thermostat_rounded,
                          size: 15,
                          color: Color(0xFF2A4D8F),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          state?.temperature != null
                              ? '${state!.temperature!.toStringAsFixed(1)}°C'
                              : '--°C',
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF173B33),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.water_drop_rounded,
                          size: 15,
                          color: Color(0xFF2A4D8F),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          state?.humidity != null
                              ? '${state!.humidity!.toStringAsFixed(0)}%'
                              : '--%',
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF173B33),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOn,
                onChanged: isConnected ? onToggle : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
