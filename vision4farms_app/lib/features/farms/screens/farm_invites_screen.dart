import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/safe_back.dart';

class FarmInvitesScreen extends StatefulWidget {
  const FarmInvitesScreen({super.key});

  @override
  State<FarmInvitesScreen> createState() => _FarmInvitesScreenState();
}

class _FarmInvitesScreenState extends State<FarmInvitesScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _invites = [];
  bool _isLoading = true;
  bool _isGenerating = false;

  static const Map<int, String> _roleLabels = {
    1: 'Gestor',
    2: 'Colaborador',
    3: 'Consultor',
  };

  static const Map<int, String> _statusLabels = {
    0: 'Ativo',
    1: 'Usado',
    2: 'Expirado',
    3: 'Cancelado',
  };

  static const Map<int, Color> _statusColors = {
    0: AppTheme.primary,
    1: Color(0xFF1565C0),
    2: Color(0xFFFFA726),
    3: AppTheme.error,
  };

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get(AppConstants.inviteList);
      final data = response.data;
      if (data is List) {
        setState(() => _invites = data.cast<Map<String, dynamic>>());
      } else if (data is Map && data['results'] != null) {
        setState(() => _invites = (data['results'] as List).cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _generateInvite() async {
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) return;

    // Dialog para escolher role
    final role = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Gerar convite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escolhe o perfil do convidado:',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _RoleOption(
              label: 'Colaborador',
              description: 'Consulta dados, cria observações, abre e fecha atividades',
              icon: Icons.person_outline,
              onTap: () => Navigator.pop(ctx, 2),
            ),
            const SizedBox(height: 8),
            _RoleOption(
              label: 'Consultor',
              description: 'Apenas consulta dados e atividades',
              icon: Icons.visibility_outlined,
              onTap: () => Navigator.pop(ctx, 3),
            ),
            const SizedBox(height: 8),
            _RoleOption(
              label: 'Gestor',
              description: 'Acesso total à exploração',
              icon: Icons.admin_panel_settings_outlined,
              onTap: () => Navigator.pop(ctx, 1),
            ),
          ],
        ),
      ),
    );
    if (role == null) return;

    setState(() => _isGenerating = true);
    try {
      final response = await _api.post(
        AppConstants.inviteGenerate(farm.farmId),
        data: {'role': role},
      );
      final code = response.data['invite_code']?.toString() ?? '';
      if (mounted && code.isNotEmpty) {
        _showInviteCodeDialog(code, _roleLabels[role] ?? '');
      }
      await _loadInvites();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao gerar convite.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showInviteCodeDialog(String code, String role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Convite gerado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Partilha este código com o $role:',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Válido durante 7 dias',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Código copiado!')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelInvite(int inviteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar convite'),
        content: const Text('Tens a certeza que queres cancelar este convite?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar convite'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.post(AppConstants.inviteCancel(inviteId));
      await _loadInvites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite cancelado.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao cancelar convite.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final farm = context.watch<FarmProvider>().selectedFarm;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                    onPressed: () => safeBack(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Convites',
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

            // Farm name
            if (farm != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  farm.farmName,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ),

            const SizedBox(height: 8),

            // Generate button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateInvite,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Gerar novo convite'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Invite list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _invites.isEmpty
                      ? const Center(
                          child: Text('Sem convites gerados',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: _loadInvites,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: _invites.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _buildInviteCard(_invites[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> invite) {
    final code = invite['invite_code']?.toString() ?? '';
    final role = invite['invite_role'] as int? ?? 2;
    final status = invite['invite_status'] as int? ?? 0;
    final expiresAt = invite['expires_at']?.toString() ?? '';
    final usedBy = invite['used_by_username']?.toString() ?? '';
    final email = invite['invite_email']?.toString() ?? '';
    final farmName = invite['farm_name']?.toString() ?? '';
    final isActive = status == 0;

    String expiresStr = '';
    try {
      final dt = DateTime.parse(expiresAt);
      expiresStr = DateFormat('dd/MM/yyyy HH:mm', 'pt_PT').format(dt);
    } catch (_) {
      expiresStr = expiresAt;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Code + status
          Row(
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (_statusColors[status] ?? AppTheme.textSecondary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabels[status] ?? 'Desconhecido',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColors[status] ?? AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Role + farm
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(_roleLabels[role] ?? 'Colaborador',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              if (farmName.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.agriculture_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(farmName,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Expiry
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('Expira: $expiresStr',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          // Used by
          if (status == 1 && usedBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text('Usado por: $usedBy',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
              ],
            ),
          ],
          // Email
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.email_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(email,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
          // Cancel button (active only)
          if (isActive) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado!')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copiar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelInvite(invite['invite_id'] as int),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Cancelar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  Text(description,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
