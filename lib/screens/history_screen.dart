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

  List<Map<String, dynamic>> get _ventasFiltradas {
    return _ventas.where((venta) {
      final numero = (venta['numeroFactura'] ?? '').toString().toLowerCase();
      final fecha = DateTime.tryParse((venta['fechaVenta'] ?? '').toString());
      final coincideTexto = _searchQuery.isEmpty || numero.contains(_searchQuery);
      final coincideDesde = _desde == null || (fecha != null && !fecha.isBefore(_desde!));
      final coincideHasta = _hasta == null ||
          (fecha != null &&
              !fecha.isAfter(
                DateTime(_hasta!.year, _hasta!.month, _hasta!.day, 23, 59, 59),
              ));
      return coincideTexto && coincideDesde && coincideHasta;
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
      _desde = null;
      _hasta = null;
    });
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  int? _ventaIdFrom(Map<String, dynamic> venta) {
    final id = venta['ventaId'] ?? venta['id'];
    if (id is int) return id;
    return int.tryParse('$id');
  }

  Future<void> _showFacturaDetail(Map<String, dynamic> ventaResumen) async {
    final ventaId = _ventaIdFrom(ventaResumen);
    if (ventaId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar la factura.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _FacturaDetailDialog(
          api: _api,
          ventaId: ventaId,
          resumen: ventaResumen,
          formatFecha: _formatFecha,

          asDouble: _asDouble,
        );
      },
    );
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
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: _searchCtrl,
                                            decoration: InputDecoration(
                                              labelText: 'Buscar por número de factura',
                                              prefixIcon: const Icon(Icons.search),
                                              contentPadding: const EdgeInsets.symmetric(
                                                vertical: 12,
                                                horizontal: 12,
                                              ),
                                              labelStyle: const TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        OutlinedButton(
                                          onPressed: _limpiarFiltros,
                                          child: const Text('Limpiar'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
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
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _showFacturaDetail(venta),
                              child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Cabecera: número factura + estado
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.receipt, size: 18, color: AppColors.primaryDark),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                venta['numeroFactura'] ?? '-',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Colors.black38, size: 22),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.green),
                                        ),
                                        child: Text(
                                          estado ?? '-',
                                          style: const TextStyle(
                                            color: Colors.green,
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
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _FacturaDetailDialog extends StatefulWidget {
  final ApiService api;
  final int ventaId;
  final Map<String, dynamic> resumen;
  final String Function(String?) formatFecha;
  final double Function(dynamic) asDouble;

  const _FacturaDetailDialog({
    required this.api,
    required this.ventaId,
    required this.resumen,
    required this.formatFecha,
    required this.asDouble,
  });

  @override
  State<_FacturaDetailDialog> createState() => _FacturaDetailDialogState();
}

class _FacturaDetailDialogState extends State<_FacturaDetailDialog> {
  Map<String, dynamic>? _detalle;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.getVentaById(widget.ventaId);
      if (!mounted) return;
      setState(() {
        _detalle = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get _v => _detalle ?? widget.resumen;

  List<Map<String, dynamic>> get _lineas {
    final raw = _v['detalles'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = (_v['estado'] ?? '').toString();
    final numero = (_v['numeroFactura'] ?? '-').toString();
    final subtotal = widget.asDouble(_v['subtotal']);
    final impuesto = widget.asDouble(_v['totalImpuesto']);
    final total = widget.asDouble(_v['totalVenta']);
    final ivaPct = widget.asDouble(_v['porcentajeIVA']);
    final observaciones = (_v['observaciones'] ?? '').toString().trim();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          numero,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          widget.formatFecha(_v['fechaVenta']?.toString()),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: Text(
                      estado.isEmpty ? '-' : estado,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'No se cargaron los productos: $_error',
                                style: TextStyle(color: Colors.orange[800], fontSize: 12),
                              ),
                            ),
                          _infoRow('Cliente', (_v['clienteNombre'] ?? '—').toString()),
                          _infoRow('Atendido por', (_v['usuarioNombre'] ?? '—').toString()),
                          if (observaciones.isNotEmpty)
                            _infoRow('Observaciones', observaciones),
                          const SizedBox(height: 8),
                          const Text(
                            'Productos',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_lineas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Sin detalle de productos disponible.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          else
                            ..._lineas.map((linea) {
                              final nombre = (linea['productoNombre'] ?? 'Producto').toString();
                              final cantidad = linea['cantidad'] ?? 0;
                              final precio = widget.asDouble(linea['precioUnitario']);
                              final descuento = widget.asDouble(linea['descuento']);
                              final lineTotal = widget.asDouble(linea['total']);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FBF7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFD9E6D5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombre,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Cant: $cantidad  ·  P. unit: \$${precio.toStringAsFixed(2)}'
                                      '${descuento > 0 ? '  ·  Desc: ${descuento.toStringAsFixed(0)}%' : ''}',
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '\$${lineTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal', style: TextStyle(color: Colors.black54)),
                              Text('\$${subtotal.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ivaPct > 0 ? 'IVA (${ivaPct.toStringAsFixed(0)}%)' : 'IVA',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              Text('\$${impuesto.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Text(
                                '\$${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
