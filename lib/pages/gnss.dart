import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: DashboardPage(),
  ));
}

// Mock Devices
final devices = ['GNSS 1', 'GNSS 2', 'GNSS 3', 'GNSS 4', 'GNSS 5'];

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? selectedDevice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("GNSS")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ToggleButtons(
              isSelected: [true, false],
              onPressed: (_) {},
              children: [Text("GNSS"), Text("Signal Hound")],
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedDevice,
              hint: Text("Select device"),
              onChanged: (value) {
                setState(() => selectedDevice = value);
              },
              items: devices.map((device) {
                return DropdownMenuItem(
                  value: device,
                  child: Text(device),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            Text("Click card to see more info"),
            SizedBox(height: 16),
            Expanded(
              child: selectedDevice == null
                  ? _buildEmptyCards()
                  : ParameterListPage(deviceName: selectedDevice!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCards() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: List.generate(6, (index) {
        return Card(
          elevation: 2,
          child: Center(child: Text("Parameter ${index + 1}\n–", textAlign: TextAlign.center)),
        );
      }),
    );
  }
}

class ParameterListPage extends StatelessWidget {
  final String deviceName;

  ParameterListPage({required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: List.generate(6, (index) {
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ParameterDetailPage(parameterId: 'Parameter ${index + 1}')),
            );
          },
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Parameter ${index + 1}", style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("123", style: TextStyle(fontSize: 20)),
                  Text("2025-04-24 10:00", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class ParameterDetailPage extends StatelessWidget {
  final String parameterId;

  ParameterDetailPage({required this.parameterId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$parameterId - SEN001")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _dateField("Start Date")),
                SizedBox(width: 12),
                Expanded(child: _dateField("End Date")),
              ],
            ),
            SizedBox(height: 24),
            _mockChart(),
            SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(4, (index) {
                return Container(
                  width: MediaQuery.of(context).size.width / 2 - 24,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: index == 3
                      ? Text("About (click for more info)", textAlign: TextAlign.center)
                      : Column(
                          children: [
                            Text("Stat ${index + 1}", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("value"),
                            Text("Timestamp", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                );
              }),
            )
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      readOnly: true,
    );
  }

  Widget _mockChart() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text("Chart Placeholder 📈")),
    );
  }
}