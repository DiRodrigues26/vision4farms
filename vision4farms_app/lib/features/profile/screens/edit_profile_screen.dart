import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _mobileCtrl  = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _nifCtrl     = TextEditingController();
  final _nifapCtrl   = TextEditingController();
  final _cardfitCtrl = TextEditingController();

  bool _saving = false;
  String? _error;
  String? _newPicturePath;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().user?.profile;
    if (profile != null) {
      _nameCtrl.text    = profile.profileName;
      _emailCtrl.text   = profile.profileEmail;
      _mobileCtrl.text  = profile.profileMobile ?? '';
      _phoneCtrl.text   = profile.profilePhone ?? '';
      _nifCtrl.text     = profile.profileNif ?? '';
      _nifapCtrl.text   = profile.profileNifap ?? '';
      _cardfitCtrl.text = profile.profileCardfit ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _phoneCtrl.dispose();
    _nifCtrl.dispose();
    _nifapCtrl.dispose();
    _cardfitCtrl.dispose();
    super.dispose();
  }

  String _resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    var origin = AppConstants.baseUrl;
    if (origin.endsWith('/api')) origin = origin.substring(0, origin.length - 4);
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.startsWith('media/')) return '$origin/$cleanPath';
    return '$origin/media/$cleanPath';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked != null) {
      setState(() => _newPicturePath = picked.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final auth = context.read<AuthProvider>();

    // Upload nova foto se selecionada
    if (_newPicturePath != null) {
      final ok = await auth.uploadProfilePicture(_newPicturePath!);
      if (!ok && mounted) {
        setState(() { _error = auth.errorMessage ?? 'Erro ao carregar foto.'; _saving = false; });
        return;
      }
    }

    // Atualizar campos de texto
    final data = <String, dynamic>{
      'profile_name':    _nameCtrl.text.trim(),
      'profile_email':   _emailCtrl.text.trim(),
      'profile_mobile':  _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
      'profile_phone':   _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'profile_nif':     _nifCtrl.text.trim().isEmpty ? null : _nifCtrl.text.trim(),
      'profile_nifap':   _nifapCtrl.text.trim().isEmpty ? null : _nifapCtrl.text.trim(),
      'profile_cardfit': _cardfitCtrl.text.trim().isEmpty ? null : _cardfitCtrl.text.trim(),
    };

    final ok = await auth.updateProfile(data);

    if (mounted) {
      if (ok) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
        );
      } else {
        setState(() { _error = auth.errorMessage ?? 'Erro ao atualizar perfil.'; _saving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().user?.profile;
    final picture = profile?.profilePicture;
    final pictureUrl = _resolveMediaUrl(picture);
    final name = _nameCtrl.text;

    // Determinar imagem do avatar
    ImageProvider? avatarImage;
    if (_newPicturePath != null) {
      avatarImage = FileImage(File(_newPicturePath!));
    } else if (pictureUrl.isNotEmpty) {
      avatarImage = NetworkImage(pictureUrl);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: const Color(0xFFF5F5F0),
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar com botão de câmara
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              _buildField(label: 'Nome', controller: _nameCtrl, hint: 'Nome completo',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null),
              const SizedBox(height: 16),
              _buildField(label: 'Email', controller: _emailCtrl, hint: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                  if (!v.contains('@')) return 'Email inválido';
                  return null;
                }),
              const SizedBox(height: 16),
              _buildField(label: 'Telemóvel', controller: _mobileCtrl, hint: 'Ex: 912345678',
                keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildField(label: 'Telefone', controller: _phoneCtrl, hint: 'Ex: 212345678',
                keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildField(label: 'NIF', controller: _nifCtrl, hint: 'Número de Identificação Fiscal',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length != 9) return 'NIF deve ter 9 dígitos';
                  return null;
                }),
              const SizedBox(height: 16),
              _buildField(label: 'NIFAP', controller: _nifapCtrl, hint: 'Número IFAP',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length != 9) return 'NIFAP deve ter 9 dígitos';
                  return null;
                }),
              const SizedBox(height: 16),
              _buildField(label: 'Cartão Fitossanitário', controller: _cardfitCtrl, hint: 'Número do cartão',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length != 9) return 'Deve ter 9 dígitos';
                  return null;
                }),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.error)),
          ),
        ),
      ],
    );
  }
}
