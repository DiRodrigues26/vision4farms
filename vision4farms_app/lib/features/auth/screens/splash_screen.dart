import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/theme/app_theme.dart';
import 'maintenance_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Verificar status da app e depois autenticação
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _checkStatusAndNavigate();
    });
  }

  Future<void> _checkStatusAndNavigate() async {
    try {
      final api = ApiService();
      final response = await api.get(AppConstants.appStatus);
      final data = response.data as Map<String, dynamic>;

      if (!mounted) return;

      final maintenance = data['maintenance'] == true;
      final minVersion = data['min_version']?.toString() ?? '1.0.0';
      final storeUrl = data['store_url']?.toString() ?? '';

      if (maintenance) {
        _showMaintenance(MaintenanceType.maintenance, storeUrl);
        return;
      }

      if (_isVersionOutdated(AppConstants.appVersion, minVersion)) {
        _showMaintenance(MaintenanceType.forceUpdate, storeUrl);
        return;
      }
    } catch (_) {
      // Se falhar a verificação, continua normalmente
    }

    if (!mounted) return;
    _navigateToApp();
  }

  bool _isVersionOutdated(String current, String minimum) {
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final m = minimum.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final cv = i < c.length ? c[i] : 0;
      final mv = i < m.length ? m[i] : 0;
      if (cv < mv) return true;
      if (cv > mv) return false;
    }
    return false;
  }

  void _showMaintenance(MaintenanceType type, String storeUrl) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MaintenanceScreen(
          type: type,
          storeUrl: storeUrl.isNotEmpty ? storeUrl : null,
          onRetry: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SplashScreen()),
            );
          },
        ),
      ),
    );
  }

  Future<void> _navigateToApp() async {
    final auth = context.read<AuthProvider>();
    // Espera que o checkAuth resolva (status deixa de ser 'unknown').
    // Sem isto, se a verificação ainda estiver a decorrer (ex: backend
    // em cold start), navegamos para /auth/login mas o router faz bounce
    // de volta a /splash (porque status==unknown) e a app fica presa.
    var waitedMs = 0;
    const stepMs = 150;
    const maxWaitMs = 15000;
    while (auth.status == AuthStatus.unknown &&
        waitedMs < maxWaitMs &&
        mounted) {
      await Future.delayed(const Duration(milliseconds: stepMs));
      waitedMs += stepMs;
    }
    if (!mounted) return;

    // Se mesmo após o tempo limite continuar 'unknown', força reset para
    // não-autenticado para garantir que saímos do splash.
    if (auth.status == AuthStatus.unknown) {
      auth.forceUnauthenticated();
    }

    if (auth.status == AuthStatus.authenticated) {
      context.go('/farms');
    } else {
      context.go('/auth/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Vision4Farms',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gestão agrícola digital',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white.withOpacity(0.7),
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
