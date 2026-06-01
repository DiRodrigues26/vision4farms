import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/water_model.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/offline_read.dart';
import '../../../core/services/water_service.dart';
import '../../../shared/theme/app_theme.dart';
import 'water_source_detail_screen.dart';
import 'water_source_form_screen.dart';

class WaterSourcesListScreen extends StatefulWidget {
  const WaterSourcesListScreen({super.key});

  @override
  State<WaterSourcesListScreen> createState() => _WaterSourcesListScreenState();
}

class _WaterSourcesListScreenState extends State<WaterSourcesListScreen> {
  final _service = WaterService();
  final _api = ApiService();
  List<WaterSource> _sources = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) {
      setState(() {
        _isLoading = false;
        _error = 'Sem exploração selecionada';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await OfflineRead.list(
      cacheKey: 'water_sources:farm_${farm.farmId}',
      apiCall: () => _api.get(
        AppConstants.waterSources,
        params: {'farm_id': farm.farmId},
      ),
      localEntity: 'water_source',
      parentId: farm.farmId,
    );
    if (!mounted) return;
    setState(() {
      _sources = result.items
          .map((e) => WaterSource.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = result.fromCache && _sources.isEmpty
          ? (result.errorMessage ?? 'Sem ligação e sem dados guardados.')
          : null;
      _isLoading = false;
    });
  }

  Future<void> _openForm({WaterSource? source}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WaterSourceFormScreen(source: source),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openDetail(WaterSource source) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WaterSourceDetailScreen(sourceId: source.waterSourceId),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _confirmDelete(WaterSource source) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar fonte de água'),
        content: Text('Tens a certeza que queres eliminar "${source.waterSourceName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _service.deleteSource(source.waterSourceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fonte eliminada')),
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao eliminar')),
      );
    }
  }

  IconData _iconForType(String? typeName) {
    final t = (typeName ?? '').toLowerCase();
    if (t.contains('furo')) return Icons.water_rounded;
    if (t.contains('charca') || t.contains('lago')) return Icons.waves_rounded;
    if (t.contains('reserv')) return Icons.water_drop_rounded;
    if (t.contains('rio') || t.contains('ribeiro')) return Icons.stream_rounded;
    if (t.contains('rede') || t.contains('publica')) return Icons.tap_and_play_rounded;
    return Icons.opacity_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final canManage = context.read<FarmProvider>().selectedFarm?.canManage ?? false;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: const Text('Fontes de água'),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nova fonte',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _sources.isEmpty
                  ? _EmptyView(canManage: canManage, onCreate: () => _openForm())
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: _sources.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = _sources[i];
                          return _SourceCard(
                            source: s,
                            icon: _iconForType(s.waterTypeName),
                            canManage: canManage,
                            onTap: () => _openDetail(s),
                            onEdit: () => _openForm(source: s),
                            onDelete: () => _confirmDelete(s),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Card de fonte
// ══════════════════════════════════════════════════════════════

class _SourceCard extends StatelessWidget {
  final WaterSource source;
  final IconData icon;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SourceCard({
    required this.source,
    required this.icon,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusActive = source.status == 1;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0288D1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0277BD), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          source.waterSourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (!statusActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Inativa',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    source.waterTypeName ?? '—',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (source.capacity != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.opacity_outlined,
                            size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          '${source.capacity!.toStringAsFixed(0)} m³',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (source.depthMeters != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.straighten,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            '${source.depthMeters!.toStringAsFixed(1)} m',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (canManage)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              )
            else
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Estados vazios e de erro
// ══════════════════════════════════════════════════════════════

class _EmptyView extends StatelessWidget {
  final bool canManage;
  final VoidCallback onCreate;
  const _EmptyView({required this.canManage, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_outlined,
                size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('Sem fontes de água',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                )),
            const SizedBox(height: 6),
            Text(
              canManage
                  ? 'Cria a primeira fonte para começares a registar consumos.'
                  : 'Ainda não há fontes registadas nesta exploração.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            if (canManage) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Criar fonte'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
