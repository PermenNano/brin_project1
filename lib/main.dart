import 'package:brin_project1/pages/graph/fishery_graph.dart';
import 'package:brin_project1/pages/graph/hydroponic_graph.dart';
import 'package:brin_project1/pages/graph/jamur_graph.dart';
import 'package:flutter/material.dart';
import 'pages/LoginPage.dart';
import 'pages/Jamur.dart';
import 'pages/Hydroponic.dart';
import 'pages/Fishery.dart';
import 'pages/EMFM.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/resetpassword.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BRIN App',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color.fromARGB(255, 168, 165, 169),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 168, 165, 169),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color.fromARGB(255, 114, 114, 114),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white,
        ),
        textTheme: ThemeData.dark().textTheme.copyWith(
          bodyMedium: const TextStyle(color: Colors.white),
          bodySmall: const TextStyle(color: Colors.white70),
          titleLarge: const TextStyle(color: Colors.white),
          titleMedium: const TextStyle(color: Colors.white),
          titleSmall: const TextStyle(color: Colors.white),
          labelLarge: const TextStyle(color: Colors.white),
          labelMedium: const TextStyle(color: Colors.white),
          labelSmall: const TextStyle(color: Colors.white),
          headlineSmall: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      home: const LoginPage(),
      onGenerateRoute: (settings) {
        print('Navigating to route: ${settings.name}');

        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());

          case '/jamur':
            return MaterialPageRoute(
                builder: (_) => Jamur(date: DateTime.now(), farmId: '70, 71, 0'));

          case '/hydroponic':
            return MaterialPageRoute(
                builder: (_) => Hydroponic(date: DateTime.now(), farmId: '10, 11'));

          case '/fishery':
            return MaterialPageRoute(
                builder: (_) => Fishery(date: DateTime.now(), farmId: '60, 61'));

          case '/EMFM':
            return MaterialPageRoute(
                builder: (_) => EMFM(date: DateTime.now(), farmId: 'tekno3'));

          case '/fisheryGraph':
            {
              final args = settings.arguments;
              String farmId = 'defaultFarmId';
              String? sensorId;

              if (args is Map<String, dynamic>) {
                  farmId = args['farmId'] ?? 'defaultFarmId';
                  sensorId = args['sensorId'] as String?;
              }
              return MaterialPageRoute(
                  builder: (_) => FisheryGraph(
                    farmId: farmId,
                    sensorId: sensorId,
                  ),
              );
            }

          case '/jamurGraph':
            {
              final args = settings.arguments;
              String farmId = 'defaultFarmId';
              String? sensorId;

              if (args is Map<String, dynamic>) {
                  farmId = args['farmId'] ?? 'defaultFarmId';
                  sensorId = args['sensorId'] as String?;
              }
              return MaterialPageRoute(
                  builder: (_) => JamurGraph(
                    farmId: farmId,
                    sensorId: sensorId,
                  ),
              );
            }

          case '/hydroponicGraph':
            {
              final args = settings.arguments;
              String farmId = 'defaultFarmId';
              String? sensorId;

              if (args is Map<String, dynamic>) {
                farmId = args['farmId'] ?? 'defaultFarmId';
                sensorId = args['sensorId'] as String?;
              }
              return MaterialPageRoute(
                  builder: (_) => HydroponicGraph(
                    farmId: farmId,
                    sensorId: sensorId,
                  ),
              );
            }

          case '/resetPassword':
            return MaterialPageRoute(builder: (_) => const ResetPassword());

          case '/graph':
            {
              final args = settings.arguments;
              String farmId = 'defaultFarmId';
              String? sensorId;

              if (args is Map<String, dynamic>) {
                farmId = args['farmId'] ?? 'defaultFarmId';
                sensorId = args['sensorId'] as String?;
              } else if (args is String) {
                 farmId = args;
                 sensorId = null;
              }
              return null;
            }

          default:
            return null;
        }
      },
    );
  }
}

class MainMenu extends StatelessWidget {
  final String username;

  const MainMenu({super.key, required this.username});

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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(iconData, color: Colors.white, size: 70),
          ),
          const SizedBox(height: 8),
          SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AMCS'),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 168, 165, 169),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Hello, $username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'BRIN App',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  const Text(
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
      body: Stack(
        fit: StackFit.expand,
        children: [
            Center(
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/images/logo_brin.png',
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // First row of 2 boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                      const SizedBox(width: 20.0),
                      _buildBox(
                        context,
                        'Fishery',
                        Colors.red.shade400,
                            () {
                          Navigator.pushNamed(context, '/fishery');
                        },
                        Icons.set_meal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),
                  // Second row of 2 boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBox(
                        context,
                        'Jamur',
                        Colors.green.shade600,
                            () {
                          Navigator.pushNamed(context, '/jamur');
                        },
                        Icons.grass,
                      ),
                      const SizedBox(width: 20.0),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}