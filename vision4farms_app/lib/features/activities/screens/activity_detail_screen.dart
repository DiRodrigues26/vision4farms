import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/offline_mutation.dart';
import '../../../core/services/offline_read.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/services/local_database.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../../shared/theme/app_theme.dart';

class ActivityDetailScreen extends StatefulWidget {
  final int activityId;

  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final _api = ApiService();

  Map<String, dynamic>? _activity;
  bool _isLoading = true;
  String? _error;

  //  Traduções  

  static const Map<String, String> _typeLabels = {
    'irrigation': 'Rega',
    'fertilization': 'Fertilização',
    'pruning': 'Poda',
    'harvest': 'Colheita',
    'treatment': 'Tratamento',
    'inspection': 'Inspeção',
    'maintenance': 'Manutenção',
    'other': 'Outra',
  };

  static const Map<String, IconData> _typeIcons = {
    'irrigation': Icons.water_drop_outlined,
    'fertilization': Icons.science_outlined,
    'pruning': Icons.content_cut_outlined,
    'harvest': Icons.agriculture_outlined,
    'treatment': Icons.medical_services_outlined,
    'inspection': Icons.search_outlined,
    'maintenance': Icons.build_outlined,
    'other': Icons.assignment_outlined,
  };

  static const Map<int, String> _statusLabels = {
    0: 'Pendente',
    1: 'Concluída',
    2: 'Atrasada',
    3: 'Cancelada',
  };

  static const Map<int, Color> _statusColors = {
    0: Color(0xFFFFA726),
    1: AppTheme.primary,
    2: AppTheme.error,
    3: AppTheme.textSecondary,
  };

  static const Map<int, IconData> _statusIcons = {
    0: Icons.schedule,
    1: Icons.check_circle_outline,
    2: Icons.warning_amber_rounded,
    3: Icons.cancel_outlined,
  };

  static const Map<int, String> _priorityLabels = {
    1: 'Normal',
    2: 'Alta',
    3: 'Urgente',
  };

  static const Map<int, Color> _priorityColors = {
    1: AppTheme.primary,
    2: Color(0xFFFFA726),
    3: AppTheme.error,
  };

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  //  Carregar dados 

  Future<void> _loadActivity() async {
    setState(() { _isLoading = true; _error = null; });
    final farm = context.read<FarmProvider>().selectedFarm;
    final cacheKey = 'activity_detail:${widget.activityId}';
    final result = await OfflineRead.json(
      cacheKey: cacheKey,
      apiCall: () => _api.get(AppConstants.activityDetail(widget.activityId)),
    );

    if (!mounted) return;
    if (result.data != null) {
      // Manter o cache dedicado também (usado por outras views)
      await LocalDatabase.saveActivityDetail(widget.activityId, result.data!);
      setState(() { _activity = result.data; _isLoading = false; });
      return;
    }

    // Fallback na lista de atividades em cache
    if (farm != null) {
      final cached = await LocalDatabase.getActivities(farm.farmId);
      final match = cached.where(
          (a) => (a['activity_id'] as int?) == widget.activityId);
      if (match.isNotEmpty) {
        if (!mounted) return;
        setState(() { _activity = match.first; _isLoading = false; });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _error = result.errorMessage ?? 'Sem ligação e sem dados guardados.';
      _isLoading = false;
    });
  }

  // AÃ§Ãµes

  Future<void> _updateStatus(int newStatus) async {
    if (!mounted) return;
    final farm = context.read<FarmProvider>().selectedFarm;
    final queueData = <String, dynamic>{
      'activity_id':     widget.activityId,
      'activity_status': newStatus,
      'client_uuid':     UuidHelper.v4(),
    };

    final result = await OfflineMutation.run(
      apiCall: () => _api.patch(
        AppConstants.activityDetail(widget.activityId),
        data: {'activity_status': newStatus},
      ),
      operationType: 'complete_activity',
      queueData: queueData,
      applyOptimistic: () async {
        if (farm != null) {
          final cached = await LocalDatabase.getActivities(farm.farmId);
          final updated = cached.map((a) {
            if ((a['activity_id'] as int?) == widget.activityId) {
              return {...a, 'activity_status': newStatus};
            }
            return a;
          }).toList();
          await LocalDatabase.saveActivities(farm.farmId, updated);
        }
      },
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
    await _loadActivity();
  }

  Future<void> _completeActivity() async {
    final confirmed = await _showConfirmDialog(
      title: 'Concluir atividade',
      message: 'Queres marcar esta atividade como concluída?',
      confirmText: 'Concluir',
      confirmColor: AppTheme.primary,
    );
    if (confirmed == true) await _updateStatus(1);
  }

  Future<void> _cancelActivity() async {
    final confirmed = await _showConfirmDialog(
      title: 'Cancelar atividade',
      message: 'Queres cancelar esta atividade? Esta ação não pode ser desfeita.',
      confirmText: 'Cancelar atividade',
      confirmColor: AppTheme.error,
    );
    if (confirmed == true) await _updateStatus(3);
  }

  Future<void> _reportAnomaly() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registar anomalia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Descreve a anomalia ou imprevisto ocorrido:',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ex: Solo demasiado húmido para tratamento...',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Registar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final anomalyPayload = <String, dynamic>{
        'activity_id':        widget.activityId,
        'client_uuid':        UuidHelper.v4(),
        'activity_anomaly':   1,
        'activity_anomaly_desc': result,
      };
      final mutResult = await OfflineMutation.run(
        apiCall: () => _api.patch(
          AppConstants.activityDetail(widget.activityId),
          data: {
            'activity_anomaly': 1,
            'activity_anomaly_desc': result,
          },
        ),
        operationType: 'update_activity',
        queueData: anomalyPayload,
      );

      if (mutResult.queued && mounted) {
        context.read<SyncProvider>().refreshCounts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anomalia guardada offline — sincroniza quando voltares online.'),
            backgroundColor: Color(0xFF7B1FA2),
          ),
        );
      }

      await _loadActivity();
    }
  }

  Future<void> _editActivity() async {
    if (_activity == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ActivityEditSheet(
          activity: _activity!,
          activityId: widget.activityId,
        ),
      ),
    );
    if (result == true) await _loadActivity();
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

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Detalhes da Atividade'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          if (_activity != null && _activityStatus < 2)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editActivity,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadActivity,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadActivity,
                  child: _buildContent(),
                ),
    );
  }

  int get _activityStatus => _activity?['activity_status'] as int? ?? 0;

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadActivity,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final a = _activity!;
    final name = a['activity_name']?.toString() ?? '';
    final type = a['activity_type']?.toString() ?? '';
    final description = a['activity_description']?.toString() ?? '';
    final notes = a['activity_notes']?.toString() ?? '';
    int? landId;
    final rawLand = a['land'] ?? a['land_id'];
    if (rawLand is int) {
      landId = rawLand;
    } else if (rawLand is double) {
      landId = rawLand.toInt();
    } else {
      landId = int.tryParse(rawLand?.toString() ?? '');
    }
    final landName = a['land_name']?.toString() ?? '';
    final datePlanned = a['activity_date_planned']?.toString() ?? '';
    final dateDone = a['activity_date_done']?.toString() ?? '';
    final status = a['activity_status'] as int? ?? 0;
    final priority = a['activity_priority'] as int? ?? 1;
    final hasAnomaly = ((a['activity_anomaly'] as int? ?? 0) == 1);
    final anomalyDesc = a['activity_anomaly_desc']?.toString() ?? '';
    final observation = a['observation'] as Map<String, dynamic>?;
    final yieldId = a['yield_id'];
    final yieldName = a['yield_name']?.toString() ?? '';
    final statusDisplay = a['activity_status_display']?.toString() ??
        (_statusLabels[status] ?? 'Pendente');
    final priorityDisplay = a['activity_priority_display']?.toString() ??
        (_priorityLabels[priority] ?? 'Normal');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // â”€â”€ Header: nome + tipo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _typeIcons[type] ?? Icons.assignment_outlined,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : (_typeLabels[type] ?? type),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _typeLabels[type] ?? type,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // â”€â”€ Status + Prioridade badges â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(
          children: [
            _Badge(
              icon: _statusIcons[status] ?? Icons.schedule,
              label: statusDisplay,
              color: _statusColors[status] ?? const Color(0xFFFFA726),
            ),
            const SizedBox(width: 10),
            _Badge(
              icon: Icons.flag_outlined,
              label: priorityDisplay,
              color: _priorityColors[priority] ?? AppTheme.primary,
            ),
            if (hasAnomaly) ...[
              const SizedBox(width: 10),
              const _Badge(
                icon: Icons.report_outlined,
                label: 'Anomalia',
                color: AppTheme.error,
              ),
            ],
          ],
        ),

        const SizedBox(height: 24),

        // â”€â”€ InformaÃ§Ãµes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _InfoCard(
          children: [
            _InfoRow(
              icon: Icons.grass_outlined,
              label: 'Terreno',
              value: landName.isNotEmpty ? landName : (landId?.toString() ?? '—'),
              onTap: landId != null
                  ? () => context.go(
                      '/lands/$landId?name=${Uri.encodeComponent(landName.isNotEmpty ? landName : 'Terreno')}',
                    )
                  : null,
            ),
            if (datePlanned.isNotEmpty)
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Data planeada',
                value: _formatDate(datePlanned),
              ),
            if (dateDone.isNotEmpty)
              _InfoRow(
                icon: Icons.event_available_outlined,
                label: 'Data de conclusão',
                value: _formatDate(dateDone),
              ),
            if (yieldId != null)
              _InfoRow(
                icon: Icons.energy_savings_leaf_outlined,
                label: 'Cultura',
                value: yieldName.isNotEmpty ? yieldName : 'ID: $yieldId',
              ),
          ],
        ),

        // â”€â”€ DescriÃ§Ã£o â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (description.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Descrição',
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 14, color: AppTheme.textPrimary, height: 1.6),
            ),
          ),
        ],

        /// Notas 
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Notas',
            child: Text(
              notes,
              style: const TextStyle(
                fontSize: 14, color: AppTheme.textPrimary, height: 1.6),
            ),
          ),
        ],

        //Anomalia 
        if (hasAnomaly) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.report_outlined,
                        color: AppTheme.error, size: 20),
                    SizedBox(width: 8),
                    Text('Anomalia reportada',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.error,
                        )),
                  ],
                ),
                if (anomalyDesc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(anomalyDesc,
                      style: const TextStyle(
                        fontSize: 14, color: AppTheme.textPrimary, height: 1.5)),
                ],
              ],
            ),
          ),
        ],

        //Observação associada
        if (observation != null) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Observação associada',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  observation['observation_text']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 14, color: AppTheme.textPrimary, height: 1.5),
                ),
                if (observation['praga_fungo'] != null &&
                    (observation['praga_fungo']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Badge(
                    icon: Icons.bug_report_outlined,
                    label: observation['praga_fungo'].toString(),
                    color: AppTheme.error,
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),

        // Ações disponíveis consoante o estado da atividade 
        if (status == 0 || status == 2) ...[
          // Concluir
          ElevatedButton.icon(
            onPressed: _completeActivity,
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            label: const Text('Marcar como concluída'),
          ),

          const SizedBox(height: 10),

          // Reportar anomalia
          OutlinedButton.icon(
            onPressed: _reportAnomaly,
            icon: const Icon(Icons.report_outlined, color: AppTheme.warning),
            label: Text(
              hasAnomaly ? 'Atualizar anomalia' : 'Registar anomalia',
              style: const TextStyle(color: AppTheme.warning),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.warning,
              side: const BorderSide(color: AppTheme.warning),
            ),
          ),

          const SizedBox(height: 10),

          // Cancelar
          TextButton(
            onPressed: _cancelActivity,
            child: const Text('Cancelar atividade',
                style: TextStyle(color: AppTheme.error, fontSize: 14)),
          ),
        ],

        if (status == 1) ...[
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
                Text('Atividade concluída',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    )),
              ],
            ),
          ),
        ],

        if (status == 3) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined,
                    color: AppTheme.textSecondary, size: 22),
                SizedBox(width: 10),
                Text('Atividade cancelada',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy, HH:mm', 'pt_PT').format(d);
    } catch (_) {
      return dateStr;
    }
  }
}


// Componentes UI reutilizáveis para o ecrã de detalhes da atividade - badges, linhas de informação, cartões de seção, etc. 


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
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
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
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value.isNotEmpty ? value : '—',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      )),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 18, color: AppTheme.textSecondary),
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              )),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}


// Ecrã de edição (push navigation)


class _ActivityEditSheet extends StatefulWidget {
  final Map<String, dynamic> activity;
  final int activityId;

  const _ActivityEditSheet({
    required this.activity,
    required this.activityId,
  });

  @override
  State<_ActivityEditSheet> createState() => _ActivityEditSheetState();
}

class _ActivityEditSheetState extends State<_ActivityEditSheet> {
  final _api = ApiService();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;

  String? _selectedType;
  int _selectedPriority = 1;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  static const List<Map<String, String>> _activityTypes = [
    {'value': 'treatment',     'label': 'Tratamento'},
    {'value': 'fertilization', 'label': 'Fertilização'},
    {'value': 'pruning',       'label': 'Poda'},
    {'value': 'irrigation',    'label': 'Rega'},
    {'value': 'harvest',       'label': 'Colheita'},
    {'value': 'inspection',    'label': 'Inspeção'},
    {'value': 'other',         'label': 'Outra'},
  ];

  static const Map<int, String> _priorityLabels = {
    1: 'Normal', 2: 'Alta', 3: 'Urgente',
  };
  static const Map<int, Color> _priorityColors = {
    1: AppTheme.primary, 2: Color(0xFFFFA726), 3: AppTheme.error,
  };

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _nameController = TextEditingController(
        text: a['activity_name']?.toString() ?? '');
    _descriptionController = TextEditingController(
        text: a['activity_description']?.toString() ?? '');
    _notesController = TextEditingController(
        text: a['activity_notes']?.toString() ?? '');
    _selectedType = a['activity_type']?.toString();
    _selectedPriority = a['activity_priority'] as int? ?? 1;

    final dateStr = a['activity_date_planned']?.toString() ?? '';
    try {
      final dt = DateTime.parse(dateStr);
      _selectedDate = DateTime(dt.year, dt.month, dt.day);
      if (dt.hour != 0 || dt.minute != 0) {
        _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      } else {
        _selectedTime = null;
      }
    } catch (_) {
      _selectedDate = null;
      _selectedTime = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _save() async {
    if (_selectedType == null || _selectedDate == null) return;
    setState(() => _isSubmitting = true);

    String dateTimeStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    if (_selectedTime != null) {
      dateTimeStr +=
          ' ${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
    }

    final payload = {
      'activity_name': _nameController.text.trim(),
      'activity_type': _selectedType,
      'activity_description': _descriptionController.text.trim(),
      'activity_date_planned': dateTimeStr,
      'activity_priority': _selectedPriority,
      'activity_notes': _notesController.text.trim(),
    };

    final queueData = <String, dynamic>{
      'activity_id': widget.activityId,
      'client_uuid': UuidHelper.v4(),
      ...payload,
    };

    final result = await OfflineMutation.run(
      apiCall: () => _api.patch(
        AppConstants.activityDetail(widget.activityId),
        data: payload,
      ),
      operationType: 'update_activity',
      queueData: queueData,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.queued) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alterações guardadas offline — sincroniza quando voltares online.'),
          backgroundColor: Color(0xFF7B1FA2),
        ),
      );
    } else if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Erro ao guardar.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Editar Atividade'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Tipo
          const _EditLabel(text: 'Tipo de atividade'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _activityTypes.map((t) {
              final selected = _selectedType == t['value'];
              return GestureDetector(
                onTap: () => setState(() => _selectedType = t['value']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.divider,
                    ),
                  ),
                  child: Text(
                    t['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Nome
          const _EditLabel(text: 'Nome'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
          ),

          const SizedBox(height: 20),

          // Prioridade
          const _EditLabel(text: 'Prioridade'),
          const SizedBox(height: 8),
          Row(
            children: [1, 2, 3].map((p) {
              final selected = _selectedPriority == p;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPriority = p),
                  child: Container(
                    margin: EdgeInsets.only(right: p < 3 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? _priorityColors[p]
                          : _priorityColors[p]!.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? _priorityColors[p]!
                            : _priorityColors[p]!.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _priorityLabels[p]!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _priorityColors[p],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Data e hora
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _EditLabel(text: 'Data'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Text(
                          _selectedDate != null
                              ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                              : 'dd/mm/aaaa',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedDate != null
                                ? AppTheme.textPrimary
                                : const Color(0xFFBDBDBD),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _EditLabel(text: 'Hora'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Text(
                          _selectedTime != null
                              ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                              : '--:--',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedTime != null
                                ? AppTheme.textPrimary
                                : const Color(0xFFBDBDBD),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Descrição
          const _EditLabel(text: 'Descrição'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),

          const SizedBox(height: 20),

          // Notas
          const _EditLabel(text: 'Notas'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isSubmitting ? null : _save,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Guardar alterações'),
          ),
        ],
      ),
    );
  }
}

class _EditLabel extends StatelessWidget {
  final String text;
  const _EditLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
  );
}

