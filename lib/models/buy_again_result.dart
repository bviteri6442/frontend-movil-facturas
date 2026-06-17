/// Producto que impide copiar la compra por falta de stock.
class StockIssue {
  final String nombre;
  final int cantidadPedida;
  final int stockDisponible;
  final String motivo;

  const StockIssue({
    required this.nombre,
    required this.cantidadPedida,
    required this.stockDisponible,
    required this.motivo,
  });

  int get faltante {
    if (cantidadPedida <= stockDisponible) return 0;
    return cantidadPedida - stockDisponible;
  }

  /// Texto con números para mostrar al usuario (requisito del examen).
  String get mensajeDetallado {
    if (cantidadPedida <= 0) return motivo;
    if (stockDisponible <= 0) {
      return 'Pediste $cantidadPedida · Disponible 0 · Faltan $cantidadPedida';
    }
    if (faltante > 0) {
      return 'Pediste $cantidadPedida · Disponible $stockDisponible · Faltan $faltante';
    }
    return 'Pediste $cantidadPedida · Disponible $stockDisponible · $motivo';
  }
}

/// Resultado de intentar copiar una compra histórica al carrito.
class BuyAgainResult {
  final bool success;
  final List<StockIssue> issues;

  const BuyAgainResult._({
    required this.success,
    this.issues = const [],
  });

  factory BuyAgainResult.ok() => const BuyAgainResult._(success: true);

  factory BuyAgainResult.fail(List<StockIssue> issues) =>
      BuyAgainResult._(success: false, issues: issues);
}

