import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CartScreen extends StatefulWidget {
	final Cart cart;
	const CartScreen({Key? key, required this.cart}) : super(key: key);

	@override
	State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
	void _clearCart() async {
		final confirm = await showDialog<bool>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Limpiar carrito'),
				content: const Text('¿Estás seguro de que deseas eliminar todos los productos del carrito?'),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(context).pop(false),
						child: const Text('No'),
					),
					TextButton(
						onPressed: () => Navigator.of(context).pop(true),
						child: const Text('Sí'),
					),
				],
			),
		);
		if (confirm == true) {
			setState(() {
				widget.cart.items.clear();
			});
		}
	}

	void _removeItem(int productoId) {
		setState(() {
			widget.cart.removeProductById(productoId);
		});
	}

	void _incrementItem(CartItem item) {
		if (item.cantidad < item.stockDisponible) {
			setState(() {
				item.cantidad++;
				widget.cart.updateQuantity(item.productoId, item.cantidad);
			});
		} else {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No puedes agregar más de lo que hay en stock.')),
			);
		}
	}

	void _decrementItem(CartItem item) {
		if (item.cantidad > 1) {
			setState(() {
				item.cantidad--;
				widget.cart.updateQuantity(item.productoId, item.cantidad);
			});
		} else {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('La cantidad mínima es 1.')),
			);
		}
	}

	double get subtotal => widget.cart.items.fold(0, (sum, item) => sum + item.subtotal);
	double get totalIva => widget.cart.items.fold(0, (sum, item) => sum + item.totalConIva);

	void _showFinishModal() async {
		final user = ModalRoute.of(context)?.settings.arguments as User?;
		if (user == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No se encontró el usuario.')),
			);
			return;
		}

		// Cargar saldo actual del cliente
		double saldo = 0;
		int clienteId = 0;
		try {
			final api = ApiService();
			final cliente = await api.getClienteByUserId(user.id);
			saldo = (cliente['saldo'] ?? 0).toDouble();
			clienteId = cliente['id'] ?? 0;
		} catch (_) {}

		if (clienteId == 0) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No se encontró tu cuenta de cliente.')),
			);
			return;
		}

		final bool saldoSuficiente = saldo >= totalIva;

		if (!mounted) return;
		showDialog(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Resumen de compra'),
				content: SingleChildScrollView(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							...widget.cart.items.map((item) => Padding(
								padding: const EdgeInsets.symmetric(vertical: 4.0),
								child: Row(
									mainAxisAlignment: MainAxisAlignment.spaceBetween,
									children: [
										Expanded(child: Text('${item.nombre} (x${item.cantidad})')),
										Text('\$${item.totalConIva.toStringAsFixed(2)}'),
									],
								),
							)),
							const Divider(),
							Text('Subtotal: \$${subtotal.toStringAsFixed(2)}'),
							Text(
								'Total con IVA: \$${totalIva.toStringAsFixed(2)}',
								style: const TextStyle(fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 12),
							Row(
								children: [
									const Icon(Icons.account_balance_wallet, size: 18),
									const SizedBox(width: 6),
									Text(
										'Saldo disponible: \$${saldo.toStringAsFixed(2)}',
										style: TextStyle(
											color: saldoSuficiente ? Colors.green[700] : Colors.red,
											fontWeight: FontWeight.w500,
										),
									),
								],
							),
							if (!saldoSuficiente)
								Padding(
									padding: const EdgeInsets.only(top: 8),
									child: Text(
										'Saldo insuficiente. Necesitas \$${(totalIva - saldo).toStringAsFixed(2)} más.',
										style: const TextStyle(color: Colors.red, fontSize: 13),
									),
								),
						],
					),
				),
				actions: [
					if (saldoSuficiente)
						ElevatedButton(
							style: ElevatedButton.styleFrom(
								backgroundColor: AppColors.primaryDark,
								foregroundColor: Colors.white,
							),
							onPressed: () async {
								Navigator.of(context).pop();
								await _finalizarCompra(user, clienteId);
							},
							child: const Text('Confirmar compra'),
						),
					TextButton(
						onPressed: () => Navigator.of(context).pop(),
						child: const Text('Cerrar'),
					),
				],
			),
		);
	}

	Future<void> _finalizarCompra(User user, int clienteId) async {
		final detalles = widget.cart.items.map((item) => {
			'productoId': item.productoId,
			'cantidad': item.cantidad,
			'precioUnitario': item.precioUnitario,
		}).toList();
		debugPrint('[COMPRA] Iniciando compra para clienteId: $clienteId (userId: ${user.id})');
		debugPrint('[COMPRA] Items del carrito: ${widget.cart.items.map((i) => {
			'nombre': i.nombre,
			'productoId': i.productoId,
			'cantidad': i.cantidad,
			'subtotal': i.subtotal,
			'totalConIva': i.totalConIva,
		}).toList()}');
		try {
			final api = ApiService();
			await api.saveVenta(clienteId: clienteId, detalles: detalles);
			debugPrint('[COMPRA] ✅ Venta guardada exitosamente.');
			setState(() {
				widget.cart.clear();
			});
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('¡Compra realizada con éxito!')),
				);
			}
		} catch (e) {
			debugPrint('[COMPRA] ❌ Error: $e');
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Error al guardar la venta: $e')),
				);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			appBar: AppBar(
				title: const Text('Carrito de compras'),
				backgroundColor: AppColors.primaryDark,
				foregroundColor: Colors.white,
				actions: [
					IconButton(
						icon: const Icon(Icons.cleaning_services),
						tooltip: 'Limpiar carrito',
						onPressed: widget.cart.items.isEmpty ? null : _clearCart,
					),
					IconButton(
						icon: const Icon(Icons.close, color: Colors.red),
						tooltip: 'Cerrar',
						onPressed: () => Navigator.of(context).pop(),
					),
				],
			),
			body: Column(
				children: [
					Expanded(
						child: widget.cart.items.isEmpty
								? const Center(child: Text('No hay productos en el carrito.'))
								: ListView.builder(
										itemCount: widget.cart.items.length,
										itemBuilder: (context, index) {
											final item = widget.cart.items[index];
											return Card(
												margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
												elevation: 1.5,
												child: Padding(
													padding: const EdgeInsets.all(12.0),
													child: Row(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															// Info principal
															Expanded(
																child: Column(
																	crossAxisAlignment: CrossAxisAlignment.start,
																	children: [
																		Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
																		const SizedBox(height: 8),
																		Text('Cantidad: ${item.cantidad}'),
																		Text('Subtotal: \$${item.subtotal.toStringAsFixed(2)}'),
																		Text(
																			'Total: \$${item.totalConIva.toStringAsFixed(2)}',
																			style: const TextStyle(
																				fontWeight: FontWeight.w600,
																				color: AppColors.primaryDark,
																			),
																		),
																	],
																),
															),
															const SizedBox(width: 8),
															// Imagen del producto
															ClipRRect(
																borderRadius: BorderRadius.circular(6),
																child: (item.imagenUrl != null && item.imagenUrl!.isNotEmpty)
																		? Image.network(
																				item.imagenUrl!,
																				width: 60,
																				height: 60,
																				fit: BoxFit.cover,
																				errorBuilder: (_, __, ___) => Container(
																					width: 60, height: 60,
																					color: Colors.grey[200],
																					child: const Icon(Icons.image_not_supported, color: Colors.grey),
																				),
																			)
																		: Container(
																				width: 60, height: 60,
																				color: Colors.grey[200],
																				child: const Icon(Icons.inventory_2, color: Colors.grey),
																			),
															),
															const SizedBox(width: 8),
															// Botones de cantidad y eliminar
															Column(
																children: [
																	IconButton(
																		icon: const Icon(Icons.add, color: AppColors.primary),
																		onPressed: () => _incrementItem(item),
																	),
																	IconButton(
																		icon: const Icon(Icons.remove, color: Colors.amber),
																		onPressed: () => _decrementItem(item),
																	),
																	IconButton(
																		icon: const Icon(Icons.delete, color: Colors.red),
																		onPressed: () => _removeItem(item.productoId),
																	),
																],
															),
														],
													),
												),
											);
										},
									),
					),
					// Botón finalizar compra
					Padding(
						padding: const EdgeInsets.all(16.0),
						child: SizedBox(
							width: double.infinity,
							height: 48,
							child: ElevatedButton(
								style: ElevatedButton.styleFrom(
									backgroundColor: AppColors.primary,
									foregroundColor: Colors.white,
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
								),
								onPressed: widget.cart.items.isEmpty ? null : _showFinishModal,
								child: const Text('Finalizar compra', style: TextStyle(fontWeight: FontWeight.bold)),
							),
						),
					),
				],
			),
		);
	}
}
