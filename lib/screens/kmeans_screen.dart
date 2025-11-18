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
  int k = 3;

  List<int> _kmeans(List<WifiPoint> points, int k) {
    if (points.isEmpty) return [];
    final n = points.length;
    List<int> labels = List.filled(n, 0);
    List<double> clat = List.filled(k, points[0].latitude);
    List<double> clon = List.filled(k, points[0].longitude);

    for (int iter = 0; iter < 15; iter++) {
      for (int i = 0; i < n; i++) {
        double minDist = double.infinity;
        int best = 0;
        for (int c = 0; c < k; c++) {
          double d = (points[i].latitude - clat[c]).abs() +
              (points[i].longitude - clon[c]).abs();
          if (d < minDist) {
            minDist = d;
            best = c;
          }
        }
        labels[i] = best;
      }
      List<int> count = List.filled(k, 0);
      clat = List.filled(k, 0);
      clon = List.filled(k, 0);
      for (int i = 0; i < n; i++) {
        int c = labels[i];
        clat[c] += points[i].latitude;
        clon[c] += points[i].longitude;
        count[c]++;
      }
      for (int c = 0; c < k; c++) {
        if (count[c] > 0) {
          clat[c] /= count[c];
          clon[c] /= count[c];
        }
      }
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final insecure = widget.points.where((p) => p.isInsecure).toList();
    final labels = _kmeans(insecure, k);
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.cyan
    ];

    final markers = insecure.asMap().entries.map((e) {
      final p = e.value;
      final cluster = labels[e.key];
      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: 60,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            color: colors[cluster % colors.length].withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Center(
              child: Text("$cluster",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18))),
        ),
      );
    }).toList();

    return Scaffold(
      body: insecure.isEmpty
          ? const Center(
              child: Text("No hay redes inseguras",
                  style: TextStyle(fontSize: 22)))
          : FlutterMap(
              options: MapOptions(
                  center: LatLng(insecure[0].latitude, insecure[0].longitude),
                  zoom: 14),
              children: [
                TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c']),
                MarkerLayer(markers: markers),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        child: Text("$k", style: const TextStyle(fontSize: 20)),
        onPressed: () => setState(() => k = k >= 6 ? 2 : k + 1),
      ),
    );
  }
}
