class SensorData {
  final String sensorId;
  final double value;
  final DateTime timestamp;

  SensorData({required this.sensorId, required this.value, required this.timestamp});

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      sensorId: json['sensor_id'],
      value: (json['value'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}