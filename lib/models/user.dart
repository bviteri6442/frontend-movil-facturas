class User {
	final int id;
	final String email;
	final String nombre;
	final String apellido;
	final String rol;

	User({
		required this.id,
		required this.email,
		required this.nombre,
		required this.apellido,
		required this.rol,
	});

	factory User.fromJson(Map<String, dynamic> json) => User(
				id: json['id'] ?? 0,
				email: json['email'] ?? '',
				nombre: json['nombre'] ?? '',
				apellido: json['apellido'] ?? '',
				rol: json['rol'] ?? '',
			);
}
