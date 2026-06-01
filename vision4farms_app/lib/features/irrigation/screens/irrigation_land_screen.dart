import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/water_service.dart';
import '../../../core/models/water_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/theme/app_theme.dart';

class IrrigationLandScreen extends StatefulWidget {
  final int landId;
  final String landName;

  const IrrigationLandScreen({
    super.key,
    required this.landId,
    required this.landName,
  });

  @override
  State<IrrigationLandScreen> createState() => _IrrigationLandScreenState();
}

class _IrrigationLandScreenState extends State<IrrigationLandScreen> {
  final _api = ApiService();
  final _waterService = WaterService();

  List<Map<String, dynamic>> _yields = [];
  Map<int, WaterIrrigationPlan?> _nextByYield = {};
  Map<int, String?> _lastByYield = {};
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
        _api.get(AppConstants.yields,
            params: {'land_id': widget.landId.toString()}),
        _waterService.listPlanned(landId: widget.landId, status: 0),
        _waterService.listUsage(landId: widget.landId),
      ]);
      final yieldsList = ApiService.extractResults((results[0] as dynamic).data)
          .cast<Map<String, dynamic>>();
      final plans = results[1] as List<WaterIrrigationPlan>;
      final usages = results[2] as List<WaterUsageLog>;

      final nextByYield = <int, WaterIrrigationPlan?>{};
      for (final p in plans) {
        if (p.yieldId != null) {
          final existing = nextByYield[p.yieldId!];
          if (existing == null ||
              p.plannedDate.compareTo(existing.plannedDate) < 0) {
            nextByYield[p.yieldId!] = p;
          }
        }
      }

      // Last rega é por land (usage log não tem yield_id)
      String? lastForLand;
      for (final u in usages) {
        if (lastForLand == null || u.usageDate.compareTo(lastForLand) > 0) {
          lastForLand = u.usageDate;
        }
      }
      final lastByYield = <int, String?>{
        for (final y in yieldsList) y['yield_id'] as int: lastForLand,
      };

      if (!mounted) return;
      setState(() {
        _yields = yieldsList;
        _nextByYield = nextByYield;
        _lastByYield = lastByYield;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Erro ao carregar culturas.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openYield(int yieldId, String yieldName) async {
    await context.push(
        '/irrigation/yield/$yieldId?name=${Uri.encodeComponent(yieldName)}&landName=${Uri.encodeComponent(widget.landName)}&landId=${widget.landId}');
    if (mounted) _load();
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.landName),
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
        const Text(
          'Culturas do terreno',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_yields.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Sem culturas ativas neste terreno.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          ..._yields.map((y) {
            final yid = y['yield_id'] as int;
            final yname = y['yield_name']?.toString() ?? '';
            final next = _nextByYield[yid];
            return _IrrigationItemCard(
              title: yname,
              icon: Icons.eco,
              iconBg: const Color(0xFFE8F5E9),
              iconColor: AppTheme.primary,
              lastValue: _formatDate(_lastByYield[yid]),
              nextValue: next != null ? _formatDate(next.plannedDate) : '—',
              onTap: () => _openYield(yid, yname),
            );
          }),
      ],
    );
  }
}

class _IrrigationItemCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String lastValue;
  final String nextValue;
  final String? subtitle;
  final VoidCallback onTap;

  const _IrrigationItemCard({
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.lastValue,
    required this.nextValue,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoChip(
                              label: 'Última',
                              value: lastValue,
                              color: const Color(0xFFFFF3CD),
                              textColor: const Color(0xFF7A5C00),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _InfoChip(
                              label: 'Próxima',
                              value: nextValue,
                              color: const Color(0xFFCCE5FF),
                              textColor: const Color(0xFF0D47A1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color textColor;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
        ],
      ),
    );
  }
}
