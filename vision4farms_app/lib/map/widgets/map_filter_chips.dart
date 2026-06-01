import 'package:flutter/material.dart';
import '../../core/providers/map_provider.dart';
import '../../shared/theme/app_theme.dart';

class MapFilterChips extends StatelessWidget {
  final MapFilter activeFilter;
  final ValueChanged<MapFilter> onFilterChanged;

  const MapFilterChips({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _FilterChip(
            label: 'Todos',
            icon: Icons.layers_outlined,
            filter: MapFilter.all,
            activeFilter: activeFilter,
            onTap: onFilterChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Com atividades',
            icon: Icons.task_alt_outlined,
            filter: MapFilter.withActivities,
            activeFilter: activeFilter,
            onTap: onFilterChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Atrasados',
            icon: Icons.warning_amber_outlined,
            filter: MapFilter.overdue,
            activeFilter: activeFilter,
            onTap: onFilterChanged,
            isAlert: true,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Pendentes',
            icon: Icons.schedule_outlined,
            filter: MapFilter.pending,
            activeFilter: activeFilter,
            onTap: onFilterChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Ativ. concluídas',
            icon: Icons.check_circle_outline,
            filter: MapFilter.done,
            activeFilter: activeFilter,
            onTap: onFilterChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Rega',
            icon: Icons.water_drop_outlined,
            filter: MapFilter.irrigation,
            activeFilter: activeFilter,
            onTap: onFilterChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Tratamento',
            icon: Icons.pest_control_outlined,
            filter: MapFilter.treatment,
            activeFilter: activeFilter,
            onTap: onFilterChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Colheita',
            icon: Icons.agriculture_outlined,
            filter: MapFilter.harvest,
            activeFilter: activeFilter,
            onTap: onFilterChanged,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Com culturas',
            icon: Icons.eco_outlined,
            filter: MapFilter.withCrops,
            activeFilter: activeFilter,
            onTap: onFilterChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final MapFilter filter;
  final MapFilter activeFilter;
  final ValueChanged<MapFilter> onTap;
  final bool isAlert;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.filter,
    required this.activeFilter,
    required this.onTap,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = filter == activeFilter;
    final activeColor = isAlert ? AppTheme.warning : AppTheme.primary;

    return GestureDetector(
      onTap: () => onTap(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? Colors.white : activeColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}