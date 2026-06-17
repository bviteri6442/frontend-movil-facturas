class User {
	final int id;
	final String email;
	final String nombre;
	final String apellido;
	final String rol;
	final String? imagenUrl;

	User({
		required this.id,
		required this.email,
		required this.nombre,
		required this.apellido,
		required this.rol,
		this.imagenUrl,
	});

	factory User.fromJson(Map<String, dynamic> json) => User(
				id: (json['id'] as num?)?.toInt() ?? 0,
				email: json['email'] ?? '',
				nombre: json['nombre'] ?? '',
				apellido: json['apellido'] ?? '',
				rol: json['rol'] ?? '',
				imagenUrl: json['imagenUrl'] as String?,
			);

	Map<String, dynamic> toJson() => {
		'id': id,
		'email': email,
		'nombre': nombre,
		'apellido': apellido,
		'rol': rol,
		if (imagenUrl != null) 'imagenUrl': imagenUrl,
	};
}
