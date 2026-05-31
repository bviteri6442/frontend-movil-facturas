class CartItem {
  final int productoId;
  final String nombre;
  final String descripcion;
  final double precioUnitario;
  final double iva;
  final int stockDisponible;
  final String? imagenUrl;
  int cantidad;

  CartItem({
    required this.productoId,
    required this.nombre,
    required this.descripcion,
    required this.precioUnitario,
    required this.iva,
    required this.stockDisponible,
    this.imagenUrl,
    this.cantidad = 1,
  });

  double get subtotal => precioUnitario * cantidad;
  double get totalConIva => subtotal * (1 + iva);
}

class Cart {
  final List<CartItem> items = [];

  void addProduct(CartItem item) {
    final index = items.indexWhere((e) => e.productoId == item.productoId);
    if (index == -1) {
      items.add(item);
    } else {
      final nuevaCantidad = items[index].cantidad + item.cantidad;
      items[index].cantidad = nuevaCantidad.clamp(1, items[index].stockDisponible);
    }
  }

  void removeProductById(int productoId) {
    items.removeWhere((e) => e.productoId == productoId);
  }

  void updateQuantity(int productoId, int cantidad) {
    final index = items.indexWhere((e) => e.productoId == productoId);
    if (index != -1 && cantidad > 0 && cantidad <= items[index].stockDisponible) {
      items[index].cantidad = cantidad;
    }
  }

  double get total => items.fold(0, (sum, item) => sum + item.totalConIva);
  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get totalIva => items.fold(0, (sum, item) => sum + (item.subtotal * item.iva));

  void clear() {
    items.clear();
  }

  int cantidadEnCarrito(int productoId) {
    final index = items.indexWhere((e) => e.productoId == productoId);
    return index == -1 ? 0 : items[index].cantidad;
  }
}
