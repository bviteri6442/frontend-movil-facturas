import '../models/buy_again_result.dart';
import '../models/cart.dart';
import 'api_service.dart';

/// Lógica de "Comprar nuevamente": valida stock y copia al carrito (todo o nada).
class BuyAgainService {
  final ApiService _api;

  BuyAgainService(this._api);

  /// Valida stock actual y, si todo está bien, reemplaza el carrito con los ítems.
  /// No modifica la venta histórica ni guarda una venta nueva.
  Future<BuyAgainResult> copiarAlCarrito({
    required List<Map<String, dynamic>> lineas,
    required Cart cart,
  }) async {
    if (lineas.isEmpty) {
      return BuyAgainResult.fail(const [
        StockIssue(
          nombre: '—',
          cantidadPedida: 0,
          stockDisponible: 0,
          motivo: 'La factura no tiene productos para copiar.',
        ),
      ]);
    }

    final issues = <StockIssue>[];
    final itemsToAdd = <CartItem>[];

    for (final linea in lineas) {
      final productoId = _productoIdFrom(linea);
      final cantidadPedida = _cantidadFrom(linea);
      final nombreHistorico = (linea['productoNombre'] ?? 'Producto').toString();

      if (productoId == null) {
        issues.add(StockIssue(
          nombre: nombreHistorico,
          cantidadPedida: cantidadPedida,
          stockDisponible: 0,
          motivo: 'No se pudo identificar el producto en la factura.',
        ));
        continue;
      }

      if (cantidadPedida <= 0) {
        issues.add(StockIssue(
          nombre: nombreHistorico,
          cantidadPedida: cantidadPedida,
          stockDisponible: 0,
          motivo: 'Cantidad inválida en la factura.',
        ));
        continue;
      }

      try {
        final producto = await _api.getProductoById(
          productoId,
          nombre: nombreHistorico,
        );
        final stock = _asInt(producto['stock']);
        final activo = producto['activo'] ?? true;
        final nombre = (producto['nombre'] ?? nombreHistorico).toString();
        final precio = _asDouble(producto['precio'] ?? producto['precioUnitario']);
        final ivaPct = _asDouble(producto['porcentajeIVA']);
        final imagenUrl = producto['imagenUrl'] as String?;

        if (activo != true) {
          issues.add(StockIssue(
            nombre: nombre,
            cantidadPedida: cantidadPedida,
            stockDisponible: stock,
            motivo: 'Producto inactivo.',
          ));
        } else if (stock <= 0) {
          issues.add(StockIssue(
            nombre: nombre,
            cantidadPedida: cantidadPedida,
            stockDisponible: 0,
            motivo: 'Sin stock disponible.',
          ));
        } else if (stock < cantidadPedida) {
          issues.add(StockIssue(
            nombre: nombre,
            cantidadPedida: cantidadPedida,
            stockDisponible: stock,
            motivo: 'Stock insuficiente.',
          ));
        } else {
          itemsToAdd.add(CartItem(
            productoId: productoId,
            nombre: nombre,
            descripcion: (producto['descripcion'] ?? '').toString(),
            precioUnitario: precio,
            iva: ivaPct / 100,
            stockDisponible: stock,
            imagenUrl: imagenUrl,
            cantidad: cantidadPedida,
          ));
        }
      } catch (e) {
        issues.add(StockIssue(
          nombre: nombreHistorico,
          cantidadPedida: cantidadPedida,
          stockDisponible: 0,
          motivo: e.toString().replaceFirst('Exception: ', ''),
        ));
      }
    }

    // Regla todo-o-nada: si hay al menos un problema, no se toca el carrito.
    if (issues.isNotEmpty) {
      return BuyAgainResult.fail(issues);
    }

    cart.clear();
    for (final item in itemsToAdd) {
      cart.addProduct(item);
    }

    return BuyAgainResult.ok();
  }

  int? _productoIdFrom(Map<String, dynamic> linea) {
    final raw = linea['productoId'] ?? linea['ProductoId'];
    if (raw is int) return raw;
    return int.tryParse('$raw');
  }

  int _cantidadFrom(Map<String, dynamic> linea) {
    final raw = linea['cantidad'] ?? linea['Cantidad'] ?? 0;
    if (raw is int) return raw;
    return int.tryParse('$raw') ?? 0;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
