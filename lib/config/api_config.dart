/// URL base del API en desarrollo.
///
/// Windows / Web / iOS simulador:
///   http://localhost:56398/api  (HTTP, sin certificado)
///
/// Emulador Android:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:56398/api
///
/// Dispositivo físico (misma red que la PC):
///   flutter run --dart-define=API_BASE_URL=http://TU_IP_LAN:56398/api
class ApiConfig {
  /// URL base de la API (con /api).
  ///
  /// Ejemplos:
  /// - local: http://localhost:56398/api
  /// - ngrok: https://xxxx.ngrok-free.app/api
  /// - railway: https://tu-api.up.railway.app/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Producción Railway (override local: --dart-define=API_BASE_URL=http://localhost:56398/api)
    defaultValue: 'https://backend-facturas-production-a3ab.up.railway.app/api',
  );

  /// Activa encabezado para evitar página intermedia de ngrok.
  static const bool skipNgrokWarning = bool.fromEnvironment(
    'API_SKIP_NGROK_WARNING',
    defaultValue: true,
  );
}
