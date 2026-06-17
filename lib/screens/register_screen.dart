import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/register_validation.dart';

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

  static const _errorStyle = TextStyle(color: Color(0xFFDC2626), fontSize: 12);
  static const _fieldDecoration = InputDecoration(
    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Color(0xFFD9E6D5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: AppColors.primaryDark, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Color(0xFFDC2626)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: Color(0xFFDC2626), width: 1.5),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    errorStyle: _errorStyle,
  );

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

  void _normalizeFields() {
    nombreUsuarioController.text = RegisterValidation.normalizeNombreUsuario(nombreUsuarioController.text);
    nombreController.text = RegisterValidation.normalizeNombre(nombreController.text);
    apellidoController.text = RegisterValidation.normalizeApellido(apellidoController.text);
    emailController.text = RegisterValidation.normalizeEmail(emailController.text);
    passwordController.text = RegisterValidation.normalizePassword(passwordController.text);
    documentoController.text = RegisterValidation.normalizeDocumento(documentoController.text);
    direccionController.text = RegisterValidation.normalizeDireccion(direccionController.text);
    telefonoController.text = RegisterValidation.normalizeTelefono(telefonoController.text);
  }

  void _register() async {
    _normalizeFields();
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, corrige los errores en el formulario.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => isLoading = true);

    final api = ApiService();
    final result = await api.registerUserAndClient(
      nombreUsuario: nombreUsuarioController.text,
      nombre: nombreController.text,
      apellido: apellidoController.text,
      email: emailController.text,
      password: passwordController.text,
      documento: documentoController.text,
      direccion: direccionController.text,
      telefono: telefonoController.text,
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscureText = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        decoration: _fieldDecoration.copyWith(labelText: label),
        keyboardType: keyboardType,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              _buildField(
                controller: nombreUsuarioController,
                label: 'Nombre de usuario',
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: RegisterValidation.validateNombreUsuario,
              ),
              _buildField(
                controller: nombreController,
                label: 'Nombre',
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: RegisterValidation.validateNombre,
              ),
              _buildField(
                controller: apellidoController,
                label: 'Apellido',
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: RegisterValidation.validateApellido,
              ),
              _buildField(
                controller: emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(50),
                ],
                validator: RegisterValidation.validateEmail,
              ),
              _buildField(
                controller: passwordController,
                label: 'Contraseña',
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: RegisterValidation.validatePassword,
              ),
              _buildField(
                controller: documentoController,
                label: 'Documento (Cédula)',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: RegisterValidation.validateDocumento,
              ),
              _buildField(
                controller: direccionController,
                label: 'Dirección',
                inputFormatters: [
                  LengthLimitingTextInputFormatter(100),
                ],
                validator: RegisterValidation.validateDireccion,
              ),
              _buildField(
                controller: telefonoController,
                label: 'Teléfono',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: RegisterValidation.validateTelefono,
              ),
              const SizedBox(height: 8),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Registrarse'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
