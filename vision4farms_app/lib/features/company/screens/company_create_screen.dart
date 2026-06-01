import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/theme/app_theme.dart';

class CompanyCreateScreen extends StatefulWidget {
  const CompanyCreateScreen({super.key});

  @override
  State<CompanyCreateScreen> createState() => _CompanyCreateScreenState();
}

class _CompanyCreateScreenState extends State<CompanyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nifController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  final _api = ApiService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nifController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      await _api.post('/farms/company/create/', data: {
        'company_name': _nameController.text.trim(),
        'company_email': _emailController.text.trim(),
        if (_nifController.text.isNotEmpty) 'company_nif': _nifController.text.trim(),
        if (_addressController.text.isNotEmpty) 'company_address': _addressController.text.trim(),
        if (_cityController.text.isNotEmpty) 'company_city': _cityController.text.trim(),
        if (_districtController.text.isNotEmpty) 'company_district': _districtController.text.trim(),
        'company_country': 'Portugal',
      });

      if (!mounted) return;
      context.go('/farms');

    } catch (e) {
      String msg = 'Erro ao criar empresa.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data.containsKey('detail')) {
          msg = data['detail'];
        } else {
          msg = 'Status: ${e.response?.statusCode} — $data';
        }
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Header
              const Icon(Icons.business_outlined, size: 48, color: AppTheme.primary),
              const SizedBox(height: 20),
              const Text(
                'Criar empresa',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Antes de criares explorações, precisas de registar a tua empresa.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da empresa *',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email da empresa *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => !v!.contains('@') ? 'Email inválido' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nifController,
                      decoration: const InputDecoration(
                        labelText: 'NIF (opcional)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Morada (opcional)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(labelText: 'Cidade'),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _districtController,
                            decoration: const InputDecoration(labelText: 'Distrito'),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Criar empresa'),
                    ),
                    const SizedBox(height: 16),
                    // Opção de saltar (utilizadores já existentes com empresa)
                    TextButton(
                      onPressed: () => context.go('/farms'),
                      child: const Text(
                        'Já tenho empresa — ir para as explorações',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}