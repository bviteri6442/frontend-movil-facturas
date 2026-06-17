import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/buy_again_result.dart';
import '../models/cart.dart';
import '../models/user.dart';
import '../models/credit_card.dart';
import '../services/api_service.dart';
import '../services/cart_stock_service.dart';
import '../theme/app_theme.dart';
import '../utils/user_messages.dart';

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

	void _editQuantity(CartItem item) {
		final ctrl = TextEditingController(text: '${item.cantidad}');
		showDialog(
			context: context,
			builder: (ctx) => AlertDialog(
				title: Text('Cantidad — ${item.nombre}'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text('Stock disponible: ${item.stockDisponible}',
							style: TextStyle(
								color: item.stockDisponible < 5 ? Colors.red : Colors.green[700],
								fontWeight: FontWeight.bold,
							)),
						const SizedBox(height: 12),
						TextField(
							controller: ctrl,
							keyboardType: TextInputType.number,
							inputFormatters: [
								FilteringTextInputFormatter.digitsOnly,
								_LengthLimitFormatter(item.stockDisponible),
							],
							decoration: InputDecoration(
								labelText: 'Cantidad',
								hintText: 'Máx ${item.stockDisponible}',
								border: const OutlineInputBorder(),
							),
						),
					],
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
					ElevatedButton(
						style: ElevatedButton.styleFrom(
							backgroundColor: AppColors.primaryDark,
							foregroundColor: Colors.white,
						),
						onPressed: () {
							final qty = int.tryParse(ctrl.text) ?? 0;
							if (qty < 1 || qty > item.stockDisponible) return;
							setState(() {
								item.cantidad = qty;
								widget.cart.updateQuantity(item.productoId, qty);
							});
							Navigator.pop(ctx);
						},
						child: const Text('Aplicar'),
					),
				],
			),
		);
	}

	void _mostrarErroresStock(List<StockIssue> issues) {
		showDialog(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('No se puede finalizar la compra'),
				content: SingleChildScrollView(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							const Text(
								'Stock insuficiente. Revisa las cantidades en tu carrito:',
								style: TextStyle(fontSize: 13),
							),
							const SizedBox(height: 12),
							...issues.map((issue) => Padding(
								padding: const EdgeInsets.only(bottom: 10),
								child: Container(
									width: double.infinity,
									padding: const EdgeInsets.all(10),
									decoration: BoxDecoration(
										color: const Color(0xFFFFF3F3),
										borderRadius: BorderRadius.circular(8),
										border: Border.all(color: const Color(0xFFE57373)),
									),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(issue.nombre,
												style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
											const SizedBox(height: 4),
											Text(issue.mensajeDetallado,
												style: const TextStyle(fontSize: 13, color: Colors.black87)),
										],
									),
								),
							)),
						],
					),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
				],
			),
		);
	}

	double get subtotal => widget.cart.items.fold(0, (sum, item) => sum + item.subtotal);
	double get totalIva => widget.cart.items.fold(0, (sum, item) => sum + item.totalConIva);

	void _mostrarAviso(String titulo, String mensaje) {
		showDialog<void>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: Text(titulo),
				content: Text(mensaje),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
				],
			),
		);
	}

	void _showFinishModal() async {
		final user = ModalRoute.of(context)?.settings.arguments as User?;
		if (user == null) {
			_mostrarAviso('Sesión no válida', 'No se encontró el usuario. Vuelve a iniciar sesión.');
			return;
		}

		final stockResult = await CartStockService(ApiService()).validarCarrito(widget.cart);
		if (!mounted) return;
		if (!stockResult.success) {
			_mostrarErroresStock(stockResult.issues);
			return;
		}

		// Cargar información del cliente
		int clienteId = 0;
		CreditCard? tarjeta;
		try {
			final api = ApiService();
			final cliente = await api.getClienteByUserId(user.id);
			clienteId = cliente['id'] ?? 0;
		} catch (_) {}

		if (clienteId == 0) {
			if (!mounted) return;
			_mostrarAviso(
				'Cuenta no encontrada',
				'No se encontró tu cuenta de cliente. Completa tu registro en el perfil.',
			);
			return;
		}

		// Verificar si el usuario tiene tarjeta guardada localmente
		try {
			final prefs = await SharedPreferences.getInstance();
			final tarjetaJson = prefs.getString('tarjeta_${user.id}');
			if (tarjetaJson != null) {
				tarjeta = CreditCard.fromJson(jsonDecode(tarjetaJson));
			}
		} catch (_) {}

		if (!mounted) return;
		
		if (tarjeta != null && tarjeta.estaValidada) {
			_mostrarDialogCompra(user, clienteId, subtotal, totalIva, tarjeta);
		} else {
			_mostrarDialogSinTarjeta(user);
		}
	}

	void _mostrarDialogSinTarjeta(User user) {
		showDialog(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Información de pago requerida'),
				content: const Text('Para realizar su compra ingrese información de pago.'),
				actions: [
					TextButton(
						onPressed: () {
							Navigator.of(context).pop();
							Navigator.pushNamed(context, '/saldo', arguments: user);
						},
						style: TextButton.styleFrom(foregroundColor: AppColors.primary),
						child: const Text('Ir'),
					),
					TextButton(
						onPressed: () => Navigator.of(context).pop(),
						child: const Text('Cancelar'),
					),
				],
			),
		);
	}

	void _mostrarDialogCompra(User user, int clienteId, double subtotal, double totalIva, CreditCard tarjeta) {
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
						],
					),
				),
				actions: [
					ElevatedButton(
						style: ElevatedButton.styleFrom(
							backgroundColor: AppColors.primaryDark,
							foregroundColor: Colors.white,
						),
						onPressed: () async {
							Navigator.of(context).pop();
							await _finalizarCompra(user, clienteId, tarjeta);
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

	Future<void> _finalizarCompra(User user, int clienteId, CreditCard tarjeta) async {
		final pmId = tarjeta.paymentMethodId;
		if (pmId == null || pmId.isEmpty) {
			_mostrarAviso(
				'Tarjeta requerida',
				'Tu tarjeta no está validada. Ve a Mi Tarjeta y regístrala con una tarjeta de prueba.',
			);
			return;
		}

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
			await api.checkoutMovil(
				clienteId: clienteId,
				detalles: detalles,
				paymentMethodId: pmId,
				montoTotal: totalIva,
			);
			debugPrint('[COMPRA] ✅ Venta guardada exitosamente.');
			setState(() {
				widget.cart.clear();
			});
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('¡Compra realizada con éxito!')),
				);
				// Retornar true para indicar que la compra fue exitosa
				Future.delayed(const Duration(milliseconds: 500), () {
					if (mounted) {
						Navigator.of(context).pop(true);
					}
				});
			}
		} catch (e) {
			debugPrint('[COMPRA] ❌ Error: $e');
			if (mounted) {
				_mostrarAviso('No se pudo completar la compra', mensajeAmigable(e));
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
																		InkWell(
																			onTap: () => _editQuantity(item),
																			child: Text(
																				'Editar cantidad',
																				style: TextStyle(
																					color: AppColors.primary,
																					fontSize: 12,
																					decoration: TextDecoration.underline,
																				),
																			),
																		),
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

class _LengthLimitFormatter extends TextInputFormatter {
	final int max;
	_LengthLimitFormatter(this.max);

	@override
	TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
		if (newValue.text.isEmpty) return newValue;
		final n = int.tryParse(newValue.text);
		if (n == null) return oldValue;
		if (n > max) return oldValue;
		return newValue;
	}
}
