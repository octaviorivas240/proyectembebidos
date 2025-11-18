// lib/services/adafruit_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/wifi_point.dart';
import '../config.dart';

class AdafruitService {
  static Future<List<WifiPoint>> fetchAllPoints() async {
    final url = Uri.parse(
        'https://io.adafruit.io/api/v2/${Config.username}/feeds/${Config.feed}/data?limit=100');

    try {
      debugPrint('Cargando últimos 100 valores del feed...');
      final response = await http.get(
        url,
        headers: {'X-AIO-Key': Config.aioKey},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('Error HTTP: ${response.statusCode}');
        return [];
      }

      final List<dynamic> data = json.decode(response.body);
      final Set<WifiPoint> allPoints = {};

      for (var item in data) {
        String raw = (item['value'] ?? '').toString().trim();
        if (raw.isEmpty) continue;

        // QUITAR "View" SI EXISTE (al inicio o en cualquier lado)
        raw = raw.replaceAll(RegExp(r'[Vv]iew', caseSensitive: false), '');
        raw = raw.replaceAll(
            RegExp(r'^[,\s]+'), ''); // limpiar comas/espacios al inicio

        // Convertir \n literales en saltos de línea reales
        raw = raw.replaceAll('\\n', '\n');

        for (var line in raw.split('\n')) {
          line = line.trim();
          if (line.isEmpty) continue;

          final parts = line.split(',');
          if (parts.length >= 6) {
            try {
              final point = WifiPoint(
                ssid: parts[0].trim(),
                security: parts[1].trim(),
                latitude: double.parse(parts[2].trim()),
                longitude: double.parse(parts[3].trim()),
                signal: int.parse(parts[4].trim()),
                mac: parts[5].trim().toLowerCase(),
                timestamp: DateTime.now(),
              );
              allPoints.add(point); // Set evita duplicados
            } catch (e) {
              // Ignorar línea rota
            }
          }
        }
      }

      final result = allPoints.toList();
      debugPrint(
          'TOTAL: ${result.length} puntos únicos cargados del historial');
      return result;
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      return [];
    }
  }
}
