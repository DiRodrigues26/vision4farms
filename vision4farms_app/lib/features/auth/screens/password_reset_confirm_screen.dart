import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

class PasswordResetConfirmScreen extends StatefulWidget {
  const PasswordResetConfirmScreen({super.key});

  @override
  State<PasswordResetConfirmScreen> createState() => _PasswordResetConfirmScreenState();
}

class _PasswordResetConfirmScreenState extends State<PasswordResetConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _success = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.confirmPasswordReset(
      token: _tokenController.text.trim(),
      newPassword: _passwordController.text,
      confirmPassword: _confirmController.text,
    );
    if (ok && mounted) setState(() => _success = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: AppTheme.textPrimary),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _success ? _buildSuccess() : _buildForm(auth),
        ),
      ),
    );
  }

  Widget _buildForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Nova palavra-passe',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('Introduz o código recebido por email e define a nova palavra-passe.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 32),
        if (auth.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(auth.errorMessage!, style: const TextStyle(color: AppTheme.error)),
          ),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _tokenController,
                decoration: const InputDecoration(labelText: 'Código de recuperação', prefixIcon: Icon(Icons.vpn_key_outlined)),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure1,
                decoration: InputDecoration(
                  labelText: 'Nova palavra-passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscure2,
                decoration: InputDecoration(
                  labelText: 'Confirmar palavra-passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                validator: (v) => v != _passwordController.text ? 'As passwords não coincidem' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
        const SizedBox(height: 24),
        const Text('Palavra-passe alterada!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('Podes agora iniciar sessão com a nova palavra-passe.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => context.go('/auth/login'),
          child: const Text('Ir para o login'),
        ),
      ],
    );
  }
}
