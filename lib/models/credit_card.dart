class CreditCard {
  final int? id;
  final int clienteId;
  final String? numeroTarjeta;
  final String fechaVencimiento;
  final String? cvv;
  final String? titular;
  final String? paymentMethodId;
  final String? ultimos4;
  final String? marca;

  CreditCard({
    this.id,
    required this.clienteId,
    this.numeroTarjeta,
    required this.fechaVencimiento,
    this.cvv,
    this.titular,
    this.paymentMethodId,
    this.ultimos4,
    this.marca,
  });

  bool get estaValidada =>
      paymentMethodId != null && paymentMethodId!.isNotEmpty;

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
        id: json['id'],
        clienteId: json['clienteId'] ?? 0,
        numeroTarjeta: json['numeroTarjeta'] as String?,
        fechaVencimiento: json['fechaVencimiento'] ?? '',
        cvv: json['cvv'] as String?,
        titular: json['titular'] as String?,
        paymentMethodId: json['paymentMethodId'] as String?,
        ultimos4: json['ultimos4'] as String?,
        marca: json['marca'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'clienteId': clienteId,
        if (numeroTarjeta != null) 'numeroTarjeta': numeroTarjeta,
        'fechaVencimiento': fechaVencimiento,
        if (titular != null) 'titular': titular,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (ultimos4 != null) 'ultimos4': ultimos4,
        if (marca != null) 'marca': marca,
      };

  String get numeroMascarado {
    final ult4 = ultimos4 ??
        (numeroTarjeta != null && numeroTarjeta!.length >= 4
            ? numeroTarjeta!.substring(numeroTarjeta!.length - 4)
            : '****');
    final marcaTxt = (marca ?? 'VISA').toUpperCase();
    return '$marcaTxt •••• $ult4';
  }
}
