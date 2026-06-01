import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
	static String get baseUrl => ApiConfig.baseUrl;

	Map<String, String> _headers({String? token}) {
		final headers = <String, String>{
			'Content-Type': 'application/json',
			'Accept': 'application/json',
		};
		if (token != null && token.isNotEmpty) {
			headers['Authorization'] = 'Bearer $token';
		}
		// En Flutter Web este header puede provocar preflight/CORS con ngrok.
		if (ApiConfig.skipNgrokWarning && !kIsWeb) {
			headers['ngrok-skip-browser-warning'] = 'true';
		}
		return headers;
	}

	Future<Map<String, dynamic>> getProductosPaginados({int page = 1, int limit = 30, String? search}) async {
		final prefs = await SharedPreferences.getInstance();
		final token = prefs.getString('authToken');
		if (token == null) {
			throw Exception('No autenticado');
		}
		String urlStr = '$baseUrl/productos?page=$page&limit=$limit';
		if (search != null && search.isNotEmpty) {
			urlStr += '&search=${Uri.encodeComponent(search)}';
		}
		final url = Uri.parse(urlStr);
		final response = await http.get(
			url,
			headers: _headers(token: token),
		);
		if (response.statusCode == 200) {
			final data = jsonDecode(response.body);
			return data;
		} else {
			throw Exception('Error al obtener productos: ${response.statusCode}');
		}
	}

	/// Guarda una venta en el backend
	Future<void> saveVenta({
		required int clienteId,
		required List<Map<String, dynamic>> detalles,
	}) async {
		final prefs = await SharedPreferences.getInstance();
		final token = prefs.getString('authToken');
		if (token == null) {
			throw Exception('No autenticado');
		}
		final url = Uri.parse('$baseUrl/Ventas');
		final body = jsonEncode({
			'clienteId': clienteId,
			'detalles': detalles,
		});
		final response = await http.post(
			url,
			headers: _headers(token: token),
			body: body,
		);
		if (response.statusCode != 200 && response.statusCode != 201) {
			throw Exception('Error al guardar venta: \n${response.statusCode}\n${response.body}');
		}
	}

	/// Obtiene el historial de ventas de un cliente
	Future<List<Map<String, dynamic>>> getVentasByClienteId(int clienteId) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.get(
			Uri.parse('$baseUrl/Ventas?clienteId=$clienteId'),
			headers: _headers(token: token),
		);
		if (response.statusCode == 200) {
			final List<dynamic> data = jsonDecode(response.body);
			return data.cast<Map<String, dynamic>>();
		}
		throw Exception('Error al obtener historial: ${response.statusCode}');
	}

	Future<Map<String, dynamic>> login(String email, String password) async {
		try {
			final url = Uri.parse('$baseUrl/Auth/login');
			final response = await http.post(
				url,
				headers: _headers(),
				body: jsonEncode({'email': email, 'contrasena': password}),
			);
			final data = jsonDecode(response.body);
			if (response.statusCode == 200 && data['exitoso'] == true) {
				// Guarda el token JWT
				final prefs = await SharedPreferences.getInstance();
				await prefs.setString('authToken', data['token']);
				// Construye el usuario con los campos correctos
				return {
					'success': true,
					'user': {
						'id': data['usuarioId'],
						'email': data['correo'],
						'nombre': data['nombreUsuario'],
						'apellido': '', // No viene en la respuesta, puedes dejarlo vacío o usar nombreCompleto
						'rol': data['rol'],
					}
				};
			} else {
				return {'success': false, 'message': data['mensaje'] ?? 'Error de autenticación'};
			}
		} catch (e) {
			final msg = e.toString();
			if (kIsWeb && (msg.contains('Failed to fetch') || msg.contains('CORS'))) {
				return {
					'success': false,
					'message':
						'Bloqueo CORS en navegador (ngrok + Flutter Web). '
						'Prueba en Windows/Android o usa backend en Railway.'
				};
			}
			return {'success': false, 'message': 'No se pudo conectar con el servidor.'};
		}
	}

	Future<void> logout() async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.remove('authToken');
	}

	Future<String?> getToken() async {
		final prefs = await SharedPreferences.getInstance();
		return prefs.getString('authToken');
	}

	/// Obtiene datos del usuario por ID
	Future<Map<String, dynamic>> getUsuarioById(int id) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.get(
			Uri.parse('$baseUrl/Usuarios/$id'),
			headers: _headers(token: token),
		);
		if (response.statusCode == 200) return jsonDecode(response.body);
		throw Exception('Error al obtener usuario: ${response.statusCode}');
	}

	/// Obtiene el cliente asociado a un usuario (retorna mapa vacío si no existe)
	Future<Map<String, dynamic>> getClienteByUserId(int userId) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.get(
			Uri.parse('$baseUrl/Clientes/by-user/$userId'),
			headers: _headers(token: token),
		);
		if (response.statusCode == 200) return jsonDecode(response.body);
		if (response.statusCode == 404) return {}; // Usuario sin registro de cliente
		throw Exception('Error al obtener cliente: ${response.statusCode}');
	}

	/// Agrega saldo al cliente
	Future<Map<String, dynamic>> agregarSaldo({required int clienteId, required double monto}) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.post(
			Uri.parse('$baseUrl/Clientes/$clienteId/agregar-saldo'),
			headers: _headers(token: token),
			body: jsonEncode({'monto': monto}),
		);
		if (response.statusCode == 200) return jsonDecode(response.body);
		Map<String, dynamic> err = {};
		try { if (response.body.isNotEmpty) err = jsonDecode(response.body); } catch (_) {}
		throw Exception(err['mensaje'] ?? 'Error al agregar saldo (${response.statusCode})');
	}

	/// Actualiza datos del usuario (nombre, apellido)
	Future<Map<String, dynamic>> updateUsuario(int id, Map<String, dynamic> datos) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.put(
			Uri.parse('$baseUrl/Usuarios/$id'),
			headers: _headers(token: token),
			body: jsonEncode(datos),
		);
		Map<String, dynamic> data = {};
		try { if (response.body.isNotEmpty) data = jsonDecode(response.body); } catch (_) {}
		if (response.statusCode == 200) return {'success': true, 'data': data};
		return {'success': false, 'message': data['mensaje'] ?? data['message'] ?? 'Error al actualizar usuario (${response.statusCode})'};
	}

	/// Actualiza datos personales del cliente (el propio usuario, sin rol admin)
	Future<Map<String, dynamic>> updateCliente(int id, Map<String, dynamic> datos) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.put(
			Uri.parse('$baseUrl/Clientes/$id/mi-perfil'),
			headers: _headers(token: token),
			body: jsonEncode(datos),
		);
		Map<String, dynamic> data = {};
		try { if (response.body.isNotEmpty) data = jsonDecode(response.body); } catch (_) {}
		if (response.statusCode == 200) return {'success': true, 'data': data};
		return {'success': false, 'message': data['mensaje'] ?? data['message'] ?? 'Error al actualizar perfil (${response.statusCode})'};
	}

	/// Cambia la contraseña del usuario
	Future<Map<String, dynamic>> cambiarContrasena({
		required int usuarioId,
		required String contrasenaActual,
		required String nuevaContrasena,
	}) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.post(
			Uri.parse('$baseUrl/Auth/cambiar-contrasena'),
			headers: _headers(token: token),
			body: jsonEncode({
				'usuarioId': usuarioId,
				'contrasenaActual': contrasenaActual,
				'nuevaContrasena': nuevaContrasena,
			}),
		);
		final data = jsonDecode(response.body);
		if (response.statusCode == 200) return {'success': true, 'message': data['mensaje'] ?? 'Contraseña actualizada'};
		return {'success': false, 'message': data['mensaje'] ?? 'Error al cambiar contraseña'};
	}

	/// Registro híbrido: crea usuario y cliente en una sola llamada
	Future<Map<String, dynamic>> registerUserAndClient({
		required String nombreUsuario,
		required String nombre,
		required String apellido,
		required String email,
		required String password,
		required String documento,
		required String direccion,
		required String telefono,
	}) async {
		final url = Uri.parse('$baseUrl/Auth/registro-hibrido');
		final response = await http.post(
			url,
			headers: _headers(),
			body: jsonEncode({
				'nombreUsuario': nombreUsuario,
				'nombre': nombre,
				'apellido': apellido,
				'email': email,
				'contrasena': password,
				'documento': documento,
				'direccion': direccion,
				'telefono': telefono,
			}),
		);
		try {
			final data = jsonDecode(response.body);
			if (response.statusCode == 200 || response.statusCode == 201) {
				return {'success': true, 'message': data['mensaje'] ?? 'Registro exitoso'};
			} else {
				return {'success': false, 'message': data['mensaje'] ?? 'Error en el registro'};
			}
		} catch (e) {
			return {'success': false, 'message': 'Respuesta inválida del servidor.'};
		}
	}

	/// Sube una imagen a Cloudinary y retorna la URL segura
	Future<String> uploadImageToCloudinary(List<int> bytes, String fileName) async {
		const cloudName = 'dotoxykvr';
		const uploadPreset = 'ml_default';
		final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
		final request = http.MultipartRequest('POST', url)
			..fields['upload_preset'] = uploadPreset
			..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
		final streamedResponse = await request.send();
		final response = await http.Response.fromStream(streamedResponse);
		if (response.statusCode == 200) {
			final data = jsonDecode(response.body);
			return data['secure_url'] as String;
		}
		String detail = '';
		try { detail = jsonDecode(response.body)['error']['message'] ?? ''; } catch (_) { detail = response.body; }
		throw Exception('Cloudinary ${response.statusCode}: $detail');
	}

	/// Actualiza la imagen de perfil del usuario en el backend
	Future<void> updateUsuarioImagen(int usuarioId, String imagenUrl) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.patch(
			Uri.parse('$baseUrl/Usuarios/$usuarioId/imagen'),
			headers: _headers(token: token),
			body: jsonEncode({'imagenUrl': imagenUrl}),
		);
		if (response.statusCode != 200 && response.statusCode != 204) {
			throw Exception('Error al actualizar imagen: ${response.statusCode}');
		}
	}
}
