import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/offline_read.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../shared/theme/app_theme.dart';
import 'observation_create_dialog.dart';
import 'observation_detail_screen.dart';

class ObservationsScreen extends StatefulWidget {
  const ObservationsScreen({super.key});

  @override
  State<ObservationsScreen> createState() => _ObservationsScreenState();
}

class _ObservationsScreenState extends State<ObservationsScreen> {
  final _api = ApiService();
  List<dynamic> _observations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isLoading = false); return; }
    final result = await OfflineRead.list(
      cacheKey: 'observations:farm_${farm.farmId}',
      apiCall: () => _api.get(
        AppConstants.observations,
        params: {'farm_id': farm.farmId.toString()},
      ),
      localEntity: 'observation',
      parentId: farm.farmId,
    );
    if (!mounted) return;
    setState(() {
      _observations = result.items;
      _error = result.fromCache && result.items.isEmpty
          ? (result.errorMessage ?? 'Sem ligação e sem dados guardados.')
          : null;
      _isLoading = false;
    });
  }

  void _openCreate() async {
    final result = await showCreateObservationDialog(context);
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Observações'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (context.read<FarmProvider>().selectedFarm?.canContribute ?? false)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _openCreate,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : _observations.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: _observations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final obs = _observations[i] as Map<String, dynamic>;
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ObservationDetailScreen(observation: obs),
                              ),
                            ),
                            child: _ObservationCard(obs: obs),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _load,
      child: ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(Icons.visibility_outlined, size: 56,
                    color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text('Sem observações',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                const Text('Regista a primeira observação de campo.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Nova observação'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Card de observação
// ══════════════════════════════════════════════════════════════

class _ObservationCard extends StatelessWidget {
  final Map<String, dynamic> obs;
  const _ObservationCard({required this.obs});

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
    final text = obs['observation_text']?.toString() ?? '';
    final landName = obs['land_name']?.toString() ?? '';
    final landId = obs['land'] ?? obs['land_id'];
    final pragaFungo = obs['praga_fungo']?.toString() ?? '';
    final estadoFen = obs['estado_fenologico']?.toString() ?? '';
    final createdAt = obs['created_at']?.toString() ?? '';

    String dateFormatted = '';
    try {
      final dt = DateTime.parse(createdAt);
      dateFormatted = DateFormat('dd MMM yyyy, HH:mm', 'pt_PT').format(dt);
    } catch (_) {
      dateFormatted = createdAt;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: terreno + data
          Row(
            children: [
              const Icon(Icons.grass_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  landName.isNotEmpty ? landName : 'Terreno $landId',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
              ),
              Text(dateFormatted,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),

          const SizedBox(height: 10),

          // Texto da observação
          Text(text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary,
                  height: 1.5)),

          // Badges
          if (pragaFungo.isNotEmpty || estadoFen.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
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
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}
