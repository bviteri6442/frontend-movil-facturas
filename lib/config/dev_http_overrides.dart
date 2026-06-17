import 'dart:io';

import 'package:flutter/foundation.dart';

/// Permite el certificado HTTPS de desarrollo de ASP.NET Core (localhost).
/// Solo activo en modo debug; no usar en producción.
class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => kDebugMode;
  }
}
