import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/connectivity_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/services/local_database.dart';
import '../../../shared/theme/app_theme.dart';

/// Ecrã para inspecionar a fila de operações offline.
/// Mostra:
///  - Pendentes (em fila, ainda por enviar)
///  - Falhadas (atingiram 3 retries) — com opção de re-tentar ou descartar
class PendingOperationsScreen extends StatefulWidget {
  const PendingOperationsScreen({super.key});

  @override
  State<PendingOperationsScreen> createState() =>
      _PendingOperationsScreenState();
}

class _PendingOperationsScreenState extends State<PendingOperationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final all = await LocalDatabase.getAllOperations();
    if (!mounted) return;
    setState(() {
      _items = all;
      _isLoading = false;
    });
    context.read<SyncProvider>().refreshCounts();
  }

  Future<void> _syncNow() async {
    final isOnline = context.read<ConnectivityProvider>().isOnline;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem ligação — não é possível sincronizar.')),
      );
      return;
    }
    final sync = context.read<SyncProvider>();
    await sync.sync();
    await _load();
  }

  Future<void> _retryFailed() async {
    final isOnline = context.read<ConnectivityProvider>().isOnline;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem ligação — não é possível re-tentar.')),
      );
      return;
    }
    await context.read<SyncProvider>().retryFailed();
    await _load();
  }

  Future<void> _discardAllFailed() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar todas as falhadas'),
        content: const Text(
            'Esta ação remove permanentemente todas as operações falhadas. Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    await context.read<SyncProvider>().discardAllFailed();
    await _load();
  }

  Future<void> _discard(int id) async {
    await context.read<SyncProvider>().discard(id);
    await _load();
  }

  String _humanizeType(String type) {
    const map = {
      'create_land': 'Criar terreno',
      'update_land': 'Atualizar terreno',
      'create_yield': 'Criar cultura',
      'update_yield': 'Atualizar cultura',
      'delete_yield': 'Eliminar cultura',
      'create_activity': 'Criar atividade',
      'update_activity': 'Atualizar atividade',
      'complete_activity': 'Concluir atividade',
      'delete_activity': 'Eliminar atividade',
      'create_observation': 'Criar observação',
      'create_harvest': 'Criar colheita',
      'update_harvest': 'Atualizar colheita',
      'delete_harvest': 'Eliminar colheita',
      'create_water_source': 'Criar fonte de água',
      'update_water_source': 'Atualizar fonte de água',
      'delete_water_source': 'Eliminar fonte de água',
      'create_water_usage': 'Registar consumo de água',
      'update_water_usage': 'Atualizar consumo de água',
      'delete_water_usage': 'Eliminar consumo de água',
      'create_water_planned': 'Planear rega',
      'update_water_planned': 'Atualizar rega planeada',
      'delete_water_planned': 'Eliminar rega planeada',
      'execute_water_planned': 'Executar rega planeada',
      'create_agenda': 'Criar evento',
      'update_agenda': 'Atualizar evento',
      'delete_agenda': 'Eliminar evento',
      'create_soil_analysis': 'Criar análise de solo',
      'create_foliar_analysis': 'Criar análise foliar',
      'mark_notification_read': 'Marcar notificação',
      'update_profile': 'Atualizar perfil',
    };
    return map[type] ?? type;
  }

  String _summarize(Map<String, dynamic> data) {
    if (data['land_name'] != null) return data['land_name'].toString();
    if (data['activity_name'] != null) return data['activity_name'].toString();
    if (data['observation_text'] != null) {
      final t = data['observation_text'].toString();
      return t.length > 50 ? '${t.substring(0, 47)}…' : t;
    }
    if (data['harvest_name'] != null) return data['harvest_name'].toString();
    if (data['agenda_title'] != null) return data['agenda_title'].toString();
    if (data['yield_name'] != null) return data['yield_name'].toString();
    if (data['water_source_name'] != null) {
      return data['water_source_name'].toString();
    }
    return '';
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((i) => i['status'] == 'pending').toList();
    final failed = _items.where((i) => i['status'] == 'failed').toList();
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    final isSyncing = context.watch<SyncProvider>().isSyncing;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Operações pendentes'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: pending.isEmpty || isSyncing
          ? null
          : FloatingActionButton.extended(
              onPressed: isOnline ? _syncNow : null,
              backgroundColor:
                  isOnline ? AppTheme.primary : AppTheme.textSecondary,
              icon: const Icon(Icons.sync, color: Colors.white),
              label: Text(
                isOnline ? 'Sincronizar agora' : 'Offline',
                style: const TextStyle(color: Colors.white),
              ),
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  if (isSyncing) ...[
                    const _StatusBanner(
                      color: Color(0xFF1565C0),
                      icon: Icons.sync,
                      text: 'Sincronização em curso…',
                    ),
                    const SizedBox(height: 12),
                  ] else if (pending.isEmpty && failed.isEmpty) ...[
                    const _StatusBanner(
                      color: AppTheme.primary,
                      icon: Icons.check_circle_outline,
                      text: 'Tudo sincronizado.',
                    ),
                  ],

                  if (pending.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Em fila (${pending.length})',
                      color: const Color(0xFFFFA726),
                    ),
                    const SizedBox(height: 8),
                    ...pending.map((op) => _OpCard(
                          op: op,
                          humanized: _humanizeType(op['operation_type'] as String),
                          summary: _summarize(_decode(op['data'])),
                          dateLabel: _formatDate(op['created_at'] as String),
                          isFailed: false,
                          onDiscard: () => _discard(op['id'] as int),
                        )),
                    const SizedBox(height: 24),
                  ],

                  if (failed.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _SectionHeader(
                            title: 'Falhadas (${failed.length})',
                            color: AppTheme.error,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: isOnline ? _retryFailed : null,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Re-tentar todas'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primary),
                        ),
                        TextButton(
                          onPressed: _discardAllFailed,
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.error),
                          child: const Text('Descartar todas'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...failed.map((op) => _OpCard(
                          op: op,
                          humanized: _humanizeType(op['operation_type'] as String),
                          summary: _summarize(_decode(op['data'])),
                          dateLabel: _formatDate(op['created_at'] as String),
                          errorMessage: op['error_message'] as String?,
                          isFailed: true,
                          onDiscard: () => _discard(op['id'] as int),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  Map<String, dynamic> _decode(dynamic raw) {
    try {
      return jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _StatusBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: color,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _OpCard extends StatelessWidget {
  final Map<String, dynamic> op;
  final String humanized;
  final String summary;
  final String dateLabel;
  final bool isFailed;
  final String? errorMessage;
  final VoidCallback onDiscard;

  const _OpCard({
    required this.op,
    required this.humanized,
    required this.summary,
    required this.dateLabel,
    required this.isFailed,
    required this.onDiscard,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final retries = op['retries'] as int? ?? 0;
    final accent = isFailed ? AppTheme.error : const Color(0xFFFFA726);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6, height: 36,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(humanized,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(summary,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.error, size: 20),
                tooltip: 'Descartar',
                onPressed: onDiscard,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(dateLabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              if (retries > 0) ...[
                const SizedBox(width: 12),
                const Icon(Icons.refresh, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('$retries tentativas',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ],
          ),
          if (errorMessage != null && errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: AppTheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(errorMessage!,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.error)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
