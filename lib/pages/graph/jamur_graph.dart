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

  Map<String, String> _sensorNameMap = {};
  String? _selectedSensorId;

  final Color _backgroundColor = Colors.grey[900]!;
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = Colors.white70;
  final Color _minColor = Colors.redAccent;
  final Color _maxColor = Colors.greenAccent;

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _endTime = TimeOfDay.fromDateTime(now);
    _startDate = now.subtract(const Duration(hours: 24));
    _startTime = TimeOfDay.fromDateTime(_startDate!);

    _selectedSensorId = widget.sensorId;
    _initializeGraphData();
  }

  Future<void> _initializeGraphData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
      _showGraph = false;
      sensorData = [];
    });

    if (_selectedSensorId == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'No sensor ID provided to display graph.';
          _showGraph = false;
        });
      }
      return;
    }

    await _fetchSensorNames();
    if (mounted) await _fetchSensorData();
  }

  Future<void> _fetchSensorNames() async {
    if (!mounted) return;

    try {
      final url = Uri.parse('http://172.20.10.4:3000/sensors?farm_id=${widget.farmId}');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final dataList = jsonData['data'];

        if (dataList != null && dataList is List) {
          Map<String, String> fetchedSensorNameMap = {};
          for (var item in dataList) {
            if (item is Map && item.containsKey('sensor_id')) {
              String sensorId = item['sensor_id'].toString();
              String sensorName = item.containsKey('name') && item['name'] != null
                  ? item['name'].toString()
                  : sensorId;
              fetchedSensorNameMap[sensorId] = sensorName;
            }
          }

          if (mounted) {
            setState(() {
              _sensorNameMap = fetchedSensorNameMap;
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching sensor names: $e');
    }
  }

  double _calculateMin() {
    if (sensorData.isEmpty) return 0.0;
    return sensorData.map((e) => e.y).reduce((a, b) => a < b ? a : b);
  }

  double _calculateMax() {
    if (sensorData.isEmpty) return 0.0;
    return sensorData.map((e) => e.y).reduce((a, b) => a > b ? a : b);
  }

  double _calculateAverage() {
    if (sensorData.isEmpty) return 0.0;
    return sensorData.map((e) => e.y).reduce((a, b) => a + b) / sensorData.length;
  }

  Widget _buildStatsCards() {
    if (!_showGraph || sensorData.isEmpty) return const SizedBox.shrink();

    final minValue = _calculateMin();
    final maxValue = _calculateMax();
    final avgValue = _calculateAverage();
    final sensorName = _sensorNameMap[_selectedSensorId] ?? _selectedSensorId!;
    final sensorDescription = _getSensorDescription(_selectedSensorId!);
    final lineColor = _sensorColors[_selectedSensorId] ?? Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard('Min', minValue.toStringAsFixed(2), _minColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Max', maxValue.toStringAsFixed(2), _maxColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStatCard('Avg', avgValue.toStringAsFixed(2), lineColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildAboutCard(sensorName, sensorDescription)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: _secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: _textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(String sensorName, String description) {
    final lineColor = _sensorColors[_selectedSensorId] ?? Colors.orange;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: lineColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: lineColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sensor Info',
                  style: TextStyle(
                    color: _secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sensorName,
              style: TextStyle(
                color: _textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: _secondaryTextColor,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getSensorDescription(String sensorId) {
    switch (sensorId) {
      case 'TEM01': return 'Air Temperature 1 - Measures ambient temperature in growing area (°C)';
      case 'TEM02': return 'Air Temperature 2 - Measures secondary ambient temperature (°C)';
      case 'HUM01': return 'Air Humidity 1 - Measures relative humidity in growing area (%)';
      case 'HUM02': return 'Air Humidity 2 - Measures secondary humidity (%)';
      case 'HUM03': return 'Air Humidity 3 - Measures tertiary humidity (%)';
      case 'CO001': return 'CO2 Level - Measures carbon dioxide concentration (ppm)';
      case 'PH001': return 'pH Level 1 - Measures substrate acidity/alkalinity (0-14 pH)';
      case 'PH011': return 'pH Level 2 - Measures secondary pH level (0-14 pH)';
      case 'CE001': return 'EC Level - Measures electrical conductivity of substrate (µS/cm)';
      case 'NH001': return 'NH4 Level - Measures ammonium concentration (ppm)';
      case 'OX001': return 'Dissolved Oxygen - Measures oxygen levels in substrate (mg/L)';
      case 'LUX01': return 'Light Intensity - Measures illumination levels (lux)';
      case 'PRED1': return 'Precipitation - Measures rainfall prediction';
      case 'PRE02': return 'Pressure - Measures atmospheric pressure (hPa)';
      case 'RAIN1': return 'Rainfall 1 - Measures precipitation levels (mm)';
      case 'RAIN2': return 'Rainfall 2 - Measures secondary precipitation (mm)';
      case 'WINA1': return 'Wind Angle - Measures wind direction (degrees)';
      case 'WIND1': return 'Wind Direction - Measures wind compass direction';
      case 'WINS1': return 'Wind Speed - Measures air movement velocity (m/s)';
      case 'POT01': return 'Soil Temperature - Measures substrate temperature (°C)';
      case 'NI001': return 'Soil Moisture - Measures substrate water content (%)';
      case 'CC001': return 'Carbon Monoxide - Measures CO concentration (ppm)';
      case 'CC002': return 'Carbon Dioxide - Measures CO2 concentration (ppm)';
      default: return 'Mushroom farm sensor measurement data';
    }
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
        Text(label, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _secondaryTextColor.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date != null ? DateFormat('yyyy-MM-dd').format(date.toLocal()) : 'Select Date', 
                    style: TextStyle(color: _textColor)),
                Icon(Icons.calendar_today, size: 18, color: _secondaryTextColor),
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
        Text(label, style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _secondaryTextColor.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time != null ? time.format(context) : 'Select Time', 
                    style: TextStyle(color: _textColor)),
                Icon(Icons.access_time, size: 18, color: _secondaryTextColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final now = DateTime.now();
    final initial = isStartDate ? (_startDate ?? now) : (_endDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.orange,
              onPrimary: _textColor,
              surface: _backgroundColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _backgroundColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && picked.isBefore(_startDate!)) {
            _startDate = picked;
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
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.orange,
              onPrimary: _textColor,
              surface: _backgroundColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _backgroundColor,
          ),
          child: MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _onShowGraphPressed() {
    FocusScope.of(context).unfocus();
    _fetchSensorData();
  }

  Future<void> _fetchSensorData() async {
    if (_selectedSensorId == null) {
      setState(() {
        errorMessage = 'Sensor ID is not set.';
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

    final startDateTime = DateTime(
      _startDate!.year, _startDate!.month, _startDate!.day, 
      _startTime!.hour, _startTime!.minute
    );
    final endDateTime = DateTime(
      _endDate!.year, _endDate!.month, _endDate!.day,
      _endTime!.hour, _endTime!.minute
    );

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
      final formattedStartDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(startDateTime.toUtc());
      final formattedEndDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(endDateTime.toUtc());

      final url = Uri.parse(
        'http://172.20.10.4:3000/sensor_data?farm_id=${widget.farmId}'
        '&start_date=$formattedStartDate&end_date=$formattedEndDate'
        '&sensor_id=$_selectedSensorId'
      );

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
            final timestamp = DateTime.parse(item['timestamp'].toString()).toUtc().millisecondsSinceEpoch.toDouble();
            final value = double.tryParse(item['value'].toString()) ?? 0.0;
            return FlSpot(timestamp, value);
          } catch (e) {
            return null;
          }
        }).whereType<FlSpot>().toList();

        setState(() {
          isLoading = false;
          if (sensorData.isEmpty) {
            errorMessage = "No valid data points available";
            _showGraph = false;
          }
        });
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
    if (sensorData.isEmpty) return const SizedBox.shrink();

    final lineColor = _sensorColors[_selectedSensorId] ?? Colors.orange;
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

    // Find min and max spots
    final minSpot = sensorData.firstWhere((spot) => spot.y == minY);
    final maxSpot = sensorData.firstWhere((spot) => spot.y == maxY);

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                final spot = barData.spots[index];
                Color dotColor = lineColor;
                if (spot.y == minY) dotColor = _minColor;
                if (spot.y == maxY) dotColor = _maxColor;
                return TouchedSpotIndicatorData(
                  FlLine(color: lineColor.withOpacity(0.5), strokeWidth: 2),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, idx) => 
                      FlDotCirclePainter(radius: 6, color: dotColor),
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                  final sensorName = _sensorNameMap[_selectedSensorId] ?? _selectedSensorId;
                  return LineTooltipItem(
                    '${sensorName}\n${DateFormat('yyyy-MM-dd HH:mm:ss').format(date.toLocal())}'
                    '\nValue: ${spot.y.toStringAsFixed(2)}',
                    TextStyle(color: lineColor, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
              getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
            ),
            handleBuiltInTouches: true,
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
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  if (spot == minSpot) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: _minColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  } else if (spot == maxSpot) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: _maxColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 0,
                    color: Colors.transparent,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withOpacity(0.2),
              ),
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
            getDrawingHorizontalLine: (value) => 
              FlLine(color: _secondaryTextColor.withOpacity(0.2), strokeWidth: 1),
            drawVerticalLine: true,
            verticalInterval: interval.toDouble(),
            getDrawingVerticalLine: (value) =>
              FlLine(color: _secondaryTextColor.withOpacity(0.1), strokeWidth: 1),
          ),
          borderData: FlBorderData(
            show: true, 
            border: Border.all(color: _secondaryTextColor, width: 1)),
        ),
      ),
    );
  }

  Widget _buildNoDataOrInitialScreen() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.orange));
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          errorMessage,
          style: const TextStyle(color: Colors.redAccent, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_selectedSensorId == null) {
      return Center(
        child: Text(
          'Error: No sensor ID provided to display graph.',
          style: TextStyle(color: _secondaryTextColor, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_showGraph || sensorData.isEmpty) {
      return Center(
        child: Text(
          'Select a time range and tap "Show Graph"\nNo data available for the selected range or sensor.',
          style: TextStyle(color: _secondaryTextColor, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: _buildGraph()),
        _buildStatsCards(),
      ],
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    final style = TextStyle(
      color: _secondaryTextColor, 
      fontWeight: FontWeight.bold, 
      fontSize: 10
    );
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
    final style = TextStyle(
      color: _secondaryTextColor, 
      fontWeight: FontWeight.bold, 
      fontSize: 12
    );
    final text = value.toStringAsFixed(value.abs() > 10 ? 0 : 1);
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text(text, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sensorId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Jamur Graph - Farm ${widget.farmId}'),
          backgroundColor: _backgroundColor,
        ),
        backgroundColor: _backgroundColor,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Error: No sensor ID provided to display graph.',
              style: TextStyle(color: Colors.redAccent, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Jamur Graph - Farm ${widget.farmId}'),
        backgroundColor: _backgroundColor,
      ),
      backgroundColor: _backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateTimePickers(),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: isLoading || _selectedSensorId == null ? null : _onShowGraphPressed,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, 
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Show Graph'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildNoDataOrInitialScreen(),
            ),
          ],
        ),
      ),
    );
  }
}