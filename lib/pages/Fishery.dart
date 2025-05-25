import 'dart:async' show StreamSubscription, TimeoutException;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:typed_data/src/typed_buffer.dart';
import 'dart:convert';
import 'graph/fishery_graph.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';

class Fishery extends StatefulWidget {
  final DateTime date;
  final String farmId;

  const Fishery({Key? key, required this.date, required this.farmId})
      : super(key: key);

  @override
  _FisheryState createState() => _FisheryState();
}

class _FisheryState extends State<Fishery>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  final List<String> _locations = ['60', '61'];
  final Map<String, Map<String, Map<String, dynamic>>> _allLatestData = {};
  String _selectedLocation = '60';
  final List<String> _sensorIdsToDisplay = [
    'DO001',
    'HUM01',
    'TEM01',
    'TEM02',
    'RSS01',
    'TDS01',
  ];
  final int _numberOfEmptyCards = 4;

  late TabController _tabController;

  // MQTT Configuration
  final String mqttBrokerHost = 'broker.emqx.io';
  final int mqttBrokerPort = 1883;
  final String baseMqttClientId = 'mqttx_2875518f';
  final String setpointMqttTopic = 'topic/06/flutterapp';
  // *** ADD YOUR SENSOR DATA TOPIC(S) HERE ***
  final List<String> subscriptionTopics = [
    'topic/06/flutterapp', // Keep the command topic if needed
  ];

  MqttServerClient? client;
  MqttConnectionState mqttConnectionState = MqttConnectionState.disconnected;
  String _lastMqttMessage = 'No MQTT messages received.';


  final TextEditingController _minHumController = TextEditingController();
  final TextEditingController _maxHumController = TextEditingController();
  final TextEditingController _minTempController = TextEditingController();
  final TextEditingController _maxTempController = TextEditingController();

  String _commandStatus = '';
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _mqttSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    List<String> initialFarmIds =
        widget.farmId.split(',').map((e) => e.trim()).toList();
    _selectedLocation = _locations.firstWhere(
      (loc) => initialFarmIds.contains(loc),
      orElse: () => _locations.isNotEmpty ? _locations.first : '60',
    );

    if (_locations.isEmpty) {
      _isLoading = false;
      _errorMessage = "No locations defined for this view.";
    } else {
      _fetchInitialData();
    }

    _connectMqtt();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _minHumController.dispose();
    _maxHumController.dispose();
    _minTempController.dispose();
    _maxTempController.dispose();
    _mqttSubscription?.cancel();
    _disconnectMqtt();
    super.dispose();
  }

  Future<void> _connectMqtt() async {
    if (mqttConnectionState == MqttConnectionState.connecting ||
        mqttConnectionState == MqttConnectionState.connected) {
      return;
    }

    if (mounted) {
      setState(() {
        mqttConnectionState = MqttConnectionState.connecting;
        _commandStatus = 'Connecting to MQTT broker...';
        _lastMqttMessage = 'No MQTT messages received yet.';
      });
    }

    try {
      client = MqttServerClient(mqttBrokerHost, '${baseMqttClientId}_${DateTime.now().millisecondsSinceEpoch}');
      client!.port = mqttBrokerPort;
      client!.logging(on: false);
      client!.keepAlivePeriod = 60;
      client!.onDisconnected = _onDisconnected;
      client!.onConnected = _onConnected;
      client!.onSubscribed = _onSubscribed;
      client!.pongCallback = _onPong;
      client!.autoReconnect = true;
      client!.resubscribeOnAutoReconnect = true;

      final connMess = MqttConnectMessage()
          .withClientIdentifier(client!.clientIdentifier)
          .withWillQos(MqttQos.atLeastOnce)
          .startClean()
          .withWillTopic('willtopic') // Consider if you need a Last Will Topic
          .withWillMessage('Client disconnected unexpectedly') // Last Will Message
          .withWillRetain(); // Last Will Retain

      // If your broker supports MQTT 5 and you want to use it explicitly, uncomment the line below.
      // Make sure you have cleared build caches and re-run pub get if you uncomment this.
      // .withMqttVersion(MqttForSupportedProtocols.mqtt5);


      client!.connectionMessage = connMess;

      await client!.connect().timeout(const Duration(seconds: 15));

      if (client!.connectionStatus?.state == MqttConnectionState.connected) {
        print('MQTT client connected successfully');
        if (mounted) {
          setState(() {
            mqttConnectionState = MqttConnectionState.connected;
            _commandStatus = 'Connected to MQTT broker. Ready to send commands.';
          });
        }
         _subscribeToTopics(); // Subscribe AFTER successful connection
      } else {
        print('MQTT connection failed with state: ${client!.connectionStatus?.state}');
        if (mounted) {
          setState(() {
            mqttConnectionState = client!.connectionStatus?.state ?? MqttConnectionState.faulted;
            _commandStatus = 'Connection failed: ${client!.connectionStatus?.state}.';
          });
        }
        _disconnectMqtt();
      }
    } on TimeoutException {
      print('MQTT connection timed out');
      if (mounted) {
        setState(() {
          mqttConnectionState = MqttConnectionState.faulted;
          _commandStatus = 'Connection timed out. Please check broker address/port or network.';
        });
      }
      _disconnectMqtt();
    } on SocketException catch (e) {
      print('MQTT SocketException: $e');
      if (mounted) {
        setState(() {
          mqttConnectionState = MqttConnectionState.faulted;
          _commandStatus = 'Network error: ${e.message}. Check your connection.';
        });
      }
    } on Exception catch (e) {
      print('MQTT connection error: $e');
      if (mounted) {
        setState(() {
          mqttConnectionState = MqttConnectionState.faulted;
          _commandStatus = 'Connection error: ${e.toString()}';
        });
      }
      _disconnectMqtt();
    }
  }

   void _subscribeToTopics() {
    if (client?.connectionStatus?.state != MqttConnectionState.connected) {
      print('Cannot subscribe - client not connected');
      return;
    }

    if (subscriptionTopics.isEmpty) {
      print('No subscription topics defined.');
      return;
    }

    print('Subscribing to topics: ${subscriptionTopics.join(', ')}');

    try {
      for (final topic in subscriptionTopics) {
        client!.subscribe(topic, MqttQos.atLeastOnce);
      }
       _setupMessageHandling(); // Setup message handling AFTER successful subscription
    } catch (e) {
      print('Error subscribing to topics: $e');
      if (mounted) {
        setState(() {
          _commandStatus = 'Subscription error: ${e.toString()}';
        });
      }
    }
  }


  void _setupMessageHandling() {
    if (client == null || client!.updates == null) {
      print('MQTT client or updates stream is null');
      return;
    }

    // Cancel previous subscription to avoid multiple listeners if reconnecting
    _mqttSubscription?.cancel();

    _mqttSubscription = client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final receivedMsg = message.payload;
        final topic = message.topic;

        if (receivedMsg is! MqttPublishMessage) {
          print('Received non-publish message on topic: $topic');
          continue;
        }

        final MqttPublishMessage recMess = receivedMsg;
        // Corrected payload extraction
        final String payloadStr = MqttPublishPayload.bytesToStringAsString(recMess.payload as Uint8Buffer);


        print('Received message on topic: $topic with payload: $payloadStr');

        if (mounted) {
          setState(() {
            _lastMqttMessage = 'Topic: $topic\nPayload: $payloadStr';
          });
        }

        // *** Process messages based on topic and intended use (threshold table / UI update) ***

        if (topic == setpointMqttTopic) {
          // Handle messages received on the command topic (if needed, e.g., confirmation)
          print('Received message on command topic.');
           try {
            final jsonData = jsonDecode(payloadStr);
             if (jsonData is Map) {
               // Optionally update control fields if the broker echoes values
              if (jsonData.containsKey('min_humidity')) {
                _minHumController.text = jsonData['min_humidity'].toString();
              }
              if (jsonData.containsKey('max_humidity')) {
                _maxHumController.text = jsonData['max_humidity'].toString();
              }
              if (jsonData.containsKey('min_temperature')) {
                _minTempController.text = jsonData['min_temperature'].toString();
              }
              if (jsonData.containsKey('max_temperature')) {
                _maxTempController.text = jsonData['max_temperature'].toString();
              }
            }
          } catch (e) {
             print('Error parsing command confirmation message: $e');
          }

        }
        // You'll need to adjust this condition based on the actual topic(s) your sensors publish to
        // This condition attempts to match topics that might contain sensor data
        // Example: 'farm/60/sensor_data', 'farm/61/sensor_data', 'sensor/tem01/data', etc.
        // You might need more specific checks depending on your topic structure.
        else if (subscriptionTopics.any((t) => topic.startsWith(t.replaceAll('#', '').replaceAll('+', '')) && topic != setpointMqttTopic)) {
           print('Attempting to process sensor data message.');
          try {
            final jsonData = jsonDecode(payloadStr);

            // *** Validate and Extract Sensor Data relevant for threshold table and UI ***
            // Assuming the payload contains farm_id, sensor_id, value, and optionally timestamp
            if (jsonData is Map &&
                jsonData.containsKey('farm_id') &&
                jsonData.containsKey('sensor_id') &&
                jsonData.containsKey('value')) {

              final String farmId = jsonData['farm_id'].toString();
              final String sensorId = jsonData['sensor_id'].toString();
              final double? value = double.tryParse(jsonData['value'].toString());
              final String? timestamp = jsonData.containsKey('timestamp') ? jsonData['timestamp'].toString() : null; // Get timestamp if available


              if (value != null) { // Process if value is valid

                // Check if this sensor/farm combination needs to update the threshold table
                 if ( (sensorId == 'TEM01' || sensorId == 'HUM01') ) { // Only send TEM01 and HUM01 to threshold endpoint
                    print('Parsed Sensor Data for Threshold: Farm ID: $farmId, Sensor ID: $sensorId, Value: $value');
                    // *** Call function to send data to the threshold table endpoint ***
                    _sendSensorDataToThresholdTable(farmId, sensorId, value);
                 } else {
                    print('Received sensor data for non-TEM01/HUM01 sensor ($sensorId). Not sending to threshold.');
                 }


                 // Update UI data structure for all relevant sensors on the selected farm
                 if(mounted && _selectedLocation == farmId && _sensorIdsToDisplay.contains(sensorId)) {
                    setState(() {
                       _allLatestData.update(farmId, (currentData) {
                           // Keep the timestamp from the MQTT message if available, or generate one
                           currentData[sensorId] = {
                               'farm_id': farmId,
                               'sensor_id': sensorId,
                               'timestamp': timestamp ?? DateTime.now().toIso8601String(), // Store timestamp in UI data
                               'value': value
                           };
                           return currentData;
                       }, ifAbsent: () => {
                           sensorId: {
                               'farm_id': farmId,
                               'sensor_id': sensorId,
                               'timestamp': timestamp ?? DateTime.now().toIso8601String(), // Store timestamp in UI data
                               'value': value
                           }
                       });
                       _updateErrorMessage(); // Recalculate error message based on new data
                    });
                 }

              } else {
                 print('Received sensor data message with invalid value for sensor $sensorId: ${jsonData['value']}');
              }

            } else {
               print('Received sensor data message with unexpected JSON format: $payloadStr');
            }

          } catch (e) {
            print('Error parsing sensor data message: $e');
          }

        } else {
           // Handle messages on other topics if necessary
           print('Received message on an unhandled topic: $topic');
        }
      }
    }, onError: (error) {
      print('MQTT message stream error: $error');
      if (mounted) {
        setState(() {
          _commandStatus = 'MQTT stream error: ${error.toString()}';
        });
      }
    });

    print('MQTT message handling listener setup complete.');
  }

  // Function to send sensor data to your backend API for threshold table update
  Future<void> _sendSensorDataToThresholdTable(String farmId, String parameter, double value) async {
      // *** REPLACE WITH YOUR ACTUAL BACKEND ENDPOINT FOR THRESHOLD UPDATE/INSERT ***
      final url = Uri.parse('http://172.20.10.4:3000/update_threshold_data'); // Make sure this URL is correct
      try {
         final response = await http.post( // Or PUT, depending on your backend API design
             url,
             headers: {'Content-Type': 'application/json'},
             body: jsonEncode({
                 'farm_id': farmId,
                 'parameter': parameter, // Use 'parameter' as per your threshold table schema
                 'value': value,
             }),
         ).timeout(const Duration(seconds: 10));

         if (response.statusCode == 200) {
             print('Sensor data ($parameter) successfully sent to backend for threshold update: Farm $farmId, Value: $value');
             // Optionally show a success message to the user
         } else {
             print('Failed to send sensor data ($parameter) to backend for threshold update: ${response.statusCode} ${response.reasonPhrase}');
             // Handle backend error, maybe show a status message
              if (mounted) {
                setState(() {
                   _commandStatus = 'Failed to update threshold for $parameter: ${response.statusCode}';
                });
              }
         }
      } catch (e) {
          print('Error sending sensor data ($parameter) to backend for threshold update: $e');
           // Handle network or other errors during the HTTP request
            if (mounted) {
              setState(() {
                 _commandStatus = 'Network error updating threshold for $parameter: ${e.toString()}';
              });
            }
      }
  }


  void _disconnectMqtt() {
    print('Attempting to disconnect MQTT client');
    try {
      _mqttSubscription?.cancel(); // Cancel the subscription on disconnect
      if (client?.connectionStatus?.state == MqttConnectionState.connected) {
        for (final topic in subscriptionTopics) {
          client!.unsubscribe(topic);
          print('Unsubscribed from topic: $topic');
        }
      }
      client?.disconnect();
       if (mounted) {
        setState(() {
          mqttConnectionState = MqttConnectionState.disconnected;
           if (_commandStatus.contains('Connected') || _commandStatus.contains('Disconnecting')) {
              _commandStatus = 'Disconnected from MQTT broker.';
           }
           _lastMqttMessage = 'MQTT Disconnected.';
        });
       }
    } catch (e) {
      print('Error during MQTT disconnect: $e');
      if (mounted) {
        setState(() {
          mqttConnectionState = MqttConnectionState.disconnected;
          _commandStatus = 'Disconnected, but encountered an error: ${e.toString()}';
        });
      }
    }
  }

  void _onConnected() {
    print('MQTT Client::Connected callback');
    if (mounted) {
      setState(() {
        mqttConnectionState = MqttConnectionState.connected;
        _commandStatus = 'Connected to MQTT broker. Ready to send commands.';
      });
    }
    // Subscriptions are now handled in _connectMqtt after successful connection
  }

  void _onDisconnected() {
    print('MQTT Client::Disconnected callback');
    if (mounted) {
      setState(() {
        mqttConnectionState = MqttConnectionState.disconnected;
        if (_commandStatus.contains('Connected') || _commandStatus.contains('Disconnecting')) {
          _commandStatus = 'Disconnected from MQTT broker.';
        }
        _lastMqttMessage = 'MQTT Disconnected.';
      });
    }
  }

  void _onSubscribed(String topic) {
    print('MQTT Client::Subscribed callback - topic: $topic');
    if (mounted) {
      setState(() {
        _commandStatus = 'Subscribed to $topic';
      });
    }
  }

  void _onPong() {
    print('MQTT Client::Ping response callback received');
  }

  void _sendCommand() {
    FocusScope.of(context).unfocus();

    if (client?.connectionStatus?.state != MqttConnectionState.connected) {
      if (mounted) {
        setState(() {
          _commandStatus = 'Not connected to MQTT broker. Trying to reconnect...';
        });
      }
      _connectMqtt();
      return;
    }

    final payload = <String, dynamic>{};
    bool hasValidData = false;

    if (_minTempController.text.isNotEmpty) {
      final minTemp = double.tryParse(_minTempController.text);
      if (minTemp != null) {
        payload['min_temperature'] = minTemp;
        hasValidData = true;
      }
    }

    if (_maxTempController.text.isNotEmpty) {
      final maxTemp = double.tryParse(_maxTempController.text);
      if (maxTemp != null) {
        payload['max_temperature'] = maxTemp;
        hasValidData = true;
      }
    }

    if (_minHumController.text.isNotEmpty) {
      final minHum = double.tryParse(_minHumController.text);
      if (minHum != null) {
        payload['min_humidity'] = minHum;
        hasValidData = true;
      }
    }

    if (_maxHumController.text.isNotEmpty) {
      final maxHum = double.tryParse(_maxHumController.text);
      if (maxHum != null) {
        payload['max_humidity'] = maxHum;
        hasValidData = true;
      }
    }

    if (!hasValidData) {
      if (mounted) {
        setState(() {
          _commandStatus = 'No valid control values entered';
        });
      }
      return;
    }

    final payloadStr = jsonEncode(payload);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payloadStr);

    try {
      print('Publishing to $setpointMqttTopic: $payloadStr');
      client!.publishMessage(
        setpointMqttTopic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      if (mounted) {
        setState(() {
          _commandStatus = 'Command sent successfully';
        });
      }
    } catch (e) {
      print('Error publishing MQTT message: $e');
      if (mounted) {
        setState(() {
          _commandStatus = 'Failed to send command: ${e.toString()}';
        });
      }
    }
  }

  String _mqttConnectionStateString(MqttConnectionState state) {
    switch (state) {
      case MqttConnectionState.connecting:
        return 'Connecting...';
      case MqttConnectionState.connected:
        return 'Connected';
      case MqttConnectionState.disconnected:
        return 'Disconnected';
      case MqttConnectionState.disconnecting:
        return 'Disconnecting...';
      case MqttConnectionState.faulted:
        return 'Connection Error';
      default:
        return 'Unknown State';
    }
  }

  Color _getConnectionStatusColor(MqttConnectionState state) {
    switch (state) {
      case MqttConnectionState.connected:
        return Colors.green;
      case MqttConnectionState.connecting:
        return Colors.orange;
      case MqttConnectionState.disconnected:
        return Colors.red;
      case MqttConnectionState.disconnecting:
        return Colors.orange;
      case MqttConnectionState.faulted:
        return Colors.red;
      default:
        return Colors.grey;
    }
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
      });
    }
  }

  Future<void> _fetchLatestSensorData(String farmId) async {
    if (!mounted) return;

    // This function is still intended to fetch the *latest* sensor data for display,
    // likely from the sensor_data table, not the threshold table.
    // If you want to display current threshold values, you would need a separate
    // endpoint for the threshold table.
    // *** REPLACE WITH YOUR ACTUAL BACKEND ENDPOINT FOR LATEST SENSOR DATA ***
    try {
      final url = Uri.parse('http://172.20.10.4:3000/latest_sensor_data?farm_id=$farmId'); // Make sure this URL is correct
      print('Fetching latest data for farm $farmId from URL: $url');

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
          print("Unexpected response format for latest data for location $farmId: $decodedBody");
          if (mounted) _allLatestData[farmId] = {};
          return;
        }

        Map<String, Map<String, dynamic>> latestRecords = {};
        for (var item in dataList) {
          if (item is! Map<String, dynamic> ||
              item['sensor_id'] == null ||
              item['timestamp'] == null || // Ensure timestamp is present if you use it internally
              item['value'] == null) {
            print("Skipping invalid data item for farm $farmId: $item");
            continue;
          }
          String sensorId = item['sensor_id'] as String;
          latestRecords[sensorId] = item;
        }

        if (mounted) {
          final Map<String, Map<String, dynamic>> filteredLatestRecords = {};
          for (var sensorId in _sensorIdsToDisplay) {
            if (latestRecords.containsKey(sensorId)) {
              filteredLatestRecords[sensorId] = latestRecords[sensorId]!;
            }
          }
          _allLatestData[farmId] = filteredLatestRecords;
          print('Successfully fetched and processed latest data for farm $farmId. Displaying ${filteredLatestRecords.length} of ${_sensorIdsToDisplay.length} sensors.');
        }
      } else {
        print("Failed to load latest data for location $farmId: ${response.statusCode} ${response.reasonPhrase ?? 'Unknown Error'}");
        if (mounted) {
          _allLatestData[farmId] = {};
        }
      }
    } catch (e) {
      print("Error fetching latest data for location $farmId: $e");
      if (mounted) {
        _allLatestData[farmId] = {};
      }
    }
  }

  // This function is used to format the timestamp string for display,
  // but the display lines in _buildSensorCard are commented out now.
  String _formatTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return "-";
    try {
      // Assuming timestamp is in a format parsable by DateTime
      final dtUtc = DateTime.parse(ts).toUtc();
      final dtLocal = dtUtc.toLocal();
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(dtLocal);
    } catch (_) {
      print('Failed to parse timestamp for formatting: $ts');
      return ts ?? '-';
    }
  }

  String _getFarmName(String farmId) {
    final farmNames = {
      '60': 'Farm 60',
      '61': 'Farm 61',
    };
    return farmNames[farmId] ?? 'Farm $farmId';
  }

  void _updateErrorMessage() {
    if (_isLoading) {
      _errorMessage = null;
      return;
    }

    if (_locations.isEmpty) {
      _errorMessage = "No locations defined for this view.";
      return;
    }

    if (_allLatestData.isEmpty) {
      _errorMessage = _errorMessage ?? "Could not retrieve data for any location. Check backend and network.";
      return;
    }

    if (!_allLatestData.containsKey(_selectedLocation) || _allLatestData[_selectedLocation] == null) {
      _errorMessage = "Data for Farm ${_getFarmName(_selectedLocation)} not loaded. Please check backend or try refreshing.";
      return;
    }

    if (_allLatestData[_selectedLocation]!.isEmpty) {
      if (_sensorIdsToDisplay.isNotEmpty) {
        _errorMessage = "No sensor data available for Farm ${_getFarmName(_selectedLocation)}.";
      } else {
        _errorMessage = "No known sensors configured for Farm ${_getFarmName(_selectedLocation)} in the app.";
      }
      return;
    }

    _errorMessage = null;
  }

  String _getSensorTitle(String sensorId) {
    final sensorTitles = {
      'DO001': 'Dissolved Oxygen',
      'HUM01': 'Air Humidity',
      'TEM01': 'Water Temperature',
      'TEM02': 'Air Temperature',
      'RSS01': 'pH',
      'TDS01': 'TDS',
    };
    return sensorTitles[sensorId] ?? sensorId;
  }

  String _getSensorUnit(String sensorId) {
    switch (sensorId) {
      case 'DO001':
        return 'mg/L';
      case 'HUM01':
        return '%';
      case 'TEM01':
      case 'TEM02':
        return '°C';
      case 'RSS01':
        return '';
      case 'TDS01':
        return 'ppm';
      default:
        return '';
    }
  }

  Widget _buildSensorCard(String title, String value, String? timestamp,
      String sensorId, VoidCallback? onTap) {
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
              // const SizedBox(height: 8), // Commented out
              // Text( // Commented out
              //   timestamp ?? '-', // Commented out
              //   style: Theme.of(context).textTheme.bodySmall?.copyWith( // Commented out
              //         color: onTap != null ? Colors.grey[600] : Colors.white38, // Commented out
              //       ), // Commented out
              //   textAlign: TextAlign.center, // Commented out
              // ), // Commented out
               const SizedBox(height: 8), // Kept a SizedBox for spacing below value
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

  Widget _buildLocationDropdown() {
    if (_locations.length <= 1) {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Farm:',
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
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color.fromARGB(255, 114, 114, 114),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            value: _locations.contains(_selectedLocation)
                ? _selectedLocation
                : (_locations.isNotEmpty ? _locations.first : null),
            icon: const Icon(Icons.arrow_downward, color: Colors.white),
            elevation: 16,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            dropdownColor: const Color.fromARGB(255, 114, 114, 114),
            onChanged: (String? newValue) {
              if (newValue != null && newValue != _selectedLocation) {
                setState(() {
                  _selectedLocation = newValue;
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

  Widget _buildControlTab() {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.grey[850],
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      color: _getConnectionStatusColor(mqttConnectionState),
                      Icons.circle,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'MQTT Status: ${_mqttConnectionStateString(mqttConnectionState)}',
                        style: TextStyle(
                          color: _getConnectionStatusColor(mqttConnectionState),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (mqttConnectionState ==
                            MqttConnectionState.disconnected ||
                        mqttConnectionState == MqttConnectionState.faulted)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _connectMqtt,
                        tooltip: 'Reconnect',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _lastMqttMessage,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey[850],
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Temperature Control',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Set Minimum Temperature (°C):',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _minTempController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          hintText: 'Enter min temperature',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[800],
                          hintStyle: const TextStyle(color: Colors.white38)),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Set Maximum Temperature (°C):',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _maxTempController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          hintText: 'Enter max temperature',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[800],
                          hintStyle: const TextStyle(color: Colors.white38)),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey[850],
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Humidity Control',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Set Minimum Humidity (%):',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _minHumController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          hintText: 'Enter min humidity',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[800],
                          hintStyle: const TextStyle(color: Colors.white38)),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Set Maximum Humidity (%):',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _maxHumController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          hintText: 'Enter max humidity',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[800],
                          hintStyle: const TextStyle(color: Colors.white38)),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: mqttConnectionState == MqttConnectionState.connected
                  ? _sendCommand
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[700],
                disabledForegroundColor: Colors.grey[400],
              ),
              child: const Text('Submit All Controls'),
            ),
            const SizedBox(height: 8),
            Text(
              _commandStatus,
              style: TextStyle(
                color: _commandStatus.contains('Error') ||
                        _commandStatus.contains('Invalid') ||
                        _commandStatus.contains('failed') ||
                        _commandStatus.contains('Not connected') ||
                        _commandStatus.contains('timed out')
                    ? Colors.redAccent
                    : (_commandStatus.contains('Connected') || _commandStatus.contains('sent successfully') ? Colors.greenAccent : Colors.white70),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorsTab(List<Widget> sensorCards) {
    return RefreshIndicator(
      onRefresh: _fetchInitialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLocationDropdown(),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_locations.isNotEmpty)
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final selectedLocationData = _allLatestData[_selectedLocation] ?? {};

    final List<Widget> sensorCards = _sensorIdsToDisplay.map((sensorId) {
      final sensorData = selectedLocationData[sensorId];
      final bool isTappable = sensorData != null;

      return _buildSensorCard(
        _getSensorTitle(sensorId),
        sensorData?['value']?.toString() ?? '-',
        _formatTimestamp(sensorData?['timestamp']), // Timestamp is still passed but not displayed in the card
        sensorId,
        isTappable
            ? () {
                FocusScope.of(context).unfocus();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FisheryGraph(
                      farmId: _selectedLocation,
                      sensorId: sensorId,
                    ),
                  ),
                );
              }
            : null,
      );
    }).toList();

    final int cardsToAdd = _numberOfEmptyCards;
    if (sensorCards.length < _sensorIdsToDisplay.length + cardsToAdd) {
      final int remainingSlots = (_sensorIdsToDisplay.length + cardsToAdd) - sensorCards.length;
      for (int i = 0; i < remainingSlots; i++) {
        if (sensorCards.length < _sensorIdsToDisplay.length + _numberOfEmptyCards) {
          sensorCards.add(_buildEmptyCard());
        } else {
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Fishery - ${_getFarmName(_selectedLocation)}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.thermostat), text: 'Sensors'),
            Tab(icon: Icon(Icons.tune), text: 'Control'),
          ],
          indicatorColor: Colors.white,
        ),
        centerTitle: true,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSensorsTab(sensorCards),
          _buildControlTab(),
        ],
      ),
    );
  }
}