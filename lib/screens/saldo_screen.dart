import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/credit_card.dart';
import '../services/api_service.dart';
import '../services/stripe_service.dart';
import '../theme/app_theme.dart';
import '../utils/user_messages.dart';
import '../widgets/stripe_test_banner.dart';

class SaldoScreen extends StatefulWidget {
  final User user;
  const SaldoScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SaldoScreen> createState() => _SaldoScreenState();
}

class _SaldoScreenState extends State<SaldoScreen> {
  final TextEditingController _titularController = TextEditingController();

  CreditCard? _tarjeta;
  int _clienteId = 0;
  bool _cargando = true;
  bool _guardando = false;
  bool _mostrarFormulario = false;
  bool _editando = false;
  String? _error;
  bool _stripeListo = false;
  String? _stripeError;
  CardFieldInputDetails? _cardDetails;

  @override
  void initState() {
    super.initState();
    _cargarTarjeta();
  }

  @override
  void dispose() {
    _titularController.dispose();
    super.dispose();
  }

  Future<void> _cargarTarjeta() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final api = ApiService();
      final cliente = await api.getClienteByUserId(widget.user.id);
      setState(() {
        _clienteId = cliente['id'] ?? 0;
        _cargando = false;
      });

      // Cargar tarjeta guardada localmente
      await _cargarTarjetaLocal();
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar los datos.';
        _cargando = false;
      });
    }
  }

  Future<void> _cargarTarjetaLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tarjetaJson = prefs.getString('tarjeta_${widget.user.id}');
      
      if (tarjetaJson != null) {
        final decoded = jsonDecode(tarjetaJson);
        final tarjeta = CreditCard.fromJson(decoded);
        setState(() {
          _tarjeta = tarjeta;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar tarjeta local: $e');
    }
  }
  

  void _abrirFormulario({CreditCard? tarjeta}) {
    _titularController.clear();
    _cardDetails = null;

    if (tarjeta != null) {
      _titularController.text = tarjeta.titular ?? '';
      setState(() => _editando = true);
    } else {
      setState(() => _editando = false);
    }

    setState(() {
      _mostrarFormulario = true;
      _stripeListo = false;
      _stripeError = null;
    });
    _initStripe();
  }

  Future<void> _initStripe() async {
    try {
      final api = ApiService();
      final config = await api.getPagosConfig();
      final key = config['publishableKey'] as String? ?? '';
      await StripeService.ensureInitialized(key);
      if (mounted) {
        setState(() {
          _stripeListo = true;
          _stripeError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stripeListo = false;
          _stripeError = mensajeAmigable(e);
        });
      }
    }
  }

  void _cerrarFormulario() {
    setState(() => _mostrarFormulario = false);
  }

  Future<void> _mostrarAviso(String titulo, String mensaje, {bool esError = true}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarTarjeta() async {
    final titular = _titularController.text;

    if (!_stripeListo) {
      await _mostrarAviso(
        'Stripe no está listo',
        _stripeError ?? 'Espera a que cargue el formulario seguro de pago.',
      );
      return;
    }

    if (_cardDetails?.complete != true) {
      await _mostrarAviso(
        'Datos incompletos',
        'Completa todos los campos de la tarjeta en el formulario seguro de Stripe.',
      );
      return;
    }

    if (_clienteId == 0) {
      await _mostrarAviso('Cuenta no encontrada', 'No se encontró tu cuenta de cliente. Contacta soporte.');
      return;
    }

    setState(() => _guardando = true);
    try {
      final api = ApiService();
      final paymentMethod = await StripeService.createCardPaymentMethod(
        titular: titular.isEmpty ? null : titular,
      );

      final validado = await api.validarPaymentMethod(paymentMethod.id);

      final card = paymentMethod.card;
      final expMonth = card.expMonth;
      final expYear = card.expYear;
      final fechaFallback = (expMonth != null && expYear != null && expMonth > 0 && expYear > 0)
          ? '${expMonth.toString().padLeft(2, '0')}/${(expYear % 100).toString().padLeft(2, '0')}'
          : '';
      final nuevaTarjeta = CreditCard(
        id: _editando ? _tarjeta?.id : null,
        clienteId: _clienteId,
        fechaVencimiento: validado['fechaVencimiento'] as String? ?? fechaFallback,
        titular: titular.isEmpty ? null : titular,
        paymentMethodId: validado['paymentMethodId'] as String? ?? paymentMethod.id,
        ultimos4: validado['ultimos4'] as String? ?? card.last4,
        marca: validado['marca'] as String? ?? card.brand,
      );

      // Guardar tarjeta en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final tarjetaJson = jsonEncode(nuevaTarjeta.toJson());
      await prefs.setString('tarjeta_${widget.user.id}', tarjetaJson);

      setState(() {
        _tarjeta = nuevaTarjeta;
        _guardando = false;
      });

      _cerrarFormulario();

      if (mounted) {
        await _mostrarAviso(
          _editando ? 'Tarjeta actualizada' : 'Tarjeta agregada',
          _editando
              ? 'Tu tarjeta de prueba fue validada por Stripe y actualizada.'
              : 'Tu tarjeta de prueba fue registrada con Stripe. Ya puedes finalizar compras.',
          esError: false,
        );
      }
    } on StripeException catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        await _mostrarAviso(
          'Tarjeta no válida',
          mensajeAmigable(e.error.localizedMessage ?? e.error.message),
        );
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        await _mostrarAviso('No se pudo guardar la tarjeta', mensajeAmigable(e));
      }
    }
  }

  Future<void> _eliminarTarjeta() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarjeta'),
        content:
            const Text('¿Estás seguro de que deseas eliminar esta tarjeta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('tarjeta_${widget.user.id}');

        setState(() => _tarjeta = null);

        if (mounted) {
          await _mostrarAviso(
            'Tarjeta eliminada',
            'Se quitó la tarjeta de tu cuenta.',
            esError: false,
          );
        }
      } catch (e) {
        if (mounted) {
          await _mostrarAviso('No se pudo eliminar', mensajeAmigable(e));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Tarjeta'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _mostrarFormulario
                  ? _buildFormularioTarjeta()
                  : _buildTarjetaView(),
    );
  }

  Widget _buildTarjetaView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta visual
          if (_tarjeta != null)
            _buildTarjetaCard()
          else
            _buildTarjetaVacia(),
          const SizedBox(height: 32),
          // Botones
          if (_tarjeta != null) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Editar tarjeta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _abrirFormulario(tarjeta: _tarjeta),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete),
              label: const Text('Eliminar tarjeta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _eliminarTarjeta,
            ),
          ] else
            ElevatedButton.icon(
              icon: const Icon(Icons.add_card),
              label: const Text('Agregar una tarjeta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _abrirFormulario(),
            ),
        ],
      ),
    );
  }

  Widget _buildTarjetaVacia() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.grey[300],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.credit_card, size: 60, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text(
              'Sin tarjeta registrada',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1E5A96), // Azul visa-like
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (_tarjeta!.marca ?? 'VISA').toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _tarjeta!.numeroMascarado,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VÁLIDA HASTA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tarjeta!.fechaVencimiento,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (_tarjeta!.titular != null && _tarjeta!.titular!.isNotEmpty)
                  Text(
                    _tarjeta!.titular!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormularioTarjeta() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editando ? 'Editar tarjeta' : 'Agregar tarjeta',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const StripeTestBanner(),
          const SizedBox(height: 20),
          if (_stripeError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_stripeError!, style: const TextStyle(color: Colors.red)),
            ),
          if (!_stripeListo)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            const Text(
              'Datos de tarjeta (formulario seguro Stripe)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CardField(
                enablePostalCode: false,
                onCardChanged: (card) => setState(() => _cardDetails = card),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _titularController,
            decoration: InputDecoration(
              labelText: 'Titular (Opcional)',
              hintText: 'Nombre en la tarjeta',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.lock),
            label: Text(_guardando
                ? 'Validando con Stripe...'
                : (_editando ? 'Actualizar tarjeta' : 'Guardar tarjeta')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: (_guardando || !_stripeListo) ? null : _guardarTarjeta,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _guardando ? null : _cerrarFormulario,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
