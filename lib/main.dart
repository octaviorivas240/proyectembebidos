// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/map_screen.dart';
import 'screens/kmeans_screen.dart';
import 'screens/about_screen.dart';
import 'models/wifi_point.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CARGAR .env DESDE ASSETS → FUNCIONA EN ANDROID, iOS, WINDOWS Y WEB
  try {
    await dotenv.load(fileName: "assets/.env");
    Config.validate();
    debugPrint("Configuración cargada correctamente desde assets/.env");
  } catch (e) {
    debugPrint("Error cargando .env: $e");
    if (kIsWeb) {
      debugPrint(
          "Modo Web detectado → puedes usar credenciales de prueba aquí si quieres");
    } else {
      // En móvil o desktop, si no encuentra el .env → que explote para que lo veas
      rethrow;
    }
  }

  runApp(const WardrivingPro());
}

class WardrivingPro extends StatelessWidget {
  const WardrivingPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wardriving Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;
  List<WifiPoint> allPoints = [];

  void _updatePoints(List<WifiPoint> points) {
    setState(() => allPoints = points);
  }

  Widget _currentPage() {
    switch (_index) {
      case 0:
        return MapScreen(onPointsUpdate: _updatePoints);
      case 1:
        return KMeansScreen(points: allPoints);
      case 2:
        return const AboutScreen();
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ["Mapa en Vivo", "Análisis K-Means", "Acerca de"][_index],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.deepPurple.shade800,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              currentAccountPicture: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Icon(Icons.wifi, size: 50, color: Colors.deepPurple),
              ),
              accountName: Text(
                "Wardriving Pro",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                "v2.0 • Tiempo Real + K-Means",
                style: TextStyle(fontSize: 13),
              ),
            ),
            _menuItem(Icons.map_outlined, "Mapa en Tiempo Real", 0),
            _menuItem(Icons.analytics_outlined, "Análisis K-Means", 1),
            _menuItem(Icons.info_outline, "Acerca de", 2),
            const Divider(),
            _menuItem(Icons.exit_to_app, "Salir", 3, color: Colors.redAccent),
          ],
        ),
      ),
      body: _currentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: Colors.deepPurple.shade800,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Mapa"),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics), label: "K-Means"),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: "Info"),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, int index, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(title, style: TextStyle(color: color ?? Colors.white)),
      selected: _index == index,
      selectedTileColor: Colors.deepPurple.withOpacity(0.3),
      onTap: () {
        if (index == 3) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("Salir", style: TextStyle(color: Colors.white)),
              content: const Text("¿Cerrar la app?",
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("No",
                        style: TextStyle(color: Colors.white70))),
                TextButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text("Sí", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        } else {
          setState(() => _index = index);
          Navigator.pop(context);
        }
      },
    );
  }
}
