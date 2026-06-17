import '../models/buy_again_result.dart';
import '../models/cart.dart';
import 'api_service.dart';

/// Valida stock actual de los ítems del carrito antes de finalizar compra.
class CartStockService {
  final ApiService _api;

  CartStockService(this._api);

  Future<BuyAgainResult> validarCarrito(Cart cart) async {
    if (cart.items.isEmpty) {
      return BuyAgainResult.fail(const [
        StockIssue(
          nombre: '—',
          cantidadPedida: 0,
          stockDisponible: 0,
          motivo: 'El carrito está vacío.',
        ),
      ]);
    }

    final issues = <StockIssue>[];

    for (final item in cart.items) {
      try {
        final producto = await _api.getProductoById(
          item.productoId,
          nombre: item.nombre,
        );
        final stock = _asInt(producto['stock']);
        final activo = producto['activo'] ?? true;
        final nombre = (producto['nombre'] ?? item.nombre).toString();

        if (activo != true) {
          issues.add(StockIssue(
            nombre: nombre,
            cantidadPedida: item.cantidad,
            stockDisponible: stock,
            motivo: 'Producto inactivo.',
          ));
        } else if (stock <= 0) {
          issues.add(StockIssue(
            nombre: nombre,
            cantidadPedida: item.cantidad,
            stockDisponible: 0,
            motivo: 'Sin stock disponible.',
          ));
        } else if (stock < item.cantidad) {
          issues.add(StockIssue(
            nombre: nombre,
            cantidadPedida: item.cantidad,
            stockDisponible: stock,
            motivo: 'Stock insuficiente.',
          ));
        } else {
          item.stockDisponible = stock;
        }
      } catch (e) {
        issues.add(StockIssue(
          nombre: item.nombre,
          cantidadPedida: item.cantidad,
          stockDisponible: 0,
          motivo: e.toString().replaceFirst('Exception: ', ''),
        ));
      }
    }

    if (issues.isNotEmpty) {
      return BuyAgainResult.fail(issues);
    }
    return BuyAgainResult.ok();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
