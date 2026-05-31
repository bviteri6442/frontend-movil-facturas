import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _error;
  String? _imagenUrl;
  bool _isUploadingImage = false;

  // IDs para actualizar
  int _clienteId = 0;

  // Controladores de datos personales
  late TextEditingController _nombreUsuarioCtrl;
  late TextEditingController _nombreCtrl;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _emailCtrl;       // BLOQUEADO
  late TextEditingController _documentoCtrl;   // BLOQUEADO
  late TextEditingController _telefonoCtrl;
  late TextEditingController _direccionCtrl;

  // Controladores de cambio de contraseña
  final _contrasenaActualCtrl = TextEditingController();
  final _nuevaContrasenaCtrl  = TextEditingController();
  final _confirmarContrasenaCtrl = TextEditingController();

  bool _showChangePassword = false;
  bool _obscureActual = true;
  bool _obscureNueva  = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _nombreUsuarioCtrl = TextEditingController();
    _nombreCtrl        = TextEditingController();
    _apellidoCtrl      = TextEditingController();
    _emailCtrl         = TextEditingController();
    _documentoCtrl     = TextEditingController();
    _telefonoCtrl      = TextEditingController();
    _direccionCtrl     = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nombreUsuarioCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _documentoCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _contrasenaActualCtrl.dispose();
    _nuevaContrasenaCtrl.dispose();
    _confirmarContrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final usuario = await _api.getUsuarioById(widget.user.id);
      final cliente = await _api.getClienteByUserId(widget.user.id);
      setState(() {
        _clienteId          = cliente['id'] ?? 0;
        _nombreUsuarioCtrl.text = usuario['nombreUsuario'] ?? '';
        _nombreCtrl.text    = (cliente['nombre'] ?? usuario['nombre'] ?? '').toString();
        _apellidoCtrl.text  = (cliente['apellido'] ?? usuario['apellido'] ?? '').toString();
        _emailCtrl.text     = usuario['email'] ?? '';
        _documentoCtrl.text = cliente['documento'] ?? 'Sin registro';
        _telefonoCtrl.text  = cliente['telefono'] ?? '';
        _direccionCtrl.text = cliente['direccion'] ?? '';
        _imagenUrl          = usuario['imagenUrl'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar el perfil: $e'; _isLoading = false; });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; });
    try {
      // Actualizar usuario (nombre, apellido)
      final resUser = await _api.updateUsuario(widget.user.id, {
        'id': widget.user.id,
        'nombre': _nombreCtrl.text.trim(),
        'apellido': _apellidoCtrl.text.trim(),
      });
      bool clienteOk = true;
      String? clienteError;
      // Actualizar cliente solo si tiene registro
      if (_clienteId > 0) {
        final resCliente = await _api.updateCliente(_clienteId, {
          'id': _clienteId,
          'nombre': _nombreCtrl.text.trim(),
          'apellido': _apellidoCtrl.text.trim(),
          'telefono': _telefonoCtrl.text.trim(),
          'direccion': _direccionCtrl.text.trim(),
        });
        clienteOk = resCliente['success'] == true;
        clienteError = resCliente['message'];
      }
      if (resUser['success'] == true && clienteOk) {
        setState(() { _isEditing = false; });
        _showSnackBar('Perfil actualizado correctamente.', isError: false);
      } else {
        _showSnackBar(resUser['message'] ?? clienteError ?? 'Error al guardar.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  Future<void> _changePassword() async {
    if (_contrasenaActualCtrl.text.isEmpty ||
        _nuevaContrasenaCtrl.text.isEmpty ||
        _confirmarContrasenaCtrl.text.isEmpty) {
      _showSnackBar('Completa todos los campos de contraseña.', isError: true);
      return;
    }
    if (_nuevaContrasenaCtrl.text != _confirmarContrasenaCtrl.text) {
      _showSnackBar('Las contraseñas nuevas no coinciden.', isError: true);
      return;
    }
    if (_nuevaContrasenaCtrl.text.length < 6) {
      _showSnackBar('La nueva contraseña debe tener al menos 6 caracteres.', isError: true);
      return;
    }
    setState(() { _isSaving = true; });
    try {
      final res = await _api.cambiarContrasena(
        usuarioId: widget.user.id,
        contrasenaActual: _contrasenaActualCtrl.text,
        nuevaContrasena: _nuevaContrasenaCtrl.text,
      );
      if (res['success'] == true) {
        _contrasenaActualCtrl.clear();
        _nuevaContrasenaCtrl.clear();
        _confirmarContrasenaCtrl.clear();
        setState(() { _showChangePassword = false; });
        _showSnackBar('Contraseña actualizada correctamente.', isError: false);
      } else {
        _showSnackBar(res['message'] ?? 'Error al cambiar contraseña.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() { _isUploadingImage = true; });
    try {
      final bytes = await picked.readAsBytes();
      final url = await _api.uploadImageToCloudinary(bytes, picked.name);
      await _api.updateUsuarioImagen(widget.user.id, url);
      setState(() { _imagenUrl = url; });
      _showSnackBar('Foto de perfil actualizada.', isError: false);
    } catch (e) {
      _showSnackBar('Error al subir imagen: $e', isError: true);
    } finally {
      setState(() { _isUploadingImage = false; });
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              tooltip: _isEditing ? 'Cancelar edición' : 'Editar perfil',
              onPressed: () {
                if (_isEditing) {
                  _loadProfile(); // Restaura los datos originales
                }
                setState(() { _isEditing = !_isEditing; _showChangePassword = false; });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadProfile, child: const Text('Reintentar')),
                  ],
                ))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Foto de perfil
                        Center(
                          child: Stack(
                            children: [
                              _isUploadingImage
                                  ? const CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.deepPurple,
                                      child: CircularProgressIndicator(color: Colors.white),
                                    )
                                  : CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.deepPurple.shade100,
                                      backgroundImage: (_imagenUrl != null && _imagenUrl!.isNotEmpty)
                                          ? NetworkImage(_imagenUrl!)
                                          : null,
                                      child: (_imagenUrl == null || _imagenUrl!.isEmpty)
                                          ? const Icon(Icons.person, size: 60, color: Colors.deepPurple)
                                          : null,
                                    ),
                              if (_isEditing && !_isUploadingImage)
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: GestureDetector(
                                    onTap: _pickAndUploadImage,
                                    child: const CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.deepPurple,
                                      child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isEditing)
                          Center(
                            child: Text('Modo edición activo', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(height: 20),

                        const Text('DATOS DE CUENTA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Nombre de usuario (solo lectura siempre)
                        _buildField(
                          controller: _nombreUsuarioCtrl,
                          label: 'Nombre de usuario',
                          icon: Icons.account_circle,
                          enabled: false,
                          hint: 'No se puede cambiar el nombre de usuario',
                        ),

                        // Email (BLOQUEADO)
                        _buildField(
                          controller: _emailCtrl,
                          label: 'Correo electrónico',
                          icon: Icons.email,
                          enabled: false,
                          isLocked: true,
                        ),

                        // Documento / Cédula (BLOQUEADO)
                        _buildField(
                          controller: _documentoCtrl,
                          label: 'Cédula / Documento',
                          icon: Icons.badge,
                          enabled: false,
                          isLocked: true,
                        ),

                        const SizedBox(height: 16),
                        const Text('DATOS PERSONALES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Nombre (editable)
                        _buildField(
                          controller: _nombreCtrl,
                          label: 'Nombre',
                          icon: Icons.person,
                          enabled: _isEditing,
                          formatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]')),
                            LengthLimitingTextInputFormatter(20),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'El nombre es requerido';
                            if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                            return null;
                          },
                        ),

                        // Apellido (editable)
                        _buildField(
                          controller: _apellidoCtrl,
                          label: 'Apellido',
                          icon: Icons.person_outline,
                          enabled: _isEditing,
                          formatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ]')),
                            LengthLimitingTextInputFormatter(20),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'El apellido es requerido';
                            if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                            return null;
                          },
                        ),

                        // Teléfono (editable)
                        _buildField(
                          controller: _telefonoCtrl,
                          label: 'Teléfono',
                          icon: Icons.phone,
                          enabled: _isEditing,
                          keyboardType: TextInputType.phone,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'El teléfono es requerido';
                            if (v.trim().length != 10) return 'El teléfono debe tener 10 dígitos';
                            return null;
                          },
                        ),

                        // Dirección (editable)
                        _buildField(
                          controller: _direccionCtrl,
                          label: 'Dirección',
                          icon: Icons.location_on,
                          enabled: _isEditing,
                          formatters: [LengthLimitingTextInputFormatter(100)],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'La dirección es requerida';
                            return null;
                          },
                        ),

                        // Botón guardar cambios
                        if (_isEditing) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                              label: Text(_isSaving ? 'Guardando...' : 'Guardar cambios'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _isSaving ? null : _saveProfile,
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Sección cambio de contraseña
                        InkWell(
                          onTap: () => setState(() { _showChangePassword = !_showChangePassword; }),
                          child: Row(
                            children: [
                              const Text('CAMBIAR CONTRASEÑA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                              const Spacer(),
                              Icon(_showChangePassword ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                            ],
                          ),
                        ),
                        const Divider(),

                        if (_showChangePassword) ...[
                          const SizedBox(height: 8),
                          _buildPasswordField(
                            controller: _contrasenaActualCtrl,
                            label: 'Contraseña actual',
                            obscure: _obscureActual,
                            onToggle: () => setState(() { _obscureActual = !_obscureActual; }),
                          ),
                          _buildPasswordField(
                            controller: _nuevaContrasenaCtrl,
                            label: 'Nueva contraseña',
                            obscure: _obscureNueva,
                            onToggle: () => setState(() { _obscureNueva = !_obscureNueva; }),
                          ),
                          _buildPasswordField(
                            controller: _confirmarContrasenaCtrl,
                            label: 'Confirmar nueva contraseña',
                            obscure: _obscureConfirm,
                            onToggle: () => setState(() { _obscureConfirm = !_obscureConfirm; }),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.lock_reset),
                              label: Text(_isSaving ? 'Actualizando...' : 'Cambiar contraseña'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _isSaving ? null : _changePassword,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    bool isLocked = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: isLocked ? Colors.grey : Colors.black87),
          suffixIcon: isLocked ? const Icon(Icons.lock, color: Colors.grey, size: 18) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isLocked ? Colors.grey.shade300 : Colors.grey.shade400),
          ),
          filled: !enabled,
          fillColor: isLocked ? Colors.grey.shade100 : (enabled ? null : Colors.grey.shade50),
          labelStyle: TextStyle(color: isLocked ? Colors.grey : null),
        ),
        style: TextStyle(color: isLocked ? Colors.grey : null),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
          LengthLimitingTextInputFormatter(16),
        ],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock, color: Colors.black87),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: onToggle,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
