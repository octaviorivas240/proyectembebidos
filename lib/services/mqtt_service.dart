// lib/services/mqtt_service.dart
import 'package:flutter/foundation.dart'; // ← Necesario para debugPrint
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/wifi_point.dart';
import '../config.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  MqttServerClient? client;
  Function(List<WifiPoint>)? onNewData;
  bool _isConnected = false;

  Future<void> connect() async {
    if (_isConnected &&
        client?.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }

    client = MqttServerClient(
        'io.adafruit.com', 'flutter_${DateTime.now().millisecondsSinceEpoch}');
    client!.port = 1883;
    client!.keepAlivePeriod = 60;
    client!.autoReconnect = true;
    client!.resubscribeOnAutoReconnect = true;
    client!.logging(on: false);

    client!.connectionMessage = MqttConnectMessage()
        .authenticateAs(Config.username, Config.aioKey)
        .withClientIdentifier(
            'flutter_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      debugPrint('Conectando a MQTT (Adafruit IO)...');
      final connStatus = await client!.connect();

      if (connStatus?.state == MqttConnectionState.connected) {
        debugPrint('MQTT CONECTADO EXITOSAMENTE');
        _isConnected = true;

        final subscribeTopic = '${Config.username}/feeds/${Config.feed}';
        client!.subscribe(subscribeTopic, MqttQos.atLeastOnce);
        debugPrint('Suscrito a: $subscribeTopic');

        // FORZAR ÚLTIMO VALOR RETENIDO (CRUCIAL)
        final getTopic = '${Config.username}/f/get/${Config.feed}';
        client!.publishMessage(
          getTopic,
          MqttQos.atLeastOnce,
          MqttClientPayloadBuilder().addString('').payload!,
        );
        debugPrint('Solicitado último valor en: $getTopic');

        // ESCUCHA DE MENSAJES (AQUÍ ESTABA EL PROBLEMA DEL "View")
        client!.updates!
            .listen((List<MqttReceivedMessage<MqttMessage?>>? messages) {
          final recMess = messages![0].payload as MqttPublishMessage;
          String payload =
              MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

          if (payload.trim().isEmpty) return;

          String clean = payload.trim();

          // ELIMINAR "View" o "view" AL INICIO (insensible a mayúsculas)
          if (clean.toLowerCase().startsWith('view')) {
            clean = clean.substring(4);
            clean = clean.replaceFirst(
                RegExp(r'^[,\s]+'), ''); // quita comas o espacios después
          }

          // Limpiar saltos de línea
          clean = clean
              .replaceAll('\\n', '\n')
              .replaceAll('\\r', '\r')
              .replaceAll('\r', '')
              .trim();

          final List<WifiPoint> newPoints = [];

          for (var line in clean.split('\n')) {
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
                  mac: parts[5].trim(),
                  timestamp: DateTime.now(),
                );
                newPoints.add(point);
              } catch (e) {
                debugPrint('MQTT: Línea ignorada → $line | Error: $e');
              }
            }
          }

          if (newPoints.isNotEmpty) {
            debugPrint('MQTT: ${newPoints.length} puntos nuevos recibidos');
            onNewData?.call(newPoints);
          }
        });

        client!.onDisconnected = () {
          debugPrint('MQTT DESCONECTADO');
          _isConnected = false;
        };

        client!.onConnected = () {
          debugPrint('MQTT RECONECTADO');
          _isConnected = true;
        };
      }
    } catch (e) {
      debugPrint('Error MQTT: $e');
      _isConnected = false;
      rethrow;
    }
  }

  void disconnect() {
    if (client != null && _isConnected) {
      client!.disconnect();
      _isConnected = false;
      debugPrint('MQTT desconectado manualmente');
    }
  }
}
