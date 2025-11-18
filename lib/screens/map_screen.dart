import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/wifi_point.dart';
import '../services/mqtt_service.dart';
import '../services/storage_service.dart';

class MapScreen extends StatefulWidget {
  final Function(List<WifiPoint>) onPointsUpdate;
  const MapScreen({super.key, required this.onPointsUpdate});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final mqtt = MQTTService();
  List<WifiPoint> points = [];
  bool showOnlyInsecure = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    mqtt.onNewData = (newPoints) {
      setState(() {
        points.addAll(newPoints);
        StorageService.save(points);
        widget.onPointsUpdate(points); // Envía datos al menú principal y K-Means
      });
    };
    mqtt.connect(); // Aquí se usan las claves desde config.dart (en mqtt_service.dart)
  }

  Future<void> _loadData() async {
    final cached = await StorageService.load();
    if (cached.isNotEmpty) {
      setState(() {
        points = cached;
        widget.onPointsUpdate(points);
      });
    }
  }

  List<Marker> _buildMarkers() {
    final filtered = showOnlyInsecure
        ? points.where((p) => p.isInsecure).toList()
        : points;

    return filtered.map((p) {
      final color = p.isInsecure ? Colors.red : Colors.green;
      final size = p.signal > -70 ? 42.0 : 32.0;

      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () => _showInfo(p),
          child: Icon(
            Icons.location_on,
            color: color,
            size: size,
            shadows: const [Shadow(blurRadius: 10, color: Colors.black45)],
          ),
        ),
      );
    }).toList();
  }

  void _showInfo(WifiPoint p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(p.ssid, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.security, "Seguridad", p.security),
            _infoRow(Icons.signal_wifi_4_bar, "Señal", "${p.signal} dBm"),
            _infoRow(Icons.phonelink, "MAC", p.mac),
            _infoRow(Icons.location_on, "Coordenadas", "${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: points.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 20),
                  Text("Conectando al Pico W...", style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  points.last.latitude,
                  points.last.longitude,
                ),
                initialZoom: 16.5,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'dev.octavio.wardriving',
                ),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "filter",
            backgroundColor: showOnlyInsecure ? Colors.red.shade700 : Colors.grey.shade700,
            tooltip: "Mostrar solo redes inseguras",
            child: Icon(showOnlyInsecure ? Icons.security : Icons.wifi),
            onPressed: () => setState(() => showOnlyInsecure = !showOnlyInsecure),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "clear",
            backgroundColor: Colors.deepPurple,
            tooltip: "Limpiar todos los datos",
            child: const Icon(Icons.delete_forever),
            onPressed: () async {
              await StorageService.clear();
              setState(() => points.clear());
              widget.onPointsUpdate([]);
            },
          ),
        ],
      ),
    );
  }
}