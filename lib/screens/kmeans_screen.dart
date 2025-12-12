// lib/screens/kmeans_screen.dart → FINAL 100% FUNCIONAL (SIN ERRORES)
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
  int k = 4;
  Cluster? selectedCluster;

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
    selectedCluster = null;
    setState(() {});
  }

  void _showClusterDetails(Cluster cluster) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.dangerous, color: cluster.color, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Cluster • ${cluster.points.length} redes abiertas",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: cluster.points.length,
                  itemBuilder: (context, i) {
                    final p = cluster.points[i];
                    return Card(
                      color: Colors.grey[850],
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cluster.color,
                          child: Text(
                            "${p.signal}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(p.ssid,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        subtitle: Text(
                          "${p.security} • ${p.mac}\n${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}",
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openCount = widget.allPoints.where((p) => p.isInsecure).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("K-Means - Redes Inseguras"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _runKMeans),
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
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Column(
              children: [
                Text("Análisis de $openCount redes abiertas",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Se formaron ${clusters.length} clusters de riesgo",
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: clusters.map((c) {
                    return GestureDetector(
                      onTap: () => _showClusterDetails(c),
                      child: Chip(
                        backgroundColor: c.color.withAlpha(200),
                        avatar: CircleAvatar(backgroundColor: c.color),
                        label: Text("${c.points.length} redes",
                            style: const TextStyle(color: Colors.white)),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_moon, size: 80, color: Colors.green),
                        SizedBox(height: 20),
                        Text("¡No hay redes inseguras!",
                            style:
                                TextStyle(fontSize: 22, color: Colors.green)),
                        Text("Excelente seguridad en la zona",
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  )
                : FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(21.8824, -102.2916),
                      initialZoom: 13.5,
                    ),
                    children: [
                      TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                      MarkerLayer(
                        markers: clusters
                            .expand((c) => c.points.map((p) => Marker(
                                  point: LatLng(p.latitude, p.longitude),
                                  width: 50,
                                  height: 50,
                                  child: GestureDetector(
                                    onTap: () => _showClusterDetails(c),
                                    child: Icon(Icons.dangerous,
                                        color: c.color.withAlpha(230),
                                        size: 40),
                                  ),
                                )))
                            .toList(),
                      ),
                      MarkerLayer(
                        markers: clusters
                            .map((c) => Marker(
                                  point: c.centroid,
                                  width: 100,
                                  height: 100,
                                  child: GestureDetector(
                                    onTap: () => _showClusterDetails(c),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: c.color.withAlpha(80),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: c.color, width: 5),
                                      ),
                                      child: Center(
                                        child: Text("${c.points.length}",
                                            style: TextStyle(
                                                color: c.color,
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
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

// ================== K-MEANS 100% FUNCIONAL Y CORREGIDO ==================
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

  // Inicializar centroides
  List<LatLng> centroids = [];
  for (int i = 0; i < k; i++) {
    final p = points[random.nextInt(points.length)];
    centroids.add(LatLng(p.latitude, p.longitude));
  }

  // 12 iteraciones
  List<List<WifiPoint>> groups = [];
  for (int iter = 0; iter < 12; iter++) {
    groups = List.generate(k, (_) => <WifiPoint>[]);

    for (var point in points) {
      int bestIndex = 0;
      double bestDistance = double.infinity;

      for (int i = 0; i < k; i++) {
        final distance = sqrt(pow(point.latitude - centroids[i].latitude, 2) +
            pow(point.longitude - centroids[i].longitude, 2));
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = i;
        }
      }
      groups[bestIndex].add(point);
    }

    // Recalcular centroides
    for (int i = 0; i < k; i++) {
      if (groups[i].isNotEmpty) {
        double sumLat = 0, sumLng = 0;
        for (var p in groups[i]) {
          sumLat += p.latitude;
          sumLng += p.longitude;
        }
        centroids[i] =
            LatLng(sumLat / groups[i].length, sumLng / groups[i].length);
      }
    }
  }

  // Crear clusters finales
  return groups
      .asMap()
      .entries
      .map((entry) {
        final group = entry.value;
        if (group.isEmpty) return null;
        return Cluster(group, colors[entry.key % colors.length]);
      })
      .whereType<Cluster>()
      .toList();
}
