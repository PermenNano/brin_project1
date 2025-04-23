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
  // Default dates and times
  late DateTime startDate;
  late TimeOfDay startTime;
  late DateTime endDate;
  late TimeOfDay endTime;

  // Humidity data points
  List<FlSpot> humidityData = [];
  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Initialize with widget parameters
    startDate = widget.startDate;
    startTime = TimeOfDay.fromDateTime(widget.startDate);
    endDate = widget.endDate;
    endTime = TimeOfDay.fromDateTime(widget.endDate);
    
    // Fetch initial data
    fetchHumidityData();
  }

  Future<void> fetchHumidityData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Format date for API request
      String formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);
      
      // Create API URL
      final url = Uri.parse('http://10.0.2.2:3000/sensor_data?farm=tekno3&date=$formattedStartDate');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Filter for HUM01 entries only
        final List<dynamic> humidityEntries = data.where((entry) => 
          entry['sensor_id'] == 'HUM01').toList();
        
        // Sort by timestamp
        humidityEntries.sort((a, b) => 
          a['timestamp'].toString().compareTo(b['timestamp'].toString()));
        
        // Convert to FlSpots for chart
        humidityData = [];
        for (int i = 0; i < humidityEntries.length; i++) {
          final entry = humidityEntries[i];
          final value = double.tryParse(entry['value'].toString()) ?? 0;
          humidityData.add(FlSpot(i.toDouble(), value));
        }
        
        setState(() {
          isLoading = false;
        });
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
      firstDate: DateTime(2020),
      lastDate: DateTime(2025),
    );
    if (picked != null && picked != startDate) {
      setState(() {
        startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2025),
    );
    if (picked != null && picked != endDate) {
      setState(() {
        endDate = picked;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime,
    );
    if (picked != null && picked != startTime) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: endTime,
    );
    if (picked != null && picked != endTime) {
      setState(() {
        endTime = picked;
      });
    }
  }

  void _submitRequest() {
    // Fetch data based on selected date range
    fetchHumidityData();
  }

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
                // Date and time selectors row 1
                Row(
                  children: [
                    // Calendar icon
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 8),

                    // Start date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Date',
                            style: TextStyle(color: Colors.grey),
                          ),
                          InkWell(
                            onTap: () => _selectStartDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey),
                                ),
                              ),
                              child: Text(
                                DateFormat('dd-MM-yyyy').format(startDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Start time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Time',
                            style: TextStyle(color: Colors.grey),
                          ),
                          InkWell(
                            onTap: () => _selectStartTime(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey),
                                ),
                              ),
                              child: Text(
                                '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Date and time selectors row 2
                Row(
                  children: [
                    // Calendar icon
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 8),

                    // End date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End Date',
                            style: TextStyle(color: Colors.grey),
                          ),
                          InkWell(
                            onTap: () => _selectEndDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.purple),
                                ),
                              ),
                              child: Text(
                                DateFormat('dd-MM-yyyy').format(endDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // End time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End Time',
                            style: TextStyle(color: Colors.grey),
                          ),
                          InkWell(
                            onTap: () => _selectEndTime(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey),
                                ),
                              ),
                              child: Text(
                                '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Submit button
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

          // Loading indicator or error message
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
          // Humidity graph
          else if (humidityData.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (humidityData.length - 1).toDouble(),
                    minY: 0,
                    maxY: 100, // Assuming humidity percentage 0-100%
                    lineBarsData: [
                      LineChartBarData(
                        spots: humidityData,
                        isCurved: true,
                        barWidth: 2,
                        color: Colors.blue,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: false,
                        ),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (value % 20 != 0) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.3),
                          strokeWidth: 1,
                        );
                      },
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
                child: Text('No humidity data available'),
              ),
            ),
        ],
      ),
    );
  }
}