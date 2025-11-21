// lib/models/wifi_point.dart → VERSIÓN FINAL OFICIAL 100% FUNCIONAL
class WifiPoint {
  final String ssid;
  final String security;
  final double latitude;
  final double longitude;
  final int signal;
  final String mac;
  final DateTime timestamp;

  WifiPoint({
    required this.ssid,
    required this.security,
    required this.latitude,
    required this.longitude,
    required this.signal,
    required this.mac,
    required this.timestamp,
  });

  // Detecta redes abiertas o con WEP
  bool get isInsecure => security == "Abierta" || security == "WEP";

  // Desde CSV del Pico W
  factory WifiPoint.fromCsv(String line) {
    final parts = line.split(',');
    if (parts.length < 6) {
      throw Exception("Formato CSV inválido: $line");
    }

    return WifiPoint(
      ssid: parts[0].trim(),
      security: parts[1].trim(),
      latitude: double.parse(parts[2]),
      longitude: double.parse(parts[3]),
      signal: int.parse(parts[4]),
      mac: parts[5].trim(),
      timestamp: DateTime.now(),
    );
  }

  // ← NUEVO: Para guardar en caché
  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'security': security,
        'lat': latitude,
        'lng': longitude,
        'signal': signal,
        'mac': mac,
      };

  // ← NUEVO: Para cargar desde caché
  factory WifiPoint.fromJson(Map<String, dynamic> json) => WifiPoint(
        ssid: json['ssid'] as String? ?? 'Hidden',
        security: json['security'] as String? ?? 'Desconocida',
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        signal: (json['signal'] as num?)?.toInt() ?? -100,
        mac: json['mac'] as String? ?? '00:00:00:00:00:00',
        timestamp: DateTime.now(),
      );
}
