import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ph extends StatefulWidget {
  final DateTime date;

  const ph({Key? key, required this.date}) : super(key: key);

  @override
  _PhState createState() => _PhState();
}

class _PhState extends State<ph> {
  List<FlSpot> temperatureData = [];
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> _filteredList = []; // Declare filteredList as a member variable

  @override
  void initState() {
    super.initState();
    fetchSensorData();
  }

  Future<void> fetchSensorData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _filteredList.clear(); // Initialize or clear the list
    });
  
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(widget.date);
      final url =
          Uri.parse('http://10.0.2.2:3000/sensor_data?farm=tekno3&date=$formattedDate');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> dataList = json.decode(response.body);

        // Filter for PHO01 sensor_id only (assuming you meant pH)
        _filteredList =
            dataList.where((item) => item['sensor_id'] == 'PHO01').toList();

        // Sort by timestamp ascending for chart plotting
        _filteredList.sort((a, b) =>
            DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));

        temperatureData.clear();

        for (int i = 0; i < _filteredList.length; i++) {
          double xValue = i.toDouble(); // or use timestamp converted to double if preferred
          double yValue =
              (_filteredList[i]['value'] as num).toDouble();

          temperatureData.add(FlSpot(xValue, yValue));
        }

        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Failed to load data";
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

  Widget buildChart() {
    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < temperatureData.length) {
                  String label =
                      DateFormat.Hm().format(DateTime.parse(_filteredTimestamp(index)));
                  return Text(label, style: const TextStyle(fontSize: 10));
                }
                return Container();
              },
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true),
          ),
        ),
        lineBarsData: [
          LineChartBarData(spots: temperatureData),
        ],
      ),
    );
  }

  // Helper function to get timestamp string of point at index in filtered list.
  String _filteredTimestamp(int index) {
    if (index >= 0 && index < _filteredList.length) {
      return _filteredList[index]['timestamp'] as String;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Water pH")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: buildChart(),
                ),
    );
  }
}