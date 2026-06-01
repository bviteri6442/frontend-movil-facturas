import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  final User user;
  const HistoryScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _ventas = [];
  String _searchQuery = '';
  String _estadoFiltro = 'todos';
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final cliente = await _api.getClienteByUserId(widget.user.id);
      if (cliente.isEmpty || cliente['id'] == null) {
        setState(() {
          _error = 'No tienes una cuenta de cliente registrada.';
          _isLoading = false;
        });
        return;
      }
      final int clienteId = cliente['id'];
      final ventas = await _api.getVentasByClienteId(clienteId);
      // Ordenar por fecha descendente
      ventas.sort((a, b) {
        final fa = DateTime.tryParse(a['fechaVenta'] ?? '') ?? DateTime(0);
        final fb = DateTime.tryParse(b['fechaVenta'] ?? '') ?? DateTime(0);
        return fb.compareTo(fa);
      });
      setState(() {
        _ventas = ventas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar historial: $e';
        _isLoading = false;
      });
    }
  }

  String _formatFecha(String? raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Color _estadoColor(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'completada':
        return Colors.green[700]!;
      case 'cancelada':
      case 'anulada':
        return Colors.red;
      case 'pendiente':
        return Colors.orange;
      default:
        return Colors.black54;
    }
  }

  List<Map<String, dynamic>> get _ventasFiltradas {
    return _ventas.where((venta) {
      final numero = (venta['numeroFactura'] ?? '').toString().toLowerCase();
      final estado = (venta['estado'] ?? '').toString().toLowerCase();
      final fecha = DateTime.tryParse((venta['fechaVenta'] ?? '').toString());
      final coincideTexto = _searchQuery.isEmpty || numero.contains(_searchQuery);
      final coincideEstado = _estadoFiltro == 'todos' || estado == _estadoFiltro;
      final coincideDesde = _desde == null || (fecha != null && !fecha.isBefore(_desde!));
      final coincideHasta = _hasta == null ||
          (fecha != null &&
              !fecha.isAfter(
                DateTime(_hasta!.year, _hasta!.month, _hasta!.day, 23, 59, 59),
              ));
      return coincideTexto && coincideEstado && coincideDesde && coincideHasta;
    }).toList();
  }

  Future<void> _pickDesde() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _desde ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _desde = picked);
  }

  Future<void> _pickHasta() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hasta ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _hasta = picked);
  }

  void _limpiarFiltros() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _estadoFiltro = 'todos';
      _desde = null;
      _hasta = null;
    });
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de compras'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _loadHistory,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _ventas.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.black26),
                          SizedBox(height: 16),
                          Text(
                            'Aún no tienes compras registradas.',
                            style: TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _ventasFiltradas.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _searchCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Buscar por número de factura',
                                        prefixIcon: Icon(Icons.search),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            initialValue: _estadoFiltro,
                                            decoration: const InputDecoration(
                                              labelText: 'Estado',
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: 'todos', child: Text('Todos')),
                                              DropdownMenuItem(value: 'completada', child: Text('Completada')),
                                              DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                                              DropdownMenuItem(value: 'cancelada', child: Text('Cancelada')),
                                              DropdownMenuItem(value: 'anulada', child: Text('Anulada')),
                                            ],
                                            onChanged: (v) => setState(() => _estadoFiltro = v ?? 'todos'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: _limpiarFiltros,
                                          child: const Text('Limpiar'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _pickDesde,
                                            icon: const Icon(Icons.event),
                                            label: Text(
                                              _desde == null
                                                  ? 'Desde'
                                                  : '${_desde!.day}/${_desde!.month}/${_desde!.year}',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _pickHasta,
                                            icon: const Icon(Icons.event_available),
                                            label: Text(
                                              _hasta == null
                                                  ? 'Hasta'
                                                  : '${_hasta!.day}/${_hasta!.month}/${_hasta!.year}',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Resultados: ${_ventasFiltradas.length}',
                                        style: const TextStyle(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          final venta = _ventasFiltradas[index - 1];
                          final estado = venta['estado'] as String?;
                          final totalVenta = _asDouble(venta['totalVenta']);
                          final subtotal = _asDouble(venta['subtotal']);
                          final totalImpuesto = _asDouble(venta['totalImpuesto']);

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.black12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Cabecera: número factura + estado
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.receipt, size: 18, color: AppColors.primaryDark),
                                          const SizedBox(width: 6),
                                          Text(
                                            venta['numeroFactura'] ?? '-',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _estadoColor(estado).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: _estadoColor(estado)),
                                        ),
                                        child: Text(
                                          estado ?? '-',
                                          style: TextStyle(
                                            color: _estadoColor(estado),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Fecha
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: Colors.black54),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatFecha(venta['fechaVenta']),
                                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  // Montos
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Subtotal', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                          Text('\$${subtotal.toStringAsFixed(2)}',
                                              style: const TextStyle(fontSize: 14)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('IVA (12%)', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                          Text('\$${totalImpuesto.toStringAsFixed(2)}',
                                              style: const TextStyle(fontSize: 14)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Total',
                                              style: TextStyle(color: Colors.black54, fontSize: 12)),
                                          Text(
                                            '\$${totalVenta.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ],
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
    );
  }
}
