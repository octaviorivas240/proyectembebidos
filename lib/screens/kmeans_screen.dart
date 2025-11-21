// lib/screens/kmeans_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/wifi_point.dart';

class KMeansScreen extends StatefulWidget {
  final List<WifiPoint> allPoints;

  const KMeansScreen({Key? key, required this.allPoints}) : super(key: key);

  @override
  State<KMeansScreen> createState() => _KMeansScreenState();
}

class _KMeansScreenState extends State<KMeansScreen> {
  List<Cluster> clusters = [];
  int k = 4; // Número de clusters (puedes cambiarlo)

  @override
  void initState() {
    super.initState();
    _runKMeans();
  }

  void _runKMeans() {
    final openPoints = widget.allPoints.where((p) => p.isInsecure).toList();
    if (openPoints.isEmpty) {
      setState(() => clusters = []);
      return;
    }

    clusters = kMeans(openPoints, k);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final openCount = widget.allPoints.where((p) => p.isInsecure).length;
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.deepOrange,
      Colors.pink
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("K-Means - Redes Inseguras"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runKMeans,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text("K = $k",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Column(
              children: [
                Text(
                  "Análisis de $openCount redes abiertas/WEP",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Se formaron ${clusters.length} clusters de alta concentración",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: clusters.map((c) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: c.color, size: 20),
                          const SizedBox(width: 4),
                          Text("${c.points.length} redes"),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: clusters.isEmpty
                ? const Center(
                    child: Text(
                      "No hay redes abiertas detectadas\n¡Excelente seguridad en la zona!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.green),
                    ),
                  )
                : FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(19.4326, -99.1332),
                      initialZoom: 12.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.wardriving.live',
                      ),
                      MarkerLayer(
                        markers: clusters.expand((cluster) {
                          return cluster.points.map((p) {
                            return Marker(
                              point: LatLng(p.latitude, p.longitude),
                              width: 50,
                              height: 50,
                              child: Icon(
                                Icons.dangerous,
                                color: cluster.color.withOpacity(0.9),
                                size: 40,
                                shadows: const [
                                  Shadow(
                                      color: Colors.black87,
                                      blurRadius: 10,
                                      offset: Offset(0, 2))
                                ],
                              ),
                            );
                          });
                        }).toList(),
                      ),
                      // Centroides grandes
                      MarkerLayer(
                        markers: clusters.map((c) {
                          return Marker(
                            point: c.centroid,
                            width: 80,
                            height: 80,
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.color.withOpacity(0.3),
                                shape: BoxShape.circle,
                                border: Border.all(color: c.color, width: 4),
                              ),
                              child: Center(
                                child: Text(
                                  "${c.points.length}",
                                  style: TextStyle(
                                    color: c.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add),
        onPressed: () {
          setState(() {
            k = k < 8 ? k + 1 : 3;
            _runKMeans();
          });
        },
      ),
    );
  }
}

// ================== K-MEANS REAL (no dummy) ==================
class Cluster {
  final List<WifiPoint> points;
  final Color color;
  late LatLng centroid;

  Cluster(this.points, this.color) {
    centroid = _calculateCentroid();
  }

  LatLng _calculateCentroid() {
    double lat = 0, lng = 0;
    for (var p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }
}

List<Cluster> kMeans(List<WifiPoint> points, int k) {
  if (points.isEmpty || k <= 0) return [];

  final random = Random();
  final colors = [
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.deepOrange,
    Colors.pink,
    Colors.teal,
    Colors.amber,
    Colors.cyan
  ];

  // Inicializar centroides aleatorios
  List<LatLng> centroids = [];
  for (int i = 0; i < k; i++) {
    final p = points[random.nextInt(points.length)];
    centroids.add(LatLng(p.latitude, p.longitude));
  }

  // Iterar 10 veces (suficiente)
  for (int iter = 0; iter < 10; iter++) {
    List<List<WifiPoint>> groups = List.generate(k, (_) => []);
    for (var point in points) {
      double minDist = double.infinity;
      int best = 0;
      for (int i = 0; i < k; i++) {
        final dist = _distance(point, centroids[i]);
        if (dist < minDist) {
          minDist = dist;
          best = i;
        }
      }
      groups[best].add(point);
    }

    // Recalcular centroides
    for (int i = 0; i < k; i++) {
      if (groups[i].isNotEmpty) {
        double lat = 0, lng = 0;
        for (var p in groups[i]) {
          lat += p.latitude;
          lng += p.longitude;
        }
        centroids[i] = LatLng(lat / groups[i].length, lng / groups[i].length);
      }
    }
  }

  // Crear clusters finales
  List<Cluster> result = [];
  for (int i = 0; i < k; i++) {
    final group = <WifiPoint>[];
    for (var point in points) {
      if (_distance(point, centroids[i]) <
          _distance(point, centroids[result.length])) {
        group.add(point);
      }
    }
    if (group.isNotEmpty) {
      result.add(Cluster(group, colors[i % colors.length]));
    }
  }

  return result;
}

double _distance(WifiPoint a, LatLng b) {
  final dx = a.latitude - b.latitude;
  final dy = a.longitude - b.longitude;
  return sqrt(dx * dx + dy * dy);
}
