import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'graph/jamur_graph.dart';

class Jamur extends StatefulWidget {
  final DateTime date;
  final String farmId;

  const Jamur({Key? key, required this.date, required this.farmId}) : super(key: key);

  @override
  _JamurState createState() => _JamurState();
}

class _JamurState extends State<Jamur> with AutomaticKeepAliveClientMixin {
  Map<String, Map<String, dynamic>>? _latestData;
  bool _isLoading = true;
  String? _errorMessage;
  final List<String> _locations = const ['70', '71', '0'];
  final Map<String, Map<String, Map<String, dynamic>>> _allLatestData = {};
  String _selectedLocation = '70';

  final Map<String, List<String>> _farmSensors = {
    '70': [
      'TEM01', 'HUM01', 'CO001', 'PH001', 'CE001',
      'NH001', 'OX001', 'LUX01', 'PRED1',
    ],
    '71': [
      'HUM03', 'PRE02', 'RAIN1', 'RAIN2', 'TEM02',
      'WINA1', 'WIND1', 'WINS1',
    ],
    '0': [
      'TEM01', 'TEM02', 'HUM01', 'HUM02', 'LUX01',
      'NI001', 'OX001', 'PH001', 'PH011', 'POT01',
      'CC001', 'CC002',
    ],
  };

  final int _numberOfEmptyCards = 4;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    List<String> initialFarmIds = widget.farmId.split(',').map((e) => e.trim()).toList();
    _selectedLocation = _locations.firstWhere(
      (loc) => initialFarmIds.contains(loc),
      orElse: () => _locations.isNotEmpty ? _locations.first : '70',
    );

    if (_locations.isEmpty) {
      _isLoading = false;
      _errorMessage = "No locations defined for this view.";
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
      _allLatestData.clear();
    });

    List<Future<void>> fetchFutures = [];
    for (final location in _locations) {
      fetchFutures.add(_fetchLatestSensorData(location));
    }

    try {
      await Future.wait(fetchFutures);
    } catch (e) {
      if(mounted) {
        setState(() {
          _errorMessage = "Error fetching initial data: ${e.toString()}";
        });
      }
    }

    if (mounted) {
      setState(() {
        _latestData = _allLatestData.containsKey(_selectedLocation) ? _allLatestData[_selectedLocation] : null;
        _isLoading = false;
        _updateErrorMessage();
      });
    }
  }

  Future<void> _fetchLatestSensorData(String farmId) async {
    if (!mounted) return;

    try {
      final url = Uri.parse('http://172.20.10.4:3000/latest_sensor_data?farm_id=$farmId');

      print('Fetching latest data for farm $farmId from URL: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        dynamic decodedBody = json.decode(response.body);
        List<dynamic> dataList = [];

        if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('data') && decodedBody['data'] is List) {
          dataList = decodedBody['data'] as List;
        } else {
          print("Unexpected response format for location $farmId: $decodedBody");
          if(mounted) _allLatestData[farmId] = {};
          return;
        }

        Map<String, Map<String, dynamic>> latestRecords = {};
        for (var item in dataList) {
          if (item is! Map<String, dynamic> || item['sensor_id'] == null || item['timestamp'] == null || item['value'] == null) {
            print("Skipping invalid data item for farm $farmId: $item");
            continue;
          }
          String sensorId = item['sensor_id'] as String;

          latestRecords[sensorId] = item;
        }

        if (mounted) {
            final List<String> sensorsToDisplay = _farmSensors[farmId] ?? [];
            final Map<String, Map<String, dynamic>> filteredLatestRecords = {};
            for(var sensorId in sensorsToDisplay) {
              if(latestRecords.containsKey(sensorId)) {
                filteredLatestRecords[sensorId] = latestRecords[sensorId]!;
              }
            }
          _allLatestData[farmId] = filteredLatestRecords;
          print('Successfully fetched and processed latest data for farm $farmId. Displaying ${filteredLatestRecords.length} of ${sensorsToDisplay.length} sensors.');
        }

      } else {
        print("Failed to load data for location $farmId: ${response.statusCode}");
        if(mounted) {
          _allLatestData[farmId] = {};
        }
      }

    } catch (e) {
      print("Error fetching data for location $farmId: $e");
      if(mounted) {
        _allLatestData[farmId] = {};
      }
    }
  }

  void _navigateToDetail(BuildContext context, String farmId, String sensorId) {
    print('Navigating to JamurGraph for Farm $farmId, Sensor $sensorId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JamurGraph(
          farmId: farmId,
          sensorId: sensorId,
        ),
      ),
    );
  }

  Widget _buildSensorCard(
      String title,
      String value,
      String? timestamp,
      String sensorId,
      VoidCallback? onTap,
  ) {
    final bool hasData = onTap != null;

    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.blueAccent,
                  ),
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

  String _getFarmName(String farmId) {
    final farmNames = const {
      '70': 'Farm 70',
      '71': 'Farm 71',
      '0': 'Farm 0',
    };
    return farmNames[farmId] ?? 'Farm $farmId';
  }

  String _getSensorTitle(String sensorId) {
    final sensorTitles = {
      'TEM01': 'Water Temperature',
      'HUM01': 'Air Humidity',
      'CO001': 'CO2',
      'PH001': 'pH',
      'CE001': 'EC',
      'NH001': 'NH4',
      'OX001': 'Dissolved Oxygen',
      'LUX01': 'Light Intensity',
      'PRED1': 'Precipitation',

      'HUM03': 'Humidity',
      'PRE02': 'Pressure 2',
      'RAIN1': 'Rainfall 1 Hour',
      'RAIN2': 'Rainfall 1 Day',
      'TEM02': 'Air Temperature',
      'WINA1': 'Wind Direction',
      'WIND1': 'Wind Speed Avg',
      'WINS1': 'Wind Speed Max',

      'TEM02': 'Air Temperature',
      'HUM02': 'Air Humidity',
      'NI001': 'Soil Moisture',
      'PH001': 'pH',
      'PH011': 'Soil pH',
      'POT01': 'Soil Temperature',
      'CC001': 'Carbon Monoxide',
      'CC002': 'Carbon Dioxide',
      'OX001': 'Soil Oxygen',
      'LUX01': 'Light Intensity',
    };
      final defaultTitles = {
         'TEM01': 'Temperature 1', 'HUM01': 'Humidity 1', 'CO001': 'CO2 1',
         'PH001': 'pH 1', 'CE001': 'EC 1', 'NH001': 'NH4 1', 'OX001': 'Oxygen 1',
         'LUX01': 'Light 1', 'PRED1': 'Precipitation 1',
         'HUM03': 'Humidity 3', 'PRE02': 'Pressure 2',
         'RAIN1': 'Rain 1 Hour', 'RAIN2': 'Rain 1 Day', 'TEM02': 'Temperature 2',
         'WINA1': 'Wind Angle 1', 'WIND1': 'Wind Speed 1', 'WINS1': 'Wind Speed Max 1',
         'HUM02': 'Humidity 2', 'NI001': 'Nutrient 1', 'PH011': 'pH 1.1',
         'POT01': 'Potassium 1', 'CC001': 'Carbon 1', 'CC002': 'Carbon 2',
       };

    return sensorTitles[sensorId] ?? defaultTitles[sensorId] ?? sensorId;
  }

  void _updateErrorMessage() {
      if (!mounted) return;

    if (_locations.isEmpty) {
      setState(() {
          _errorMessage = "No locations defined for this view.";
      });
      return;
    }

    if (_isLoading) {
        setState(() {
          _errorMessage = null;
        });
        return;
    }

      final List<String> expectedSensors = _farmSensors[_selectedLocation] ?? [];

    final selectedLocationData = _allLatestData[_selectedLocation];

    if (selectedLocationData == null || selectedLocationData.isEmpty) {
      setState(() {
          if(expectedSensors.isNotEmpty){
            _errorMessage = "No sensor data available for Farm ${_getFarmName(_selectedLocation)}.";
          } else {
            _errorMessage = "No known sensors configured for Farm ${_getFarmName(_selectedLocation)} in the app.";
          }
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    final selectedLocationData = _allLatestData[_selectedLocation] ?? {};
    final sensorsToDisplay = _farmSensors[_selectedLocation] ?? [];


    final List<Widget> sensorCards = sensorsToDisplay.map((sensorId) {
      final sensorData = selectedLocationData.containsKey(sensorId) ? selectedLocationData[sensorId] : null;
      return _buildSensorCard(
        _getSensorTitle(sensorId),
        sensorData?['value']?.toString() ?? '-',
        sensorData?['timestamp']?.toString(),
        sensorId,
        sensorData != null ? () => _navigateToDetail(context, _selectedLocation, sensorId) : null,
      );
    }).toList();

    final int expectedCardsCount = sensorsToDisplay.length;
    final int currentCardsCount = sensorCards.length;
    if (currentCardsCount < expectedCardsCount + _numberOfEmptyCards) {
      final int remainingSlots = (expectedCardsCount + _numberOfEmptyCards) - currentCardsCount;
        for (int i = 0; i < remainingSlots; i++) {
          sensorCards.add(_buildEmptyCard());
        }
    }


    return Scaffold(
      appBar: AppBar(
        title: Text('Jamur - ${_getFarmName(_selectedLocation)}'),
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
                  _buildLocationDropdown(),


                if (_isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  )),

                if (_errorMessage != null && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),

                if (!_isLoading && _errorMessage == null && _locations.isNotEmpty && sensorsToDisplay.isNotEmpty)
                    GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 0.9,
                    children: sensorCards,
                  )
                else if (!_isLoading && _errorMessage == null && _locations.isNotEmpty && sensorsToDisplay.isEmpty)
                    Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
                      child: Text(
                        'No sensor configurations defined for Farm ${_getFarmName(_selectedLocation)}.',
                         style: const TextStyle(color: Colors.orangeAccent, fontSize: 16),
                         textAlign: TextAlign.center,
                       ),
                     )

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDropdown() {
    if (_locations.length <= 1) {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Farm:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color.fromARGB(255, 114, 114, 114),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            value: _locations.contains(_selectedLocation) ? _selectedLocation : (_locations.isNotEmpty ? _locations.first : null),
            icon: const Icon(Icons.arrow_downward, color: Colors.white),
            elevation: 16,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            dropdownColor: const Color.fromARGB(255, 114, 114, 114),
            onChanged: (String? newValue) {
              if (newValue != null && newValue != _selectedLocation) {
                setState(() {
                  _selectedLocation = newValue;
                  _latestData = _allLatestData[_selectedLocation];
                  _updateErrorMessage();
                });
              }
            },
            items: _locations.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(_getFarmName(value)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}