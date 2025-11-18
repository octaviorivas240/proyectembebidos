import 'package:flutter/foundation.dart'; // ← Necesario para kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/map_screen.dart';
import 'screens/kmeans_screen.dart';
import 'screens/about_screen.dart';
import 'models/wifi_point.dart';
import 'config.dart'; // ← Tu config.dart limpio

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CARGAR .env SOLO EN MÓVIL (Android/iOS)
  if (!kIsWeb) {
    await dotenv.load(fileName: ".env");
    // Validamos que las claves estén bien configuradas
    Config.validate();
  } else {
    // En web usamos valores por defecto (no hay .env)
    debugPrint("Running on Web → Using demo credentials");
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
        fontFamily: 'Roboto',
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
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.wifi, size: 50, color: Colors.deepPurple),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Wardriving Pro",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "v2.0 - Tiempo Real + K-Means",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            _menuItem(Icons.map_outlined, "Mapa en Tiempo Real", 0),
            _menuItem(Icons.analytics_outlined, "Análisis K-Means", 1),
            _menuItem(Icons.info_outline, "Acerca de", 2),
            const Divider(height: 30, thickness: 1),
            _menuItem(Icons.exit_to_app, "Salir", 3, color: Colors.redAccent),
          ],
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          MapScreen(onPointsUpdate: _updatePoints),
          KMeansScreen(points: allPoints),
          const AboutScreen(),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, int index, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70),
      title: Text(
        title,
        style: TextStyle(color: color ?? Colors.white, fontSize: 16),
      ),
      selected: _index == index,
      selectedTileColor: Colors.deepPurple.withOpacity(0.3),
      selectedColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () {
        if (index == 3) {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("Salir de Wardriving Pro"),
              content:
                  const Text("¿Estás seguro de que quieres cerrar la app?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar",
                      style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  child:
                      const Text("Salir", style: TextStyle(color: Colors.red)),
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
