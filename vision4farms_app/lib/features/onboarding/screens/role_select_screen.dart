import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Icon(Icons.eco_rounded, size: 48, color: AppTheme.primary),
              const SizedBox(height: 24),
              const Text(
                'Como vais usar\na Vision4Farms?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolhe o teu perfil para configurarmos a app corretamente.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 40),

              _RoleCard(
                icon: Icons.agriculture_outlined,
                title: 'Gestor',
                description: 'Crio e giro as minhas próprias explorações agrícolas.',
                color: AppTheme.primary,
                onTap: () => _showManagerDialog(context),
              ),
              const SizedBox(height: 14),

              _RoleCard(
                icon: Icons.badge_outlined,
                title: 'Trabalhador',
                description: 'Fui convidado para trabalhar numa exploração existente.',
                color: Colors.teal,
                onTap: () => context.go('/worker/join'),
              ),

              const Spacer(),
              TextButton(
                onPressed: () => context.go('/farms'),
                child: const Text(
                  'Saltar por agora',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showManagerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tipo de conta'),
        content: const Text('Tens uma empresa associada às tuas explorações?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/company/create');
            },
            child: const Text('Sim, tenho empresa'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/farms/create');
            },
            child: const Text('Não, sou independente'),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}