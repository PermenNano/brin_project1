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
      'DAT01', 'LON01', 'ALT01', 'LAT01', 'HD01', 'SCO01', 'SNR01', 'UTC01',
      'GSE01', 'SAT01', 'PDO01', 'VDO01', 'FXQ01', 'MVR01',
    ],
    'GNSS2': [
      'UTC02', 'ALT02', 'SCO02', 'MVR02', 'FXQ02', 'HDO02', 'GSE02', 'VDO02',
      'HUM02', 'LON02', 'SAT02', 'LAT02', 'DAT02', 'TEM02', 'PDO02', 'SNR02',
    ],
    'GNSS3': [
      'DAT03', 'LON03', 'ALT03', 'LAT03', 'HD03', 'SCO03', 'SNR03', 'UTC03',
      'GSE03', 'SAT03', 'PDO03', 'VDO03', 'FXQ03', 'MVR03',
    ],
    'GNSS4': [
      'UTC04', 'ALT04', 'SCO04', 'MVR04', 'FXQ04', 'HDO04', 'GSE04', 'VDO04',
      'HUM04', 'LON04', 'SAT04', 'LAT04', 'DAT04', 'TEM04', 'PDO04', 'SNR04',
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

  @override
  void dispose() {
    super.dispose();
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
          .get(Uri.parse('http://172.20.10.4:3000/gnss_devices'))
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
          print("Failed to parse GNSS devices data from backend. Unexpected format: $decodedBody");
            if (mounted) {
              setState(() {
                  _errorMessage = "Failed to parse available GNSS devices. Unexpected backend format.";
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
              if (mounted) {
                setState(() {
                    _errorMessage = "No known GNSS devices found from backend.";
                });
              }
          }
        } else {
            if (mounted) {
              setState(() {
                  _errorMessage = "No GNSS devices available from backend.";
              });
            }
        }
      } else {
        print("Error fetching GNSS devices from backend: Status ${gnssDevicesResponse.statusCode}");
        if (mounted) {
          setState(() {
            _errorMessage = "Error fetching available GNSS devices: Status ${gnssDevicesResponse.statusCode}";
          });
        }
      }
    } catch (e) {
      print("Network error fetching GNSS devices: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Network error fetching available GNSS devices: ${e.toString()}";
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
          'http://172.20.10.4:3000/gnss_latest_data?gnss_id=$gnssId');

      print('Fetching latest data for GNSS $gnssId from URL: $url');

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
            print('Successfully fetched and processed latest data for GNSS $gnssId. Found ${latestRecords.length} readings.');
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

  String _getSensorNameBase(String sensorId) {
      final Map<String, String> sensorNameMap = const {
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
    final baseType = sensorId.length >= 3 ? sensorId.substring(0, 3).toUpperCase() : sensorId.toUpperCase();
      return sensorNameMap[baseType] ?? baseType;
  }

  String _getSensorNumberSuffix(String sensorId) {
      return sensorId.length > 3 ? sensorId.substring(3) : '';
  }

  String _getSensorTitle(String sensorId) {
      final baseName = _getSensorNameBase(sensorId);
      final suffix = _getSensorNumberSuffix(sensorId);

        if (baseName.contains(sensorId.substring(0,3)) && suffix.isNotEmpty) {
            return '$baseName $suffix'.trim();
        }

      final sensorNames = {
        'TEM01': 'Water Temperature',
        'TEM02': 'Air Temperature',
        'HUM01': 'Air Humidity',
        'HUM02': 'Humidity 2',
        'HUM03': 'Humidity 3',
        'PH001': 'pH 1',
        'PH011': 'Soil pH',
        'CE001': 'EC 1',
        'DO001': 'Dissolved Oxygen 1',
        'LUX01': 'Light Intensity 1',
        'NI001': 'Soil Moisture 1',
        'OX001': 'Dissolved Oxygen',
        'POT01': 'Soil Temperature 1',
        'CC001': 'Carbon Monoxide 1',
        'CC002': 'Carbon Dioxide 1',
          'PRED1': 'Precipitation 1',
          'PRE02': 'Pressure 2',
          'RAIN1': 'Rainfall 1 Hour',
          'RAIN2': 'Rainfall 1 Day',
          'WINA1': 'Wind Direction 1',
          'WIND1': 'Wind Speed Avg 1',
          'WINS1': 'Wind Speed Max 1',

          'DAT01': 'Date 1', 'LON01': 'Longitude 1', 'ALT01': 'Altitude 1', 'LAT01': 'Latitude 1',
          'HD01': 'HDOP 1', 'SCO01': 'Course 1', 'SNR01': 'Signal Quality 1', 'UTC01': 'UTC Time 1',
          'GSE01': 'Ground Speed 1', 'SAT01': 'Satellites 1', 'PDO01': 'PDOP 1', 'VDO01': 'VDOP 1',
          'FXQ01': 'Fix Quality 1', 'MVR01': 'Movement 1',

          'DAT02': 'Date 2', 'LON02': 'Longitude 2', 'ALT02': 'Altitude 2', 'LAT02': 'Latitude 2',
          'HDO02': 'HDOP 2', 'SCO02': 'Course 2', 'SNR02': 'Signal Quality 2', 'UTC02': 'UTC Time 2',
          'GSE02': 'Ground Speed 2', 'SAT02': 'Satellites 2', 'PDO02': 'PDOP 2', 'VDO02': 'VDOP 2',
          'FXQ02': 'Fix Quality 2', 'MVR02': 'Movement 2',
      };

    return sensorNames[sensorId] ?? '$baseName $suffix'.trim();
  }

  void _updateStatusMessage() {
      if (!mounted) return;

    if (_isLoading) {
        setState(() {
           _errorMessage = null;
        });
        return;
    }

    final List<String> availableLocations = _locations.toList();

    if (availableLocations.isEmpty) {
      setState(() {
           _errorMessage = "No GNSS locations available from the backend or defined in the app.";
      });
      return;
    }

    if (_selectedLocation == null) {
        setState(() {
           _errorMessage = "Select a GNSS location from the dropdown.";
        });
        return;
    }

      final List<String> expectedSensors = _knownGnssSensors[_selectedLocation!] ?? [];

    final selectedLocationData = _gnssLatestData[_selectedLocation!];

    if (selectedLocationData == null || selectedLocationData.isEmpty) {
      setState(() {
          if(expectedSensors.isNotEmpty){
            _errorMessage = "No sensor data available for selected location ${_selectedLocation!}.";
          } else {
            _errorMessage = "No known sensors defined for ${_selectedLocation!}.";
          }
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });
  }

  Widget _buildStatusWidget() {
    if (_isLoading && _locations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
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

    final selectedLocationData = _selectedLocation != null ? (_gnssLatestData[_selectedLocation!] ?? {}) : {};

    final List<String> sensorIdsToDisplay = _selectedLocation != null
        ? (_knownGnssSensors[_selectedLocation!] ?? [])
        : [];

    final List<Widget> sensorCards = sensorIdsToDisplay.map((sensorId) {
      final sensorData = selectedLocationData.containsKey(sensorId) ? selectedLocationData[sensorId] : null;
      final bool isTappable = sensorData != null;

      return _buildSensorCard(
        _getSensorTitle(sensorId),
        sensorData?['value']?.toString() ?? '-',
        sensorData?['timestamp']?.toString(),
        sensorId,
        isTappable
            ? () {
                FocusScope.of(context).unfocus();
                  if (_selectedLocation != null) {
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
              }
            : null,
      );
    }).toList();

      final int expectedCardsCount = sensorIdsToDisplay.length;
      final int currentCardsCount = sensorCards.length;
      if (currentCardsCount < expectedCardsCount + 4) {
        final int remainingSlots = (expectedCardsCount + 4) - currentCardsCount;
          for (int i = 0; i < remainingSlots; i++) {
            sensorCards.add(_buildEmptyCard());
          }
      }

    return Scaffold(
      appBar: AppBar(
        title: Text('GNSS Data - ${_selectedLocation ?? "Loading..."}'),
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
                  if (_locations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
                        child: Text(
                          'No sensor configurations defined for ${_selectedLocation!}.',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 16),
                            textAlign: TextAlign.center,
                        ),
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
    final bool hasData = onTap != null;

    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        color: hasData ? Theme.of(context).cardColor : Colors.grey[800],
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
                      color: hasData ? null : Colors.white54,
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
                      color: hasData ? null : Colors.white54,
                    ),
                textAlign: TextAlign.center,
              ),
                const SizedBox(height: 8),
              Text(
                'ID: $sensorId',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: hasData ? Colors.grey[500] : Colors.white30,
                      fontSize: 10,
                    ),
                textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              if (hasData)
                Text(
                  'More Info',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.blueAccent),
                ),
              if (!hasData)
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

  Widget _buildEmptyCard() {
    return _buildSensorCard(
      'No Sensor',
      '-',
      null,
      'N/A',
      null,
    );
  }
}