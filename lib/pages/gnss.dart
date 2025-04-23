import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class Gnss extends StatefulWidget {
  final DateTime date;
  final String farmId;

  const Gnss({Key? key, required this.date, required this.farmId})
      : super(key: key);

  @override
  State<Gnss> createState() => _GnssState();
}

class _GnssState extends State<Gnss> {
  Map<String, Map<String, dynamic>>? latestData;
  bool isLoading = true;
  String? errorMessage;
  bool isGnssSelected = true; // To manage the toggle button state

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
        List<dynamic> dataList = json.decode(response.body);

        if (dataList.isEmpty) {
          setState(() {
            errorMessage = "No data available for selected date.";
            isLoading = false;
          });
          return;
        }

        Map<String, Map<String, dynamic>> latestRecords = {};

        for (var item in dataList) {
          String sensorId = item['sensor_id'];
          DateTime timestamp = DateTime.parse(item['timestamp']);

          if (!latestRecords.containsKey(sensorId) ||
              timestamp.isAfter(
                  DateTime.parse(latestRecords[sensorId]!['timestamp']))) {
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

  Widget buildSensorCard(
          String title, String value, String timestamp, String route) =>
      GestureDetector(
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 24),
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
      appBar: AppBar(title: const Text("GNSS & Signal Hound Data")),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  )
                : Column(
                    children: [
                      const SizedBox(height: 10),
                      ToggleButtons(
                        isSelected: [isGnssSelected, !isGnssSelected],
                        onPressed: (index) {
                          setState(() {
                            isGnssSelected = index == 0;
                          });
                          // You might want to fetch different data based on the selection here
                          // For now, we'll just toggle the visual selection
                        },
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text('GNSS'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text('Signal Hound'),
                          ),
                        ],
                      ),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (isGnssSelected) ...[
                              buildSensorCard(
                                "GNSS Latitude",
                                "${latestData?['gnss_latitude']?['value'] ?? '-'}",
                                formatTimestamp(
                                    latestData?['gnss_latitude']?['timestamp']),
                                '/gnss/latitude', // Define this route
                              ),
                              buildSensorCard(
                                "GNSS Longitude",
                                "${latestData?['gnss_longitude']?['value'] ?? '-'}",
                                formatTimestamp(latestData?['gnss_longitude']
                                    ?['timestamp']),
                                '/gnss/longitude', // Define this route
                              ),
                              // Add more GNSS related cards here
                            ],
                            if (!isGnssSelected) ...[
                              buildSensorCard(
                                "SH Frequency",
                                "${latestData?['sh_frequency']?['value'] ?? '-'}",
                                formatTimestamp(
                                    latestData?['sh_frequency']?['timestamp']),
                                '/signalhound/frequency', // Define this route
                              ),
                              buildSensorCard(
                                "SH Amplitude",
                                "${latestData?['sh_amplitude']?['value'] ?? '-'}",
                                formatTimestamp(
                                    latestData?['sh_amplitude']?['timestamp']),
                                '/signalhound/amplitude', // Define this route
                              ),
                              // Add more Signal Hound related cards here
                            ],
                            buildSensorCard(
                              "Air Humidity",
                              "${latestData?['air_humidity']?['value'] ?? '-'}",
                              formatTimestamp(
                                  latestData?['air_humidity']?['timestamp']),
                              '/humidity',
                            ),
                            buildSensorCard(
                              "Hygrometer",
                              "${latestData?['hygrometer']?['value'] ?? '-'}",
                              formatTimestamp(
                                  latestData?['hygrometer']?['timestamp']),
                              '/humidity',
                            ),
                            buildSensorCard(
                              "pH",
                              "${latestData?['ph_value']?['value'] ?? '-'}",
                              formatTimestamp(latestData?['ph_value']?['timestamp']),
                              '/ph',
                            ),
                            buildSensorCard(
                              "TDS",
                              "${latestData?['tds_value']?['value'] ?? '-'}",
                              formatTimestamp(latestData?['tds_value']?['timestamp']),
                              '/ph',
                            ),
                            buildSensorCard(
                              "Water Temperature",
                              "${latestData?['water_temperature']?['value'] ?? '-'}",
                              formatTimestamp(latestData?['water_temperature']
                                  ?['timestamp']),
                              '/temperature',
                            ),
                            buildSensorCard(
                              "Air Temperature",
                              "${latestData?['air_temperature']?['value'] ?? '-'}",
                              formatTimestamp(latestData?['air_temperature']
                                  ?['timestamp']),
                              '/temperature',
                            ),
                          ],
                        ),
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