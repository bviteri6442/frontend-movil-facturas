import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
	const LoginScreen({Key? key}) : super(key: key);

	@override
	State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
	final _formKey = GlobalKey<FormState>();
	final TextEditingController _emailController = TextEditingController();
	final TextEditingController _passwordController = TextEditingController();
	bool _obscurePassword = true;
	String? _errorMessage;
	bool _isLoading = false;

	@override
	void dispose() {
		_emailController.dispose();
		_passwordController.dispose();
		super.dispose();
	}

	void _togglePasswordVisibility() {
		setState(() {
			_obscurePassword = !_obscurePassword;
		});
	}



	void _login() async {
		if (!_formKey.currentState!.validate()) return;
		if (_isLoading) return;
		setState(() {
			_isLoading = true;
			_errorMessage = null;
		});
		try {
			final api = ApiService();
			final result = await api.login(_emailController.text.trim(), _passwordController.text);
			if (!mounted) return;
			setState(() {
				_isLoading = false;
			});
			if (result['success'] == true && result['user'] != null) {
				try {
					final user = User.fromJson(result['user']);
					if (!mounted) return;
					Navigator.pushReplacementNamed(context, '/catalog', arguments: user);
				} catch (e) {
					if (!mounted) return;
					setState(() {
						_errorMessage = 'Error al procesar los datos del usuario.';
					});
				}
			} else {
				setState(() {
					_errorMessage = result['message'] ?? 'Error de autenticación';
				});
			}
		} catch (e) {
			if (!mounted) return;
			setState(() {
				_isLoading = false;
				_errorMessage = 'No se pudo conectar al backend. Verifica URL API/CORS/ngrok.';
			});
		}
	}

	void _goToRegister() {
		Navigator.pushNamed(context, '/register');
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			body: Center(
				child: SingleChildScrollView(
					padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							const Icon(Icons.shopping_cart, size: 64, color: AppColors.primaryDark),
							const SizedBox(height: 16),
							const Text(
								'Iniciar Sesión',
								style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text),
							),
							const SizedBox(height: 8),
							const Text(
								'Bienvenido a PuntoVenta',
								style: TextStyle(fontSize: 16, color: Colors.black54),
							),
							const SizedBox(height: 32),
							Form(
								key: _formKey,
								child: Column(
									children: [
										TextFormField(
											controller: _emailController,
											keyboardType: TextInputType.emailAddress,
											decoration: const InputDecoration(
												labelText: 'Correo electrónico',
												prefixIcon: Icon(Icons.email),
												border: OutlineInputBorder(),
											),
											validator: (value) {
												if (value == null || value.isEmpty) {
													return 'Ingrese su correo';
												}
												if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
													return 'Correo inválido';
												}
												return null;
											},
										),
										const SizedBox(height: 20),
										TextFormField(
											controller: _passwordController,
											obscureText: _obscurePassword,
											decoration: InputDecoration(
												labelText: 'Contraseña',
												prefixIcon: const Icon(Icons.lock),
												border: const OutlineInputBorder(),
												suffixIcon: IconButton(
													icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
													onPressed: _togglePasswordVisibility,
												),
											),
											validator: (value) {
												if (value == null || value.isEmpty) {
													return 'Ingrese su contraseña';
												}
												if (value.length < 6 || value.length > 16) {
													return 'La contraseña debe tener entre 6 y 16 caracteres';
												}
												return null;
											},
										),
										const SizedBox(height: 12),
										if (_errorMessage != null)
											Padding(
												padding: const EdgeInsets.only(bottom: 8),
												child: Text(
													_errorMessage!,
													style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
												),
											),
										SizedBox(
											width: double.infinity,
											child: ElevatedButton(
												onPressed: _isLoading ? null : _login,
												style: ElevatedButton.styleFrom(
													backgroundColor: AppColors.primary, foregroundColor: Colors.white,
													padding: const EdgeInsets.symmetric(vertical: 16),
													shape: RoundedRectangleBorder(
														borderRadius: BorderRadius.circular(8),
													),
												),
												child: _isLoading
														? const SizedBox(
																width: 24,
																height: 24,
																child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
															)
														: const Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
											),
										),
									],
								),
							),
							const SizedBox(height: 16),
							Row(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									const Text('¿No tienes cuenta?'),
									TextButton(
										onPressed: _goToRegister,
										style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
										child: const Text('Regístrate'),
									),
								],
							),
						],
					),
				),
			),
		);
	}
}
