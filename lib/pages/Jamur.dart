import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class Jamur extends StatefulWidget {
  final DateTime date;
  final String farmId;

  const Jamur({Key? key, required this.date, required this.farmId}) : super(key: key);

  @override
  _JamurState createState() => _JamurState();
}

class _JamurState extends State<Jamur> {
  Map<String, dynamic>? latestData;
  bool isLoading = true;
  String? errorMessage;
  String selectedLocation = '70'; // Default location
  List<String> locations = ['70', '71', '0']; // Your farm IDs

  // Map to store the latest data for each location
  Map<String, Map<String, dynamic>> allLatestData = {};

  @override
  void initState() {
    super.initState();
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    for (final location in locations) {
      await fetchLatestSensorData(location);
    }
    // After fetching data for all locations, set the initial display data
    setState(() {
      latestData = allLatestData[selectedLocation];
      isLoading = false;
    });
  }

  Future<void> fetchLatestSensorData(String farmId) async {
    setState(() {
      if (allLatestData[farmId] == null) {
        // Only show loading if data for this location hasn't been fetched yet
        isLoading = true;
      }
      errorMessage = null;
    });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(widget.date);
      final url = Uri.parse(
          'http://10.0.2.2:3000/sensor_data?farm_id=$farmId'); // Fetch for specific farm_id

      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> dataList = json.decode(response.body);

        if (dataList.isEmpty) {
          setState(() {
            if (locations.length == 1 || allLatestData.isEmpty) {
              errorMessage = "No data available for location $farmId.";
            }
            if (allLatestData.isEmpty) {
              isLoading = false;
            }
          });
          return;
        }

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
          allLatestData[farmId] = latestRecords;
          if (selectedLocation == farmId) {
            latestData = latestRecords;
          }
          // Only set loading to false after all initial data is fetched
          if (allLatestData.length == locations.length) {
            isLoading = false;
          }
        });
      } else {
        setState(() {
          errorMessage =
              "Failed to load data for location $farmId: ${response.statusCode} ${response.reasonPhrase}";
          if (allLatestData.isEmpty) {
            isLoading = false;
          }
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching data for location $farmId: $e";
        if (allLatestData.isEmpty) {
          isLoading = false;
        }
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
      appBar: AppBar(
        title: const Text("Jamur"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: selectedLocation,
              onChanged: (String? newValue) {
                setState(() {
                  selectedLocation = newValue!;
                  latestData = allLatestData[selectedLocation];
                });
              },
              items: locations.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              decoration: InputDecoration(
                labelText: "Select Location",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.purple),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: isLoading && allLatestData.isEmpty
                  ? CircularProgressIndicator()
                  : errorMessage != null && allLatestData.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                          ),
                        )
                      : latestData == null
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text("No data available for the selected location."),
                            )
                          : GridView.count(
                              crossAxisCount: 2,
                              padding: const EdgeInsets.all(12),
                              children: [
                                buildSensorCard(
                                  "Air Humidity",
                                  "${latestData?['HUM01']?['value'] ?? '-'}",
                                  formatTimestamp(latestData?['HUM01']?['timestamp']),
                                  '/humidity',
                                ),
                                buildSensorCard(
                                  "Hygrometer",
                                  "${latestData?['hygrometer']?['value'] ?? '-'}",
                                  formatTimestamp(latestData?['hygrometer']?['timestamp']),
                                  '/humidity',
                                ),
                                buildSensorCard(
                                  "pH",
                                  "${latestData?['PHO01']?['value'] ?? '-'}",
                                  formatTimestamp(latestData?['PHO01']?['timestamp']),
                                  '/ph',
                                ),
                                buildSensorCard(
                                  "TDS",
                                  "${latestData?['TDS01']?['value'] ?? '-'}",
                                  formatTimestamp(latestData?['TDS01']?['timestamp']),
                                  '/ph',
                                ),
                                buildSensorCard(
                                  "Water Temperature",
                                  "${latestData?['TEM01']?['value'] ?? '-'}",
                                  formatTimestamp(latestData?['TEM01']?['timestamp']),
                                  '/temperature',
                                ),
                                buildSensorCard(
                                  "Air Temperature",
                                  "${latestData?['air_temperature']?['value'] ?? '-'}",
                                  formatTimestamp(latestData?['air_temperature']?['timestamp']),
                                  '/temperature',
                                ),
                              ],
                            ),
            ),
          ),
        ],
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