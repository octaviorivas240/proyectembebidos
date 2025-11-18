// lib/screens/map_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wifi_point.dart';
import '../config.dart';

class MapScreen extends StatefulWidget {
  final Function(List<WifiPoint>) onPointsUpdate;
  const MapScreen({Key? key, required this.onPointsUpdate}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<WifiPoint> allPoints = [];
  bool showOnlyOpen = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadPoints();

    // Recarga cada 12 segundos
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 12));
      if (mounted) await _loadPoints();
      return mounted;
    });
  }

  Future<void> _loadPoints() async {
    try {
      final url =
          'https://io.adafruit.com/api/v2/${Config.username}/feeds/${Config.feed}/data?limit=200';
      final response =
          await http.get(Uri.parse(url), headers: {'X-AIO-Key': Config.aioKey});

      if (response.statusCode != 200) return;

      final List<dynamic> items = json.decode(response.body);
      final List<WifiPoint> loaded = [];

      for (var item in items) {
        final String? raw = item['value'] as String?;
        if (raw == null || raw.trim().isEmpty) continue;

        for (var line in raw.split('\n')) {
          line = line.trim();
          if (line.isEmpty) continue;
          try {
            loaded.add(WifiPoint.fromCsv(line));
          } catch (_) {
            continue;
          }
        }
      }

      if (loaded.isNotEmpty && mounted) {
        setState(() {
          allPoints = loaded;
          widget.onPointsUpdate(loaded);
        });

        // Guardar caché
        final prefs = await SharedPreferences.getInstance();
        final cache = loaded
            .map((p) => {
                  'ssid': p.ssid,
                  'security': p.security,
                  'lat': p.latitude,
                  'lng': p.longitude,
                  'signal': p.signal,
                  'mac': p.mac,
                })
            .toList();
        await prefs.setString('cached_points', jsonEncode(cache));
      }
    } catch (e) {
      await _loadFromCache();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('cached_points');
      if (data != null && mounted) {
        final List list = json.decode(data);
        final cached = list
            .map((e) => WifiPoint(
                  ssid: e['ssid'] ?? '',
                  security: e['security'] ?? 'Desconocido',
                  latitude: (e['lat'] as num).toDouble(),
                  longitude: (e['lng'] as num).toDouble(),
                  signal: e['signal'] ?? -100,
                  mac: e['mac'] ?? '',
                  timestamp: DateTime.now(),
                ))
            .toList();

        setState(() {
          allPoints = cached;
          widget.onPointsUpdate(cached);
        });
      }
    } catch (_) {}
  }

  void _toggleFilter() => setState(() => showOnlyOpen = !showOnlyOpen);

  int get displayedCount => showOnlyOpen
      ? allPoints.where((p) => p.isInsecure).length
      : allPoints.length;

  List<WifiPoint> get displayedPoints =>
      showOnlyOpen ? allPoints.where((p) => p.isInsecure).toList() : allPoints;

  @override
  Widget build(BuildContext context) {
    // LA CLAVE: Key única que fuerza reconstrucción completa de marcadores
    final markerKey =
        ValueKey('markers_${displayedPoints.length}_$showOnlyOpen');

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(19.4326, -99.1332),
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.wardriving.live',
            ),

            // Marcadores con key que se regenera → nunca se sobreponen
            MarkerLayer(
              key: markerKey,
              markers: displayedPoints.map((p) {
                return Marker(
                  point: LatLng(p.latitude, p.longitude),
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.circle,
                    color: p.isInsecure ? Colors.red : Colors.green,
                    size: 36,
                    shadows: const [
                      Shadow(
                          blurRadius: 12,
                          color: Colors.black87,
                          offset: Offset(0, 2))
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Contador
        Positioned(
          bottom: 90,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: showOnlyOpen ? Colors.red.shade800 : Colors.green.shade700,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 12)
              ],
            ),
            child: Text(
              "$displayedCount ${showOnlyOpen ? 'redes abiertas' : 'redes'}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ),

        // Botón filtro
        Positioned(
          bottom: 90,
          right: 20,
          child: FloatingActionButton(
            heroTag: "filter",
            backgroundColor: showOnlyOpen ? Colors.red : Colors.green,
            elevation: 8,
            onPressed: _toggleFilter,
            child: const Icon(Icons.shield, color: Colors.white, size: 34),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
