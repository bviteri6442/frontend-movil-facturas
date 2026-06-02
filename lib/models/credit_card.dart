class CreditCard {
  final int? id;
  final int clienteId;
  final String numeroTarjeta;
  final String fechaVencimiento; // MM/YY
  final String cvv;
  final String? titular;

  CreditCard({
    this.id,
    required this.clienteId,
    required this.numeroTarjeta,
    required this.fechaVencimiento,
    required this.cvv,
    this.titular,
  });

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
        id: json['id'],
        clienteId: json['clienteId'] ?? 0,
        numeroTarjeta: json['numeroTarjeta'] ?? '',
        fechaVencimiento: json['fechaVencimiento'] ?? '',
        cvv: json['cvv'] ?? '',
        titular: json['titular'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'clienteId': clienteId,
        'numeroTarjeta': numeroTarjeta,
        'fechaVencimiento': fechaVencimiento,
        'cvv': cvv,
        'titular': titular,
      };

  // Método para obtener el número de tarjeta enmascarado
  String get numeroMascarado {
    if (numeroTarjeta.length < 8) return numeroTarjeta;
    final primerosDos = numeroTarjeta.substring(0, 4);
    final ultimosCuatro = numeroTarjeta.substring(numeroTarjeta.length - 4);
    return '$primerosDos xxxx xxxx $ultimosCuatro';
  }
}
