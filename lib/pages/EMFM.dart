import 'package:brin_project1/pages/graph/EMFM_graph.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EMFM extends StatefulWidget {
  final DateTime date;
  final String farmId;

  const EMFM({
    super.key,
    required this.date,
    required this.farmId,
  });

  @override
  State<EMFM> createState() => _EMFMState();
}

class _EMFMState extends State<EMFM> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _locations = {};
  final Map<String, Map<String, dynamic>> _gnssLatestData = {};
  String? _selectedLocation;

  final Map<String, List<String>> _knownGnssSensors = const {
    'GNSS1': [
      'DAT01',
      'LON01',
      'ALT01',
      'LAT01',
      'HD01',
      'SCO01',
      'SNR01',
      'UTC01',
      'GSE01',
      'SAT01',
      'PDO01',
      'VDO01',
      'FXQ01',
      'MVR01',
    ],
    'GNSS2': [
      'UTC02',
      'ALT02',
      'SCO02',
      'MVR02',
      'FXQ02',
      'HDO02',
      'GSE02',
      'VDO02',
      'HUM02',
      'LON02',
      'SAT02',
      'LAT02',
      'DAT02',
      'TEM02',
      'PDO02',
      'SNR02',
    ],
    'GNSS3': [
      'DAT01',
      'LON01',
      'ALT01',
      'LAT01',
      'HD01',
      'SCO01',
      'SNR01',
      'UTC01',
      'GSE01',
      'SAT01',
      'PDO01',
      'VDO01',
      'FXQ01',
      'MVR01',
    ],
    'GNSS4': [
      'UTC02',
      'ALT02',
      'SCO02',
      'MVR02',
      'FXQ02',
      'HDO02',
      'GSE02',
      'VDO02',
      'HUM02',
      'LON02',
      'SAT02',
      'LAT02',
      'DAT02',
      'TEM02',
      'PDO02',
      'SNR02',
    ],
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (_knownGnssSensors.isEmpty) {
      _isLoading = false;
      _errorMessage = "No known GNSS sensors defined in the app.";
    } else {
      _fetchInitialData();
    }
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _gnssLatestData.clear();
      _locations.clear();
      _selectedLocation = null;
    });

    try {
      final gnssDevicesResponse = await http
          .get(Uri.parse('http://192.168.1.2:3000/gnss_devices'))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (gnssDevicesResponse.statusCode == 200) {
        final decodedBody = json.decode(gnssDevicesResponse.body);
        List<String> devices = [];

        if (decodedBody is Map &&
            decodedBody.containsKey('data') &&
            decodedBody['data'] is List) {
          devices = (decodedBody['data'] as List)
              .map((item) {
                if (item is Map && item.containsKey('gnss_id')) {
                  return item['gnss_id'].toString();
                }
                return null;
              })
              .whereType<String>()
              .toList();
        } else {
          if (mounted) {
            setState(() {
              _errorMessage =
                  "Failed to parse GNSS devices data from backend. Unexpected format.";
              _isLoading = false;
            });
          }
          return;
        }

        if (devices.isNotEmpty) {
          final availableKnownLocations = devices
              .where((device) => _knownGnssSensors.containsKey(device))
              .toList();

          if (availableKnownLocations.isNotEmpty) {
            _locations.addAll(availableKnownLocations);

            List<Future<void>> fetchFutures = [];
            for (final gnssId in availableKnownLocations) {
              fetchFutures.add(_fetchGnssLatestData(gnssId));
            }

            await Future.wait(fetchFutures);

            if (_locations.contains('GNSS1')) {
              _selectedLocation = 'GNSS1';
            } else {
              _selectedLocation = _locations.isNotEmpty ? _locations.first : null;
            }
          } else {
            setState(() {
              _errorMessage = "No known GNSS devices found from backend.";
            });
          }
        } else {
          setState(() {
            _errorMessage = "No GNSS devices available from backend.";
          });
        }
      } else {
        setState(() {
          _errorMessage =
              "Error fetching GNSS devices from backend: Status ${gnssDevicesResponse.statusCode}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Network error fetching GNSS devices: ${e.toString()}";
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _updateStatusMessage();
      });
    }
  }

  Future<void> _fetchGnssLatestData(String gnssId) async {
    if (!mounted) return;

    try {
      final url = Uri.parse(
          'http://192.168.1.2:3000/gnss_latest_data?gnss_id=$gnssId');

      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        dynamic decodedBody = json.decode(response.body);
        List<dynamic> dataList = [];

        if (decodedBody is Map<String, dynamic> &&
            decodedBody.containsKey('data') &&
            decodedBody['data'] is List) {
          dataList = decodedBody['data'] as List;
        } else {
          print(
              "Unexpected response format for latest data for GNSS $gnssId: $decodedBody");
          if (mounted) _gnssLatestData[gnssId] = {};
          return;
        }

        Map<String, dynamic> latestRecords = {};
        for (var item in dataList) {
          if (item is! Map<String, dynamic> ||
              item['sensor_id'] == null ||
              item['timestamp'] == null ||
              item['value'] == null) {
            print("Skipping invalid data item for GNSS $gnssId: $item");
            continue;
          }
          String sensorId = item['sensor_id'] as String;

          latestRecords[sensorId] = item;
        }

        if (mounted) {
          _gnssLatestData[gnssId] = latestRecords;
        }
      } else {
        print(
            "Failed to load latest data for GNSS $gnssId: ${response.statusCode} ${response.reasonPhrase ?? 'Unknown Error'}");
        if (mounted) {
          _gnssLatestData[gnssId] = {};
        }
      }
    } catch (e) {
      print("Error fetching latest data for GNSS $gnssId: $e");
      if (mounted) {
        _gnssLatestData[gnssId] = {};
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
      print('Failed to parse timestamp for formatting: $ts');
      return ts ?? '-';
    }
  }

  String _getSensorTitle(String sensorId) {
    final sensorNames = const {
      'ALT': 'Altitude',
      'DAT': 'Date',
      'FXQ': 'Fix Quality',
      'GSE': 'Ground Speed',
      'HDO': 'HDOP',
      'HUM': 'Humidity',
      'LAT': 'Latitude',
      'LON': 'Longitude',
      'MVR': 'Movement',
      'PDO': 'PDOP',
      'SAT': 'Satellites',
      'SCO': 'Course',
      'SNR': 'Signal Quality',
      'TEM': 'Temperature',
      'UTC': 'UTC Time',
      'VDO': 'VDOP',
      'CO': 'Carbon',
      'CE': 'EC',
      'NH': 'Ammonium',
      'OX': 'Oxygen',
      'LUX': 'Light',
      'PRE': 'Pressure',
      'RAIN': 'Rainfall',
      'WIN': 'Wind',
      'NI': 'Soil Moisture',
      'POT': 'Soil Temp',
      'CC': 'Carbon',
      'PH': 'pH',
    };
    final baseType = sensorId.length >= 3 ? sensorId.substring(0, 3) : sensorId;
    final sensorNumber = sensorId.length > 3 ? sensorId.substring(3) : '';

    if (sensorNames.containsKey(baseType)) {
      final genericName = sensorNames[baseType]!;
      if (genericName.contains(baseType) || genericName == baseType || sensorNumber.isEmpty) {
        return '$genericName $sensorNumber'.trim();
      } else {
        return '$genericName$sensorNumber';
      }
    }

    return sensorId;
  }

  void _updateStatusMessage() {
    if (_isLoading) {
      _errorMessage = null;
      return;
    }

    if (_locations.isEmpty) {
      _errorMessage = "No GNSS locations available.";
      return;
    }

    if (_selectedLocation == null) {
      _errorMessage = "No GNSS location selected.";
      return;
    }

    final selectedLocationData = _gnssLatestData[_selectedLocation];
    if (selectedLocationData == null || selectedLocationData.isEmpty) {
      final knownSensorsForSelectedLocation =
          _knownGnssSensors[_selectedLocation];

      if (knownSensorsForSelectedLocation == null ||
          knownSensorsForSelectedLocation.isEmpty) {
        _errorMessage = "No known sensors defined for ${_selectedLocation!}.";
      } else {
        _errorMessage =
            "No sensor data available for selected location ${_selectedLocation!}.";
      }
      return;
    }

    _errorMessage = null;
  }

  Widget _buildStatusWidget() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final selectedLocationData = _gnssLatestData[_selectedLocation] ?? {};

    final List<String> sensorIdsToDisplay = _selectedLocation != null
        ? (_knownGnssSensors[_selectedLocation] ?? [])
        : [];

    final List<Widget> sensorCards = sensorIdsToDisplay.map((sensorId) {
      final sensorData = selectedLocationData[sensorId];
      final bool isTappable = sensorData != null;

      return _buildSensorCard(
        _getSensorTitle(sensorId),
        sensorData?['value']?.toString() ?? '-',
        _formatTimestamp(sensorData?['timestamp']),
        sensorId,
        isTappable
            ? () {
                FocusScope.of(context).unfocus();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EMFMGraph(
                      gnssId: _selectedLocation!,
                      sensorId: sensorId,
                    ),
                  ),
                );
              }
            : null,
      );
    }).toList();

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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(style: BorderStyle.none),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(style: BorderStyle.none),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.red, width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
                            ),
                            filled: true,
                            fillColor: const Color.fromARGB(255, 114, 114, 114),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          value: _selectedLocation,
                          icon: const Icon(Icons.arrow_downward, color: Colors.white),
                          elevation: 16,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          dropdownColor: const Color.fromARGB(255, 114, 114, 114),
                          onChanged: (String? newValue) {
                            if (newValue != null && newValue != _selectedLocation) {
                              setState(() {
                                _selectedLocation = newValue;
                                _updateStatusMessage();
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
                _buildStatusWidget(),
                if (!_isLoading && _errorMessage == null && _selectedLocation != null)
                  if (sensorIdsToDisplay.isNotEmpty)
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
      String title,
      String value,
      String? timestamp,
      String sensorId,
      VoidCallback? onTap
      ) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
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
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.blueAccent),
                ),
              if (onTap == null)
                const Text(
                  'No Data',
                  style: TextStyle(color: Colors.white38),
                ),
            ],
          ),
        ),
      ),
    );
  }
}