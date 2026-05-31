import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class SaldoScreen extends StatefulWidget {
  final User user;
  const SaldoScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SaldoScreen> createState() => _SaldoScreenState();
}

class _SaldoScreenState extends State<SaldoScreen> {
  final TextEditingController _montoController = TextEditingController();
  double _saldoActual = 0;
  int _clienteId = 0;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSaldo();
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _cargarSaldo() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final api = ApiService();
      final cliente = await api.getClienteByUserId(widget.user.id);
      setState(() {
        _clienteId = cliente['id'] ?? 0;
        _saldoActual = (cliente['saldo'] ?? 0).toDouble();
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar el saldo.';
        _cargando = false;
      });
    }
  }

  Future<void> _agregarSaldo() async {
    final monto = double.tryParse(_montoController.text) ?? 0;
    if (monto < 1 || monto > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El monto debe estar entre \$1 y \$10,000.')),
      );
      return;
    }
    if (_clienteId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró tu cuenta de cliente.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final api = ApiService();
      final res = await api.agregarSaldo(clienteId: _clienteId, monto: monto);
      setState(() {
        _saldoActual = (res['saldo'] ?? _saldoActual + monto).toDouble();
        _guardando = false;
      });
      _montoController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['mensaje'] ?? '¡Saldo agregado!')),
        );
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Saldo'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tarjeta de saldo actual
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.black87,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                          child: Column(
                            children: [
                              const Text(
                                'Saldo actual',
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${_saldoActual.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Agregar saldo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _montoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _SaldoLimitFormatter(10000),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Monto a agregar',
                          hintText: 'Entre \$1 y \$10,000',
                          prefixText: '\$ ',
                          suffixText: '/ 10,000',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: Text(_guardando ? 'Procesando...' : 'Agregar saldo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _guardando ? null : _agregarSaldo,
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SaldoLimitFormatter extends TextInputFormatter {
  final int maxValue;
  _SaldoLimitFormatter(this.maxValue);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final value = int.tryParse(newValue.text);
    if (value == null) return oldValue;
    if (value > maxValue) return oldValue;
    return newValue;
  }
}
