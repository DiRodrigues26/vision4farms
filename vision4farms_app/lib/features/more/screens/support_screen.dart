import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/theme/app_theme.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _email = 'suporte@vision4farms.com';
  static const _faqUrl = 'https://vision4farms.com/faq';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Suporte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: AppTheme.primary, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('Como podemos ajudar?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                const Text(
                  'Escolhe uma das opções abaixo ou envia-nos uma mensagem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary,
                      height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Email
          _SupportTile(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: _email,
            color: const Color(0xFF1565C0),
            onTap: () async {
              final uri = Uri(scheme: 'mailto', path: _email,
                  queryParameters: {'subject': 'Suporte Vision4Farms'});
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),

          const SizedBox(height: 10),

          // FAQ
          _SupportTile(
            icon: Icons.help_outline_rounded,
            title: 'Perguntas frequentes',
            subtitle: 'Consulta as dúvidas mais comuns',
            color: AppTheme.primary,
            onTap: () async {
              final uri = Uri.parse(_faqUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),

          const SizedBox(height: 10),

          // Formulário inline
          _ContactForm(),
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 13,
                      color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ContactForm extends StatefulWidget {
  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _controller = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enviar mensagem',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          if (_sent)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Mensagem enviada! Responderemos em breve.',
                        style: TextStyle(fontSize: 13, color: AppTheme.success)),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Descreve o teu problema ou sugestão...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  if (_controller.text.trim().isEmpty) return;
                  // TODO: integrar com endpoint de suporte quando existir
                  setState(() => _sent = true);
                },
                child: const Text('Enviar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
