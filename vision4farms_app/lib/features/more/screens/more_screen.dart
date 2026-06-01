import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/theme/app_theme.dart';
import 'support_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final farmProvider = context.watch<FarmProvider>();
    final farm = farmProvider.selectedFarm;
    final isGestor = farm?.isManager ?? false;
    final profile = auth.user?.profile;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(children: [
            _ProfileTile(
              name: profile?.profileName ?? auth.user?.username ?? '',
              email: profile?.profileEmail ?? '',
              role: farm != null ? _roleLabel(farm.userRole) : '',
            ),
          ]),
          const SizedBox(height: 16),

          if (farm != null) ...[
            _SectionHeader(title: 'Exploração — ${farm.farmName}'),
            _SectionCard(children: [
              if (isGestor) ...[
                _MenuTile(
                  icon: Icons.person_add_outlined,
                  label: 'Gerar código de convite',
                  color: AppTheme.primary,
                  onTap: () => _showInviteDialog(context, farm.farmId, farm.farmName),
                ),
                _MenuTile(
                  icon: Icons.list_alt_outlined,
                  label: 'Lista de convites',
                  color: Colors.teal,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => InviteListScreen(farmId: farm.farmId)),
                  ),
                ),
                _MenuTile(
                  icon: Icons.pending_actions_outlined,
                  label: 'Pedidos de acesso pendentes',
                  color: Colors.orange,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const _PendingRequestsScreen()),
                  ),
                ),
                const Divider(height: 1),
              ],
              _MenuTile(
                icon: Icons.swap_horiz_outlined,
                label: 'Mudar exploração',
                color: AppTheme.textSecondary,
                onTap: () {
                  farmProvider.clearSelectedFarm();
                  context.go('/farms');
                },
              ),
            ]),
            const SizedBox(height: 16),
          ],

          _SectionHeader(title: 'Geral'),
          _SectionCard(children: [
            _MenuTile(
              icon: Icons.cloud_sync_outlined,
              label: 'Operações pendentes',
              color: const Color(0xFFFFA726),
              onTap: () => context.go('/sync/pending'),
            ),
            const Divider(height: 1),
            _MenuTile(
              icon: Icons.support_agent_outlined,
              label: 'Suporte',
              color: const Color(0xFF1565C0),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupportScreen()),
              ),
            ),
            const Divider(height: 1),
            _MenuTile(
              icon: Icons.settings_outlined,
              label: 'Definições',
              color: AppTheme.textSecondary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          _SectionHeader(title: 'Conta'),
          _SectionCard(children: [
            _MenuTile(
              icon: Icons.logout,
              label: 'Terminar sessão',
              color: AppTheme.error,
              onTap: () => _confirmLogout(context),
            ),
          ]),
        ],
      ),
    );
  }

  String _roleLabel(int role) {
    switch (role) {
      case 1: return 'Gestor';
      case 2: return 'Colaborador';
      case 3: return 'Consultor';
      default: return '';
    }
  }

  void _showInviteDialog(BuildContext context, int farmId, String farmName) {
    showDialog(
      context: context,
      builder: (_) => _InviteDialog(farmId: farmId, farmName: farmName),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

// ── Dialog de gerar convite ────────────────────────────────
class _InviteDialog extends StatefulWidget {
  final int farmId;
  final String farmName;
  const _InviteDialog({required this.farmId, required this.farmName});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _api = ApiService();
  final _emailController = TextEditingController();
  int _selectedRole = 2; // Colaborador por defeito
  bool _loading = false;
  String? _code;
  String? _error;
  bool _emailSent = false;

  final Map<int, String> _roles = {
    2: 'Colaborador',
    3: 'Consultor',
    1: 'Gestor',
  };

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; _emailSent = false; });
    try {
      final response = await _api.post(
        '/farms/${widget.farmId}/invite/generate/',
        data: {
          'invite_role': _selectedRole,
          if (_emailController.text.trim().isNotEmpty)
            'invite_email': _emailController.text.trim(),
        },
      );
      setState(() {
        _code = response.data['invite_code'];
        _emailSent = response.data['email_sent'] == true;
      });
    } catch (e) {
      String msg = 'Erro ao gerar convite.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data.containsKey('detail')) msg = data['detail'];
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Convidar para a exploração'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Convida alguém para "${widget.farmName}".',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),

            // Role
            const Text('Perfil do convidado',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._roles.entries.map((e) => RadioListTile<int>(
              value: e.key,
              groupValue: _selectedRole,
              title: Text(e.value),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.primary,
              onChanged: _code == null ? (v) => setState(() => _selectedRole = v!) : null,
            )),
            const SizedBox(height: 12),

            // Email opcional
            if (_code == null) ...[
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (opcional)',
                  prefixIcon: Icon(Icons.email_outlined),
                  hintText: 'Envia o convite por email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
            ],

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),

            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppTheme.primary),
              )),

            if (_code != null) ...[
              // Email enviado
              if (_emailSent)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_read_outlined,
                          color: AppTheme.success, size: 18),
                      const SizedBox(width: 8),
                      Text('Email enviado para ${_emailController.text}',
                          style: const TextStyle(color: AppTheme.success, fontSize: 13)),
                    ],
                  ),
                ),

              // Código
              Center(
                child: Column(
                  children: [
                    const Text('Código de convite',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                      ),
                      child: Text(_code!,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                              color: AppTheme.primary, letterSpacing: 4)),
                    ),
                    const SizedBox(height: 8),
                    Text('Perfil: ${_roles[_selectedRole]} • Válido 7 dias',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _code!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Código copiado!'),
                              duration: Duration(seconds: 2)),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar código'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_loading && _code != null)
          TextButton(
            onPressed: () => setState(() { _code = null; _emailSent = false; }),
            child: const Text('Gerar novo'),
          ),
        if (!_loading && _code == null)
          ElevatedButton(
            onPressed: _generate,
            child: const Text('Gerar convite'),
          ),
        if (_code != null)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
      ],
    );
  }
}

// ── Lista de convites ──────────────────────────────────────
class InviteListScreen extends StatefulWidget {
  final int farmId;
  const InviteListScreen({super.key, required this.farmId});

  @override
  State<InviteListScreen> createState() => _InviteListScreenState();
}

class _InviteListScreenState extends State<InviteListScreen> {
  final _api = ApiService();
  List<dynamic> _invites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/farms/invite/list/',
          params: {'farm_id': widget.farmId});
      setState(() => _invites = ApiService.extractResults(response.data));
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _cancel(int inviteId) async {
    try {
      await _api.post('/farms/invite/$inviteId/cancel/');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite cancelado.'), backgroundColor: AppTheme.error),
        );
      }
    } catch (_) {}
  }

  Color _statusColor(int status) {
    switch (status) {
      case 0: return AppTheme.primary;
      case 1: return AppTheme.success;
      case 2: return AppTheme.textSecondary;
      case 3: return AppTheme.error;
      default: return AppTheme.textSecondary;
    }
  }

  IconData _statusIcon(int status) {
    switch (status) {
      case 0: return Icons.schedule_outlined;
      case 1: return Icons.check_circle_outline;
      case 2: return Icons.timer_off_outlined;
      case 3: return Icons.cancel_outlined;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Convites enviados')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _invites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail_outline, size: 64,
                          color: AppTheme.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text('Sem convites enviados',
                          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _invites.length,
                    itemBuilder: (context, index) {
                      final inv = _invites[index];
                      final invStatus = inv['invite_status'] as int;
                      final color = _statusColor(invStatus);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(_statusIcon(invStatus), color: color, size: 20),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      inv['invite_status_label'] ?? '',
                                      style: TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.w600, color: color),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      inv['invite_role_label'] ?? '',
                                      style: const TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Email
                              Row(
                                children: [
                                  const Icon(Icons.email_outlined, size: 14,
                                      color: AppTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    inv['invite_email'] ?? 'Sem email',
                                    style: const TextStyle(fontSize: 13,
                                        color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Código
                              Row(
                                children: [
                                  const Icon(Icons.vpn_key_outlined, size: 14,
                                      color: AppTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    inv['invite_code'] ?? '',
                                    style: const TextStyle(fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                        letterSpacing: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  if (invStatus == 0)
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(
                                            ClipboardData(text: inv['invite_code']));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text('Código copiado!'),
                                              duration: Duration(seconds: 2)),
                                        );
                                      },
                                      child: const Icon(Icons.copy, size: 14,
                                          color: AppTheme.textSecondary),
                                    ),
                                ],
                              ),
                              // Cancelar se ativo
                              if (invStatus == 0) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => _cancel(inv['invite_id']),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.error,
                                      side: const BorderSide(color: AppTheme.error),
                                      minimumSize: const Size(0, 36),
                                    ),
                                    child: const Text('Cancelar convite'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Pedidos pendentes ──────────────────────────────────────
class _PendingRequestsScreen extends StatefulWidget {
  const _PendingRequestsScreen();

  @override
  State<_PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<_PendingRequestsScreen> {
  final _api = ApiService();
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/farms/access/pending/');
      setState(() => _requests = ApiService.extractResults(response.data));
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _action(int rowId, String action) async {
    try {
      await _api.post('/farms/access/$rowId/action/', data: {'action': action});
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'approve' ? 'Acesso aprovado!' : 'Acesso recusado.'),
          backgroundColor: action == 'approve' ? AppTheme.success : AppTheme.error,
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Pedidos de acesso')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64,
                          color: AppTheme.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text('Sem pedidos pendentes',
                          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final req = _requests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                                    child: const Icon(Icons.person_outline,
                                        color: AppTheme.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(req['profile_name'] ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600, fontSize: 15)),
                                        Text(req['profile_email'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 13, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.agriculture_outlined, size: 14,
                                    color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(req['farm_name'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 13, color: AppTheme.textSecondary)),
                              ]),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _action(req['row_id'], 'reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.error,
                                        side: const BorderSide(color: AppTheme.error),
                                      ),
                                      child: const Text('Recusar'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _action(req['row_id'], 'approve'),
                                      child: const Text('Aprovar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 13,
        fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
  );
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(children: children),
  );
}

class _ProfileTile extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  const _ProfileTile({required this.name, required this.email, required this.role});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  color: AppTheme.primary)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text(email, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              if (role.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(role, style: const TextStyle(fontSize: 11,
                      color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.label,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: TextStyle(fontSize: 15,
        color: color == AppTheme.textSecondary ? AppTheme.textPrimary : color)),
    trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
    onTap: onTap,
  );
}