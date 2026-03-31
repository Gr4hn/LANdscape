import 'package:flutter/material.dart';

class MqttStatusCard extends StatelessWidget {
  const MqttStatusCard({
    super.key,
    required this.brokerHost,
    required this.brokerPort,
    required this.topic,
    required this.brokerHostController,
    required this.topicController,
    required this.clientIdController,
    required this.status,
    required this.lastMessage,
    required this.isConnecting,
    required this.onReconnectTap,
  });

  final String brokerHost;
  final int brokerPort;
  final String topic;
  final TextEditingController brokerHostController;
  final TextEditingController topicController;
  final TextEditingController clientIdController;
  final String status;
  final String lastMessage;
  final bool isConnecting;
  final Future<void> Function() onReconnectTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF2A4D8F).withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.hub_rounded, color: Color(0xFF2A4D8F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MQTT Connection',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF173B33),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$brokerHost:$brokerPort',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF173B33).withValues(alpha: 0.66),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: isConnecting ? null : () => onReconnectTap(),
                child: Text(isConnecting ? 'Connecting...' : 'Reconnect'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: brokerHostController,
            decoration: const InputDecoration(
              labelText: 'Broker host',
              hintText: 'e.g. 192.168.1.50',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: topicController,
            decoration: const InputDecoration(
              labelText: 'Topic',
              hintText: 'e.g. home/lan/status',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: clientIdController,
            decoration: const InputDecoration(
              labelText: 'Client ID',
              hintText: 'e.g. my_android_client',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Topic: $topic',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF173B33).withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Status: $status',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF173B33),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Last payload: $lastMessage',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF173B33).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
