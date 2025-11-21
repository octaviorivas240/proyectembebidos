// lib/screens/map_screen.dart → VERSIÓN FINAL DEFINITIVA 100% FUNCIONAL
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
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

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _startLocationTracking();

    // Recarga automática cada 12 segundos
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 12));
      if (mounted) await _loadPoints();
      return mounted;
    });
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Activa el GPS para verte en el mapa")),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permite ubicación en Ajustes")),
        );
      }
      return;
    }

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position position) {
      setState(() => _currentPosition = position);
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        16.5,
      );
    });

    try {
      Position pos = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = pos);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16.5);
    } catch (_) {}
  }

  // ELIMINA DUPLICADOS POR MAC + GUARDA SOLO EL DE MEJOR SEÑAL
  Future<void> _loadPoints() async {
    try {
      final url =
          'https://io.adafruit.com/api/v2/${Config.username}/feeds/${Config.feed}/data?limit=500';
      final response =
          await http.get(Uri.parse(url), headers: {'X-AIO-Key': Config.aioKey});

      if (response.statusCode != 200) return;

      final List<dynamic> items = json.decode(response.body);
      final Map<String, WifiPoint> uniqueByMac = {};

      for (var item in items) {
        final String? raw = item['value'] as String?;
        if (raw == null || raw.trim().isEmpty) continue;

        for (var line in raw.split('\n')) {
          line = line.trim();
          if (line.isEmpty) continue;

          try {
            final point = WifiPoint.fromCsv(line);
            final String macKey = point.mac.toUpperCase().trim();

            if (macKey.isEmpty || macKey == "00:00:00:00:00:00") continue;

            if (!uniqueByMac.containsKey(macKey) ||
                point.signal > (uniqueByMac[macKey]?.signal ?? -200)) {
              uniqueByMac[macKey] = point;
            }
          } catch (_) {
            continue;
          }
        }
      }

      final List<WifiPoint> loaded = uniqueByMac.values.toList();

      if (loaded.isNotEmpty && mounted) {
        setState(() {
          allPoints = loaded;
          widget.onPointsUpdate(loaded);
        });

        final prefs = await SharedPreferences.getInstance();
        final cache = loaded.map((p) => p.toJson()).toList();
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
            .map((e) => WifiPoint.fromJson(e as Map<String, dynamic>))
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
    final markerKey =
        ValueKey('markers_${displayedPoints.length}_$showOnlyOpen');

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition != null
                ? LatLng(
                    _currentPosition!.latitude, _currentPosition!.longitude)
                : const LatLng(19.4326, -99.1332),
            initialZoom: _currentPosition != null ? 16.5 : 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.wardriving.live',
            ),
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
            if (_currentPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude),
                    width: 70,
                    height: 70,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withAlpha(80),
                        border: Border.all(color: Colors.blue, width: 4),
                      ),
                      child: const Icon(Icons.my_location,
                          color: Colors.blue, size: 40),
                    ),
                  ),
                ],
              ),
          ],
        ),
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
              "$displayedCount ${showOnlyOpen ? 'abiertas' : 'redes'}",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17),
            ),
          ),
        ),
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
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}
