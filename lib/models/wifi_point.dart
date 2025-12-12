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

  factory WifiPoint.fromCsv(String line) {
    final parts = line.split(',');
    if (parts.length < 6) throw Exception("Formato inválido");

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

  bool get isInsecure => security == "Abierta" || security == "WEP";

  // ← ESTOS DOS MÉTODOS SON LOS QUE FALTABAN
  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'security': security,
        'lat': latitude,
        'lng': longitude,
        'signal': signal,
        'mac': mac,
      };

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
