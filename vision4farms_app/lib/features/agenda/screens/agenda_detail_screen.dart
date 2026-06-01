import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/offline_mutation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../../shared/theme/app_theme.dart';

class AgendaDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  const AgendaDetailScreen({super.key, required this.event});

  @override
  State<AgendaDetailScreen> createState() => _AgendaDetailScreenState();
}

class _AgendaDetailScreenState extends State<AgendaDetailScreen> {
  final _api = ApiService();
  late Map<String, dynamic> _event;

  static const Map<String, IconData> _typeIcons = {
    'task': Icons.check_circle_outline,
    'visit': Icons.directions_walk_outlined,
    'meeting': Icons.groups_outlined,
    'reminder': Icons.notifications_outlined,
    'other': Icons.event_outlined,
  };

  static const Map<String, Color> _typeColors = {
    'task': Color(0xFF2E7D32),
    'visit': Color(0xFF1565C0),
    'meeting': Color(0xFF7B1FA2),
    'reminder': Color(0xFFF57C00),
    'other': Color(0xFF757575),
  };

  static const Map<String, String> _typeLabels = {
    'task': 'Tarefa',
    'visit': 'Visita',
    'meeting': 'Reunião',
    'reminder': 'Lembrete',
    'other': 'Outro',
  };

  static const Map<int, String> _statusLabels = {
    0: 'Pendente',
    1: 'Concluído',
    2: 'Cancelado',
  };

  static const Map<int, Color> _statusColors = {
    0: Color(0xFFFFA726),
    1: AppTheme.primary,
    2: AppTheme.textSecondary,
  };

  static const Map<int, IconData> _statusIcons = {
    0: Icons.schedule,
    1: Icons.check_circle_outline,
    2: Icons.cancel_outlined,
  };

  @override
  void initState() {
    super.initState();
    _event = Map<String, dynamic>.from(widget.event);
  }

  int get _agendaId => _event['agenda_id'] as int;
  int get _status => _event['agenda_status'] as int? ?? 0;

  Future<void> _updateStatus(int newStatus) async {
    if (!mounted) return;
    final result = await OfflineMutation.run(
      apiCall: () => _api.patch(
        AppConstants.agendaDetail(_agendaId),
        data: {'agenda_status': newStatus},
      ),
      operationType: 'update_agenda',
      queueData: {
        'agenda_id': _agendaId,
        'agenda_status': newStatus,
        'client_uuid': UuidHelper.v4(),
      },
      applyOptimistic: () async =>
          setState(() => _event['agenda_status'] = newStatus),
    );
    if (!mounted) return;
    if (result.queued) {
      context.read<SyncProvider>().refreshCounts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardado offline — sincroniza quando voltares online.'),
          backgroundColor: Color(0xFF7B1FA2),
        ),
      );
    }
  }

  Future<void> _completeEvent() async {
    final confirmed = await _showConfirmDialog(
      title: 'Concluir evento',
      message: 'Queres marcar este evento como concluído?',
      confirmText: 'Concluir',
      confirmColor: AppTheme.primary,
    );
    if (confirmed == true) await _updateStatus(1);
  }

  Future<void> _cancelEvent() async {
    final confirmed = await _showConfirmDialog(
      title: 'Cancelar evento',
      message: 'Queres cancelar este evento?',
      confirmText: 'Cancelar evento',
      confirmColor: AppTheme.error,
    );
    if (confirmed == true) await _updateStatus(2);
  }

  Future<void> _deleteEvent() async {
    final confirmed = await _showConfirmDialog(
      title: 'Eliminar evento',
      message: 'Queres eliminar este evento? Esta ação não pode ser desfeita.',
      confirmText: 'Eliminar',
      confirmColor: AppTheme.error,
    );
    if (confirmed != true || !mounted) return;

    final result = await OfflineMutation.run(
      apiCall: () => _api.delete(AppConstants.agendaDetail(_agendaId)),
      operationType: 'delete_agenda',
      queueData: {
        'agenda_id': _agendaId,
        'client_uuid': UuidHelper.v4(),
      },
    );

    if (!mounted) return;
    if (result.queued) {
      context.read<SyncProvider>().refreshCounts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eliminação guardada offline — sincroniza quando voltares online.'),
          backgroundColor: Color(0xFF7B1FA2),
        ),
      );
    }
    Navigator.pop(context, true);
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _event['agenda_title']?.toString() ?? '';
    final type = _event['agenda_type']?.toString() ?? 'task';
    final description = _event['agenda_description']?.toString() ?? '';
    final notes = _event['agenda_notes']?.toString() ?? '';
    final dateStr = _event['agenda_date']?.toString() ?? '';
    final timeStart = _event['agenda_time_start']?.toString() ?? '';
    final timeEnd = _event['agenda_time_end']?.toString() ?? '';
    final allday = _event['agenda_allday'] == true || _event['agenda_allday'] == 1;
    final landName = _event['land_name']?.toString() ?? '';
    final landId = _event['land'] ?? _event['land_id'];
    final status = _status;
    final color = _typeColors[type] ?? AppTheme.textSecondary;

    String dateFormatted = '';
    try {
      dateFormatted = DateFormat('EEEE, d MMMM yyyy', 'pt_PT').format(DateTime.parse(dateStr));
      dateFormatted = dateFormatted[0].toUpperCase() + dateFormatted.substring(1);
    } catch (_) {
      dateFormatted = dateStr;
    }

    String timeLabel = '';
    if (!allday && timeStart.isNotEmpty) {
      timeLabel = timeStart.substring(0, 5);
      if (timeEnd.isNotEmpty) timeLabel += ' – ${timeEnd.substring(0, 5)}';
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Evento'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _typeIcons[type] ?? Icons.event_outlined,
                  color: color, size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(_typeLabels[type] ?? type,
                        style: const TextStyle(fontSize: 13,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Badges
          Row(
            children: [
              _Badge(
                icon: _statusIcons[status] ?? Icons.schedule,
                label: _statusLabels[status] ?? 'Pendente',
                color: _statusColors[status] ?? const Color(0xFFFFA726),
              ),
              if (allday) ...[
                const SizedBox(width: 10),
                const _Badge(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Dia inteiro',
                  color: Color(0xFFF57C00),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // Info card
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Data',
                value: dateFormatted,
              ),
              if (timeLabel.isNotEmpty)
                _InfoRow(
                  icon: Icons.access_time,
                  label: 'Horário',
                  value: timeLabel,
                ),
              if (landName.isNotEmpty)
                _InfoRow(
                  icon: Icons.grass_outlined,
                  label: 'Terreno',
                  value: landName,
                  onTap: landId != null
                      ? () => context.go(
                          '/lands/$landId?name=${Uri.encodeComponent(landName)}')
                      : null,
                ),
            ],
          ),

          // Descrição
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Descrição',
              child: Text(description,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary,
                      height: 1.6)),
            ),
          ],

          // Notas
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Notas',
              child: Text(notes,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary,
                      height: 1.6)),
            ),
          ],

          const SizedBox(height: 28),

          // Ações
          if (status == 0) ...[
            ElevatedButton.icon(
              onPressed: _completeEvent,
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text('Marcar como concluído'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _cancelEvent,
              child: const Text('Cancelar evento',
                  style: TextStyle(color: AppTheme.error, fontSize: 14)),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _deleteEvent,
              icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
              label: const Text('Eliminar evento',
                  style: TextStyle(color: AppTheme.error, fontSize: 14)),
            ),
          ],

          if (status == 1)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
                  SizedBox(width: 10),
                  Text('Evento concluído',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                ],
              ),
            ),

          if (status == 2)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, color: AppTheme.textSecondary, size: 22),
                  SizedBox(width: 10),
                  Text('Evento cancelado',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Componentes reutilizáveis ──────────────────────────────────

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, color: AppTheme.divider),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon, required this.label, required this.value, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value.isNotEmpty ? value : '—',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
