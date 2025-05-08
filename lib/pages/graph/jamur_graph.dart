import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class JamurGraph extends StatefulWidget {
  final String farmId;
  final String? sensorId;

  const JamurGraph({Key? key, required this.farmId, this.sensorId})
      : super(key: key);

  @override
  _JamurGraphState createState() => _JamurGraphState();
}

class _JamurGraphState extends State<JamurGraph> {
  List<FlSpot> sensorData = [];
  bool isLoading = false;
  String errorMessage = '';
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _showGraph = false;

  List<String> _availableSensorsForFarm = [];
  List<String> _availableSensorsFiltered = [];
  Map<String, String> _sensorNameMap = {};
  String? _selectedSensorId;

  final Map<String, Color> _sensorColors = {
    'TEM01': Colors.orange,
    'TEM02': Colors.deepOrange,
    'HUM01': Colors.blue,
    'HUM02': Colors.lightBlue,
    'HUM03': Colors.blueGrey,
    'CO001': Colors.teal,
    'PH001': Colors.green,
    'PH011': Colors.lightGreen,
    'CE001': Colors.yellow,
    'NH001': Colors.brown,
    'OX001': Colors.cyan,
    'LUX01': Colors.purple,
    'PRED1': Colors.indigo,
    'PRE02': Colors.deepPurple,
    'RAIN1': Colors.blueAccent,
    'RAIN2': Colors.lightBlueAccent,
    'WINA1': Colors.pink,
    'WIND1': Colors.pinkAccent,
    'WINS1': Colors.red,
    'POT01': Colors.amber,
    'NI001': Colors.lime,
    'CC001': Colors.grey,
    'CC002': Colors.blueGrey,
  };

  final List<String> _jamurSensorIds = [
    'TEM01', 'TEM02', 'HUM01', 'HUM02', 'HUM03',
    'CO001', 'PH001', 'PH011', 'CE001', 'NH001',
    'OX001', 'LUX01', 'PRED1', 'PRE02', 'RAIN1',
    'RAIN2', 'WINA1', 'WIND1', 'WINS1', 'POT01',
    'NI001', 'CC001', 'CC002'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _endTime = TimeOfDay.fromDateTime(now);
    _startDate = now.subtract(const Duration(hours: 24));
    _startTime = TimeOfDay.fromDateTime(_startDate!);
    _selectedSensorId = widget.sensorId;
    _fetchAvailableSensors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jamur Graph - Farm ${widget.farmId}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_availableSensorsFiltered.isNotEmpty) _buildSensorDropdown(),
            const SizedBox(height: 16),
            _buildDateTimePickers(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _onShowGraphPressed,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Show Graph'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _showGraph && sensorData.isNotEmpty
                  ? _buildGraph()
                  : _buildNoDataOrInitialScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSensorId,
      decoration: const InputDecoration(
        labelText: 'Select Sensor',
        border: OutlineInputBorder(),
      ),
      items: _availableSensorsFiltered
          .map((id) => DropdownMenuItem(
                value: id,
                child: Text(_sensorNameMap[id] ?? id),
              ))
          .toList(),
      onChanged: (val) => setState(() => _selectedSensorId = val),
    );
  }

  Widget _buildDateTimePickers() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDatePicker('Start Date', _startDate, () => _selectDate(context, true))),
            const SizedBox(width: 10),
            Expanded(child: _buildTimePicker('Start Time', _startTime, () => _selectTime(context, true))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildDatePicker('End Date', _endDate, () => _selectDate(context, false))),
            const SizedBox(width: 10),
            Expanded(child: _buildTimePicker('End Time', _endTime, () => _selectTime(context, false))),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white70),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date != null ? DateFormat('yyyy-MM-dd').format(date) : 'Select Date', 
                     style: Theme.of(context).textTheme.bodyMedium),
                const Icon(Icons.calendar_today, size: 18, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white70),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time != null ? time.format(context) : 'Select Time', 
                     style: Theme.of(context).textTheme.bodyMedium),
                const Icon(Icons.access_time, size: 18, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onShowGraphPressed() => _fetchSensorData();

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final now = DateTime.now();
    final initial = isStartDate ? (_startDate ?? now) : (_endDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
            _endTime = _startTime;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && picked.isBefore(_startDate!)) {
            _startDate = picked;
            _startTime = _endTime;
          }
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final initial = isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          if (_startDate != null && _endDate != null && _startTime != null && _endTime != null) {
            final s = _startDate!.add(Duration(hours: _startTime!.hour, minutes: _startTime!.minute));
            final e = _endDate!.add(Duration(hours: _endTime!.hour, minutes: _endTime!.minute));
            if (s.isAfter(e)) _endTime = _startTime;
          }
        } else {
          _endTime = picked;
          if (_startDate != null && _endDate != null && _startTime != null && _endTime != null) {
            final s = _startDate!.add(Duration(hours: _startTime!.hour, minutes: _startTime!.minute));
            final e = _endDate!.add(Duration(hours: _endTime!.hour, minutes: _endTime!.minute));
            if (e.isBefore(s)) _startTime = _endTime;
          }
        }
      });
    }
  }

  Future<void> _fetchAvailableSensors() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
      _availableSensorsForFarm = [];
      _availableSensorsFiltered = [];
      _sensorNameMap = {};
      _showGraph = false;
      sensorData = [];
    });

    try {
      final url = Uri.parse('http://10.0.2.2:3000/sensors?farm_id=${widget.farmId}');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final dataList = jsonData['data'];

        if (dataList != null && dataList is List) {
          // Default sensor names
          _sensorNameMap = {
            'TEM01': 'Air Temperature 1',
            'TEM02': 'Air Temperature 2',
            'HUM01': 'Air Humidity 1',
            'HUM02': 'Air Humidity 2',
            'HUM03': 'Air Humidity 3',
            'CO001': 'CO2 Level',
            'PH001': 'pH Level 1',
            'PH011': 'pH Level 2',
            'CE001': 'EC Level',
            'NH001': 'NH4 Level',
            'OX001': 'Dissolved Oxygen',
            'LUX01': 'Light Intensity',
            'PRED1': 'Precipitation',
            'PRE02': 'Pressure',
            'RAIN1': 'Rainfall 1',
            'RAIN2': 'Rainfall 2',
            'WINA1': 'Wind Angle',
            'WIND1': 'Wind Direction',
            'WINS1': 'Wind Speed',
            'POT01': 'Soil Temperature',
            'NI001': 'Soil Moisture',
            'CC001': 'Carbon Monoxide',
            'CC002': 'Carbon Dioxide',
          };

          // Override with any custom names from the API
          for (var sensor in dataList) {
            if (sensor['sensor_id'] != null && sensor['name'] != null) {
              _sensorNameMap[sensor['sensor_id'].toString()] = sensor['name'].toString();
            }
          }

          _availableSensorsForFarm = dataList
              .map<String>((sensor) => sensor['sensor_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();

          _availableSensorsFiltered = _availableSensorsForFarm
              .where((id) => _jamurSensorIds.contains(id))
              .toList();

          if (widget.sensorId != null && _availableSensorsFiltered.contains(widget.sensorId)) {
            _selectedSensorId = widget.sensorId;
          } else if (_availableSensorsFiltered.isNotEmpty) {
            _selectedSensorId = _availableSensorsFiltered.first;
          } else {
            _selectedSensorId = null;
          }

          if (_selectedSensorId != null) {
            await _fetchSensorData();
          } else {
            setState(() {
              isLoading = false;
              errorMessage = 'No mushroom farm sensors available';
              _showGraph = false;
            });
          }
        } else {
          setState(() {
            isLoading = false;
            errorMessage = 'No sensor data available';
            _showGraph = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Could not load sensors. Please try again.';
          _showGraph = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Network error. Please check your connection.';
        _showGraph = false;
      });
    }
  }

  Future<void> _fetchSensorData() async {
    if (_selectedSensorId == null) {
      setState(() {
        errorMessage = 'Please select a sensor';
        isLoading = false;
        _showGraph = false;
      });
      return;
    }

    if (_startDate == null || _endDate == null || _startTime == null || _endTime == null) {
      setState(() {
        errorMessage = 'Please select a complete date and time range';
        isLoading = false;
        _showGraph = false;
      });
      return;
    }

    final startDateTime = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, 
                                  _startTime!.hour, _startTime!.minute);
    final endDateTime = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 
                                _endTime!.hour, _endTime!.minute);

    if (endDateTime.isBefore(startDateTime)) {
      setState(() {
        errorMessage = 'End time must be after start time';
        isLoading = false;
        _showGraph = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
      _showGraph = true;
      sensorData = [];
    });

    try {
      final formattedStartDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(startDateTime);
      final formattedEndDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(endDateTime);
      final url = Uri.parse(
          'http://10.0.2.2:3000/sensor_data?farm_id=${widget.farmId}&start_date=$formattedStartDate&end_date=$formattedEndDate&sensor_id=${_selectedSensorId!}');

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final dataList = jsonData['data'];

        if (dataList == null || dataList is! List || dataList.isEmpty) {
          setState(() {
            errorMessage = "No data available for selected time range";
            isLoading = false;
            _showGraph = false;
          });
          return;
        }

        final sortedList = List<Map<String, dynamic>>.from(dataList)
            ..sort((a, b) => (a['timestamp'] as String).compareTo(b['timestamp'] as String));

        sensorData = sortedList.map((item) {
          try {
            if (item['timestamp'] == null || item['value'] == null) return null;
            final timestamp = DateTime.parse(item['timestamp'].toString());
            final value = double.tryParse(item['value'].toString()) ?? 0;
            return FlSpot(timestamp.millisecondsSinceEpoch.toDouble(), value);
          } catch (e) {
            return null;
          }
        }).whereType<FlSpot>().toList();

        if (mounted) {
          setState(() {
            isLoading = false;
            if (sensorData.isEmpty) {
              errorMessage = "No valid data points available";
              _showGraph = false;
            } else {
              errorMessage = '';
              _showGraph = true;
            }
          });
        }
      } else {
        setState(() {
          errorMessage = 'Could not load data. Please try again.';
          isLoading = false;
          _showGraph = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error. Please check your connection.';
        isLoading = false;
        _showGraph = false;
      });
    }
  }

  Widget _buildGraph() {
    if (sensorData.isEmpty) return _buildNoDataOrInitialScreen();

    final lineColor = _sensorColors[_selectedSensorId] ?? Colors.blue;
    final ys = sensorData.map((e) => e.y).toList();
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final yRange = maxY - minY;
    final padY = yRange > 0 ? yRange * 0.1 : 1.0;

    final xs = sensorData.map((e) => e.x).toList();
    final minX = xs.first;
    final maxX = xs.last;
    final xRange = maxX - minX;
    final interval = xRange > 0 ? (xRange / 5 > 60000 ? xRange / 5 : 60000) : 60000;

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: LineChart(LineChartData(
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(color: lineColor.withOpacity(0.5), strokeWidth: 2),
                FlDotData(
                  getDotPainter: (spot, percent, bar, idx) => 
                    FlDotCirclePainter(radius: 6, color: lineColor),
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                final sensorDisplayName = _sensorNameMap[_selectedSensorId] ?? _selectedSensorId;
                return LineTooltipItem(
                  '${sensorDisplayName}\n${DateFormat('yyyy-MM-dd HH:mm:ss').format(date.toLocal())}\nValue: ${spot.y.toStringAsFixed(2)}',
                  TextStyle(color: lineColor, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        minX: minX,
        maxX: maxX,
        minY: minY - padY,
        maxY: maxY + padY,
        lineBarsData: [
          LineChartBarData(
            spots: sensorData,
            isCurved: true,
            barWidth: 3,
            color: lineColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: lineColor.withOpacity(0.2)),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: bottomTitleWidgets,
              reservedSize: 40,
              interval: interval.toDouble(),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: leftTitleWidgets,
              reservedSize: 40,
              interval: (yRange > 0 ? yRange / 5 : 10).toDouble(),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          horizontalInterval: (yRange > 0 ? yRange / 5 : 10).toDouble(),
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          drawVerticalLine: true,
          verticalInterval: interval.toDouble(),
          getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey, width: 1)),
      )),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10);
    if (sensorData.isEmpty || value < sensorData.first.x || value > sensorData.last.x) {
      return const SizedBox.shrink();
    }
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final formattedDate = DateFormat('MM-dd HH:mm').format(date.toLocal());
    return SideTitleWidget(
      axisSide: meta.axisSide, 
      space: 8, 
      child: Text(formattedDate, style: style, textAlign: TextAlign.center),
    );
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12);
    final text = value.toStringAsFixed(value.abs() > 10 ? 0 : 1);
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text(text, style: style),
    );
  }

  Widget _buildNoDataOrInitialScreen() {
    if (errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          errorMessage,
          style: const TextStyle(color: Colors.redAccent, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_availableSensorsFiltered.isEmpty && !isLoading) {
      return Center(
        child: Text(
          'No mushroom sensors available for this farm',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_showGraph && !isLoading && sensorData.isEmpty) {
      return const Center(
        child: Text(
          'Select a sensor and time range, then tap "Show Graph"',
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}