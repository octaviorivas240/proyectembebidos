// lib/screens/kmeans_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/wifi_point.dart';

class KMeansScreen extends StatefulWidget {
  final List<WifiPoint> points;
  const KMeansScreen({Key? key, required this.points}) : super(key: key);

  @override
  State<KMeansScreen> createState() => _KMeansScreenState();
}

class _KMeansScreenState extends State<KMeansScreen> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(KMeansScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ajustar cámara cuando cambien los puntos
    if (widget.points.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bounds = _calculateBounds(widget.points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(60),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const Center(
        child: Text(
          "No hay datos para analizar\nEscanea redes primero",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, color: Colors.white70),
        ),
      );
    }

    final clusters = _runKMeans(widget.points, 4);

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(19.4326, -99.1332),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.wardriving_live',
        ),
        MarkerLayer(
          markers: widget.points.map((p) {
            final cluster = clusters.firstWhere(
              (c) => c['points'].contains(p),
              orElse: () => {'color': Colors.grey},
            );
            return Marker(
              point: LatLng(p.latitude, p.longitude),
              width: 40,
              height: 40,
              child: Icon(
                Icons.location_on,
                color: cluster['color'] as Color,
                size: 40,
                shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            );
          }).toList(),
        ),
        CircleLayer(
          circles: clusters.map((c) {
            final centerPoint = c['center'] as WifiPoint;
            return CircleMarker(
              point: LatLng(centerPoint.latitude, centerPoint.longitude),
              radius: 60,
              useRadiusInMeter: false,
              color: (c['color'] as Color).withAlpha(80),
              borderColor: c['color'] as Color,
              borderStrokeWidth: 4,
            );
          }).toList(),
        ),
      ],
    );
  }

  // === K-MEANS Y UTILIDADES (sin cambios) ===
  List<Map<String, dynamic>> _runKMeans(List<WifiPoint> points, int k) {
    if (points.isEmpty) return [];

    List<WifiPoint> centroids = List.from(points)..shuffle();
    centroids = centroids.take(k).toList();

    List<Map<String, dynamic>> clusters = [];
    bool changed = true;

    while (changed) {
      clusters = List.generate(
          k, (i) => {'points': <WifiPoint>[], 'color': _getColor(i)});
      for (var point in points) {
        int closest = 0;
        double minDist = double.infinity;
        for (int i = 0; i < centroids.length; i++) {
          final dist = _distance(point, centroids[i]);
          if (dist < minDist) {
            minDist = dist;
            closest = i;
          }
        }
        clusters[closest]['points'].add(point);
      }

      changed = false;
      for (int i = 0; i < k; i++) {
        final clusterPoints = clusters[i]['points'] as List<WifiPoint>;
        if (clusterPoints.isEmpty) continue;
        final newCenter = WifiPoint(
          ssid: 'centroid',
          security: '',
          latitude:
              clusterPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
                  clusterPoints.length,
          longitude:
              clusterPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
                  clusterPoints.length,
          signal: 0,
          mac: '',
          timestamp: DateTime.now(),
        );
        if (_distance(newCenter, centroids[i]) > 0.0001) {
          changed = true;
          centroids[i] = newCenter;
        }
        clusters[i]['center'] = centroids[i];
      }
    }

    return clusters;
  }

  double _distance(WifiPoint a, WifiPoint b) {
    return (a.latitude - b.latitude).abs() + (a.longitude - b.longitude).abs();
  }

  Color _getColor(int index) {
    const colors = [Colors.red, Colors.blue, Colors.yellow, Colors.purple];
    return colors[index % colors.length];
  }

  LatLngBounds _calculateBounds(List<WifiPoint> points) {
    if (points.isEmpty) {
      return LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
    }
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    return LatLngBounds(
      LatLng(lats.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a < b ? a : b)),
      LatLng(lats.reduce((a, b) => a > b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b)),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
