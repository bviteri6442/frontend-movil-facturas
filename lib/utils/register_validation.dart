class RegisterValidation {
  static final RegExp _emailRe = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,4}$');
  static final RegExp _lettersRe = RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]');

  static String normalizeNombreUsuario(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s'), '');
    return cleaned.length <= 20 ? cleaned : cleaned.substring(0, 20);
  }

  static String normalizeNombre(String value) {
    final cleaned = _lettersRe.allMatches(value).map((m) => m.group(0)!).join();
    return cleaned.length <= 20 ? cleaned : cleaned.substring(0, 20);
  }

  static String normalizeApellido(String value) => normalizeNombre(value);

  static String normalizeEmail(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s'), '').toLowerCase();
    return cleaned.length <= 50 ? cleaned : cleaned.substring(0, 50);
  }

  static String normalizePassword(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s'), '');
    return cleaned.length <= 20 ? cleaned : cleaned.substring(0, 20);
  }

  static String normalizeDocumento(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 10 ? digits : digits.substring(0, 10);
  }

  static String normalizeTelefono(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 10 ? digits : digits.substring(0, 10);
  }

  static String normalizeDireccion(String value) {
    final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length <= 100 ? collapsed : collapsed.substring(0, 100);
  }

  static bool validarCedulaEcuatoriana(String cedula) {
    final cedulaLimpia = cedula.replaceAll(RegExp(r'[-\s]'), '');
    if (!RegExp(r'^\d{10}$').hasMatch(cedulaLimpia)) return false;
    if (RegExp(r'^(\d)\1{9}$').hasMatch(cedulaLimpia)) return false;
    final provincia = int.tryParse(cedulaLimpia.substring(0, 2));
    if (provincia == null || provincia < 1 || provincia > 24) return false;
    final tercerDigito = int.tryParse(cedulaLimpia[2]);
    if (tercerDigito == null || tercerDigito < 0 || tercerDigito > 9) return false;
    const factores = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    var suma = 0;
    for (var i = 0; i < 9; i++) {
      var producto = int.parse(cedulaLimpia[i]) * factores[i];
      if (producto >= 10) producto -= 9;
      suma += producto;
    }
    final residuo = suma % 10;
    final digitoVerificadorEsperado = residuo == 0 ? 0 : 10 - residuo;
    final digitoVerificadorRecibido = int.parse(cedulaLimpia[9]);
    return digitoVerificadorEsperado == digitoVerificadorRecibido;
  }

  static String? validateNombreUsuario(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingrese su nombre de usuario';
    if (v.contains(' ')) return 'No se permiten espacios';
    if (v.length < 4) return 'Mínimo 4 caracteres';
    return null;
  }

  static String? validateNombre(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingrese su nombre';
    if (v.contains(' ')) return 'No se permiten espacios';
    if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ]+$').hasMatch(v)) return 'Solo se permiten letras';
    if (v.length < 2) return 'Mínimo 2 letras';
    return null;
  }

  static String? validateApellido(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingrese su apellido';
    if (v.contains(' ')) return 'No se permiten espacios';
    if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ]+$').hasMatch(v)) return 'Solo se permiten letras';
    if (v.length < 2) return 'Mínimo 2 letras';
    return null;
  }

  static String? validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingrese su email';
    if (v.contains(' ')) return 'No se permiten espacios';
    if (!_emailRe.hasMatch(v)) return 'Email inválido';
    return null;
  }

  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingrese su contraseña';
    if (v.contains(' ')) return 'No se permiten espacios';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  static String? validateDocumento(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingrese su cédula';
    if (v.length != 10) return 'La cédula debe tener 10 dígitos';
    if (!validarCedulaEcuatoriana(v)) return 'Cédula ecuatoriana inválida';
    return null;
  }

  static String? validateDireccion(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Ingrese su dirección';
    return null;
  }

  static String? validateTelefono(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingrese su teléfono';
    if (v.length != 10) return 'El teléfono debe tener 10 dígitos';
    return null;
  }
}
