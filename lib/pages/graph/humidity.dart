import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Humidity extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const Humidity({Key? key, required this.startDate, required this.endDate}) : super(key: key);

  @override
  _HumidityState createState() => _HumidityState();
}

class _HumidityState extends State<Humidity> {
  late DateTime startDate;
  late TimeOfDay startTime;
  late DateTime endDate;
  late TimeOfDay endTime;

  List<FlSpot> humidityData = [];
  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    startDate = widget.startDate;
    startTime = TimeOfDay.fromDateTime(widget.startDate);
    endDate = widget.endDate;
    endTime = TimeOfDay.fromDateTime(widget.endDate);
  }

  Future<void> fetchHumidityData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final completeStartDateTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        startTime.hour,
        startTime.minute,
      );

      final completeEndDateTime = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        endTime.hour,
        endTime.minute,
      );

      String formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);
      final url = Uri.parse('http://10.0.2.2:3000/sensor_data?farm=tekno3&date=$formattedStartDate');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        final List<dynamic> humidityEntries = data.where((entry) {
          if (entry['sensor_id'] != 'HUM01') return false;

          try {
            DateTime timestamp = DateTime.parse(entry['timestamp']);
            return timestamp.isAfter(completeStartDateTime) &&
                timestamp.isBefore(completeEndDateTime.add(const Duration(minutes: 1)));
          } catch (e) {
            return false;
          }
        }).toList();

        humidityEntries.sort((a, b) =>
            DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));

        humidityData = [];
        for (int i = 0; i < humidityEntries.length; i++) {
          final entry = humidityEntries[i];
          final value = double.tryParse(entry['value'].toString()) ?? 0;
          humidityData.add(FlSpot(i.toDouble(), value));
        }

        setState(() => isLoading = false);
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load data: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching data: $e';
      });
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != startDate) {
      setState(() => startDate = picked);
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime,
    );
    if (picked != null && picked != startTime) {
      setState(() => startTime = picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != endDate) {
      setState(() => endDate = picked);
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: endTime,
    );
    if (picked != null && picked != endTime) {
      setState(() => endTime = picked);
    }
  }

  void _submitRequest() => fetchHumidityData();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Humidity'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Start Date', style: TextStyle(color: Colors.grey)),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectStartDate(context),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('dd-MM-yyyy').format(startDate),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(color: Colors.grey, height: 1),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Start Time', style: TextStyle(color: Colors.grey)),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectStartTime(context),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(color: Colors.grey, height: 1),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('End Date', style: TextStyle(color: Colors.grey)),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectEndDate(context),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('dd-MM-yyyy').format(endDate),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(color: Colors.grey, height: 1),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('End Time', style: TextStyle(color: Colors.grey)),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectEndTime(context),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(color: Colors.grey, height: 1),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade50,
                      foregroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red))),
            )
          else if (humidityData.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (humidityData.length - 1).toDouble(),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: humidityData,
                        isCurved: true,
                        barWidth: 2,
                        color: Colors.blue,
                        dotData:  FlDotData(show: false),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (value % 20 != 0) return const SizedBox.shrink();
                            return Text(
                              value.toInt().toString(),
                              style:  TextStyle(color: Colors.grey, fontSize: 12),
                            );
                          },
                        ),
                      ),
                      rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withOpacity(0.3),
                        strokeWidth: 1,
                      ),
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('Select dates and press Submit to view humidity data'),
              ),
            ),
        ],
      ),
    );
  }
}