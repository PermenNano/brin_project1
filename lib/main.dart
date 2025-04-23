import 'package:brin_project1/pages/gnss.dart';
import 'package:flutter/material.dart';
import 'pages/LoginPage.dart';
import 'pages/Jamur.dart';
import 'pages/Hydroponic.dart';
import 'pages/Fishery.dart';
import 'pages/EMFM.dart';
import 'pages/fishery/temperature.dart';
import 'pages/fishery/humidity.dart';
import 'pages/fishery/ph.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return MaterialApp(
      title: 'BRIN App',
      theme: ThemeData(
        primaryColor: Colors.purple,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/gnss': (context) =>  Gnss(date: DateTime.now(), farmId: 'tekno3'),
        '/jamur': (context) => const Jamur(),
        '/hydroponic': (context) => Hydroponic(date: DateTime.now(), farmId: 'tekno3'),
        '/fishery': (context) => Fishery(date: DateTime.now(), farmId: 'tekno3'),
        '/EMFM': (context) => const EMFM(),
        '/temperature': (context) => Temperature(startDate: startOfDay, endDate: endOfDay),
        '/humidity': (context) => Humidity(startDate: startOfDay, endDate: endOfDay),
        '/ph': (context) => ph(date: DateTime.now()),
      },
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  Widget _buildBox(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onTap,
    IconData iconData,
  ) {
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
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.purple,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'BRIN App',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Menu',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Logo below app bar
            // Image.asset(
            //   'assets/logo.png', // Replace with your logo asset path
            //   height: 100,
            // ),
            const SizedBox(height: 24), // Spacing between logo and buttons

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBox(
                  context,
                  'Hydroponic',
                  Colors.orange.shade400,
                  () {
                    Navigator.pushNamed(context, '/hydroponic');
                  },
                  Icons.local_florist,
                ),
                _buildBox(
                  context,
                  'Fishery',
                  Colors.red.shade400,
                  () {
                    Navigator.pushNamed(context, '/fishery');
                  },
                  Icons.set_meal,
                ),
                _buildBox(
                  context,
                  'Jamur',
                  Colors.green.shade600,
                  () {
                    Navigator.pushNamed(context, '/jamur');
                  },
                  Icons.grass,
                ),
                _buildBox(
                  context,
                  'EMFM',
                  Colors.blue.shade600,
                  () {
                    Navigator.pushNamed(context, '/EMFM');
                  },
                  Icons.wifi_sharp,
                ),
              ],
            ),

            const SizedBox(height: 40), // Spacing between rows

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBox(
                  context,
                  'GNSS',
                  const Color.fromARGB(255, 229, 30, 30),
                  () {
                    Navigator.pushNamed(
                        context, '/gnss'); // Update route if needed
                  },
                  Icons.satellite_alt,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}