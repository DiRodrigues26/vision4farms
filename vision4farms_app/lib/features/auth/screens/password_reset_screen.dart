import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

class PasswordResetScreen extends StatefulWidget {
  final String? token; // Pré-preenchido se vier do deep link
  final String? email;
  const PasswordResetScreen({super.key, this.token, this.email});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  int _step = 1; // 1=email, 2=intermédio, 3=código+password, 4=sucesso

  @override
  void initState() {
    super.initState();
    // Se vier do deep link, pré-preencher e ir direto para o passo 3
    if (widget.token != null && widget.token!.isNotEmpty) {
      _tokenController.text = widget.token!;
      if (widget.email != null) _emailController.text = widget.email!;
      _step = 3;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.requestPasswordReset(_emailController.text.trim());
    if (ok && mounted) setState(() => _step = 2); // Ir para página intermédia
  }

  Future<void> _confirmReset() async {
    if (!_resetFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.confirmPasswordReset(
      token: _tokenController.text.trim(),
      newPassword: _passwordController.text,
      confirmPassword: _confirmController.text,
    );
    if (ok && mounted) setState(() => _step = 4);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Recuperar palavra-passe',
            style: TextStyle(color: AppTheme.textPrimary)),
        leading: _step == 3
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = 2),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildStep(auth),
        ),
      ),
    );
  }

  Widget _buildStep(AuthProvider auth) {
    switch (_step) {
      case 1: return _buildEmailStep(auth);
      case 2: return _buildIntermediateStep();
      case 3: return _buildCodeStep(auth);
      case 4: return _buildSuccess();
      default: return _buildEmailStep(auth);
    }
  }

  // Passo 1 — Email
  Widget _buildEmailStep(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.lock_reset, size: 48, color: AppTheme.primary),
        const SizedBox(height: 24),
        const Text('Esqueceste a palavra-passe?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('Introduz o teu email e enviaremos um link para definires uma nova palavra-passe.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 32),
        if (auth.errorMessage != null) ...[
          _ErrorBox(message: auth.errorMessage!),
          const SizedBox(height: 16),
        ],
        Form(
          key: _emailFormKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => !v!.contains('@') ? 'Email inválido' : null,
                onFieldSubmitted: (_) => _sendEmail(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: auth.isLoading ? null : _sendEmail,
                child: auth.isLoading
                    ? const _LoadingIndicator()
                    : const Text('Enviar link'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Voltar ao login'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Passo 2 — Página intermédia
  Widget _buildIntermediateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.mark_email_read_outlined, size: 48, color: AppTheme.success),
        const SizedBox(height: 24),
        const Text('Email enviado!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Enviámos um link de recuperação para ${_emailController.text}.',
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                SizedBox(width: 8),
                Text('Como funciona?',
                    style: TextStyle(fontWeight: FontWeight.w600,
                        color: AppTheme.primary, fontSize: 14)),
              ]),
              SizedBox(height: 8),
              Text('1. Abre o email que enviámos',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              SizedBox(height: 4),
              Text('2. Clica no link — abre esta app automaticamente',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              SizedBox(height: 4),
              Text('3. Define a nova palavra-passe',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('Recebeste o email?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => _step = 3),
          child: const Text('Sim, tenho o código'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => setState(() => _step = 1),
          child: const Text('Não recebi — reenviar'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/auth/login'),
          child: const Text('Voltar ao login',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }

  // Passo 3 — Código + nova password
  Widget _buildCodeStep(AuthProvider auth) {
    final fromDeepLink = widget.token != null && widget.token!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (fromDeepLink) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Link válido! Define a tua nova palavra-passe.',
                    style: TextStyle(fontSize: 13, color: AppTheme.success,
                        fontWeight: FontWeight.w500))),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        const Text('Nova palavra-passe',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('Introduce o código recebido e define a nova palavra-passe.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        if (auth.errorMessage != null) ...[
          _ErrorBox(message: auth.errorMessage!),
          const SizedBox(height: 16),
        ],
        Form(
          key: _resetFormKey,
          child: Column(
            children: [
              TextFormField(
                controller: _tokenController,
                readOnly: fromDeepLink,
                decoration: InputDecoration(
                  labelText: 'Código de recuperação',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  filled: true,
                  fillColor: fromDeepLink
                      ? AppTheme.primary.withOpacity(0.05)
                      : Colors.white,
                ),
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
                validator: (v) => v != _passwordController.text
                    ? 'As passwords não coincidem' : null,
                onFieldSubmitted: (_) => _confirmReset(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: auth.isLoading ? null : _confirmReset,
                child: auth.isLoading
                    ? const _LoadingIndicator()
                    : const Text('Confirmar nova palavra-passe'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Passo 4 — Sucesso
  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
        const SizedBox(height: 24),
        const Text('Palavra-passe alterada!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
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

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) => Container(
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
        Expanded(child: Text(message,
            style: const TextStyle(color: AppTheme.error, fontSize: 13))),
      ],
    ),
  );
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 20, width: 20,
    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
  );
}