import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/water_service.dart';
import '../../../core/models/water_model.dart';
import '../../../shared/theme/app_theme.dart';

/// Lista regas de uma cultura:
///  - Planeadas: filtradas por yield_id
///  - Executadas: usage_log do mesmo land_id (não há yield_id no log)
class IrrigationYieldScreen extends StatefulWidget {
  final int yieldId;
  final int landId;
  final String yieldName;
  final String landName;

  const IrrigationYieldScreen({
    super.key,
    required this.yieldId,
    required this.landId,
    required this.yieldName,
    required this.landName,
  });

  @override
  State<IrrigationYieldScreen> createState() => _IrrigationYieldScreenState();
}

class _IrrigationYieldScreenState extends State<IrrigationYieldScreen> {
  final _waterService = WaterService();

  List<WaterIrrigationPlan> _planned = [];
  List<WaterUsageLog> _executed = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _waterService.listPlanned(landId: widget.landId),
        _waterService.listUsage(landId: widget.landId),
      ]);
      final allPlanned = results[0] as List<WaterIrrigationPlan>;
      // Filter planeadas só desta cultura
      final planned = allPlanned
          .where((p) => p.yieldId == widget.yieldId)
          .toList()
        ..sort((a, b) => a.plannedDate.compareTo(b.plannedDate));
      final executed = results[1] as List<WaterUsageLog>;
      if (!mounted) return;
      setState(() {
        _planned = planned;
        _executed = executed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Erro ao carregar regas.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPlanned(int plannedId) async {
    await context.push('/irrigation/planned/$plannedId');
    if (mounted) _load();
  }

  String _formatDateTime(String date, String? time) {
    try {
      final d = DateTime.parse(date);
      final dateStr = DateFormat('dd/MM/yyyy').format(d);
      if (time != null && time.isNotEmpty) {
        return '$dateStr  ${time.substring(0, 5)}';
      }
      return dateStr;
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.yieldName),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.landName,
          style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),

        const _SectionLabel(label: 'Planeadas'),
        const SizedBox(height: 8),
        if (_planned.isEmpty)
          const _EmptyBox(text: 'Sem regas planeadas para esta cultura.')
        else
          ..._planned.map((p) {
            final status = p.status;
            return _IrrigationRow(
              icon: Icons.schedule,
              iconColor: status == 1
                  ? AppTheme.primary
                  : status == 2
                      ? AppTheme.error
                      : const Color(0xFF0D47A1),
              iconBg: status == 1
                  ? const Color(0xFFE8F5E9)
                  : status == 2
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFCCE5FF),
              title: _formatDateTime(p.plannedDate, p.plannedTime),
              subtitle: _subtitleFor(p),
              trailing: _StatusBadge(status: status),
              onTap: () => _openPlanned(p.plannedId),
            );
          }),

        const SizedBox(height: 20),
        const _SectionLabel(label: 'Executadas (neste terreno)'),
        const SizedBox(height: 8),
        if (_executed.isEmpty)
          const _EmptyBox(text: 'Sem consumos registados.')
        else
          ..._executed.map((u) => _IrrigationRow(
                icon: Icons.check_circle,
                iconColor: AppTheme.primary,
                iconBg: const Color(0xFFE8F5E9),
                title: _formatDateTime(u.usageDate, null),
                subtitle:
                    '${u.volumeLiters.toStringAsFixed(0)} L${u.methodName != null ? ' • ${u.methodName}' : ''}',
                trailing: null,
                onTap: null,
              )),
      ],
    );
  }

  String _subtitleFor(WaterIrrigationPlan p) {
    final parts = <String>[];
    if (p.durationMin != null) parts.add('${p.durationMin} min');
    if (p.volumeLiters != null) parts.add('${p.volumeLiters!.toStringAsFixed(0)} L');
    if (p.methodName != null && p.methodName!.isNotEmpty) parts.add(p.methodName!);
    return parts.join(' • ');
  }
}

class _StatusBadge extends StatelessWidget {
  final int status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;
    switch (status) {
      case 1:
        label = 'Executada';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF1B5E20);
        break;
      case 2:
        label = 'Cancelada';
        bg = const Color(0xFFFFEBEE);
        fg = AppTheme.error;
        break;
      default:
        label = 'Planeada';
        bg = const Color(0xFFCCE5FF);
        fg = const Color(0xFF0D47A1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _IrrigationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _IrrigationRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.textSecondary, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  final String text;
  const _EmptyBox({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
      );
}
