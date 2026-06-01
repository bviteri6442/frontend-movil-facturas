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
  final int stock;
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
            leading: const Icon(Icons.account_balance_wallet, color: AppColors.primaryDark),
            title: const Text('Agregar saldo'),
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
        final productos = (data['productos'] as List<dynamic>?) ?? [];
        final products = productos
          .where((e) => (e['stock'] ?? 0) > 0)
          .map((e) => Product.fromJson(e))
          .toList();
      setState(() {
        _currentPageProducts = products;
        _totalProducts = data['total'] ?? products.length;
        _isLoading = false;
      });
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
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CartScreen(cart: _cart),
                    settings: RouteSettings(arguments: user),
                  ),
                );
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
            const SizedBox(height: 16),
            // Paginación
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _showGoToPageDialog,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Ir a página'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                      ),
                      Flexible(
                        child: Text(
                          'Página $_currentPage de $_totalPages',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Card(
                              elevation: 1.5,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Imagen del producto
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: product.imagenUrl != null && product.imagenUrl!.isNotEmpty
                                              ? Image.network(
                                                  product.imagenUrl!,
                                                  width: 120,
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => Container(
                                                    width: 120,
                                                    height: 120,
                                                    color: Colors.grey[200],
                                                    child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                                  ),
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return Container(
                                                      width: 120,
                                                      height: 120,
                                                      color: Colors.grey[200],
                                                      child: const Center(child: CircularProgressIndicator()),
                                                    );
                                                  },
                                                )
                                              : Container(
                                                  width: 120,
                                                  height: 120,
                                                  color: Colors.grey[200],
                                                  child: const Icon(Icons.inventory_2, size: 48, color: Colors.grey),
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Info principal
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.nombre,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                product.descripcion,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.black54),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            _infoBox('Stock', product.stock.toString()),
                                                            const SizedBox(width: 8),
                                                            _infoBox('Precio unitario', '\$${product.precioUnitario.toStringAsFixed(2)}'),
                                                            const SizedBox(width: 8),
                                                            _infoBox('IVA', '${(product.iva * 100).toStringAsFixed(0)}%'),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Total sin IVA
                                                  _infoBox('Total', '\$${product.total.toStringAsFixed(2)}'),
                                                  const SizedBox(width: 8),
                                                  // Total con IVA
                                                  _infoBox('Total c/IVA', '\$${product.totalConIva.toStringAsFixed(2)}'),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Botón añadir al carrito
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.add_shopping_cart),
                                          label: const Text('Añadir al carrito'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                          ),
                                          onPressed: () => _addToCart(product),
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
            // Paginación
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _showGoToPageDialog,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Ir a página'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                    ),
                    Text('Página $_currentPage de $_totalPages'),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _infoBox(String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FBF7),
      border: Border.all(color: const Color(0xFFD9E6D5)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
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