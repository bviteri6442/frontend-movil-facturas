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
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:56398/api',
  );
}
