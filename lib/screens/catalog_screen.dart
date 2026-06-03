import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:proyecto_north/screens/cart_screen.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/cart.dart';
import '../theme/app_theme.dart';

class Product {
  final int id;
  final String nombre;
  final String descripcion;
  int stock;
  final double precioUnitario;
  final double iva;
  final String? imagenUrl;

  Product({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.stock,
    required this.precioUnitario,
    required this.iva,
    this.imagenUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      stock: json['stock'] ?? 0,
      precioUnitario: (json['precio'] ?? 0).toDouble(),
      iva: ((json['porcentajeIVA'] ?? 0) / 100).toDouble(),
      imagenUrl: json['imagenUrl'] as String?,
    );
  }

  double get total => precioUnitario * stock;
  double get totalConIva => total * (1 + iva);
}

class CustomDrawer extends StatefulWidget {
  final String userName;
  final String userEmail;
  final dynamic user;

  const CustomDrawer({
    Key? key,
    required this.userName,
    required this.userEmail,
    required this.user,
  }) : super(key: key);

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String? _imagenUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final api = ApiService();
      final usuario = await api.getUsuarioById(widget.user.id as int);
      final url = usuario['imagenUrl'] as String?;
      if (mounted && url != null && url.isNotEmpty) {
        setState(() { _imagenUrl = url; });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(widget.userEmail),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: (_imagenUrl != null && _imagenUrl!.isNotEmpty)
                  ? NetworkImage(_imagenUrl!)
                  : null,
              child: (_imagenUrl == null || _imagenUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 40, color: Colors.black87)
                  : null,
            ),
            decoration: const BoxDecoration(color: AppColors.primaryDark),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: AppColors.primaryDark),
            title: const Text('Editar Perfil'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile', arguments: widget.user);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: AppColors.primaryDark),
            title: const Text('Historial de compras'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/history', arguments: widget.user);
            },
          ),
          ListTile(
            leading: const Icon(Icons.credit_card, color: AppColors.primaryDark),
            title: const Text('Agregar Tarjeta'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/saldo', arguments: widget.user);
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: AppColors.primaryDark),
            title: const Text('Servicio al cliente'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/soporte');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}

class CatalogScreen extends StatefulWidget {
  final User user;
  const CatalogScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final Cart _cart = Cart();
  final TextEditingController _searchController = TextEditingController();
  final int _pageSize = 30;
  int _currentPage = 1;
  int _totalProducts = 0;
  List<Product> _currentPageProducts = [];
  List<Product> _productosIniciales = []; // Guardar lista completa inicial
  bool _isLoading = true;
  String? _error;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(() {
      final query = _searchController.text.trim();
      if (query != _searchTerm) {
        // Solo buscar si cambia el término
        _searchProducts(query);
      }
    });
  }

  Future<void> _fetchProducts({int? page, String? search}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ApiService();
      final data = await api.getProductosPaginados(
        page: page ?? _currentPage,
        limit: _pageSize,
        search: search ?? _searchTerm,
      );
        final productos = (data['data'] as List<dynamic>?)
            ?? (data['productos'] as List<dynamic>?)
            ?? [];
        
        // En la primera carga (página 1, sin búsqueda), guardar los productos iniciales completos
        if (_currentPage == 1 && _searchTerm.isEmpty && _productosIniciales.isEmpty) {
          _productosIniciales = productos
            .where((e) => (e['stock'] ?? 0) > 0)
            .map((e) => Product.fromJson(e))
            .toList();
        }
        
        // Si estamos en página 1 sin búsqueda y ya tenemos guardados los iniciales,
        // mostrar los iniciales pero actualizar su stock con los datos del API
        if (_currentPage == 1 && _searchTerm.isEmpty && _productosIniciales.isNotEmpty) {
          // Crear un mapa de ID -> stock actualizado del API
          final stockActualizado = <int, int>{};
          for (var producto in productos) {
            final id = (producto['id'] as int?) ?? 0;
            final stock = (producto['stock'] as int?) ?? 0;
            stockActualizado[id] = stock;
          }
          
          // Actualizar stock de los productos guardados
          for (var producto in _productosIniciales) {
            if (stockActualizado.containsKey(producto.id)) {
              producto.stock = stockActualizado[producto.id]!;
            }
          }
          
          setState(() {
            _currentPageProducts = _productosIniciales;
            _totalProducts = (data['total'] as int?) ?? 0;
            _isLoading = false;
          });
        } else {
          // Para otras páginas o búsquedas, filtrar normalmente
          final products = productos
            .where((e) => (e['stock'] ?? 0) > 0)
            .map((e) => Product.fromJson(e))
            .toList();
            
          setState(() {
            _currentPageProducts = products;
            _totalProducts = (data['total'] as int?) ?? products.length;
            _isLoading = false;
          });
        }
    } catch (e) {
      setState(() {
        _error = 'Error al cargar productos';
        _isLoading = false;
      });
    }
  }

  void _searchProducts(String query) {
    setState(() {
      _searchTerm = query;
      _currentPage = 1;
    });
    _fetchProducts(page: 1, search: query);
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _fetchProducts(page: page);
  }

  void _showGoToPageDialog() async {
    int? selectedPage;
    await showDialog(
      context: context,
      builder: (context) {
        final TextEditingController pageController = TextEditingController();
        return AlertDialog(
          title: const Text('Ir a página'),
          content: TextField(
            controller: pageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Número de página'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final page = int.tryParse(pageController.text);
                if (page != null && page > 0 && page <= _totalPages) {
                  selectedPage = page;
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Ir'),
            ),
          ],
        );
      },
    );
    if (selectedPage != null) {
      _goToPage(selectedPage!);
    }
  }

  int get _totalPages => (_totalProducts / _pageSize).ceil();

  Widget _buildPaginationBar() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _showGoToPageDialog,
          icon: const Icon(Icons.keyboard, size: 18),
          label: const Text('Ir a página'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryDark,
            side: const BorderSide(color: AppColors.primaryDark),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
        ),
        Text(
          'Página $_currentPage de $_totalPages',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductImage(product, size: 72),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _infoChip('Stock', '${product.stock}'),
                _infoChip('Precio u.', _formatMoney(product.precioUnitario)),
                _infoChip('IVA', '${(product.iva * 100).toStringAsFixed(0)}%'),
                _infoChip('Total', _formatMoney(product.total)),
                _infoChip('Total c/IVA', _formatMoney(product.totalConIva), emphasized: true),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart, size: 20),
                label: const Text('Añadir al carrito'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _addToCart(product),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product, {required double size}) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      child: Icon(Icons.inventory_2, size: size * 0.45, color: Colors.grey),
    );

    if (product.imagenUrl == null || product.imagenUrl!.isEmpty) {
      return ClipRRect(borderRadius: BorderRadius.circular(8), child: placeholder);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        product.imagenUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            color: Colors.grey[200],
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }

  String _formatMoney(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (value >= 10000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    }
    return '\$${value.toStringAsFixed(2)}';
  }

  void _addToCart(Product product) {
    if (product.precioUnitario <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede agregar un producto con precio 0 al carrito.')),
      );
      return;
    }
    final int enCarrito = _cart.cantidadEnCarrito(product.id);
    final int stockRestante = product.stock - enCarrito;
    if (stockRestante <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya tienes todo el stock disponible en el carrito.')),
      );
      return;
    }

    final TextEditingController cantidadCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stock total: ${product.stock}', style: const TextStyle(color: Colors.black54)),
                if (enCarrito > 0)
                  Text('En carrito: $enCarrito', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
            Text('Disponible: $stockRestante', style: TextStyle(
              color: stockRestante < 5 ? Colors.red : Colors.green[700],
              fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 12),
            TextField(
              controller: cantidadCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _StockLimitFormatter(stockRestante),
              ],
              decoration: InputDecoration(
                labelText: 'Cantidad',
                hintText: 'Máx $stockRestante',
                suffixText: '/ $stockRestante',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final int cantidad = int.tryParse(cantidadCtrl.text) ?? 1;
              if (cantidad < 1) return;
              setState(() {
                _cart.addProduct(CartItem(
                  productoId: product.id,
                  nombre: product.nombre,
                  descripcion: product.descripcion,
                  precioUnitario: product.precioUnitario,
                  iva: product.iva,
                  stockDisponible: product.stock,
                  imagenUrl: product.imagenUrl,
                  cantidad: cantidad,
                ));
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${product.nombre} ($cantidad) añadido al carrito')),
              );
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Productos'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Ver carrito',
              onPressed: () async {
                final resultado = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CartScreen(cart: _cart),
                    settings: RouteSettings(arguments: user),
                  ),
                );
                // Si compra fue exitosa, actualizar stock de los productos
                if (resultado == true && mounted) {
                  _fetchProducts(page: _currentPage);
                }
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart),
                  if (_cart.items.isNotEmpty)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_cart.items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      drawer: CustomDrawer(
        userName: '${user.nombre} ${user.apellido}',
        userEmail: user.email,
        user: user,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input de búsqueda
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar productos por nombre o descripción',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (value) {
                _searchProducts(value.trim());
              },
            ),
            const SizedBox(height: 12),
            _buildPaginationBar(),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (_error != null)
              Expanded(child: Center(child: Text(_error!))),
            if (!_isLoading && _error == null)
              Expanded(
                child: _currentPageProducts.isEmpty
                    ? const Center(child: Text('No se encontraron productos.'))
                    : ListView.builder(
                        itemCount: _currentPageProducts.length,
                        itemBuilder: (context, index) {
                          final product = _currentPageProducts[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: _buildProductCard(product),
                          );
                        },
                      ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

Widget _infoChip(String label, String value, {bool emphasized = false}) {
  return Container(
    constraints: const BoxConstraints(minWidth: 72, maxWidth: 160),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: emphasized ? const Color(0xFFE8F5E6) : const Color(0xFFF8FBF7),
      border: Border.all(
        color: emphasized ? AppColors.primary : const Color(0xFFD9E6D5),
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: emphasized ? 13 : 12,
            color: emphasized ? AppColors.primaryDark : AppColors.primaryDark,
          ),
        ),
      ],
    ),
  );
}

class _StockLimitFormatter extends TextInputFormatter {
  final int maxStock;
  _StockLimitFormatter(this.maxStock);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final value = int.tryParse(newValue.text);
    if (value == null) return oldValue;
    if (value > maxStock) return oldValue;
    if (value <= 0 && newValue.text.length > 1) return oldValue;
    return newValue;
  }
}