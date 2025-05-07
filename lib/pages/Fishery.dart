import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// Import the separate FisheryGraph page for navigation
import 'graph/fishery_graph.dart';


// Represents the Fishery sector page, displaying latest sensor readings for selected farms.
class Fishery extends StatefulWidget {
  // Although 'date' is a required parameter from main.dart, it's not currently used in this page's logic.
  final DateTime date;
  // 'farmId' is passed from main.dart, potentially containing multiple IDs like '60, 61'.
  // This page handles multiple farms internally based on its own _locations list.
  final String farmId;

  const Fishery({Key? key, required this.date, required this.farmId}) : super(key: key);

  @override
  _FisheryState createState() => _FisheryState();
}

class _FisheryState extends State<Fishery> with AutomaticKeepAliveClientMixin {
  // Mixin to keep the state alive when navigating between tabs (like in MainMenu)

  // Stores the latest data map for the *currently selected* farm
  // Map structure: sensorId -> { 'sensor_id': '...', 'value': ..., 'timestamp': '...' }
  Map<String, Map<String, dynamic>>? _latestData;

  // Loading state for the initial data fetch operation
  bool _isLoading = true;

  // Message to display in case of errors during fetch or if no data is available
  String? _errorMessage;

  // List of farm IDs relevant to this Fishery page.
  // This list determines which farms are available in the dropdown and whose data is fetched.
  final List<String> _locations = ['60', '61'];

  // Stores the fetched latest data for *all* locations defined in _locations.
  // Map structure: farmId -> (Map: sensorId -> data item)
  final Map<String, Map<String, Map<String, dynamic>>> _allLatestData = {};

  // The farm ID currently selected in the dropdown.
  String _selectedLocation = '60'; // Default to the first farm (Farm 60)

  // List of sensor IDs expected to be displayed on the cards.
  // This list determines which cards are built and in what order.
  final List<String> _sensorIdsToDisplay = [
    'DO001', // Dissolved Oxygen
    'HUM01', // Air Humidity
    'TEM01', // Water Temperature
    'TEM02', // Air Temperature
    'RSS01', // pH (Assuming RSS01 is pH)
    'TDS01', // TDS
    // Add other sensor IDs here as needed for the cards
  ];

  // Number of additional empty cards to display (adjust as needed)
  final int _numberOfEmptyCards = 4;


  @override
  bool get wantKeepAlive => true; // Keep this page's state when not active


  @override
  void initState() {
    super.initState();
    // Determine the initially selected location based on the 'farmId' passed to the widget,
    // ensuring it's one of the valid _locations.
    List<String> initialFarmIds = widget.farmId.split(',').map((e) => e.trim()).toList();
    _selectedLocation = _locations.firstWhere(
      (loc) => initialFarmIds.contains(loc),
      // If none of the passed farmIds are in _locations, or _locations is empty, default to the first location or '60'.
      orElse: () => _locations.isNotEmpty ? _locations.first : '60',
    );

    // Start fetching data for all predefined locations when the page initializes.
    if (_locations.isEmpty) {
      _isLoading = false;
      _errorMessage = "No locations defined for this view.";
    } else {
      _fetchInitialData();
    }
  }

  @override
  void dispose() {
    // Clean up resources here if necessary, although typically not needed for simple HTTP fetches.
    super.dispose();
  }


  // Fetches data for all predefined locations concurrently.
  // Calls the function to fetch the latest data for each location.
  Future<void> _fetchInitialData() async {
    if (!mounted) return; // Prevent setState calls after widget is disposed
    setState(() {
      _isLoading = true; // Set loading state
      _errorMessage = null; // Clear previous errors
      _allLatestData.clear(); // Clear previous data before fetching
    });

    // Create a list of futures, one for fetching data for each location.
    List<Future<void>> fetchFutures = [];
    for (final location in _locations) {
      fetchFutures.add(_fetchLatestSensorData(location));
    }

    try {
      // Wait for all fetch operations to complete.
      await Future.wait(fetchFutures);
    } catch (e) {
      // Catch potential errors that occur during the concurrent fetching process.
      if (mounted) {
        setState(() {
          _errorMessage = "Error fetching initial data: ${e.toString()}";
        });
      }
    }

    if (mounted) { // Check mounted state again before calling setState
      setState(() {
        // After all fetches are done, update the displayed data (_latestData)
        // to show the data fetched for the currently _selectedLocation.
        _latestData = _allLatestData.containsKey(_selectedLocation) ? _allLatestData[_selectedLocation] : null;

        _isLoading = false; // Stop the main loading indicator.

        // Update the error message based on the overall fetch results and the selected location's data.
        _updateErrorMessage();
      });
    }
  }


  // Fetches the latest sensor data for a single farm ID using the dedicated backend endpoint.
  // Stores the result in the _allLatestData map.
  Future<void> _fetchLatestSensorData(String farmId) async {
    if (!mounted) return; // Ensure widget is still mounted

    try {
      // Construct the URL to call the new backend endpoint for latest data.
      final url = Uri.parse(
          'http://10.0.2.2:3000/latest_sensor_data?farm_id=$farmId');

      print('Fetching latest data for farm $farmId from URL: $url');

      // Send the HTTP GET request with a timeout.
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (!mounted) return; // Check mounted again after async operation

      if (response.statusCode == 200) {
        dynamic decodedBody = json.decode(response.body);
        List<dynamic> dataList = [];

        // Expecting a JSON structure like {"success": true, "data": [...] }.
        if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('data') && decodedBody['data'] is List) {
          dataList = decodedBody['data'] as List;
        } else {
          // Log if the response format is unexpected.
          print("Unexpected response format for latest data for location $farmId: $decodedBody");
          // Store an empty map for this farm's latest data to indicate fetch failed or data was malformed.
          if (mounted) _allLatestData[farmId] = {};
          return; // Exit the function for this farm's fetch.
        }

        Map<String, Map<String, dynamic>> latestRecords = {};
        // Process the list of data items received from the backend.
        // The backend endpoint should return the latest record per sensor.
        for (var item in dataList) {
          // Basic validation for each item in the data list.
          if (item is! Map<String, dynamic> || item['sensor_id'] == null || item['timestamp'] == null || item['value'] == null) {
            print("Skipping invalid data item for farm $farmId: $item");
            continue; // Skip this invalid item.
          }
          String sensorId = item['sensor_id'] as String;

          // Store the entire data item using sensorId as the key in the latestRecords map for this farm.
          latestRecords[sensorId] = item;
        }

        if (mounted) { // Check mounted before setState in case processing took time
          // Store the fetched latest records for this farmId in the main _allLatestData map.
          _allLatestData[farmId] = latestRecords;
          // Updated log message to reflect fetching latest data
          print('Successfully fetched and processed latest data for farm $farmId. Found ${latestRecords.length} latest sensor readings.');
        }

      } else {
        // Log the failure with status code and reason message.
        print("Failed to load latest data for location $farmId: ${response.statusCode} ${response.reasonPhrase ?? 'Unknown Error'}");
        // Store an empty map for this farm's latest data on HTTP error.
        if (mounted) {
          _allLatestData[farmId] = {};
        }
      }

    } catch (e) {
      // Log any errors that occur during the HTTP request or initial processing.
      print("Error fetching latest data for location $farmId: $e");
      // Store an empty map for this farm's latest data on fetch error.
      if (mounted) {
        _allLatestData[farmId] = {};
      }
    }
  }


  // Helper function to format timestamp strings consistently.
  String _formatTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return "-";
    try {
      // Attempt to parse the timestamp string (assuming ISO 8601 or similar).
      // Convert to UTC first, then to the local time zone for display.
      final dtUtc = DateTime.parse(ts).toUtc();
      final dtLocal = dtUtc.toLocal();
      // Format using the desired pattern: Day-Month-Year Hour:Minute:Second
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(dtLocal);
    } catch (_) {
      // If parsing fails, print an error and return the original string or a dash.
      print('Failed to parse timestamp for formatting: $ts');
      return ts ?? '-'; // Return original string or '-'
    }
  }


  // Helper function to get a user-friendly name for a location/farm ID
  String _getFarmName(String farmId) {
    // Define a map of farm IDs to user-friendly names.
    final farmNames = {
      '60': 'Farm 60',
      '61': 'Farm 61',
      // Add other farm IDs here as needed.
    };
    // Return the friendly name if found, otherwise return a default name with the ID.
    return farmNames[farmId] ?? 'Farm $farmId';
  }


  // Helper function to update the error message based on the current state of fetched data.
  void _updateErrorMessage() {
    if (_locations.isEmpty) {
      _errorMessage = "No locations defined for this view.";
    } else if (_allLatestData.isEmpty && !_isLoading) { // Check _isLoading to avoid showing this message during initial load
      _errorMessage = _errorMessage ?? "Could not retrieve data for any location. Check backend and network."; // Use existing error or a general one
    } else if (!_allLatestData.containsKey(_selectedLocation) && !_isLoading) {
      // This scenario might happen if fetching for the selected location failed individually.
      _errorMessage = "Data for Farm $_selectedLocation not loaded. Please check backend or try refreshing.";
    } else if ((_allLatestData[_selectedLocation] == null || _allLatestData[_selectedLocation]!.isEmpty) && !_isLoading) {
      // This means fetching for the selected location succeeded, but returned no data.
      _errorMessage = "No sensor data available for Farm $_selectedLocation.";
    } else {
      _errorMessage = null; // Clear error message if data is successfully loaded for the selected location.
    }
  }


  @override
  Widget build(BuildContext context) {
    // Get the latest data for the currently selected location.
    // Use a default empty map if the selected location's data is not yet fetched or is null/empty.
    final selectedLocationData = _allLatestData[_selectedLocation] ?? {};

    // Combine the list of sensor IDs to display and placeholders for empty cards.
    // Create a list of widgets to pass to GridView.count.
    final List<Widget> sensorCards = _sensorIdsToDisplay.map((sensorId) {
      // Get the data for the current sensor ID from the fetched data.
      final sensorData = selectedLocationData[sensorId];
      // Build the sensor card, passing the specific data found (or null if not found).
      return _buildSensorCard(
        _getSensorTitle(sensorId), // Get user-friendly title for the sensor ID
        sensorData?['value']?.toString() ?? '-', // Get value or '-'
        _formatTimestamp(sensorData?['timestamp']), // Get formatted timestamp or '-'
        sensorId, // Pass the sensor ID
        // Define the onTap action: navigate to the graph page if data is available for this sensor
        sensorData != null ? () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FisheryGraph(
              farmId: _selectedLocation, // Pass the currently selected farm ID
              sensorId: sensorId, // Pass the specific sensor ID for the graph
            ),
          ),
        ) : () {
          // Optional: Show a message or do nothing if data is not available for this sensor
          print('No data available to show graph for $sensorId on Farm $_selectedLocation');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No historical data available for ${_getSensorTitle(sensorId)}.')),
          );
        },
      );
    }).toList(); // Convert the mapped iterable to a list of widgets.

    // Add the specified number of empty cards to the list.
    for (int i = 0; i < _numberOfEmptyCards; i++) {
      sensorCards.add(_buildEmptyCard()); // Add an empty card widget
    }


    return Scaffold(
      appBar: AppBar(
        // Updated title to be static as the farm name is now in the body
        title: const Text('Fishery'),
        centerTitle: true, // Center the title
        // Removed the actions list containing the dropdown
        // actions: [ ... ]
      ),
      // Wrap the body content in a RefreshIndicator and SingleChildScrollView.
      body: RefreshIndicator( // Allows users to pull down to refresh the data.
        onRefresh: _fetchInitialData, // The function called when the user pulls down.
        child: SingleChildScrollView( // Makes the content scrollable if it overflows.
          physics: const AlwaysScrollableScrollPhysics(), // Ensures scrolling is possible even if content fits the screen.
          child: Padding(
            padding: const EdgeInsets.all(8.0), // Padding around the main column content.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally.
              children: [
                // --- Location dropdown added here ---
                // Only show the dropdown if there are locations defined and more than one option.
                if (!_isLoading && _locations.isNotEmpty && _locations.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // Add some padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Align label to the start
                      children: [
                        Text(
                          'Select Location:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70), // Style for the label
                        ),
                        const SizedBox(height: 4), // Small space between label and dropdown
                        DropdownButtonFormField<String>(
                          // Use DropdownButtonFormField for better styling and integration in forms
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8), // Rounded corners for the dropdown
                              borderSide: BorderSide.none, // No border line
                            ),
                            filled: true,
                            fillColor: const Color.fromARGB(255, 114, 114, 114), // Background color of the dropdown field
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Padding inside the field
                          ),
                          // Set the value to the selected location, or the first location if the selected one is invalid/null.
                          value: _locations.contains(_selectedLocation) ? _selectedLocation : (_locations.isNotEmpty ? _locations.first : null),
                          icon: const Icon(Icons.arrow_downward, color: Colors.white),
                          elevation: 16,
                          style: const TextStyle(color: Colors.white, fontSize: 16), // Slightly smaller text in dropdown
                          // Removed dropdownColor: Colors.transparent to make it visible
                          onChanged: (String? newValue) {
                            if (newValue != null && newValue != _selectedLocation) {
                              setState(() {
                                _selectedLocation = newValue;
                                // Update the displayed data to the newly selected location's data.
                                _latestData = _allLatestData[_selectedLocation];
                                _updateErrorMessage(); // Update error message based on new selection.
                              });
                            }
                          },
                          items: _locations.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(_getFarmName(value)), // Display friendly farm name
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                // --- End Location dropdown ---

                // Show a loading indicator if _isLoading is true.
                if (_isLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20.0), // Add padding around indicator
                    child: CircularProgressIndicator(),
                  )),

                // Show the error message if _errorMessage is set and not currently loading.
                if (_errorMessage != null && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _errorMessage!, // Display the error message.
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Show the GridView of sensor cards if not loading and no error, and data is available for the selected location.
                // Or show the grid with empty cards if locations are defined but no data is loaded yet or available.
                if (!_isLoading && _errorMessage == null && (_locations.isNotEmpty))
                  GridView.count(
                    shrinkWrap: true, // Makes the GridView take minimum space needed.
                    physics: const NeverScrollableScrollPhysics(), // Prevents the GridView from having its own scroll behavior inside SingleChildScrollView.
                    crossAxisCount: 2, // Displays cards in a 2-column grid.
                    crossAxisSpacing: 8.0, // Horizontal spacing between cards.
                    mainAxisSpacing: 8.0, // Vertical spacing between cards.
                    childAspectRatio: 0.9, // Controls the width to height ratio of the cards.
                    // Use the combined list of sensorCards (real data cards + empty placeholders)
                    children: sensorCards,
                  )
                // Removed the redundant check for empty selectedLocationData here,
                // as the empty cards are now always added if locations exist and not loading/error.
                // The message for no data for the selected location is handled by _updateErrorMessage.

              ],
            ),
          ),
        ),
      ),
    );
  }


  // _buildSensorCard widget to display sensor information in a card format.
  // It is also tappable to navigate to the graph page for that sensor.
  Widget _buildSensorCard(
      String title, // Title of the sensor (e.g., "Dissolved Oxygen")
      String value, // The latest sensor reading value (formatted as a string)
      String? timestamp, // The timestamp of the latest reading (formatted string or null)
      String sensorId, // The unique ID of the sensor (e.g., "DO001")
      VoidCallback? onTap // The function to call when the card is tapped (for navigation), can be null
      ) {
    // Use InkWell for tap detection and ripple effect. onTap is now nullable.
    return InkWell(
      onTap: onTap, // Assign the provided onTap function (can be null).
      // Use a slightly different color or style if the card is not tappable (onTap is null)
      // This is a simple visual cue that there's no data to show a graph for.
      child: Card(
        elevation: 3, // Card shadow.
        margin: const EdgeInsets.all(6), // Margin around the card.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Rounded corners for the card.
        // Set background color based on whether the card is tappable (has data)
        color: onTap != null ? Theme.of(context).cardColor : Colors.grey[800], // Darker grey for non-tappable
        child: Padding(
          padding: const EdgeInsets.all(12), // Padding inside the card.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center content vertically.
            crossAxisAlignment: CrossAxisAlignment.center, // Center content horizontally.
            children: [
              Text(
                title, // Display the sensor title.
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: onTap != null ? null : Colors.white54, // Dim text if not tappable
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // Allow title to span up to 2 lines.
                overflow: TextOverflow.ellipsis, // Add ellipsis if title overflows.
              ),
              const SizedBox(height: 8), // Spacing.
              Text(
                value, // Display the sensor value.
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onTap != null ? null : Colors.white54, // Dim text if not tappable
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8), // Spacing.
              // --- This displays the timestamp ---
              Text(
                timestamp ?? '-', // Display timestamp or '-' if null.
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: onTap != null ? Colors.grey[600] : Colors.white38, // Dim text if not tappable
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4), // Spacing.
              // --- Display Sensor ID below the timestamp (Optional, but can help identify) ---
              Text(
                'ID: $sensorId', // Display the sensor ID.
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: onTap != null ? Colors.grey[500] : Colors.white30, // Dim text if not tappable
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8), // Space before button-like text.
              // --- More Info Text (looks like a button due to styling and InkWell parent) ---
              // Only show "More Info" if the card is tappable (has data)
              if (onTap != null)
                Text(
                  'More Info',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.blueAccent), // Style as a link/button.
                ),
            ],
          ),
        ),
      ),
    );
  }

  // _buildEmptyCard widget to display a placeholder card.
  Widget _buildEmptyCard() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[850], // A darker grey for empty cards
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 30, color: Colors.white54), // Placeholder icon
            SizedBox(height: 8),
            Text(
              'No Data Available',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white54, // Dim text
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              'Placeholder',
              style: TextStyle(fontSize: 12, color: Colors.white38), // Smaller, dim text
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            // No "More Info" text for empty cards
          ],
        ),
      ),
    );
  }

  // Helper function to get a user-friendly title for a sensor ID
  String _getSensorTitle(String sensorId) {
    final sensorTitles = {
      'DO001': 'Dissolved Oxygen',
      'HUM01': 'Air Humidity',
      'TEM01': 'Water Temperature',
      'TEM02': 'Air Temperature',
      'RSS01': 'pH',
      'TDS001': 'TDS',
      // Add other sensor ID to title mappings here
    };
    return sensorTitles[sensorId] ?? sensorId; // Return title if found, otherwise the ID itself
  }
}
