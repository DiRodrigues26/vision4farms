import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/theme/app_theme.dart';

enum MaintenanceType { maintenance, forceUpdate }

class MaintenanceScreen extends StatelessWidget {
  final MaintenanceType type;
  final String? storeUrl;
  final VoidCallback onRetry;

  const MaintenanceScreen({
    super.key,
    required this.type,
    this.storeUrl,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isMaintenance = type == MaintenanceType.maintenance;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: (isMaintenance ? AppTheme.warning : AppTheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    isMaintenance ? Icons.construction_rounded : Icons.system_update_outlined,
                    size: 48,
                    color: isMaintenance ? AppTheme.warning : AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  isMaintenance
                      ? 'Em manutenção'
                      : 'Atualização disponível',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isMaintenance
                      ? 'Estamos a melhorar a plataforma.\nPor favor, tenta novamente em breve.'
                      : 'Existe uma nova versão obrigatória da aplicação.\nPor favor, atualiza para continuar.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                if (isMaintenance)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (storeUrl != null) {
                          final uri = Uri.parse(storeUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Atualizar agora'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Verificar novamente'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
