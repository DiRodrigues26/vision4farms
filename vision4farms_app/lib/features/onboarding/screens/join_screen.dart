import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';
import 'worker_join_screen.dart';

class JoinScreen extends StatelessWidget {
  const JoinScreen({super.key});

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
              const SizedBox(height: 32),
              const Text('Juntar a uma exploração',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              const Text('Entra como colaborador ou consultor com um código de convite.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 40),

              _OptionCard(
                icon: Icons.vpn_key_outlined,
                title: 'Entrar com código de convite',
                description: 'Usa o código fornecido pelo gestor da exploração.',
                color: Colors.teal,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WorkerJoinCodeScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Ecrã só com o tab de código (sem pesquisa)
class WorkerJoinCodeScreen extends StatelessWidget {
  const WorkerJoinCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WorkerJoinScreen();
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon, required this.title,
    required this.description, required this.color, required this.onTap,
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
                width: 52, height: 52,
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
                    Text(title, style: const TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(description, style: const TextStyle(
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