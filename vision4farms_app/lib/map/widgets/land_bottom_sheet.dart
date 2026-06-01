import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/land_model.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/services/api_service.dart';

class LandBottomSheet extends StatefulWidget {
  final LandMapItem item;
  final VoidCallback onClose;
  final ApiService apiService;

  const LandBottomSheet({
    super.key,
    required this.item,
    required this.onClose,
    required this.apiService,
  });

  @override
  State<LandBottomSheet> createState() => _LandBottomSheetState();
}

class _LandBottomSheetState extends State<LandBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final land = widget.item.land;
    final hasOverdue = widget.item.hasOverdue;

    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.28,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.38, 0.75],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle + Header
              _buildHandle(),
              _buildHeader(land, hasOverdue),

              // Conteúdo scrollável
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cards de métricas
                      _buildMetricsRow(land),
                      const SizedBox(height: 16),

                      // Atividades pendentes
                      if (widget.item.hasActivities) ...[
                        _buildActivitiesSection(),
                        const SizedBox(height: 16),
                      ],

                      // Detalhes do terreno
                      _buildDetailsSection(land),
                      const SizedBox(height: 24),

                      // Botões de ação
                      _buildActionButtons(land),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(LandModel land, bool hasOverdue) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Row(
        children: [
          // Ícone do terreno
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasOverdue
                  ? AppTheme.warning.withOpacity(0.15)
                  : AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.terrain,
              color: hasOverdue ? AppTheme.warning : AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Nome e localização
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  land.landName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (land.landLocation != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        land.landLocation!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Botão fechar
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(LandModel land) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Área',
            value: land.landSize != null
                ? '${land.landSize!.toStringAsFixed(3)} ha'
                : '—',
            icon: Icons.square_foot_outlined,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Pendentes',
            value: widget.item.pendingActivities.toString(),
            icon: Icons.task_outlined,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Atrasadas',
            value: widget.item.overdueActivities.toString(),
            icon: Icons.warning_amber_outlined,
            color: widget.item.hasOverdue ? AppTheme.warning : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Atividades',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        // Banner de atrasos
        if (widget.item.hasOverdue)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.warning, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${widget.item.overdueActivities} atividade${widget.item.overdueActivities != 1 ? 's' : ''} atrasada${widget.item.overdueActivities != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppTheme.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        if (widget.item.pendingActivities > 0 && !widget.item.hasOverdue)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.task_alt,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${widget.item.pendingActivities} atividade${widget.item.pendingActivities != 1 ? 's' : ''} pendente${widget.item.pendingActivities != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsSection(LandModel land) {
    final details = <_DetailRow>[];

    if (land.landGps != null) {
      details.add(_DetailRow(
        icon: Icons.gps_fixed_outlined,
        label: 'Coordenadas',
        value: land.landGps!,
      ));
    }
    if (land.landInclination != null) {
      details.add(_DetailRow(
        icon: Icons.terrain_outlined,
        label: 'Inclinação',
        value: land.landInclination!,
      ));
    }
    if (land.landSunExposure != null) {
      details.add(_DetailRow(
        icon: Icons.wb_sunny_outlined,
        label: 'Exposição solar',
        value: land.landSunExposure!,
      ));
    }
    if (land.landElevation != null) {
      details.add(_DetailRow(
        icon: Icons.height_outlined,
        label: 'Altitude',
        value: land.landElevation!,
      ));
    }
    if (land.landWater == 1) {
      details.add(const _DetailRow(
        icon: Icons.water_drop_outlined,
        label: 'Rega',
        value: 'Com sistema de rega',
      ));
    }

    if (details.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informações',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: details
                .asMap()
                .entries
                .map((e) => Column(
                      children: [
                        e.value,
                        if (e.key < details.length - 1)
                          const Divider(height: 1, indent: 40),
                      ],
                    ))
                .toList(),
          ),
        ),

        // Notas
        if (land.landNotes != null && land.landNotes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notes_outlined, size: 14,
                        color: AppTheme.textSecondary),
                    SizedBox(width: 5),
                    Text(
                      'Notas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  land.landNotes!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(LandModel land) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  context.go('/lands/${land.landId}?name=${Uri.encodeComponent(land.landName)}');
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver terreno'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: Size.zero,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: navegar para criar atividade neste terreno
                  widget.onClose();
                },
                icon: const Icon(Icons.add_task, size: 16),
                label: const Text('Nova atividade'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: Size.zero,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ───────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}