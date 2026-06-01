import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../notifications/screens/notification_preferences_screen.dart';
import '../../farms/screens/farm_invites_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    var origin = AppConstants.baseUrl;
    if (origin.endsWith('/api')) origin = origin.substring(0, origin.length - 4);
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.startsWith('media/')) return '$origin/$cleanPath';
    return '$origin/media/$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final profile = auth.user?.profile;
    final name    = profile?.profileName ?? auth.user?.username ?? '';
    final email   = profile?.profileEmail ?? '';
    final pictureUrl = _resolveMediaUrl(profile?.profilePicture);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // Header com seta voltar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                    onPressed: () => context.go('/home'),
                  ),
                  const Expanded(
                    child: Text(
                      'Perfil',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Avatar
            Center(
              child: GestureDetector(
                onTap: () => _openEditProfile(context),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                      backgroundImage: pictureUrl.isNotEmpty ? NetworkImage(pictureUrl) : null,
                      child: pictureUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit_outlined,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Nome e email
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              email,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),

            const SizedBox(height: 32),

            // Menu items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _MenuItem(
                    icon: Icons.person_outline,
                    label: 'Editar Perfil',
                    onTap: () => _openEditProfile(context),
                  ),
                  const SizedBox(height: 10),
                  _MenuItem(
                    icon: Icons.lock_outline,
                    label: 'Alterar Password',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MenuItem(
                    icon: Icons.tune_outlined,
                    label: 'Preferências de Notificações',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()),
                    ),
                  ),
                  if (context.read<FarmProvider>().selectedFarm?.canManage ?? false) ...[
                    const SizedBox(height: 10),
                    _MenuItem(
                      icon: Icons.mail_outline,
                      label: 'Convites da Exploração',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FarmInvitesScreen()),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _MenuItem(
                    icon: Icons.help_outline,
                    label: 'Suporte',
                    onTap: () => _showSupportDialog(context),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Botão Terminar Sessão
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: OutlinedButton(
                onPressed: () => _confirmLogout(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Terminar Sessão',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditProfile(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Suporte'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Precisas de ajuda? Contacta-nos:',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.email_outlined, size: 18, color: AppTheme.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'suporte@vision4farms.pt',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Versão 1.0.0',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminar sessão'),
        content: const Text('Tens a certeza que queres sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              context.read<FarmProvider>().clearSelectedFarm();
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/auth/login');
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

// ── Menu item ─────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
