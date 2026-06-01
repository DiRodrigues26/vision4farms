import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _currentCtrl    = TextEditingController();
  final _newCtrl        = TextEditingController();
  final _confirmCtrl    = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );

    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password alterada com sucesso!')),
        );
      } else {
        setState(() { _error = auth.errorMessage ?? 'Erro ao alterar password.'; _saving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('Alterar Password'),
        backgroundColor: const Color(0xFFF5F5F0),
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Introduz a tua password atual e define uma nova.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),

              const SizedBox(height: 28),

              _buildPasswordField(
                label: 'Password atual',
                controller: _currentCtrl,
                obscure: !_showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
                validator: (v) => (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
              ),

              const SizedBox(height: 16),

              _buildPasswordField(
                label: 'Nova password',
                controller: _newCtrl,
                obscure: !_showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo obrigatório';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildPasswordField(
                label: 'Confirmar nova password',
                controller: _confirmCtrl,
                obscure: !_showConfirm,
                onToggle: () => setState(() => _showConfirm = !_showConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo obrigatório';
                  if (v != _newCtrl.text) return 'As passwords não coincidem';
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Alterar Password',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.textSecondary, size: 20),
              onPressed: onToggle,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.error),
            ),
          ),
        ),
      ],
    );
  }
}
