import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  static String get username {
    final value = dotenv.env['ADAFRUIT_USERNAME'];
    if (value == null || value.isEmpty || value.contains('tu_usuario')) {
      throw Exception('Configura ADAFRUIT_USERNAME en el archivo .env');
    }
    return value.trim();
  }

  static String get aioKey {
    final value = dotenv.env['ADAFRUIT_KEY'];
    if (value == null || value.isEmpty || !value.startsWith('aio_')) {
      throw Exception('Configura ADAFRUIT_KEY válida en el archivo .env');
    }
    return value.trim();
  }

  static String get feed {
    final value = dotenv.env['ADAFRUIT_FEED'];
    return value?.trim() ?? 'sistemasembebidos';
  }

  static void validate() {
    username; // llama a los getters para validar
    aioKey;
    feed;
  }
}
