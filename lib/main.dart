import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/map_screen.dart';
import 'screens/kmeans_screen.dart';
import 'screens/about_screen.dart';
import 'models/wifi_point.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
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
        title: Text(["Mapa en Vivo", "Análisis K-Means", "Acerca de"][_index]),
        centerTitle: true,
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
                  Text("Wardriving Pro", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            _item(Icons.map, "Mapa en Tiempo Real", 0),
            _item(Icons.analytics, "Análisis K-Means", 1),
            _item(Icons.info_outline, "Acerca de", 2),
            const Divider(),
            _item(Icons.exit_to_app, "Salir", 3, color: Colors.redAccent),
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

  Widget _item(IconData icon, String title, int index, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white),
      title: Text(title, style: TextStyle(color: color ?? Colors.white)),
      selected: _index == index,
      selectedTileColor: Colors.white.withValues(alpha: 0.1),
      onTap: () {
        if (index == 3) {
          Navigator.pop(context);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Salir"),
              content: const Text("¿Cerrar la app?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
                TextButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text("Sí")),
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