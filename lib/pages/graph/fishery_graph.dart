import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FisheryGraph extends StatefulWidget {
  final String farmId;
  final String? sensorId;

  const FisheryGraph({Key? key, required this.farmId, this.sensorId})
      : super(key: key);

  @override
  _FisheryGraphState createState() => _FisheryGraphState();
}

class _FisheryGraphState extends State<FisheryGraph> {
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

  final Color _graphColor = Colors.cyan;
  final Color _backgroundColor = Colors.grey[900]!;
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = Colors.white70;
  final Color _minColor = Colors.redAccent;
  final Color _maxColor = Colors.greenAccent;

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

    if (mounted) {
      await _fetchSensorData();
    }
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

              String sensorName =
                  item.containsKey('name') && item['name'] != null
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
        } else {
          print('Warning: Received invalid sensor list format from server for names.');
          if (mounted) {
            setState(() {
              _sensorNameMap = {};
            });
          }
        }
      } else {
        print('Warning: Could not load sensor names: Status ${response.statusCode}.');
        if (mounted) {
          setState(() {
            _sensorNameMap = {};
          });
        }
      }
    } catch (e) {
      print('Network error fetching sensor names: ${e.toString()}.');
      if (mounted) {
        setState(() {
          _sensorNameMap = {};
        });
      }
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
    return sensorData.isNotEmpty
        ? sensorData.map((e) => e.y).reduce((a, b) => a + b) / sensorData.length
        : 0.0;
  }

  Widget _buildStatsCards() {
    if (!_showGraph || sensorData.isEmpty) return const SizedBox.shrink();

    final minValue = _calculateMin();
    final maxValue = _calculateMax();
    final avgValue = _calculateAverage();
    final sensorName =
        _sensorNameMap[_selectedSensorId] ?? _selectedSensorId!;
    final sensorDescription = _getSensorDescription(_selectedSensorId!);

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Min Value',
                  minValue.toStringAsFixed(2),
                  _minColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Max Value',
                  maxValue.toStringAsFixed(2),
                  _maxColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Avg Value',
                  avgValue.toStringAsFixed(2),
                  _graphColor,
                ),
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

  String _getSensorDescription(String sensorId) {
    switch (sensorId) {
      case 'DO001':
        return 'Dissolved Oxygen - Measures oxygen levels in water (mg/L)';
      case 'HUM01':
        return 'Humidity - Measures relative humidity in air (%)';
      case 'TEM01':
        return 'Temperature - Measures ambient temperature (°C)';
      case 'RSS01':
        return 'Signal Strength - Measures wireless signal strength (dBm)';
      case 'TDS01':
        return 'Total Dissolved Solids - Measures water purity (ppm)';
      default:
        return 'Sensor measurement data';
    }
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                    color: _graphColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: _graphColor,
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

  Widget _buildDateTimePickers() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _buildDatePicker(
                    'Start Date', _startDate, () => _selectDate(context, true))),
            const SizedBox(width: 10),
            Expanded(
                child: _buildTimePicker(
                    'Start Time', _startTime, () => _selectTime(context, true))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildDatePicker(
                    'End Date', _endDate, () => _selectDate(context, false))),
            const SizedBox(width: 10),
            Expanded(
                child: _buildTimePicker(
                    'End Time', _endTime, () => _selectTime(context, false))),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePicker(
      String label, DateTime? date, VoidCallback onTap) {
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
                Text(
                    date != null
                        ? DateFormat('yyyy-MM-dd').format(date.toLocal())
                        : 'Select Date',
                    style: TextStyle(color: _textColor)),
                Icon(Icons.calendar_today,
                    size: 18, color: _secondaryTextColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(
      String label, TimeOfDay? time, VoidCallback onTap) {
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
                Text(
                    time != null ? time.format(context) : 'Select Time',
                    style: TextStyle(color: _textColor)),
                Icon(Icons.access_time,
                    size: 18, color: _secondaryTextColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onShowGraphPressed() {
    _fetchSensorData();
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
            if (_startDate?.isAtSameMomentAs(_endDate!) == true &&
                _startTime != null &&
                _endTime != null) {
               final s = DateTime(_startDate!.year, _startDate!.month,
                   _startDate!.day, _startTime!.hour, _startTime!.minute);
               final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day,
                   _endTime!.hour, _endTime!.minute);
               if (s.isAfter(e)) {
                 _endTime = _startTime;
               }
             }
          }
        } else {
          _endDate = picked;
          if (_startDate != null && picked.isBefore(_startDate!)) {
            _startDate = picked;
            if (_startDate?.isAtSameMomentAs(_endDate!) == true &&
                _startTime != null &&
                _endTime != null) {
               final s = DateTime(_startDate!.year, _startDate!.month,
                   _startDate!.day, _startTime!.hour, _startTime!.minute);
               final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day,
                   _endTime!.hour, _endTime!.minute);
               if (e.isBefore(s)) {
                 _startTime = _endTime;
               }
             }
          }
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final initial =
        isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now());
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
          if (_startDate != null &&
              _endDate != null &&
              _startTime != null &&
              _endTime != null && _startDate?.isAtSameMomentAs(_endDate!) == true) {
            final s = _startDate!.add(Duration(
                hours: _startTime!.hour, minutes: _startTime!.minute));
            final e = _endDate!.add(
                Duration(hours: _endTime!.hour, minutes: _endTime!.minute));
            if (s.isAfter(e)) _endTime = _startTime;
          }
        } else {
          _endTime = picked;
          if (_startDate != null &&
              _endDate != null &&
              _startTime != null &&
              _endTime != null && _startDate?.isAtSameMomentAs(_endDate!) == true) {
            final s = _startDate!.add(Duration(
                hours: _startTime!.hour, minutes: _startTime!.minute));
            final e = _endDate!.add(
                Duration(hours: _endTime!.hour, minutes: _endTime!.minute));
            if (e.isBefore(s)) _startTime = _endTime;
          }
        }
      });
    }
  }

  Future<void> _fetchSensorData() async {
    if (!mounted) return;

    if (_selectedSensorId == null) {
      setState(() {
        errorMessage = 'Sensor ID is not set.';
        isLoading = false;
        _showGraph = false;
      });
      return;
    }

    if (_startDate == null ||
        _endDate == null ||
        _startTime == null ||
        _endTime == null) {
      setState(() {
        errorMessage = 'Please select a complete date and time range';
        isLoading = false;
        _showGraph = false;
      });
      return;
    }

    final startDateTime = DateTime(_startDate!.year, _startDate!.month,
        _startDate!.day, _startTime!.hour, _startTime!.minute);
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
      final formattedStartDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(startDateTime.toUtc());
      final formattedEndDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(endDateTime.toUtc());

      final url = Uri.parse(
          'http://172.20.10.4:3000/sensor_data?farm_id=${widget.farmId}&start_date=$formattedStartDate&end_date=$formattedEndDate&sensor_id=$_selectedSensorId');

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
          ..sort((a, b) =>
              (a['timestamp'] as String).compareTo(b['timestamp'] as String));

        sensorData = sortedList.map((item) {
          try {
            if (item['timestamp'] == null || item['value'] == null) {
              return null;
            }
            final timestamp = DateTime.parse(item['timestamp'].toString()).toUtc().millisecondsSinceEpoch.toDouble();
            final value = double.tryParse(item['value'].toString()) ?? 0.0;
            return FlSpot(timestamp, value);
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
    if (sensorData.isEmpty) return const SizedBox.shrink();

    final ys = sensorData.map((e) => e.y).toList();
    final minY = ys.isNotEmpty ? ys.reduce((a, b) => a < b ? a : b) : 0.0;
    final maxY = ys.isNotEmpty ? ys.reduce((a, b) => a > b ? a : b) : 0.0;
    final yRange = maxY - minY;
    final padY = yRange > 0 ? yRange * 0.1 : 1.0;

    final xs = sensorData.map((e) => e.x).toList();
    final minX = xs.isNotEmpty ? xs.first : 0.0;
    final maxX = xs.isNotEmpty ? xs.last : 0.0;
    final xRange = maxX - minX;
    final interval =
        xRange > 0 ? (xRange / 5 > 60000 ? xRange / 5 : 60000) : 60000;

    // Find min and max spots
    final minSpot = sensorData.firstWhere((spot) => spot.y == minY);
    final maxSpot = sensorData.firstWhere((spot) => spot.y == maxY);

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: LineChart(LineChartData(
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              final spot = barData.spots[index];
              Color dotColor = _graphColor;
              if (spot.y == minY) {
                dotColor = _minColor;
              } else if (spot.y == maxY) {
                dotColor = _maxColor;
              }
              return TouchedSpotIndicatorData(
                FlLine(
                    color: _graphColor.withOpacity(0.5), strokeWidth: 2),
                FlDotData(
                  getDotPainter: (spot, percent, bar, idx) {
                    return FlDotCirclePainter(radius: 6, color: dotColor);
                  },
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final date =
                    DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                final sensorDisplayName =
                    _sensorNameMap[_selectedSensorId] ?? _selectedSensorId;
                return LineTooltipItem(
                  '${sensorDisplayName}\n${DateFormat('yyyy-MM-dd HH:mm:ss').format(date.toLocal())}\nValue: ${spot.y.toStringAsFixed(2)}',
                  TextStyle(
                      color: _textColor,
                      fontWeight:
                          FontWeight.bold),
                );
              }).toList();
            },
             getTooltipColor: (touchedSpot) {
                return Colors.blueGrey.withOpacity(0.8);
              },
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
            color: _graphColor,
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
                color: _graphColor.withOpacity(0.2)),
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
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          horizontalInterval: (yRange > 0 ? yRange / 5 : 10).toDouble(),
          getDrawingHorizontalLine: (value) => FlLine(
              color: _secondaryTextColor.withOpacity(0.2), strokeWidth: 1),
          drawVerticalLine: true,
          verticalInterval: interval.toDouble(),
          getDrawingVerticalLine: (value) =>
              FlLine(color: _secondaryTextColor.withOpacity(0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(
            show: true, border: Border.all(color: _secondaryTextColor, width: 1)),
      )),
    );
  }

  Widget _buildNoDataOrInitialScreen() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: _graphColor));
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
        color: _secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 10);
    if (sensorData.isEmpty ||
        value < sensorData.first.x ||
        value > sensorData.last.x) return const SizedBox.shrink();
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final formattedDate = DateFormat('MM-dd HH:mm').format(date.toLocal());

    return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 8,
        child: Text(formattedDate, style: style, textAlign: TextAlign.center));
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    final style = TextStyle(
        color: _secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 12);
    final text = value.toStringAsFixed(value.abs() > 10 ? 0 : 1);
    return SideTitleWidget(axisSide: meta.axisSide, space: 8, child: Text(text, style: style));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sensorId == null) {
       return Scaffold(
         appBar: AppBar(
           title: Text('Fishery Graph - Farm ${widget.farmId}'),
            backgroundColor: _backgroundColor,
         ),
         backgroundColor: _backgroundColor,
         body: const Center(
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
        title: Text('Fishery Graph - Farm ${widget.farmId}'),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isLoading || _selectedSensorId == null ? null : _onShowGraphPressed,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Show Graph',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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