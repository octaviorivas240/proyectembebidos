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
}