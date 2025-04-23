import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class Hydroponic extends StatefulWidget {
  final DateTime date;
  final String farmId;

  const Hydroponic({Key? key, required this.date, required this.farmId}) : super(key: key);

  @override
  _HydroponicState createState() => _HydroponicState();
}

class _HydroponicState extends State<Hydroponic> {
  Map<String, dynamic>? latestData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchLatestSensorData();
  }

  Future<void> fetchLatestSensorData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(widget.date);
      final url = Uri.parse(
          'http://10.0.2.2:3000/sensor_data?farm=${widget.farmId}&date=$formattedDate');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Parse response as List<dynamic>
        List<dynamic> dataList = json.decode(response.body);

        if (dataList.isEmpty) {
          setState(() {
            errorMessage = "No data available for selected date.";
            isLoading = false;
          });
          return;
        }

        // Group data by sensor_id and find the latest record for each
        Map<String, Map<String, dynamic>> latestRecords = {};

        for (var item in dataList) {
          String sensorId = item['sensor_id'];
          DateTime timestamp = DateTime.parse(item['timestamp']);

          if (!latestRecords.containsKey(sensorId) ||
              timestamp.isAfter(DateTime.parse(latestRecords[sensorId]!['timestamp']))) {
            latestRecords[sensorId] = item;
          }
        }

        setState(() {
          latestData = latestRecords;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              "Failed to load data: ${response.statusCode} ${response.reasonPhrase}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching data: $e";
        isLoading = false;
      });
    }
  }

  Widget buildSensorCard(String title, String value, String timestamp, String route) => GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, route);
        },
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  timestamp,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("gnss")),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  )
                : GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(12),
                    children: [
                      buildSensorCard(
                        "Air Humidity",
                        "${latestData?['']?['value'] ?? '-'}",
                        formatTimestamp(latestData?['']?['timestamp']),
                        '/humidity',
                      ),
                      buildSensorCard(
                        "Hygrometer",
                        "${latestData?['']?['value'] ?? '-'}",
                        formatTimestamp(latestData?['']?['timestamp']),
                        '/humidity',
                      ),
                      buildSensorCard(
                        "pH",
                        "${latestData?['']?['value'] ?? '-'}",
                        formatTimestamp(latestData?['']?['timestamp']),
                        '/ph',
                      ),
                      buildSensorCard(
                        "TDS",
                        "${latestData?['']?['value'] ?? '-'}",
                        formatTimestamp(latestData?['']?['timestamp']),
                        '/ph',
                      ),
                      buildSensorCard(
                        "Water Temperature",
                        "${latestData?['']?['value'] ?? '-'}",
                        formatTimestamp(latestData?['']?['timestamp']),
                        '/temperature',
                      ),
                      buildSensorCard(
                        "Air Temperature",
                        "${latestData?['']?['value'] ?? '-'}",
                        formatTimestamp(latestData?['']?['timestamp']),
                        '/temperature',
                      ),
                    ],
                  ),
      ),
    );
  }

  String formatTimestamp(String? ts) {
    if (ts == null) return "-";
    try {
      final dt = DateTime.parse(ts);
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(dt);
    } catch (_) {
      return ts; // fallback raw string if parsing fails
    }
  }
}
