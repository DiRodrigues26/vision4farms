import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  final String? inviteCode; // Pré-preenchido se vier do link de convite
  const RegisterScreen({super.key, this.inviteCode});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final TextEditingController _inviteController;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _inviteController = TextEditingController(text: widget.inviteCode ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmController.text,
      fullName: _nameController.text.trim(),
      mobile: _mobileController.text.trim(),
      inviteCode: _inviteController.text.trim().toUpperCase(),
    );
    if (success && mounted) context.go('/farms');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasInvite = widget.inviteCode != null && widget.inviteCode!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Criar conta', style: TextStyle(color: AppTheme.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Registo',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              const Text('Preenche os teus dados para criar a conta.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 24),

              // Banner de convite
              if (hasInvite)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Convite válido! Preenche os dados para entrar.',
                            style: TextStyle(fontSize: 13, color: AppTheme.primary,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),

              if (auth.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(auth.errorMessage!,
                          style: const TextStyle(color: AppTheme.error, fontSize: 14))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Código de convite
                    TextFormField(
                      controller: _inviteController,
                      readOnly: hasInvite,
                      decoration: InputDecoration(
                        labelText: 'Código de convite *',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        filled: true,
                        fillColor: hasInvite
                            ? AppTheme.primary.withOpacity(0.05)
                            : Colors.white,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 8,
                      validator: (v) => v!.isEmpty ? 'Código de convite obrigatório' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v!.length < 3 ? 'Mínimo 3 caracteres' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => !v!.contains('@') ? 'Email inválido' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Telemóvel (opcional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Palavra-passe *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmar palavra-passe *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) => v != _passwordController.text
                          ? 'As passwords não coincidem' : null,
                      onFieldSubmitted: (_) => _register(),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: auth.isLoading ? null : _register,
                      child: auth.isLoading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Criar conta'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Já tens conta? ',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Iniciar sessão'),
                        ),
                      ],
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