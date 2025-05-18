// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:intl/intl.dart'; // Import for date formatting

// // Import the new Parameter History Page
// // Ensure 'parameter_history_page.dart' is in the same directory (lib/pages)
// import 'parameter_history_page.dart';

// // Parameter List Page
// // Displays a list of latest readings for each parameter for a selected GNSS device.
// class GNSSDataPage extends StatefulWidget {
//   const GNSSDataPage({super.key});

//   @override
//   State<GNSSDataPage> createState() => _GNSSDataPageState();
// }

// class _GNSSDataPageState extends State<GNSSDataPage> {
//   // List to hold the latest data for each unique sensor_id (parameter) fetched from the backend
//   List<dynamic> fetchedParameters = [];
//   // List to hold the filtered parameters that will be displayed
//   List<dynamic> displayedParameters = [];

//   String selectedGnssId = 'GNSS1'; // Initialize with a default GNSS device ID
//   // List of available GNSS device IDs (assuming these are the values in the gnss_id column in your DB)
//   // Added GNSS2, GNSS3, etc., based on previous context, assuming they might exist.
//   final List<String> gnssList = ['GNSS1', 'GNSS2', 'GNSS3', 'GNSS4', 'GNSS5']; // Example list

//   bool isLoading = true; // State to manage loading indicator
//   String? errorMessage; // Added for user-facing error messages

//   // --- List of Sensor IDs to Display for GNSS (Based on your screenshot for GNSS1) ---
//   // You can customize this list to show only the sensors you want for GNSS.
//   // These should match the 'sensor_id' values in your 'gnss' database table.
//   final List<String> _gnssSensorIdsToDisplay = const [
//     'ALT01', // Altitude
//     'DAT01', // Data Quality?
//     'FXQ01', // Fix Quality?
//     'GSE01', // Ground Speed?
//     'HAD01', // Heading Angle?
//     'HD001', // Horizontal Dilution of Precision (HDOP)
//     'HUM01', // Humidity (If GNSS unit also measures this)
//     'LAD01', // Latitude Deviation?
//     'LAT01', // Latitude
//     'LOD01', // Lock Duration?
//     'LON01', // Longitude
//     'MVA01', // Magnetic Variation?
//     'MVR01', // Magnetic Variation Rate?
//     'PD001', // Positional Dilution of Precision (PDOP)
//     'SAT01', // Satellites visible?
//     'SCO01', // Satellite Count?
//     'SNR01', // Signal-to-Noise Ratio
//     'SPD01', // Speed
//     'TEM01', // Temperature (If GNSS unit also measures this)
//     'UTC01', // UTC Time
//     'VDO01', // Vertical Dilution of Precision (VDOP)
//     // Add or remove sensor IDs here as needed
//   ];
//   // --- End List of Sensor IDs to Display ---

//   // Number of additional empty cards to display (adjust as needed)
//   // Added for consistency with Hydroponic/Jamur pages
//   final int _numberOfEmptyCards = 4;

//   // Date formatter for displaying timestamps
//   final DateFormat dateTimeFormatter = DateFormat('dd-MM-yyyy HH:mm:ss');


//   @override
//   void initState() {
//     super.initState();
//     // Fetch initial data for the default selected GNSS ID when the page loads
//     fetchLatestParameters(selectedGnssId);
//   }

//   // Function to fetch the latest data for each parameter for a given GNSS device ID
//   Future<void> fetchLatestParameters(String gnssId) async {
//     setState(() {
//       isLoading = true; // Show loading indicator
//       fetchedParameters = []; // Clear previous fetched data
//       displayedParameters = []; // Clear previous displayed data
//       errorMessage = null; // Clear previous error message
//     });

//     try {
//       // Construct the URL to fetch the latest GNSS data for the selected GNSS device
//       // This uses the backend endpoint: GET /gnss/:gnss_id/latest
//       // IMPORTANT: Include the 'sensor=GNSS' query parameter as required by the backend.
//       var url = Uri.parse('http://10.0.2.2:3000/gnss/$gnssId/latest').replace(
//         queryParameters: {
//           'sensor': 'GNSS', // Add the required sensor query parameter
//         },
//       );

//       print('Fetching latest data from: $url'); // Log the URL being fetched

//       var response = await http.get(url);

//       if (!mounted) return; // Check if widget is still mounted after async operation

//       if (response.statusCode == 200) {
//         // Successful response (status code 200)
//         final responseBody = json.decode(response.body);

//         // Check the 'success' field from the backend response
//         if (responseBody['success'] == true) {
//            setState(() {
//              // Ensure 'data' is a list before assigning
//              if (responseBody['data'] is List) {
//                 fetchedParameters = responseBody['data']; // Store all fetched data
//                 // Filter the fetched data based on the _gnssSensorIdsToDisplay list
//                 displayedParameters = fetchedParameters.where((param) {
//                    // Check if sensor ID is in our display list using the 'name' field from the backend response
//                    return _gnssSensorIdsToDisplay.contains(param['name']);
//                 }).toList();
//              } else {
//                 // Handle unexpected data format
//                 print('Backend returned unexpected data format: ${responseBody['data']}');
//                 errorMessage = 'Received unexpected data format from server.';
//                 fetchedParameters = []; // Ensure data list is empty
//                 displayedParameters = [];
//              }
//              isLoading = false; // Hide loading indicator
//            });
//            print('Successfully fetched ${fetchedParameters.length} parameters. Displaying ${displayedParameters.length} parameters.');
//         } else {
//            // Handle backend reporting failure (success is false)
//            print('Backend reported failure: ${responseBody['error']}');
//            setState(() {
//              isLoading = false; // Hide loading indicator even on backend failure
//              errorMessage = responseBody['error'] ?? 'Failed to fetch data.'; // Display backend error message
//              fetchedParameters = []; // Ensure data list is empty
//              displayedParameters = [];
//            });
//         }

//       } else {
//         // Handle HTTP errors (status code not 200)
//         print('HTTP Error fetching latest data: ${response.statusCode}');
//         print('Response body: ${response.body}');
//          setState(() {
//            isLoading = false; // Hide loading indicator on HTTP error
//            errorMessage = 'Server returned status code ${response.statusCode}.'; // Display HTTP error status
//            fetchedParameters = []; // Ensure data list is empty
//            displayedParameters = [];
//          });
//          // Optionally throw an exception if you want to handle it higher up
//          // throw Exception('Failed to load latest GNSS data: ${response.statusCode}');
//       }
//     } catch (e) {
//       // Handle network or other errors during the fetch process
//       print('Error fetching latest GNSS data: $e');
//       setState(() {
//         isLoading = false; // Hide loading indicator on error
//         errorMessage = 'An error occurred: ${e.toString()}'; // Display generic error message
//         fetchedParameters = []; // Ensure data list is empty on error
//         displayedParameters = [];
//       });
//     }
//   }

//   // Handler for when the GNSS device ID dropdown value changes
//   void onGnssIdChanged(String? newValue) {
//     if (newValue != null && newValue != selectedGnssId) { // Check if the new value is different and not null
//         setState(() {
//             selectedGnssId = newValue; // Update the selected GNSS ID
//         });
//         // Fetch new data for the newly selected GNSS device ID
//         fetchLatestParameters(newValue);
//     }
//   }

//   // Helper function to format timestamp strings
//   String _formatTimestamp(String? ts) {
//     if (ts == null || ts.isEmpty || ts == 'N/A') return "-";
//     try {
//       // Attempt to parse the timestamp string (assuming ISO 8601 or similar).
//       // Convert to UTC first, then to the local time zone for display.
//       final dtUtc = DateTime.parse(ts).toUtc();
//       final dtLocal = dtUtc.toLocal();
//       // Format using the desired pattern
//       return dateTimeFormatter.format(dtLocal);
//     } catch (_) {
//       // If parsing fails, print an error and return the original string or a dash.
//       print('Failed to parse timestamp for formatting: $ts');
//       return ts; // Return original string or '-'
//     }
//   }

//   // Helper function to get a user-friendly title for a sensor ID in GNSS context
//   String _getSensorTitle(String sensorId) {
//     final sensorTitles = {
//       'ALT01': 'Altitude',
//       'DAT01': 'Data Quality',
//       'FXQ01': 'Fix Quality',
//       'GSE01': 'Ground Speed',
//       'HAD01': 'Heading Angle',
//       'HD001': 'HDOP', // Horizontal Dilution of Precision
//       'HUM01': 'Humidity',
//       'LAD01': 'Latitude Deviation',
//       'LAT01': 'Latitude',
//       'LOD01': 'Lock Duration',
//       'LON01': 'Longitude',
//       'MVA01': 'Magnetic Variation',
//       'MVR01': 'Magnetic Variation Rate',
//       'PD001': 'PDOP', // Positional Dilution of Precision
//       'SAT01': 'Satellites Visible',
//       'SCO01': 'Satellite Count',
//       'SNR01': 'Signal-to-Noise Ratio',
//       'SPD01': 'Speed',
//       'TEM01': 'Temperature',
//       'UTC01': 'UTC Time',
//       'VDO01': 'VDOP', // Vertical Dilution of Precision
//       // Add other sensor ID to title mappings here for GNSS
//     };
//     return sensorTitles[sensorId] ?? sensorId; // Return title if found, otherwise the ID itself
//   }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('GNSS'), // Updated title
//         centerTitle: true, // Center the title
//       ),
//       body: Column(
//         children: [
//           // GNSS ID Dropdown
//           Padding(
//             padding: const EdgeInsets.all(16.0), // Increased padding
//             child: DropdownButtonFormField<String>(
//               decoration: InputDecoration(
//                 labelText: 'Select GNSS Device',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(8.0), // Rounded corners
//                 ),
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 15.0), // Adjust padding
//               ),
//               value: selectedGnssId,
//               onChanged: onGnssIdChanged,
//               items: gnssList
//                   .map<DropdownMenuItem<String>>((String value) {
//                 return DropdownMenuItem<String>(
//                   value: value,
//                   child: Text(value),
//                 );
//               }).toList(),
//               isExpanded: true, // Make the dropdown take full width
//             ),
//           ),
//           // Parameter Grid
//           Expanded(
//             child: isLoading
//                 ? const Center(child: CircularProgressIndicator()) // Show loading indicator while fetching
//                 : errorMessage != null // Show error message if there is one
//                     ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)))
//                     // Show message if no data after loading and no error, or if fetched data didn't match display list
//                     : displayedParameters.isEmpty
//                         ? Center(child: Text('No data available for $selectedGnssId or no selected sensors found in data.', textAlign: TextAlign.center,)) // Updated message
//                         : GridView.builder(
//                             padding: const EdgeInsets.all(16), // Increased padding
//                             gridDelegate:
//                                 const SliverGridDelegateWithFixedCrossAxisCount(
//                               crossAxisCount: 2, // Display 2 cards per row
//                               childAspectRatio: 0.9, // Adjusted aspect ratio for consistency with Hydroponic
//                               crossAxisSpacing: 8.0, // Horizontal spacing between cards
//                               mainAxisSpacing: 8.0, // Vertical spacing between cards
//                             ),
//                             itemCount: displayedParameters.length + _numberOfEmptyCards, // Add empty cards
//                             itemBuilder: (context, index) {
//                               // If index is within the range of displayed data, build a sensor card
//                               if (index < displayedParameters.length) {
//                                 final param = displayedParameters[index]; // Use the filtered list
//                                 // Ensure 'name', 'value', and 'timestamp' keys exist before accessing
//                                 final parameterName = param['name'] ?? 'N/A';
//                                 final parameterValue = param['value']?.toString() ?? 'N/A'; // Convert value to string
//                                 final timestamp = param['timestamp']; // Get raw timestamp

//                                 return GestureDetector(
//                                   onTap: () {
//                                     // Navigate to the history page when a card is tapped
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) => ParameterHistoryPage(
//                                           gnssId: selectedGnssId, // Pass the selected GNSS ID
//                                           parameterName: parameterName, // Pass the parameter name (sensor_id)
//                                         ),
//                                       ),
//                                     );
//                                   },
//                                   child: Card(
//                                     elevation: 3, // Adjusted elevation for consistency
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(12.0), // Rounded corners
//                                     ),
//                                     child: Padding(
//                                       padding: const EdgeInsets.all(12.0), // Adjusted padding inside card
//                                       child: Column(
//                                         mainAxisAlignment: MainAxisAlignment.center,
//                                         crossAxisAlignment: CrossAxisAlignment.center, // Center content for consistency
//                                         children: [
//                                           Text(
//                                             _getSensorTitle(parameterName), // Use helper to get friendly title
//                                             style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                                               fontWeight: FontWeight.bold,
//                                             ),
//                                             textAlign: TextAlign.center, // Center text
//                                             maxLines: 2, // Allow title to span up to 2 lines.
//                                             overflow: TextOverflow.ellipsis, // Prevent text overflow
//                                           ),
//                                           const SizedBox(height: 8),
//                                           Text(
//                                             parameterValue, // Display the latest value
//                                             style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600), // Adjusted style
//                                             textAlign: TextAlign.center, // Center text
//                                           ),
//                                           const SizedBox(height: 8),
//                                           Text(
//                                             // Format the timestamp for display
//                                             _formatTimestamp(timestamp), // Display the timestamp
//                                             style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]), // Adjusted style
//                                             textAlign: TextAlign.center, // Center text
//                                           ),
//                                            const SizedBox(height: 4), // Spacing.
//                                            Text(
//                                               'ID: $parameterName', // Display the sensor ID.
//                                               style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                                                 color: Colors.grey[500], // Dim text if not tappable
//                                                 fontSize: 10,
//                                               ),
//                                               textAlign: TextAlign.center, // Center text
//                                             ),
//                                             const SizedBox(height: 8), // Space before button-like text.
//                                             Text(
//                                               'More Info',
//                                               style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.blueAccent), // Style as a link/button.
//                                             ),
//                                         ],
//                                       ),
//                                     ),
//                                   ),
//                                 );
//                               } else {
//                                 // If index is beyond the data range, build an empty card
//                                 return _buildEmptyCard();
//                               }
//                             },
//                           ),
//           ),
//         ],
//       ),
//     );
//   }

//   // _buildSensorCard widget (kept for consistency but not used directly in GridView.builder anymore)
//   // The logic is now integrated into the itemBuilder for better handling of empty cards.
//   Widget _buildSensorCard(String title, String value, String? timestamp, String sensorId, VoidCallback? onTap) {
//      // This function is conceptually replaced by the itemBuilder logic above.
//      // Keeping it here as a placeholder or if you prefer to refactor later.
//      throw UnimplementedError('This method is not used directly in the current implementation.');
//   }

//   // _buildEmptyCard widget (copied from Hydroponic/Jamur for consistency)
//   Widget _buildEmptyCard() {
//     return Card(
//       elevation: 3,
//       margin: const EdgeInsets.all(6),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       color: Colors.grey[850], // A darker grey for empty cards
//       child: const Padding(
//         padding: EdgeInsets.all(12),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             Icon(Icons.info_outline, size: 30, color: Colors.white54), // Placeholder icon
//             SizedBox(height: 8),
//             Text(
//               'No Data Available',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//                 color: Colors.white54, // Dim text
//               ),
//               textAlign: TextAlign.center,
//             ),
//             SizedBox(height: 4),
//             Text(
//               'Placeholder',
//               style: TextStyle(fontSize: 12, color: Colors.white38), // Smaller, dim text
//               textAlign: TextAlign.center,
//             ),
//             SizedBox(height: 8),
//             // No "More Info" text for empty cards
//           ],
//         ),
//       ),
//     );
//   }
// }
