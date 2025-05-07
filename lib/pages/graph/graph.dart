import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Graph extends StatefulWidget {
  final String farmId;
  final String? sensorId; // Make sensorId nullable

  const Graph({Key? key, required this.farmId, this.sensorId})
      : super(key: key);

  @override
  _GraphState createState() => _GraphState();
}

class _GraphState extends State<Graph> {
  List<FlSpot> sensorData = [];
  bool isLoading = false;
  String errorMessage = '';
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _showGraph = false;
  String _title = 'Sensor Data Graph'; // Default title
  String _dataType = 'value'; // Default data type
  List<String> _availableSensors = []; // To store available sensor IDs
  String? _selectedSensorId; // Currently selected sensor
  Map<String, String> _sensorNameMap = {}; // Map to store sensor names

  @override
  void initState() {
    super.initState();
    _fetchAvailableSensors(); // Fetch sensors when the widget initializes
    if (widget.sensorId != null) {
      _selectedSensorId = widget.sensorId;
    }
  }

  // Function to fetch available sensors for the farm
  Future<void> _fetchAvailableSensors() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final url = Uri.parse('http://10.0.2.2:3000/sensors?farm_id=${widget.farmId}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['data'] != null) {
          _availableSensors = (jsonData['data'] as List)
              .map<String>((sensor) => sensor['sensor_id'] as String)
              .toList();

          // Create a map of sensor IDs to names.
          _sensorNameMap = Map.fromEntries(
            (jsonData['data'] as List).map((sensor) =>
                MapEntry(sensor['sensor_id'] as String, sensor['name'] as String)),
          );

          if (widget.sensorId != null &&
              _availableSensors.contains(widget.sensorId)) {
            _selectedSensorId = widget.sensorId;
          } else if (_availableSensors.isNotEmpty) {
            _selectedSensorId =
                _availableSensors.first; // Select the first sensor if none is provided.
          }
        } else {
          errorMessage = 'No sensors found for this farm.';
        }
      } else {
        errorMessage =
            'Failed to load sensors: Status ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Error fetching sensors: ${e.toString()}';
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Function to show date picker
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        isStartDate ? (_startDate ?? now) : (_endDate ?? now);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked.add(const Duration(days: 1));
          }
        } else {
          if (_startDate != null && picked.isBefore(_startDate!)) {
            _endDate = _startDate!.add(const Duration(days: 1));
          } else {
            _endDate = picked;
          }
        }
      });
    }
  }

  // Function to show time picker
  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay initialTime =
        isStartTime ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now());

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _fetchSensorData() async {
    if (_startDate == null ||
        _endDate == null ||
        _startTime == null ||
        _endTime == null) {
      setState(() {
        errorMessage = 'Please select start and end dates and times.';
        isLoading = false;
        _showGraph = false;
      });
      return;
    }
    setState(() {
      isLoading = true;
      errorMessage = '';
      _showGraph = true;
    });

    try {
      DateTime startDateTime = _startDate!.add(
          Duration(hours: _startTime!.hour, minutes: _startTime!.minute));
      DateTime endDateTime = _endDate!.add(
          Duration(hours: _endTime!.hour, minutes: _endTime!.minute));

      if (endDateTime.isBefore(startDateTime)) {
        setState(() {
          errorMessage = 'End date/time must be after start date/time';
          isLoading = false;
          _showGraph = false;
        });
        return;
      }

      final formattedStartDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(startDateTime);
      final formattedEndDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(endDateTime);

      String urlString =
          'http://10.0.2.2:3000/sensor_data?farm_id=${widget.farmId}&start_date=$formattedStartDate&end_date=$formattedEndDate';
      if (_selectedSensorId != null) {
        urlString += '&sensor_id=$_selectedSensorId';
      }
      final url = Uri.parse(urlString);

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['data'] == null || (jsonData['data'] as List).isEmpty) {
          setState(() {
            errorMessage = "No data available for selected time range";
            isLoading = false;
            sensorData = [];
            _showGraph = false;
          });
          return;
        }

        final dataList = (jsonData['data'] as List);

        dataList.sort((a, b) =>
            (a['timestamp'] as String).compareTo(b['timestamp'] as String));

        sensorData = dataList.map((item) {
          DateTime timestamp = DateTime.parse(item['timestamp']);
          double value =
              double.tryParse(item['value'].toString()) ?? 0;
          return FlSpot(
            timestamp.millisecondsSinceEpoch.toDouble(),
            value,
          );
        }).toList();
      } else {
        errorMessage =
            'Failed to load data: Status ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Error: ${e.toString()}';
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLoading) const Center(child: CircularProgressIndicator()),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            // Sensor selection dropdown.
            if (_availableSensors.isNotEmpty) ...[
              const Text('Select Sensor:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedSensorId,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSensorId = newValue;
                  });
                },
                items: _availableSensors.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(_sensorNameMap[value] ?? value), // Display sensor name if available
                  );
                }).toList(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Text(
                            _startDate == null
                                ? 'Select Start Date'
                                : DateFormat('yyyy-MM-dd').format(_startDate!),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Time',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _selectTime(context, true),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Text(
                            _startTime == null
                                ? 'Select Start Time'
                                : _startTime!.format(context),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Date',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Text(
                            _endDate == null
                                ? 'Select End Date'
                                : DateFormat('yyyy-MM-dd').format(_endDate!),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Time',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _selectTime(context, false),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Text(
                            _endTime == null
                                ? 'Select End Time'
                                : _endTime!.format(context),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchSensorData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child:
                  const Text('Show Graph', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),
            if (_showGraph) Expanded(child: _buildGraph()),
          ],
        ),
      ),
    );
  }

  Widget _buildGraph() {
    if (sensorData.isEmpty) return _buildNoDataScreen();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  DateTime dateTime =
                      DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                  String formattedDateTime =
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);

                  return LineTooltipItem(
                    '$formattedDateTime\nValue: ${spot.y.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),
          minX: sensorData.isNotEmpty ? sensorData.first.x : 0,
          maxX: sensorData.isNotEmpty ? sensorData.last.x : 0,
          minY: sensorData
                  .map((e) => e.y)
                  .reduce((a, b) => a < b ? a : b) -
              10,
          maxY: sensorData
                  .map((e) => e.y)
                  .reduce((a, b) => a > b ? a : b) +
              10,
          lineBarsData: [
            LineChartBarData(
              spots: sensorData,
              isCurved: true,
              barWidth: 2,
              color: Colors.blue,
              dotData: const FlDotData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: bottomTitleWidgets,
                reservedSize: 22,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: leftTitleWidgets,
                reservedSize: 40,
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) => FlLine(
              color: const Color(0xffe7e8ec),
              strokeWidth: 1,
            ),
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: const Color(0xff272727),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataScreen() {
    return const Center(
      child: Text(
        'No data available for the selected date range',
        style: TextStyle(color: Colors.black, fontSize: 16),
      ),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff68737d),
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );
    if (sensorData.isEmpty) {
      return const SizedBox.shrink();
    }

    DateTime? dateTime;
    try {
      dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    } catch (e) {
      return const SizedBox.shrink();
    }

    if (dateTime == null) {
      return const SizedBox.shrink();
    }
    if (value >= sensorData.first.x && value <= sensorData.last.x) {
      return Text(
        DateFormat('HH:mm').format(dateTime),
        style: style,
        textAlign: TextAlign.center,
      );
    }

    return const SizedBox.shrink();
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    return Text(
      value.toInt().toString(),
      style: const TextStyle(
        color: Color(0xff67727d),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
    );
  }
}

