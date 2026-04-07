class Device {
  const Device({
    required this.id,
    required this.name,
    required this.statusTopic,
    required this.controlTopic,
  });

  final String id;
  final String name;
  final String statusTopic;
  final String controlTopic;

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      statusTopic: json['statusTopic'] as String? ?? '',
      controlTopic: json['controlTopic'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'statusTopic': statusTopic,
      'controlTopic': controlTopic,
    };
  }
}

class DeviceState {
  double? temperature;
  double? humidity;
  DateTime? lastUpdated;
  bool enabled = false;
  String? lastRawPayload;
}
