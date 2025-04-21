import 'package:flutter/material.dart';
import 'LoginPage.dart';
import 'Jamur.dart';
import 'Hydroponic.dart';
import 'Fishery.dart'; // Import your FisheryScreen (now renamed to Fishery)
import 'EMFM.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import the dotenv package

void main() async {
  await dotenv.load(fileName: ".env"); // Load environment variables
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BRIN App',
      theme: ThemeData(
        primaryColor: Colors.purple,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/jamur': (context) => const Jamur(),
        '/hydroponic': (context) => const Hydroponic(),
        '/fishery': (context) => Fishery(date: DateTime.now()), // Pass the initial date
        '/EMFM': (context) => const EMFM(),
      },
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  Widget _buildBox(BuildContext context, String label, Color color, VoidCallback onTap, IconData iconData) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(iconData, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBox(context, 'Hydroponic', Colors.orange.shade400, () {
                  Navigator.pushNamed(context, '/hydroponic');
                }, Icons.local_florist),
                _buildBox(context, 'Fishery', Colors.red.shade400, () {
                  Navigator.pushNamed(context, '/fishery');
                }, Icons.set_meal),
                _buildBox(context, 'Jamur', Colors.green.shade600, () {
                  Navigator.pushNamed(context, '/jamur');
                }, Icons.grass),
                _buildBox(context, 'EMFM', Colors.blue.shade600, () {
                  Navigator.pushNamed(context, '/EMFM');
                }, Icons.wifi_sharp),
              ],
            ),
          ],
        ),
      ),
    );
  }
}