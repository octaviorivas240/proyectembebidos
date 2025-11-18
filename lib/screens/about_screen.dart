import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Acerca de")),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.wifi_lock, size: 100, color: Colors.deepPurple),
            SizedBox(height: 20),
            Text("Wardriving Pro", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text("v1.0", style: TextStyle(fontSize: 16)),
            SizedBox(height: 30),
            Text("Proyecto final - Sistemas Embebidos", textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
            SizedBox(height: 30),
            _Feature(text: "Mapa en tiempo real con MQTT"),
            _Feature(text: "Análisis K-Means de redes inseguras"),
            _Feature(text: "Cache offline"),
            _Feature(text: "Menú hamburguesa profesional"),
            Spacer(),
            Text("© 2025 - Uso ético y responsable", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String text;
  const _Feature({required this.text});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.check_circle, color: Colors.green),
      title: Text(text),
    );
  }
}