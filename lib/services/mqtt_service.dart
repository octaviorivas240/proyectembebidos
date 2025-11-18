import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/wifi_point.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  MqttServerClient? client;
  Function(List<WifiPoint>)? onNewData;

  // CAMBIA ESTOS DATOS CON LOS TUYOS
  final String username = "TU_USUARIO_ADAFRUIT";
  final String aioKey = "aio_TU_CLAVE_COMPLETA_AQUI";
  final String feed = "sistemasembebidos";

  Future<void> connect() async {
    client = MqttServerClient('io.adafruit.com', 'flutter_${DateTime.now().millisecondsSinceEpoch}');
    client!.port = 1883;
    client!.keepAlivePeriod = 30;
    client!.autoReconnect = true;

    final connMessage = MqttConnectMessage()
        .authenticateAs(username, aioKey)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client!.connectionMessage = connMessage;

    try {
      print('Conectando a Adafruit IO...');
      await client!.connect();
      print('¡Conectado!');

      final topic = '$username/feeds/$feed';
      client!.subscribe(topic, MqttQos.atLeastOnce);

      client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final points = _parsePayload(payload);
        if (points.isNotEmpty) onNewData?.call(points);
      });
    } catch (e) {
      print('Error MQTT: $e');
    }
  }

  List<WifiPoint> _parsePayload(String payload) {
    final List<WifiPoint> points = [];
    for (var line in payload.split('\n')) {
      line = line.trim();
      if (line.isEmpty || !line.contains(',')) continue;
      try {
        points.add(WifiPoint.fromCsv(line));
      } catch (e) {
        continue;
      }
    }
    return points;
  }

  void disconnect() => client?.disconnect();
}