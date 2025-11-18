import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wifi_point.dart';

class StorageService {
  static const String _key = 'wardriving_data';

  static Future<void> save(List<WifiPoint> points) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = points.map((p) => {
      'ssid': p.ssid,
      'security': p.security,
      'lat': p.latitude,
      'lon': p.longitude,
      'signal': p.signal,
      'mac': p.mac,
      'time': p.timestamp.toIso8601String(),
    }).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  static Future<List<WifiPoint>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];

    final List<dynamic> list = jsonDecode(data);
    return list.map((json) => WifiPoint(
      ssid: json['ssid'],
      security: json['security'],
      latitude: json['lat'],
      longitude: json['lon'],
      signal: json['signal'],
      mac: json['mac'],
      timestamp: DateTime.parse(json['time']),
    )).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}