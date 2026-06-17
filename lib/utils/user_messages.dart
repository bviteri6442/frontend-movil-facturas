/// Convierte errores técnicos en mensajes claros para el usuario.
String mensajeAmigable(Object? error) {
  if (error == null) return 'Ocurrió un error inesperado.';

  var texto = error.toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^Error:\s*'), '')
      .trim();

  final lower = texto.toLowerCase();

  if (lower.contains('expired') || lower.contains('vencid')) {
    return 'La tarjeta está vencida. Ingresa una fecha de vencimiento futura (MM/AA).';
  }
  if (lower.contains('raw card data') || lower.contains('integration surface')) {
    return 'Usa el formulario seguro de Stripe con una tarjeta de prueba (4242 4242 4242 4242).';
  }
  if (lower.contains('your card') || lower.contains('card number')) {
    return 'Revisa los datos de la tarjeta de prueba. Ejemplo: 4242 4242 4242 4242 con fecha futura.';
  }
  if (lower.contains('failed to fetch') || lower.contains('connection')) {
    return 'No hay conexión con el servidor. Verifica que el backend esté en ejecución.';
  }
  if (lower.contains('401') || lower.contains('no autenticado')) {
    return 'Tu sesión expiró. Cierra sesión e ingresa de nuevo.';
  }
  if (RegExp(r'tarjeta|dígitos|prueba|vencid|rechazad|obligatorio|inválid', caseSensitive: false).hasMatch(texto)) {
    return texto;
  }

  return texto.isEmpty ? 'Ocurrió un error. Intenta de nuevo.' : texto;
}

bool tarjetaVencidaLocal(String fechaMmYy) {
  final parts = fechaMmYy.split('/');
  if (parts.length != 2) return true;
  final mes = int.tryParse(parts[0]);
  var anio = int.tryParse(parts[1]);
  if (mes == null || anio == null || mes < 1 || mes > 12) return true;
  if (anio < 100) anio += 2000;
  final ahora = DateTime.now();
  if (anio < ahora.year) return true;
  return anio == ahora.year && mes < ahora.month;
}
