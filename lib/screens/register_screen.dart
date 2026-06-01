import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nombreUsuarioController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController apellidoController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController documentoController = TextEditingController();
  final TextEditingController direccionController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    nombreUsuarioController.dispose();
    nombreController.dispose();
    apellidoController.dispose();
    emailController.dispose();
    passwordController.dispose();
    documentoController.dispose();
    direccionController.dispose();
    telefonoController.dispose();
    super.dispose();
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) {
      // Mostrar error general en un Snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, corrige los errores en el formulario.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => isLoading = true);

    final api = ApiService();
    final result = await api.registerUserAndClient(
      nombreUsuario: nombreUsuarioController.text.trim(),
      nombre: nombreController.text.trim(),
      apellido: apellidoController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text,
      documento: documentoController.text.trim(),
      direccion: direccionController.text.trim(),
      telefono: telefonoController.text.trim(),
    );

    setState(() => isLoading = false);

    if (result['success']) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro exitoso. Ahora puedes iniciar sesión.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error en el registro'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Validador de cédula ecuatoriana (Dart)
  bool validarCedulaEcuatoriana(String cedula) {
    final cedulaLimpia = cedula.replaceAll('-', '').replaceAll(' ', '');
    if (!RegExp(r'^\d{10}$').hasMatch(cedulaLimpia)) return false;
    if (RegExp(r'^(\d)\1{9}$').hasMatch(cedulaLimpia)) return false;
    final provincia = int.tryParse(cedulaLimpia.substring(0, 2));
    if (provincia == null || provincia < 1 || provincia > 24) return false;
    final tercerDigito = int.tryParse(cedulaLimpia[2]);
    if (tercerDigito == null || tercerDigito < 0 || tercerDigito > 9) return false;
    final factores = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    int suma = 0;
    for (int i = 0; i < 9; i++) {
      int digito = int.parse(cedulaLimpia[i]);
      int producto = digito * factores[i];
      if (producto >= 10) producto -= 9;
      suma += producto;
    }
    final residuo = suma % 10;
    final digitoVerificadorEsperado = residuo == 0 ? 0 : 10 - residuo;
    final digitoVerificadorRecibido = int.parse(cedulaLimpia[9]);
    return digitoVerificadorEsperado == digitoVerificadorRecibido;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nombreUsuarioController,
                decoration: InputDecoration(labelText: 'Nombre de usuario'),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')), // Bloquea espacios
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingrese su nombre de usuario';
                  if (value.contains(' ')) return 'No se permiten espacios';
                  if (value.length < 4) return 'Mínimo 4 caracteres';
                  return null;
                },
              ),
              TextFormField(
                controller: nombreController,
                decoration: InputDecoration(labelText: 'Nombre'),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingrese su nombre';
                  if (value.contains(' ')) return 'No se permiten espacios';
                  if (value.length < 2) return 'Mínimo 2 letras';
                  return null;
                },
              ),
              TextFormField(
                controller: apellidoController,
                decoration: InputDecoration(labelText: 'Apellido'),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingrese su apellido';
                  if (value.contains(' ')) return 'No se permiten espacios';
                  if (value.length < 2) return 'Mínimo 2 letras';
                  return null;
                },
              ),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')), // Bloquea espacios
                  LengthLimitingTextInputFormatter(50),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingrese su email';
                  if (value.contains(' ')) return 'No se permiten espacios';
                  if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,4}$').hasMatch(value)) return 'Email inválido';
                  return null;
                },
              ),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')), // Bloquea espacios
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingrese su contraseña';
                  if (value.contains(' ')) return 'No se permiten espacios';
                  if (value.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              TextFormField(
                controller: documentoController,
                decoration: InputDecoration(labelText: 'Documento (Cédula)'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingrese su cédula';
                  if (value.length != 10) return 'La cédula debe tener 10 dígitos';
                  if (!validarCedulaEcuatoriana(value)) return 'Cédula ecuatoriana inválida';
                  return null;
                },
              ),
              TextFormField(
                controller: direccionController,
                decoration: InputDecoration(labelText: 'Dirección'),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(100),
                ],
                validator: (value) => value == null || value.isEmpty ? 'Ingrese su dirección' : null,
              ),
              TextFormField(
                controller: telefonoController,
                decoration: InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingrese su teléfono';
                  if (value.length != 10) return 'El teléfono debe tener 10 dígitos';
                  return null;
                },
              ),
              SizedBox(height: 20),
              isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Registrarse'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}