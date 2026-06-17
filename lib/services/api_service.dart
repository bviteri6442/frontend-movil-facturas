import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';

class ApiService {
	static const String _authTokenKey = 'authToken';
	static const String _currentUserKey = 'currentUser';

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

	/// Obtiene un producto por ID consultando el catálogo paginado.
	/// El backend no expone GET /productos/{id} (devuelve 405), por eso
	/// se busca por nombre y se filtra por [id].
	Future<Map<String, dynamic>> getProductoById(int id, {String? nombre}) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');

		if (nombre != null && nombre.trim().isNotEmpty) {
			final found = await _buscarProductoEnCatalogo(
				id: id,
				search: nombre.trim(),
			);
			if (found != null) return found;
		}

		final scanned = await _buscarProductoEnCatalogo(id: id);
		if (scanned != null) return scanned;

		throw Exception('Producto no encontrado (id: $id)');
	}

	Future<Map<String, dynamic>?> _buscarProductoEnCatalogo({
		required int id,
		String? search,
	}) async {
		const limit = 100;
		const maxPages = 120;
		var page = 1;
		var total = 0;

		while (page <= maxPages) {
			final data = await getProductosPaginados(
				page: page,
				limit: limit,
				search: search,
			);
			final batch = _extractProductList(data);
			if (page == 1) {
				total = (data['total'] as num?)?.toInt() ?? batch.length;
			}

			for (final producto in batch) {
				if (_productIdFrom(producto) == id) {
					return producto;
				}
			}

			if (batch.isEmpty || page * limit >= total) break;
			page++;
		}
		return null;
	}

	List<Map<String, dynamic>> _extractProductList(dynamic data) {
		if (data is! Map<String, dynamic>) return [];
		final list = data['data'] ?? data['productos'];
		if (list is! List) return [];
		return list
			.whereType<Map>()
			.map((e) => Map<String, dynamic>.from(e))
			.toList();
	}

	int _productIdFrom(Map<String, dynamic> producto) {
		final raw = producto['id'] ?? producto['productoId'];
		if (raw is int) return raw;
		if (raw is num) return raw.toInt();
		return int.tryParse('$raw') ?? 0;
	}

	Future<Map<String, dynamic>> getProductosPaginados({
		int page = 1,
		int limit = 30,
		String? search,
		String? codigo,
		String? sort,
		bool soloCatalogo = false,
		bool bustCache = false,
	}) async {
		final token = await getToken();
		if (token == null) {
			throw Exception('No autenticado');
		}
		final params = <String, String>{
			'page': '$page',
			'limit': '$limit',
			'_': '${DateTime.now().millisecondsSinceEpoch}',
		};
		if (search != null && search.isNotEmpty) {
			params['search'] = search;
		}
		if (codigo != null && codigo.isNotEmpty) {
			params['codigo'] = codigo;
		}
		if (sort != null && sort.isNotEmpty) {
			params['sort'] = sort;
		}
		if (soloCatalogo) {
			params['soloCatalogo'] = 'true';
		}
		final url = Uri.parse('$baseUrl/productos').replace(queryParameters: params);
		// En Flutter Web, Cache-Control/Pragma provocan fallo CORS en preflight.
		final response = await http.get(
			url,
			headers: _headers(token: token),
		);
		if (response.statusCode == 200) {
			final decoded = jsonDecode(response.body);
			if (decoded is Map<String, dynamic>) return decoded;
			if (decoded is Map) return Map<String, dynamic>.from(decoded);
			throw Exception('Respuesta de productos inválida');
		} else {
			throw Exception('Error al obtener productos: ${response.statusCode}');
		}
	}

	/// Recorre páginas del catálogo (fallback; el modo normal usa paginación directa).
	Future<List<Map<String, dynamic>>> scanProductosCatalogo({
		int maxPages = 200,
		int limit = 100,
	}) async {
		final seen = <int, Map<String, dynamic>>{};
		var page = 1;
		var totalPages = 1;

		while (page <= totalPages && page <= maxPages) {
			final data = await getProductosPaginados(
				page: page,
				limit: limit,
				sort: 'recientes',
				soloCatalogo: true,
			);
			if (page == 1) {
				final total = (data['total'] as num?)?.toInt() ?? 0;
				totalPages = total <= 0 ? 1 : (total / limit).ceil();
			}
			final items = _extractProductList(data);
			if (items.isEmpty) break;
			for (final producto in items) {
				final id = _productIdFrom(producto);
				if (id > 0) seen[id] = producto;
			}
			page++;
		}

		return seen.values.toList();
	}

	/// Guarda una venta en el backend
	Future<void> saveVenta({
		required int clienteId,
		required List<Map<String, dynamic>> detalles,
	}) async {
		final token = await getToken();
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

	/// Obtiene el historial de ventas de un cliente (API paginada: { total, page, limit, data })
	Future<List<Map<String, dynamic>>> getVentasByClienteId(int clienteId) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');

		final all = <Map<String, dynamic>>[];
		var page = 1;
		const limit = 100;
		var total = 0;

		while (page <= 50) {
			final uri = Uri.parse(
				'$baseUrl/Ventas?clienteId=$clienteId&page=$page&limit=$limit',
			);
			final response = await http.get(uri, headers: _headers(token: token));
			if (response.statusCode != 200) {
				throw Exception('Error al obtener historial: ${response.statusCode}');
			}
			final decoded = jsonDecode(response.body);
			final batch = _extractListFromResponse(decoded);
			if (page == 1 && decoded is Map<String, dynamic>) {
				total = (decoded['total'] as num?)?.toInt() ?? batch.length;
			}
			all.addAll(batch);
			if (batch.isEmpty || all.length >= total) break;
			page++;
		}
		return all;
	}

	/// Detalle de una venta/factura (incluye líneas de productos).
	Future<Map<String, dynamic>> getVentaById(int ventaId) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');

		final response = await http.get(
			Uri.parse('$baseUrl/Ventas/$ventaId'),
			headers: _headers(token: token),
		);
		if (response.statusCode == 200) {
			return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
		}
		if (response.statusCode == 404) {
			throw Exception('Factura no encontrada');
		}
		throw Exception('Error al obtener detalle de factura: ${response.statusCode}');
	}

	List<Map<String, dynamic>> _extractListFromResponse(dynamic decoded) {
		if (decoded is List) {
			return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
		}
		if (decoded is Map<String, dynamic>) {
			final list = decoded['data'];
			if (list is List) {
				return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
			}
		}
		return [];
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
				final prefs = await SharedPreferences.getInstance();
				await prefs.setString(_authTokenKey, data['token']);
				final userMap = {
					'id': data['usuarioId'],
					'email': data['correo'],
					'nombre': data['nombreUsuario'],
					'apellido': '',
					'rol': data['rol'],
					if (data['imagenUrl'] != null && '$data[imagenUrl]'.isNotEmpty)
						'imagenUrl': data['imagenUrl'],
				};
				await prefs.setString(_currentUserKey, jsonEncode(userMap));
				return {'success': true, 'user': userMap};
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
			return {
				'success': false,
				'message':
					'No se pudo conectar con el servidor (${ApiConfig.baseUrl}). '
					'Verifica que el backend Python esté en ejecución (manage.py runserver 56402).'
			};
		}
	}

	Future<void> logout() async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.remove(_authTokenKey);
		await prefs.remove(_currentUserKey);
	}

	Future<String?> getToken() async {
		final prefs = await SharedPreferences.getInstance();
		return prefs.getString(_authTokenKey);
	}

	Future<User?> getStoredUser() async {
		final prefs = await SharedPreferences.getInstance();
		final raw = prefs.getString(_currentUserKey);
		if (raw == null || raw.isEmpty) return null;
		try {
			final map = jsonDecode(raw);
			if (map is Map<String, dynamic>) return User.fromJson(map);
			if (map is Map) return User.fromJson(Map<String, dynamic>.from(map));
		} catch (_) {}
		return null;
	}

	Future<void> saveCurrentUser(User user) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
	}

	Future<String?> getAvatarUrl(int usuarioId) async {
		final prefs = await SharedPreferences.getInstance();
		return prefs.getString('avatar_$usuarioId');
	}

	Future<void> _saveAvatarUrl(int usuarioId, String imagenUrl) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setString('avatar_$usuarioId', imagenUrl);
	}

	/// Obtiene datos del usuario por ID
	Future<Map<String, dynamic>> getUsuarioById(int id, {User? fallbackUser}) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.get(
			Uri.parse('$baseUrl/Usuarios/$id'),
			headers: _headers(token: token),
		);
		if (response.statusCode == 200) {
			final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
			final localAvatar = await getAvatarUrl(id);
			final imagen = body['imagenUrl'];
			if ((imagen == null || imagen.toString().isEmpty) &&
					localAvatar != null &&
					localAvatar.isNotEmpty) {
				body['imagenUrl'] = localAvatar;
			}
			return body;
		}

		// Backend Python: /Usuarios/{id} requiere admin.
		if (response.statusCode == 403 || response.statusCode == 404) {
			final user = fallbackUser ?? await getStoredUser();
			if (user != null && user.id == id) {
				Map<String, dynamic> cliente = {};
				try {
					cliente = await getClienteByUserId(id);
				} catch (_) {}
				final localAvatar = await getAvatarUrl(id);
				return {
					'id': user.id,
					'nombreUsuario': user.nombre,
					'nombre': cliente['nombre'] ?? user.nombre,
					'apellido': cliente['apellido'] ?? user.apellido,
					'email': user.email,
					'imagenUrl': localAvatar ?? user.imagenUrl,
				};
			}
		}
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
		if (response.statusCode == 403) {
			return {
				'success': true,
				'message': 'Perfil de usuario actualizado localmente (sin permisos admin).',
			};
		}
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

	/// Perfil del usuario autenticado (sin permiso admin).
	Future<Map<String, dynamic>> getMiPerfil() async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.get(
			Uri.parse('$baseUrl/Auth/mi-perfil'),
			headers: _headers(token: token),
		);
		if (response.statusCode == 200) {
			return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
		}
		throw Exception('Error al obtener perfil: ${response.statusCode}');
	}

	/// Configuración pública de Stripe (modo test).
	Future<Map<String, dynamic>> getPagosConfig() async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.get(
			Uri.parse('$baseUrl/Pagos/config'),
			headers: _headers(token: token),
		);
		if (response.statusCode == 200) {
			return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
		}
		throw Exception('No se pudo obtener la configuración de pagos.');
	}

	/// Valida PaymentMethod de Stripe en el backend.
	Future<Map<String, dynamic>> validarPaymentMethod(String paymentMethodId) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.post(
			Uri.parse('$baseUrl/Pagos/validar-payment-method'),
			headers: _headers(token: token),
			body: jsonEncode({'paymentMethodId': paymentMethodId}),
		);
		final data = jsonDecode(response.body);
		if (response.statusCode == 200 && data is Map && data['valido'] == true) {
			return Map<String, dynamic>.from(data);
		}
		final msg = data is Map ? (data['mensaje'] ?? 'Tarjeta inválida') : 'Tarjeta inválida';
		throw Exception(msg);
	}

	/// Checkout móvil: Stripe + venta (solo apps móviles).
	Future<Map<String, dynamic>> checkoutMovil({
		required int clienteId,
		required List<Map<String, dynamic>> detalles,
		required String paymentMethodId,
		required double montoTotal,
	}) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');
		final response = await http.post(
			Uri.parse('$baseUrl/Pagos/checkout-movil'),
			headers: _headers(token: token),
			body: jsonEncode({
				'clienteId': clienteId,
				'detalles': detalles,
				'paymentMethodId': paymentMethodId,
				'montoTotal': montoTotal,
			}),
		);
		final data = jsonDecode(response.body);
		if (response.statusCode == 201) {
			return data is Map ? Map<String, dynamic>.from(data) : {'facturaId': data};
		}
		final msg = data is Map ? (data['mensaje'] ?? 'Error en checkout') : 'Error en checkout';
		throw Exception(msg);
	}

	/// Actualiza la imagen de perfil del usuario en el backend
	Future<void> updateUsuarioImagen(int usuarioId, String imagenUrl) async {
		final token = await getToken();
		if (token == null) throw Exception('No autenticado');

		var response = await http.patch(
			Uri.parse('$baseUrl/Auth/mi-imagen'),
			headers: _headers(token: token),
			body: jsonEncode({'imagenUrl': imagenUrl}),
		);
		if (response.statusCode == 200 || response.statusCode == 204) {
			await _saveAvatarUrl(usuarioId, imagenUrl);
			return;
		}

		response = await http.patch(
			Uri.parse('$baseUrl/Usuarios/$usuarioId/imagen'),
			headers: _headers(token: token),
			body: jsonEncode({'imagenUrl': imagenUrl}),
		);
		if (response.statusCode != 200 && response.statusCode != 204) {
			if (response.statusCode == 403) {
				await _saveAvatarUrl(usuarioId, imagenUrl);
				return;
			}
			throw Exception('Error al actualizar imagen: ${response.statusCode}');
		}
		await _saveAvatarUrl(usuarioId, imagenUrl);
	}
}
