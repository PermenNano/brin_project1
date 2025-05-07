import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EMFM extends StatefulWidget {
  final DateTime date;
  final String farmId;

  const EMFM({Key? key, required this.date, required this.farmId})
      : super(key: key);

  @override
  _EMFMState createState() => _EMFMState();
}

class _EMFMState extends State<EMFM> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _locations = {};
  final Map<String, Map<String, dynamic>> _gnssLatestData = {};
  String? _selectedLocation;

  final List<String> _baseSensorTypes = [
    'ALT', 'DAT', 'FXO', 'GSE', 'HDO', 
    'LAT', 'LON', 'MVR', 'PDO', 'SAT',
    'SCO', 'SNR', 'UTC', 'VDO'
  ];

  final int _numberOfEmptyCards = 4;
  final Map<String, String> _sensorNameMap = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _gnssLatestData.clear();
      _locations.clear();
      _sensorNameMap.clear();
    });

    try {
      // First fetch all available GNSS devices
      final gnssDevicesResponse = await http.get(
        Uri.parse('http://10.0.2.2:3000/gnss_devices')
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (gnssDevicesResponse.statusCode == 200) {
        final decodedBody = json.decode(gnssDevicesResponse.body);
        if (decodedBody is Map && decodedBody['data'] is List) {
          final devices = (decodedBody['data'] as List).cast<String>();
          
          // Then fetch latest data for each GNSS device
          for (final gnssId in devices) {
            await _fetchGnssLatestData(gnssId);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error fetching initial data: ${e.toString()}";
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _updateErrorMessage();
        if (_locations.isNotEmpty) {
          _selectedLocation = _locations.first;
        }
      });
    }
  }

  Future<void> _fetchGnssLatestData(String gnssId) async {
    if (!mounted) return;

    try {
      final url = Uri.parse('http://10.0.2.2:3000/gnss_latest_data?gnss_id=$gnssId');
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        if (decodedBody is Map && decodedBody['data'] is List) {
          final dataList = (decodedBody['data'] as List).cast<Map<String, dynamic>>();
          
          final Map<String, dynamic> latestData = {};
          for (var item in dataList) {
            if (item['sensor_id'] != null) {
              latestData[item['sensor_id'] as String] = item;
              _sensorNameMap[item['sensor_id'] as String] = 
                  item['sensor_name'] ?? item['sensor_id'] as String;
            }
          }

          if (mounted) {
            setState(() {
              _gnssLatestData[gnssId] = latestData;
              _locations.add(gnssId);
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gnssLatestData[gnssId] = {};
        });
      }
    }
  }

  String _formatTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return "-";
    try {
      final dtUtc = DateTime.parse(ts).toUtc();
      final dtLocal = dtUtc.toLocal();
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(dtLocal);
    } catch (_) {
      return ts ?? '-';
    }
  }

  String _getSensorIdForGnss(String baseType, String gnssId) {
    final gnssNumber = gnssId.replaceAll('GNSS', '');
    return '${baseType}${gnssNumber.padLeft(2, '0')}';
  }

  String _getSensorTitle(String sensorId) {
    final sensorNames = {
      'ALT': 'Altitude',
      'DAT': 'Date',
      'FXO': 'Fix Quality',
      'GSE': 'Ground Speed',
      'HDO': 'HDOP',
      'LAT': 'Latitude',
      'LON': 'Longitude',
      'MVR': 'Movement',
      'PDO': 'PDOP',
      'SAT': 'Satellites',
      'SCO': 'Satellites Used',
      'SNR': 'Signal Quality',
      'UTC': 'UTC Time',
      'VDO': 'VDOP',
    };

    final baseType = sensorId.length >= 3 ? sensorId.substring(0, 3) : sensorId;
    return sensorNames[baseType] ?? sensorId;
  }

  void _updateErrorMessage() {
    if (_locations.isEmpty) {
      _errorMessage = "No GNSS locations available.";
    } else if (_gnssLatestData.isEmpty && !_isLoading) {
      _errorMessage = "Could not retrieve data for any location.";
    } else if (_selectedLocation == null && !_isLoading) {
      _errorMessage = "No GNSS location selected.";
    } else if (!_gnssLatestData.containsKey(_selectedLocation) && !_isLoading) {
      _errorMessage = "Data for GNSS Location $_selectedLocation not loaded.";
    } else if ((_gnssLatestData[_selectedLocation] == null ||
            _gnssLatestData[_selectedLocation]!.isEmpty) &&
        !_isLoading) {
      _errorMessage = "No sensor data available for GNSS $_selectedLocation.";
    } else {
      _errorMessage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final List<Widget> sensorCards = [];
    
    if (_selectedLocation != null && _gnssLatestData.containsKey(_selectedLocation)) {
      for (final baseType in _baseSensorTypes) {
        final sensorId = _getSensorIdForGnss(baseType, _selectedLocation!);
        final sensorData = _gnssLatestData[_selectedLocation]?[sensorId];
        
        sensorCards.add(
          _buildSensorCard(
            _getSensorTitle(sensorId),
            sensorData?['value']?.toString() ?? '-',
            _formatTimestamp(sensorData?['timestamp']),
            sensorId,
            sensorData != null ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Showing graph for $sensorId')),
              );
            } : null,
          ),
        );
      }
    }

    // Add empty cards to fill the grid
    final remainingSlots = _baseSensorTypes.length % 2 == 0 ? 0 : 1;
    for (int i = 0; i < remainingSlots + _numberOfEmptyCards; i++) {
      sensorCards.add(_buildEmptyCard());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('GNSS Data'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInitialData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isLoading && _locations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select GNSS Location:',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: const Color.fromARGB(255, 114, 114, 114),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          value: _selectedLocation,
                          icon: const Icon(Icons.arrow_downward,
                              color: Colors.white),
                          dropdownColor: const Color.fromARGB(255, 114, 114, 114),
                          elevation: 16,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          onChanged: (String? newValue) {
                            if (newValue != null &&
                                newValue != _selectedLocation) {
                              setState(() {
                                _selectedLocation = newValue;
                                _updateErrorMessage();
                              });
                            }
                          },
                          items: _locations.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                if (_isLoading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  )),
                if (_errorMessage != null && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (!_isLoading &&
                    _errorMessage == null &&
                    _locations.isNotEmpty)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 0.9,
                    children: sensorCards,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorCard(
      String title, String value, String? timestamp, String sensorId,
      VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: onTap != null ? Theme.of(context).cardColor : Colors.grey[800],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onTap != null ? null : Colors.white54,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: onTap != null ? null : Colors.white54,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                timestamp ?? '-',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onTap != null ? Colors.grey[600] : Colors.white38,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'ID: $sensorId',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onTap != null ? Colors.grey[500] : Colors.white30,
                      fontSize: 10,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (onTap != null)
                Text(
                  'More Info',
                  style:
                      Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.blueAccent),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[850],
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 30, color: Colors.white54),
            SizedBox(height: 8),
            Text(
              'No Data Available',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'Placeholder',
              style: TextStyle(fontSize: 12, color: Colors.white38),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}