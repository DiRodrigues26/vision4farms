import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
    if (success && mounted) context.go('/farms');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Stack(
        children: [
          // ── Fundo com ilustração de paisagem ──────────
          SizedBox(
            width: size.width,
            height: size.height,
            child: CustomPaint(painter: _LandscapePainter()),
          ),

          // ── Conteúdo ──────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Título no topo
                const SizedBox(height: 60),
                const Text(
                  'Vision4Farms',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bem-vindo de volta!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(),

                // Card do formulário
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Erro
                        if (auth.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(auth.errorMessage!,
                                  style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email / Username
                        const Text('Email', style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(hintText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        const Text('Password', style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppTheme.textSecondary, size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 24),

                        // Botão Login
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _login,
                          child: auth.isLoading
                              ? const SizedBox(height: 20, width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Login'),
                        ),
                        const SizedBox(height: 14),

                        // Forgot password
                        Center(
                          child: TextButton(
                            onPressed: () => context.push('/auth/password-reset'),
                            child: const Text(
                              'Esqueceu a password?',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Criar conta
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Não tem conta? ',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.push('/auth/register'),
                                child: const Text(
                                  'Criar conta',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pintor da paisagem agrícola ────────────────────────────
class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fundo verde escuro
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF2E7D32),
    );

    // Camadas de colinas — da mais clara para a mais escura (frente)
    final hills = [
      _HillData(color: const Color(0xFF81C784), heightFactor: 0.38, waveFactor: 0.12),
      _HillData(color: const Color(0xFF66BB6A), heightFactor: 0.45, waveFactor: 0.09),
      _HillData(color: const Color(0xFF4CAF50), heightFactor: 0.52, waveFactor: 0.07),
      _HillData(color: const Color(0xFF43A047), heightFactor: 0.60, waveFactor: 0.06),
      _HillData(color: const Color(0xFF388E3C), heightFactor: 0.68, waveFactor: 0.05),
      _HillData(color: const Color(0xFF2E7D32), heightFactor: 0.78, waveFactor: 0.04),
    ];

    for (final hill in hills) {
      final path = Path();
      final baseY = size.height * hill.heightFactor;
      final waveH = size.height * hill.waveFactor;

      path.moveTo(0, baseY);
      path.cubicTo(
        size.width * 0.25, baseY - waveH,
        size.width * 0.5,  baseY + waveH * 0.6,
        size.width * 0.75, baseY - waveH * 0.4,
      );
      path.cubicTo(
        size.width * 0.88, baseY - waveH * 0.8,
        size.width,        baseY + waveH * 0.3,
        size.width,        baseY,
      );
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      canvas.drawPath(path, Paint()..color = hill.color);
    }

    // Árvores na base
    _drawTrees(canvas, size);
  }

  void _drawTrees(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1B5E20);
    final positions = [0.05, 0.12, 0.20, 0.75, 0.83, 0.91, 0.97];
    for (final x in positions) {
      final cx = size.width * x;
      final cy = size.height * 0.88;
      final h = size.height * 0.08;
      final w = size.width * 0.04;
      // Tronco
      canvas.drawRect(Rect.fromLTWH(cx - w * 0.15, cy, w * 0.3, h * 0.4), paint);
      // Copa (triângulo)
      final tree = Path()
        ..moveTo(cx, cy - h)
        ..lineTo(cx - w, cy)
        ..lineTo(cx + w, cy)
        ..close();
      canvas.drawPath(tree, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HillData {
  final Color color;
  final double heightFactor;
  final double waveFactor;
  const _HillData({required this.color, required this.heightFactor, required this.waveFactor});
}