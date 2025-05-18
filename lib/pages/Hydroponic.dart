import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'graph/hydroponic_graph.dart';

class Hydroponic extends StatefulWidget {
  final DateTime date;
  final String farmId;

  const Hydroponic({Key? key, required this.date, required this.farmId}) : super(key: key);

  @override
  _HydroponicState createState() => _HydroponicState();
}

class _HydroponicState extends State<Hydroponic> with AutomaticKeepAliveClientMixin {

  Map<String, Map<String, dynamic>>? _latestData;

  bool _isLoading = true;

  String? _errorMessage;

  final List<String> _locations = const ['10', '11']; // Added const

  final Map<String, Map<String, Map<String, dynamic>>> _allLatestData = {};

  String _selectedLocation = '10';

  final List<String> _sensorIdsToDisplay = [
    'PHO01',
    'TEM01',
    'HUM01',
    'EC001',
    'DO001',
    'LUX01',
    'TEM02',
  ];

  final int _numberOfEmptyCards = 4;


  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    List<String> initialFarmIds = widget.farmId.split(',').map((e) => e.trim()).toList();
    _selectedLocation = _locations.firstWhere(
      (loc) => initialFarmIds.contains(loc),
      orElse: () => _locations.isNotEmpty ? _locations.first : '10',
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
      final url = Uri.parse(
          'http://192.168.1.2:3000/latest_sensor_data?farm_id=$farmId');

      print('Fetching latest data for farm $farmId from URL: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        dynamic decodedBody = json.decode(response.body);
        List<dynamic> dataList = [];

        if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('data') && decodedBody['data'] is List) {
          dataList = decodedBody['data'] as List;
        } else {
          print("Unexpected response format for latest data for location $farmId: $decodedBody");
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
          _allLatestData[farmId] = latestRecords;
          print('Successfully fetched and processed latest data for farm $farmId. Found ${latestRecords.length} latest sensor readings.');
        }

      } else {
        print("Failed to load latest data for location $farmId: ${response.statusCode} ${response.reasonPhrase ?? 'Unknown Error'}");
        if(mounted) {
          _allLatestData[farmId] = {};
        }
      }

    } catch (e) {
      print("Error fetching latest data for location $farmId: $e");
      if(mounted) {
        _allLatestData[farmId] = {};
      }
    }
  }

  void _navigateToDetail(BuildContext context, String farmId, String sensorId) {
    print('Navigating to HydroponicGraph for Farm $farmId, Sensor $sensorId (from Hydroponic)');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HydroponicGraph(
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
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.blueAccent),
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

  String _formatTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return "-";
    try {
      final dtUtc = DateTime.parse(ts).toUtc();
      final dtLocal = dtUtc.toLocal();
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(dtLocal);
    } catch (_) {
      print('Failed to parse timestamp for formatting: $ts');
      return ts ?? '-'; // Added ?? '-' for safety
    }
  }

  String _getFarmName(String farmId) {
    final farmNames = const { // Added const
      '10': 'Farm 10',
      '11': 'Farm 11',
    };
    return farmNames[farmId] ?? 'Farm $farmId';
  }

  void _updateErrorMessage() {
    if (_locations.isEmpty) {
      _errorMessage = "No locations defined for this view.";
    } else if (_allLatestData.isEmpty && !_isLoading) {
      _errorMessage = _errorMessage ?? "Could not retrieve data for any location. Check backend and network.";
    } else if (!_allLatestData.containsKey(_selectedLocation) && !_isLoading) {
      _errorMessage = "Data for Farm $_selectedLocation not loaded. Please check backend or try refreshing.";
    } else if ((_allLatestData[_selectedLocation] == null || _allLatestData[_selectedLocation]!.isEmpty) && !_isLoading) {
      _errorMessage = "No sensor data available for Farm $_selectedLocation.";
    } else {
      _errorMessage = null;
    }
  }

  String _getSensorTitle(String sensorId) {
    final sensorTitles = {
      'PHO01': 'pH',
      'TEM01': 'Water Temperature',
      'HUM01': 'Humidity',
      'EC001': 'EC',
      'DO001': 'Dissolved Oxygen',
      'LUX01': 'Light Intensity',
      'TEM02': 'Air Temperature',
    };
    return sensorTitles[sensorId] ?? sensorId;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final selectedLocationData = _allLatestData[_selectedLocation] ?? {};

    final List<Widget> sensorCards = _sensorIdsToDisplay.map((sensorId) {
      final sensorData = selectedLocationData[sensorId];
      return _buildSensorCard(
        _getSensorTitle(sensorId),
        sensorData?['value']?.toString() ?? '-',
        _formatTimestamp(sensorData?['timestamp']),
        sensorId,
        sensorData != null ? () => _navigateToDetail(context, _selectedLocation, sensorId)
             : () {
           print('No data available to show graph for $sensorId on Farm $_selectedLocation');
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('No historical data available for ${_getSensorTitle(sensorId)}.')),
           );
         },
      );
    }).toList();

    for (int i = 0; i < _numberOfEmptyCards; i++) {
      sensorCards.add(_buildEmptyCard());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydroponic'),
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
                // --- Call the new _buildLocationDropdown here ---
                _buildLocationDropdown(),
                // --- Remove the old conditional Padding block that was here ---


                if (_isLoading)
                  const Center(child: Padding(
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

                // Keep the GridView conditional on _isLoading and _errorMessage
                if (!_isLoading && _errorMessage == null && (_locations.isNotEmpty))
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 0.9,
                    children: sensorCards,
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- New _buildLocationDropdown function ---
  Widget _buildLocationDropdown() {
    // This condition determines if we should show the actual dropdown or just empty space
    if (_locations.length <= 1) {
      return Container(); // Returns an empty box if not enough locations
    }

    // Otherwise, build and return the styled dropdown
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Reverted padding back to vertical: 8.0
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Location:',
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
            onChanged: (String? newValue) {
              if (newValue != null && newValue != _selectedLocation) {
                setState(() {
                  _selectedLocation = newValue;
                  // Update _latestData for the newly selected location
                  _latestData = _allLatestData[_selectedLocation];
                  _updateErrorMessage(); // Update error state based on data availability
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