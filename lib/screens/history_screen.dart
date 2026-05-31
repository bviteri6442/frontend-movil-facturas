import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  final User user;
  const HistoryScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _ventas = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de compras'),
        backgroundColor: Colors.black87,
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
                            backgroundColor: Colors.black87,
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
                        itemCount: _ventas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final venta = _ventas[index];
                          final estado = venta['estado'] as String?;
                          final totalVenta = (venta['totalVenta'] ?? 0).toDouble();
                          final subtotal = (venta['subtotal'] ?? 0).toDouble();
                          final totalImpuesto = (venta['totalImpuesto'] ?? 0).toDouble();

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
                                          const Icon(Icons.receipt, size: 18, color: Colors.black87),
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
                                          color: _estadoColor(estado).withOpacity(0.12),
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
                                              color: Colors.black87,
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
