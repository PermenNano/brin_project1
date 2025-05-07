class SensorData {
  final String farmId; // Added farmId
  final String sensorId;
  final double value;
  final DateTime timestamp;
  final String? name; // Added optional name

  SensorData({
    required this.farmId, // Added farmId
    required this.sensorId,
    required this.value,
    required this.timestamp,
    this.name, // Added optional name
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    // Using tryParse for value for robustness
    final double parsedValue = double.tryParse(json['value']?.toString() ?? '0') ?? 0.0;

    // Using tryParse for timestamp for robustness
    DateTime? parsedTimestamp;
     try {
        if (json['timestamp'] is String) {
            parsedTimestamp = DateTime.parse(json['timestamp']);
        }
     } catch (e) {
        print('Error parsing timestamp: ${json['timestamp']} - $e');
     }

     // Fallback timestamp if parsing fails (e.g., current time or epoch)
     final DateTime timestamp = parsedTimestamp ?? DateTime.now(); // Using DateTime.now() as a fallback

    return SensorData(
      farmId: json['farm_id'] as String? ?? 'unknown_farm', // Handle potentially missing farm_id
      sensorId: json['sensor_id'] as String,
      value: parsedValue,
      timestamp: timestamp,
      name: json['name'] as String?, // Handle potentially missing name
    );
  }
}