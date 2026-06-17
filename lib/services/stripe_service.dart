import 'package:flutter_stripe/flutter_stripe.dart';

/// Inicializa Stripe y crea PaymentMethods en el cliente (modo test).
/// Los números de tarjeta nunca pasan por nuestro servidor.
class StripeService {
  static bool _initialized = false;
  static String? _publishableKey;

  static bool get isInitialized => _initialized;

  static Future<void> ensureInitialized(String publishableKey) async {
    final key = publishableKey.trim();
    if (key.isEmpty) {
      throw Exception('Stripe no está configurado en el servidor (clave publicable vacía).');
    }
    if (!key.startsWith('pk_test_')) {
      throw Exception('Solo se permite modo prueba (pk_test_).');
    }
    if (_initialized && _publishableKey == key) return;

    Stripe.publishableKey = key;
    await Stripe.instance.applySettings();
    _publishableKey = key;
    _initialized = true;
  }

  /// Crea un PaymentMethod con los datos del [CardField] visible en pantalla.
  static Future<PaymentMethod> createCardPaymentMethod({String? titular}) async {
    if (!_initialized) {
      throw Exception('Stripe no está listo. Espera un momento e intenta de nuevo.');
    }

    return Stripe.instance.createPaymentMethod(
      params: PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(
          billingDetails: (titular != null && titular.trim().isNotEmpty)
              ? BillingDetails(name: titular.trim())
              : null,
        ),
      ),
    );
  }
}
