// lib/services/storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wifi_point.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static const String _key = 'wardriving_data';

  static Future<void> save(List<WifiPoint> points) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = points
          .map((p) => {
                'ssid': p.ssid,
                'security': p.security,
                'lat': p.latitude,
                'lon': p.longitude,
                'signal': p.signal,
                'mac': p.mac,
                'time': p.timestamp.toIso8601String(),
              })
          .toList();

      await prefs.setString(_key, jsonEncode(jsonList));
      debugPrint('Guardados ${points.length} puntos en caché local');
    } catch (e) {
      debugPrint('Error al guardar caché: $e');
    }
  }

  static Future<List<WifiPoint>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);

      if (data == null || data.isEmpty) return [];

      final List<dynamic> list = jsonDecode(data);
      final List<WifiPoint> points = [];

      for (var json in list) {
        try {
          // Validación segura campo por campo
          if (json is Map<String, dynamic> &&
              json['ssid'] is String &&
              json['security'] is String &&
              json['lat'] is num &&
              json['lon'] is num &&
              json['signal'] is int &&
              json['mac'] is String &&
              json['time'] is String) {
            points.add(WifiPoint(
              ssid: json['ssid'] as String,
              security: json['security'] as String,
              latitude: (json['lat'] as num).toDouble(),
              longitude: (json['lon'] as num).toDouble(),
              signal: json['signal'] as int,
              mac: json['mac'] as String,
              timestamp: DateTime.parse(json['time'] as String),
            ));
          }
        } catch (e) {
          // Ignorar punto corrupto, pero seguir con los demás
          debugPrint('Punto corrupto ignorado en caché: $e');
        }
      }

      debugPrint('Cargados ${points.length} puntos desde caché');
      return points;
    } catch (e) {
      debugPrint('Error al leer caché: $e');
      return [];
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      debugPrint('Caché borrada');
    } catch (e) {
      debugPrint('Error al borrar caché: $e');
    }
  }
}
