import '../models/cart.dart';

/// Instancia única del carrito compartida entre catálogo e historial.
class CartHolder {
  CartHolder._();

  static final CartHolder instance = CartHolder._();

  final Cart cart = Cart();
}
