import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/credit_card.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SaldoScreen extends StatefulWidget {
  final User user;
  const SaldoScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<SaldoScreen> createState() => _SaldoScreenState();
}

class _SaldoScreenState extends State<SaldoScreen> {
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _titularController = TextEditingController();

  CreditCard? _tarjeta;
  int _clienteId = 0;
  bool _cargando = true;
  bool _guardando = false;
  bool _mostrarFormulario = false;
  bool _editando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarTarjeta();
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _fechaController.dispose();
    _cvvController.dispose();
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
    _numeroController.clear();
    _fechaController.clear();
    _cvvController.clear();
    _titularController.clear();

    if (tarjeta != null) {
      _numeroController.text = tarjeta.numeroTarjeta;
      _fechaController.text = tarjeta.fechaVencimiento;
      _cvvController.text = tarjeta.cvv;
      _titularController.text = tarjeta.titular ?? '';
      setState(() => _editando = true);
    } else {
      setState(() => _editando = false);
    }

    setState(() => _mostrarFormulario = true);
  }

  void _cerrarFormulario() {
    setState(() => _mostrarFormulario = false);
  }

  Future<void> _guardarTarjeta() async {
    final numero = _numeroController.text.replaceAll(' ', '');
    final fecha = _fechaController.text;
    final cvv = _cvvController.text;
    final titular = _titularController.text;

    if (numero.length != 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El número de tarjeta debe tener 16 dígitos.')),
      );
      return;
    }

    if (fecha.length != 5 || !fecha.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha debe estar en formato MM/YY.')),
      );
      return;
    }

    if (cvv.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El CVV debe tener 3 dígitos.')),
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
      final nuevaTarjeta = CreditCard(
        id: _editando ? _tarjeta?.id : null,
        clienteId: _clienteId,
        numeroTarjeta: numero,
        fechaVencimiento: fecha,
        cvv: cvv,
        titular: titular.isEmpty ? null : titular,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editando
                ? '¡Tarjeta actualizada!'
                : '¡Tarjeta agregada correctamente!'),
          ),
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
        // Eliminar tarjeta del almacenamiento local
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('tarjeta_${widget.user.id}');

        setState(() => _tarjeta = null);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarjeta eliminada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
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
            const Text(
              'VISA',
              style: TextStyle(
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
          const SizedBox(height: 24),
          // Número de tarjeta
          TextField(
            controller: _numeroController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _TarjetaFormatter(),
            ],
            maxLength: 19, // 16 dígitos + 3 espacios
            decoration: InputDecoration(
              labelText: 'Número de tarjeta',
              hintText: '0000 0000 0000 0000',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fechaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _FechaVencimientoFormatter(),
                  ],
                  maxLength: 5,
                  decoration: InputDecoration(
                    labelText: 'Vencimiento',
                    hintText: 'MM/YY',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _cvvController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    hintText: '000',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  obscureText: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titularController,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
            ],
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
                : const Icon(Icons.save),
            label: Text(_guardando
                ? 'Guardando...'
                : (_editando ? 'Actualizar tarjeta' : 'Guardar tarjeta')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _guardando ? null : _guardarTarjeta,
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

// Formateador para número de tarjeta (xxxx xxxx xxxx xxxx)
class _TarjetaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    
    final text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

// Formateador para fecha de vencimiento (MM/YY)
class _FechaVencimientoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final text = newValue.text.replaceAll('/', '');
    if (text.length > 4) return oldValue;

    if (text.length >= 2) {
      final mes = text.substring(0, 2);
      final mesInt = int.tryParse(mes);
      if (mesInt == null || mesInt > 12) return oldValue;
      
      if (text.length == 2) {
        return TextEditingValue(
          text: '$mes/',
          selection: TextSelection.collapsed(offset: 3),
        );
      }

      final year = text.substring(2);
      return TextEditingValue(
        text: '$mes/$year',
        selection: TextSelection.collapsed(offset: mes.length + 1 + year.length),
      );
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
