import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // Import for date and time formatting

// Parameter History Page
// Displays historical data for a specific parameter (sensor_id) for a given GNSS device.
class ParameterHistoryPage extends StatefulWidget {
  final String gnssId; // The selected GNSS device ID
  final String parameterName; // The selected parameter name (sensor_id, e.g., 'ALT02')

  const ParameterHistoryPage({
    super.key,
    required this.gnssId,
    required this.parameterName,
  });

  @override
  State<ParameterHistoryPage> createState() => _ParameterHistoryPageState();
}

class _ParameterHistoryPageState extends State<ParameterHistoryPage> {
  List<dynamic> historyData = [];
  bool isLoading = true;
  String? errorMessage; // Added for user-facing error messages

  // Default date range: last 7 days from today
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  // Set end date to the end of today to include data up to the current time
  DateTime endDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);


  // Date formatter for displaying dates
  final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
  // DateTime formatter for displaying timestamps
  final DateFormat dateTimeFormatter = DateFormat('dd-MM-yyyy HH:mm:ss');


  @override
  void initState() {
    super.initState();
    // Fetch historical data when the page initializes
    fetchHistoricalData();
  }

  // Function to fetch historical data for the selected parameter and date range
  Future<void> fetchHistoricalData() async {
    setState(() {
      isLoading = true; // Show loading indicator
      historyData = []; // Clear previous data
      errorMessage = null; // Clear previous error message
    });

    try {
      // Construct the URL to fetch historical data
      // Uses the backend endpoint: GET /gnss/:gnss_id/parameter/:parameter
      // Requires 'start', 'end', AND 'sensor' query parameters.
      var url = Uri.parse('http://10.0.2.2:3000/gnss/${widget.gnssId}/parameter/${widget.parameterName}')
          .replace(queryParameters: {
        'start': startDate.toIso8601String(), // Pass start date in ISO 8601 format
        'end': endDate.toIso8601String(),     // Pass end date in ISO 8601 format
        'sensor': 'GNSS', // Added the required 'sensor' query parameter
      });

      print('Fetching historical data from: $url'); // Log the URL being fetched

      var response = await http.get(url);

      if (!mounted) return; // Check if widget is still mounted after async operation

      if (response.statusCode == 200) {
        // Successful response (status code 200)
        final responseBody = json.decode(response.body);

        // Check the 'success' field from the backend response
        if (responseBody['success'] == true) {
            setState(() {
              // Ensure 'data' is a list before assigning
              if (responseBody['data'] is List) {
                 historyData = responseBody['data']; // Update the list with fetched data
              } else {
                 // Handle unexpected data format
                 print('Backend returned unexpected data format: ${responseBody['data']}');
                 errorMessage = 'Received unexpected data format from server.';
                 historyData = []; // Ensure data list is empty
              }
              isLoading = false; // Hide loading indicator
            });
            print('Successfully fetched ${historyData.length} historical data points.');
        } else {
           // Handle backend reporting failure (success is false)
           print('Backend reported failure: ${responseBody['error']}');
           setState(() {
             isLoading = false; // Hide loading indicator even on backend failure
             errorMessage = responseBody['error'] ?? 'Failed to fetch data.'; // Display backend error message
             historyData = []; // Ensure data list is empty
           });
        }
      } else {
        // Handle HTTP errors (status code not 200)
        print('HTTP Error fetching historical data: ${response.statusCode}');
        print('Response body: ${response.body}');
         setState(() {
           isLoading = false; // Hide loading indicator on HTTP error
           errorMessage = 'Server returned status code ${response.statusCode}.'; // Display HTTP error status
           historyData = []; // Ensure data list is empty
         });
         // Optionally throw an exception if you want to handle it higher up
         // throw Exception('Failed to load historical data: ${response.statusCode}');
      }
    } catch (e) {
      // Handle network or other errors during the fetch process
      print('Error fetching historical data: $e');
      setState(() {
        isLoading = false; // Hide loading indicator on error
        errorMessage = 'An error occurred: ${e.toString()}'; // Display generic error message
        historyData = []; // Ensure data list is empty on error
      });
    }
  }

  // Function to show date picker and update start/end dates
  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000), // Allow selecting dates back to a reasonable year
      lastDate: DateTime.now(), // Cannot select future dates
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      helpText: 'Select Date Range', // Text on the date picker dialog
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith( // Customize the date picker theme
            primaryColor: Theme.of(context).primaryColor, // Use app's primary color
            colorScheme: ColorScheme.light(primary: Theme.of(context).primaryColor),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    // If a date range was picked and it's different from the current one
    if (picked != null && (picked.start != startDate || picked.end != endDate)) {
      setState(() {
        startDate = picked.start;
        // Set end date to the end of the selected day to include data up to the last moment
        endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      fetchHistoricalData(); // Fetch data for the new date range
    }
  }

   // Helper function to format timestamp strings
  String _formatTimestamp(String? ts) {
    if (ts == null || ts.isEmpty || ts == 'N/A') return "-";
    try {
      // Attempt to parse the timestamp string (assuming ISO 8601 or similar).
      // Convert to UTC first, then to the local time zone for display.
      final dtUtc = DateTime.parse(ts).toUtc();
      final dtLocal = dtUtc.toLocal();
      // Format using the desired pattern
      return dateTimeFormatter.format(dtLocal);
    } catch (_) {
      // If parsing fails, print an error and return the original string or a dash.
      print('Failed to parse timestamp for formatting: $ts');
      return ts; // Return original string or '-'
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.parameterName} History'), // Title shows parameter name
        centerTitle: true, // Center the title
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
        children: [
          // Date Range Picker Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Date Range:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'From: ${dateFormatter.format(startDate.toLocal())}', // Display formatted start date
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'To: ${dateFormatter.format(endDate.toLocal())}',     // Display formatted end date
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center( // Center the button
                  child: ElevatedButton(
                    onPressed: () => _selectDateRange(context), // Open date picker on tap
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0), // Rounded button corners
                      ),
                    ),
                    child: const Text('Change Date Range'),
                  ),
                ),
              ],
            ),
          ),
          // Historical Data List/Chart Area
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                : errorMessage != null // Show error message if there is one
                    ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)))
                    : historyData.isEmpty // Show message if no data after loading and no error
                        ? const Center(child: Text('No historical data available for the selected period.'))
                        : ListView.builder( // Display data in a list for now
                            padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add horizontal padding
                            itemCount: historyData.length,
                            itemBuilder: (context, index) {
                              final dataPoint = historyData[index];
                              // Ensure keys exist and handle potential nulls
                              final value = dataPoint['value']?.toString() ?? 'N/A';
                              final timestamp = dataPoint['timestamp']; // Get raw timestamp

                              return Card( // Use Card for each list item
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4.0), // Add vertical margin
                                child: ListTile(
                                  title: Text('Value: $value'),
                                  // Format the timestamp for display
                                  subtitle: Text('Timestamp: ${_formatTimestamp(timestamp)}'),
                                ),
                              );
                            },
                          ),
          ),
          // TODO: Replace ListView with a Chart Widget (e.g., using fl_chart or syncfusion_flutter_charts) for better visualization
        ],
      ),
    );
  }
}
