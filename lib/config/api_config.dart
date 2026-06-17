import 'package:flutter/foundation.dart';

/// URL base del API PuntoVenta (backend Python / Django).
///
/// Backend local: http://127.0.0.1:56402/
/// API REST:      http://127.0.0.1:56402/api
///
/// Override en ejecución:
///   flutter run --dart-define=API_BASE_URL=http://TU_IP:56402/api
class ApiConfig {
  /// Backend local (Windows, Web, iOS, Linux, macOS en la misma PC).
  static const String _localHttps = 'http://127.0.0.1:56402/api';

  /// Emulador Android: `localhost` apunta al emulador, no a la PC.
  static const String _androidEmulatorHttps = 'http://10.0.2.2:56402/api';

  /// URL base de la API (debe terminar en `/api`).
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidEmulatorHttps;
    }
    return _localHttps;
  }

  /// Swagger / schema del backend (solo referencia / depuración).
  static String get swaggerUrl {
    const fromEnv = String.fromEnvironment('SWAGGER_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'http://127.0.0.1:56402/api/schema/swagger-ui/';
  }

  /// Activa encabezado para evitar página intermedia de ngrok.
  static const bool skipNgrokWarning = bool.fromEnvironment(
    'API_SKIP_NGROK_WARNING',
    defaultValue: true,
  );
}
