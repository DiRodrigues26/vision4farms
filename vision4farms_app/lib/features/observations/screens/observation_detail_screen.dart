import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/safe_back.dart';

class ObservationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> observation;
  const ObservationDetailScreen({super.key, required this.observation});

  static const Map<String, IconData> _pragaIcons = {
    'praga': Icons.bug_report_outlined,
    'fungo': Icons.eco_outlined,
    'virus': Icons.coronavirus_outlined,
    'bacteria': Icons.biotech_outlined,
    'outro': Icons.help_outline,
  };

  static const Map<String, Color> _pragaColors = {
    'praga': Color(0xFFE65100),
    'fungo': Color(0xFF2E7D32),
    'virus': Color(0xFFD32F2F),
    'bacteria': Color(0xFF7B1FA2),
    'outro': Color(0xFF757575),
  };

  @override
  Widget build(BuildContext context) {
    final text = observation['observation_text']?.toString() ?? '';
    final landName = observation['land_name']?.toString() ?? '';
    final landId = observation['land'] ?? observation['land_id'];
    final yieldId = observation['yield_id'];
    final cropName = observation['crop_name']?.toString() ?? '';
    final yieldName = observation['yield_name']?.toString() ?? '';
    final photo = observation['observation_photo']?.toString() ?? '';
    final pragaFungo = observation['praga_fungo']?.toString() ?? '';
    final estadoFen = observation['estado_fenologico']?.toString() ?? '';
    final armadilha = observation['numero_armadilha']?.toString() ?? '';
    final qtDetetada = observation['qt_detetada']?.toString() ?? '';
    final gps = observation['observation_gps']?.toString() ?? '';
    final createdAt = observation['created_at']?.toString() ?? '';

    String dateFormatted = '';
    try {
      final dt = DateTime.parse(createdAt);
      dateFormatted = DateFormat('dd MMMM yyyy, HH:mm', 'pt_PT').format(dt);
    } catch (_) {
      dateFormatted = createdAt;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Observação'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safeBack(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Header com ícone
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: (pragaFungo.isNotEmpty
                      ? _pragaColors[pragaFungo] ?? AppTheme.primary
                      : AppTheme.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  pragaFungo.isNotEmpty
                      ? _pragaIcons[pragaFungo] ?? Icons.visibility_outlined
                      : Icons.visibility_outlined,
                  color: pragaFungo.isNotEmpty
                      ? _pragaColors[pragaFungo] ?? AppTheme.primary
                      : AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      landName.isNotEmpty ? landName : 'Terreno $landId',
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(dateFormatted,
                        style: const TextStyle(fontSize: 13,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Badges
          if (pragaFungo.isNotEmpty || estadoFen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (pragaFungo.isNotEmpty)
                    _Badge(
                      icon: _pragaIcons[pragaFungo] ?? Icons.help_outline,
                      label: pragaFungo[0].toUpperCase() + pragaFungo.substring(1),
                      color: _pragaColors[pragaFungo] ?? AppTheme.textSecondary,
                    ),
                  if (estadoFen.isNotEmpty)
                    _Badge(
                      icon: Icons.spa_outlined,
                      label: estadoFen,
                      color: AppTheme.primary,
                    ),
                ],
              ),
            ),

          // Foto
          if (photo.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                photo.startsWith('http')
                    ? photo
                    : '${AppConstants.baseUrl.replaceAll('/api', '')}/media/$photo',
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 220,
                    color: AppTheme.divider,
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            size: 40, color: AppTheme.textSecondary),
                        SizedBox(height: 8),
                        Text('Não foi possível carregar a imagem',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Descrição
          _SectionCard(
            title: 'Descrição',
            child: Text(text,
                style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary,
                    height: 1.6)),
          ),

          // Info card
          const SizedBox(height: 16),
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.grass_outlined,
                label: 'Terreno',
                value: landName.isNotEmpty ? landName : 'ID: $landId',
                onTap: landId != null
                    ? () => context.go(
                        '/lands/$landId?name=${Uri.encodeComponent(landName.isNotEmpty ? landName : 'Terreno')}')
                    : null,
              ),
              if (yieldId != null)
                _InfoRow(
                  icon: Icons.energy_savings_leaf_outlined,
                  label: 'Cultura',
                  value: cropName.isNotEmpty
                      ? (yieldName.isNotEmpty
                          ? '$cropName · $yieldName'
                          : cropName)
                      : (yieldName.isNotEmpty ? yieldName : 'ID: $yieldId'),
                ),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Data de registo',
                value: dateFormatted,
              ),
              if (gps.isNotEmpty)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Localização GPS',
                  value: gps,
                ),
            ],
          ),

          // Armadilha + Quantidade
          if (armadilha.isNotEmpty || (qtDetetada.isNotEmpty && qtDetetada != 'null')) ...[
            const SizedBox(height: 16),
            _InfoCard(
              children: [
                if (armadilha.isNotEmpty)
                  _InfoRow(
                    icon: Icons.gps_fixed_outlined,
                    label: 'N.o armadilha',
                    value: armadilha,
                  ),
                if (qtDetetada.isNotEmpty && qtDetetada != 'null')
                  _InfoRow(
                    icon: Icons.analytics_outlined,
                    label: 'Quantidade detetada',
                    value: qtDetetada,
                  ),
              ],
            ),
          ],
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: color)),
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
                      style: const TextStyle(fontSize: 11,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value.isNotEmpty ? value : '—',
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 18,
                  color: AppTheme.textSecondary),
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
