import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Fishery extends StatefulWidget {
  final DateTime date;

  const Fishery({super.key, required this.date});

  @override
  State<Fishery> createState() => _FisheryState();
}

class _FisheryState extends State<Fishery> {
  List<FlSpot> _sensorData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSensorData();
  }

  Future<void> _fetchSensorData() async {
    final apiUrl = dotenv.env['API_URL'] ?? 'http://localhost:3000';
    final formattedDate = DateFormat('yyyy-MM-dd').format(widget.date);
    final url = Uri.parse('$apiUrl/api/temperature/fishery?date=$formattedDate');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _sensorData = data.map((item) {
            final timestamp = DateTime.parse(item['timestamp']);
            final value = item['value'] as double;
            return FlSpot(timestamp.millisecondsSinceEpoch.toDouble(), value);
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fishery Data'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sensorData.isEmpty
              ? const Center(child: Text('No data available'))
              : LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: _sensorData,
                        isCurved: true,
                        color: Colors.blue, // Changed 'colors' to 'color'
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                            return Text(DateFormat('HH:mm').format(date));
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toStringAsFixed(1));
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                  ),
                ),
    );
  }
}