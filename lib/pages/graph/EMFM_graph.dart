import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class EMFMGraph extends StatefulWidget {
  final String gnssId;
  final String? sensorId;

  const EMFMGraph({
    Key? key,
    required this.gnssId,
    required this.sensorId,
  }) : super(key: key);

  @override
  State<EMFMGraph> createState() => _EMFMGraphState();
}

class _EMFMGraphState extends State<EMFMGraph> {
  List<FlSpot> sensorData = [];
  bool isLoading = false;
  String? errorMessage;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _showGraph = false;

  Map<String, String> _sensorNameMap = {};
  String? _selectedSensorId;

  final Color _graphColor = Colors.cyan;
  final Color _backgroundColor = Colors.grey[900]!;
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = Colors.white70;
  final Color _minColor = Colors.red;
  final Color _maxColor = Colors.green;

  final Map<String, Color> _sensorColors = {
    'DAT01': Colors.grey,
    'LON01': Colors.redAccent,
    'ALT01': Colors.blue,
    'LAT01': Colors.greenAccent,
    'HD01': Colors.brown,
    'SCO01': Colors.teal,
    'SNR01': Colors.purple,
    'UTC01': Colors.blueGrey,
    'GSE01': Colors.orange,
    'SAT01': Colors.pink,
    'PDO01': Colors.lime,
    'VDO01': Colors.indigo,
    'FXQ01': Colors.amber,
    'MVR01': Colors.cyan,
    'UTC02': Colors.blueGrey.shade700,
    'ALT02': Colors.blue.shade700,
    'SCO02': Colors.teal.shade700,
    'MVR02': Colors.cyan.shade700,
    'FXQ02': Colors.amber.shade700,
    'HDO02': Colors.brown.shade700,
    'GSE02': Colors.orange.shade700,
    'VDO02': Colors.indigo.shade700,
    'HUM02': Colors.green.shade700,
    'LON02': Colors.redAccent.shade700,
    'SAT02': Colors.pink.shade700,
    'LAT02': Colors.greenAccent.shade700,
    'DAT02': Colors.grey.shade700,
    'TEM02': Colors.red.shade700,
    'PDO02': Colors.lime.shade700,
    'SNR02': Colors.purple.shade700,
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
      errorMessage = null;
      _showGraph = false;
      sensorData = [];
    });

    await _fetchSensorNames();

    if (_selectedSensorId != null && mounted) {
      await _fetchSensorData();
    } else if (mounted) {
      setState(() {
        isLoading = false;
        errorMessage = 'No sensor selected. Please provide a sensor ID to graph.';
        _showGraph = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
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
    return sensorData.isNotEmpty
        ? sensorData.map((e) => e.y).reduce((a, b) => a + b) / sensorData.length
        : 0.0;
  }

  String _getSensorDescription(String sensorId) {
    final baseType = sensorId.length >= 3 ? sensorId.substring(0, 3) : sensorId;
    switch (baseType) {
      case 'ALT': return 'Measures altitude above sea level (m)';
      case 'TEM': return 'Measures temperature (°C)';
      case 'HUM': return 'Measures relative humidity (%)';
      case 'SNR': return 'Measures signal quality (dB)';
      case 'GSE': return 'Measures ground speed (m/s)';
      case 'HDO': return 'Measures Horizontal Dilution of Precision';
      case 'PDO': return 'Measures Positional Dilution of Precision';
      case 'VDO': return 'Measures Vertical Dilution of Precision';
      case 'SAT': return 'Number of satellites visible';
      case 'LAT': return 'Latitude coordinate';
      case 'LON': return 'Longitude coordinate';
      case 'CO': case 'CC': return 'Measures carbon compounds (ppm)';
      case 'CE': return 'Measures Electrical Conductivity (S/m)';
      case 'NH': return 'Measures Ammonium (mg/L)';
      case 'OX': return 'Measures Oxygen (mg/L)';
      case 'LUX': return 'Measures Light intensity (lx)';
      case 'PRE': return 'Measures Pressure (Pa or similar)';
      case 'RAIN': return 'Measures Rainfall (mm)';
      case 'WIN': return 'Measures Wind speed (m/s)';
      case 'NI': return 'Measures Soil Moisture (%)';
      case 'POT': return 'Measures Soil Temperature (°C)';
      case 'PH': return 'Measures pH level';
      case 'DO': return 'Measures oxygen levels in water (mg/L)';
      case 'TDS': return 'Measures water purity (ppm)';
      case 'RSS': return 'Measures wireless signal strength (dBm)';
      case 'SCO': return 'Measures direction of movement (degrees)';
      case 'FXQ': return 'Indicates quality of the GPS fix (e.g., 0, 1, 2)';
      case 'DAT': return 'Date and time information';
      case 'UTC': return 'UTC time information';
      case 'MVR': return 'Movement related data';
      default: return 'Sensor measurement data';
    }
  }

  Future<void> _fetchSensorNames() async {
    if (!mounted) return;

    try {
      final url = Uri.parse('http://172.20.10.4:3000/gnss_sensors?gnss_id=${widget.gnssId}');
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
      if (mounted) {
        setState(() {
          _sensorNameMap = {};
        });
      }
    }
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
      errorMessage = null;
      _showGraph = true;
      sensorData = [];
    });

    try {
      final formattedStartDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(startDateTime.toUtc());
      final formattedEndDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(endDateTime.toUtc());

      final url = Uri.parse(
        'http://172.20.10.4:3000/gnss_sensor_data?gnss_id=${widget.gnssId}'
        '&sensor_id=${_selectedSensorId!}'
        '&start_date=$formattedStartDate'
        '&end_date=$formattedEndDate'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        final dataList = decodedBody['data'];

        if (dataList == null || dataList is! List || dataList.isEmpty) {
          setState(() {
            errorMessage = "No data available for the selected time range.";
            isLoading = false;
            _showGraph = false;
          });
          return;
        }

        final List<Map<String, dynamic>> sortedList = 
            List<Map<String, dynamic>>.from(dataList)
              ..sort((a, b) => (a['timestamp'] as String).compareTo(b['timestamp'] as String));

        sensorData = sortedList.map((item) {
          try {
            if (item['timestamp'] == null || item['value'] == null) return null;
            final timestamp = DateTime.parse(item['timestamp'].toString())
                .toUtc()
                .millisecondsSinceEpoch
                .toDouble();
            final value = double.tryParse(item['value'].toString()) ?? 0.0;
            return FlSpot(timestamp, value);
          } catch (e) {
            print('Error parsing sensor data item: $item, Error: $e');
            return null;
          }
        }).whereType<FlSpot>().toList();

        if (mounted) {
          setState(() {
            isLoading = false;
            if (sensorData.isEmpty) {
              errorMessage = "No valid data points found in the selected range.";
              _showGraph = false;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = 'Error fetching data: Status ${response.statusCode}.';
            isLoading = false;
            _showGraph = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Network error fetching data: ${e.toString()}.';
          isLoading = false;
          _showGraph = false;
        });
      }
    }
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
              primary: _graphColor,
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
    final initial = isStart 
        ? (_startTime ?? TimeOfDay.now()) 
        : (_endTime ?? TimeOfDay.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              primary: _graphColor,
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

  Widget _buildDateTimePickers() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDatePicker(
                'Start Date', 
                _startDate, 
                () => _selectDate(context, true)
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTimePicker(
                'Start Time', 
                _startTime, 
                () => _selectTime(context, true)
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDatePicker(
                'End Date', 
                _endDate, 
                () => _selectDate(context, false)
              ),
        
            
        ),
      ],
        )
      ]
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _secondaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _secondaryTextColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null 
                      ? DateFormat('yyyy-MM-dd').format(date.toLocal())
                      : 'Select Date',
                  style: TextStyle(color: _textColor),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: _secondaryTextColor,
                ),
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
        Text(
          label,
          style: TextStyle(
            color: _secondaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _secondaryTextColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time != null ? time.format(context) : 'Select Time',
                  style: TextStyle(color: _textColor),
                ),
                Icon(
                  Icons.access_time,
                  size: 18,
                  color: _secondaryTextColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGraph() {
    if (sensorData.isEmpty) return const SizedBox.shrink();

    final lineColor = _sensorColors[_selectedSensorId] ?? _graphColor;
    final double minY = sensorData.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final double maxY = sensorData.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final double yRange = maxY - minY;
    final double padY = yRange > 0 ? yRange * 0.1 : 1.0;

    final double minX = sensorData.first.x;
    final double maxX = sensorData.last.x;
    final double xRange = maxX - minX;
    double intervalX = xRange > 0 ? (xRange / 6.0) : 3600000.0;
    if (intervalX < 3600000) intervalX = 3600000.0;
    if (xRange > 0 && xRange <= 60000) intervalX = xRange / 2.0;
    else if (xRange == 0) intervalX = 3600000.0;

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                  final sensorDisplayName = _sensorNameMap[_selectedSensorId] ?? _selectedSensorId;
                  return LineTooltipItem(
                    '${sensorDisplayName}\n${DateFormat('yyyy-MM-dd HH:mm:ss').format(date.toLocal())}\nValue: ${spot.y.toStringAsFixed(2)}',
                    TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
              getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
            ),
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: lineColor.withOpacity(0.5),
                    strokeWidth: 2,
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, idx) =>
                        FlDotCirclePainter(
                          radius: 6, 
                          color: lineColor,
                        ),
                  ),
                );
              }).toList();
            },
            handleBuiltInTouches: true,
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: (yRange > 0 ? yRange / 5.0 : 1.0),
            getDrawingHorizontalLine: (value) => FlLine(
              color: _secondaryTextColor.withOpacity(0.2),
              strokeWidth: 1,
            ),
            drawVerticalLine: true,
            verticalInterval: intervalX,
            getDrawingVerticalLine: (value) => FlLine(
              color: _secondaryTextColor.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: leftTitleWidgets,
                reservedSize: 40,
                interval: (yRange > 0 ? yRange / 5.0 : 1.0),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: bottomTitleWidgets,
                reservedSize: 40,
                interval: intervalX,
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: _secondaryTextColor,
              width: 1,
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
              color: lineColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    if (!_showGraph || sensorData.isEmpty || _selectedSensorId == null) {
      return const SizedBox.shrink();
    }

    final minValue = _calculateMin();
    final maxValue = _calculateMax();
    final avgValue = _calculateAverage();
    final sensorName = _sensorNameMap[_selectedSensorId] ?? _selectedSensorId!;
    final sensorDescription = _getSensorDescription(_selectedSensorId!);

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Min', minValue.toStringAsFixed(2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard('Max', maxValue.toStringAsFixed(2)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Avg', avgValue.toStringAsFixed(2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAboutCard(sensorName, sensorDescription),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _secondaryTextColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: _textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(String sensorName, String description) {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: TextStyle(
                color: _secondaryTextColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sensorName,
              style: TextStyle(
                color: _textColor,
                fontSize: 16,
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

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    final style = TextStyle(
      color: _secondaryTextColor,
      fontWeight: FontWeight.bold,
      fontSize: 10,
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
      fontSize: 12,
    );
    final double minY = sensorData.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final double maxY = sensorData.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final double yRange = maxY - minY;

    String text = value.toStringAsFixed(yRange > 100 ? 0 : yRange > 10 ? 1 : 2);

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text(text, style: style),
    );
  }

  Widget _buildNoDataOrInitialScreen() {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _graphColor),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Text(
          errorMessage!,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_showGraph || sensorData.isEmpty) {
      return Center(
        child: Text(
          'Select a time range and tap "Show Graph"',
          style: TextStyle(
            color: _secondaryTextColor,
            fontSize: 16,
          ),
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

  @override
  Widget build(BuildContext context) {
    if (widget.sensorId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('EMFM Graph - GNSS ${widget.gnssId}'),
          backgroundColor: _backgroundColor,
        ),
        backgroundColor: _backgroundColor,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Error: No sensor ID provided to display graph.',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('EMFM Graph - GNSS ${widget.gnssId}'),
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
              onPressed: isLoading ? null : _onShowGraphPressed,
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