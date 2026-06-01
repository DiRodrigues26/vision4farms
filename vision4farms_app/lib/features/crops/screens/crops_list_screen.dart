import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/services/local_database.dart';
import 'create_crop_dialog.dart';

class CropsListScreen extends StatefulWidget {
  const CropsListScreen({super.key});

  @override
  State<CropsListScreen> createState() => _CropsListScreenState();
}

class _CropsListScreenState extends State<CropsListScreen> {
  final _api = ApiService();
  List<dynamic> _crops = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    setState(() { _isLoading = true; _error = null; });
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isLoading = false); return; }
    try {
      final response = await _api.get(
        AppConstants.cropsFarm(farm.farmId),
      );
      final data = response.data is List
          ? response.data as List
          : ApiService.extractResults(response.data);
      await LocalDatabase.saveCrops(farm.farmId, data);
      setState(() => _crops = data);
    } catch (_) {
      final cached = await LocalDatabase.getCrops(farm.farmId);
      if (cached.isNotEmpty) {
        setState(() => _crops = cached);
      } else {
        setState(() => _error = 'Sem ligação e sem dados guardados.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'As Suas Culturas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.primary))
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _loadCrops)
                      : _crops.isEmpty
                          ? const _EmptyState()
                          : RefreshIndicator(
                              color: AppTheme.primary,
                              onRefresh: _loadCrops,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 12, 16, 100),
                                itemCount: _crops.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _CropCard(crop: _crops[index]);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            barrierColor: Colors.black54,
            builder: (_) => const CreateCropDialog(),
          );
          if (created == true) _loadCrops();
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Adicionar nova cultura',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Card de cultura ───────────────────────────────────────────

class _CropCard extends StatelessWidget {
  final Map<String, dynamic> crop;
  const _CropCard({required this.crop});

  String _fmtLastIrrigation(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date).inDays;
      if (diff == 0) return 'Hoje';
      if (diff == 1) return 'Ontem';
      const months = [
        'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
        'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
      ];
      return '${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cropName = crop['crop_name']?.toString() ?? '';
    final cropType = crop['crop_type']?.toString() ?? '';
    final lands =
        (crop['lands'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final landsLabel = lands
        .map((l) => l['land_name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .join(', ');

    double areaHa = 0;
    try {
      areaHa = double.parse(crop['total_area_ha']?.toString() ?? '0');
    } catch (_) {}

    int activityCount = 0;
    try {
      activityCount =
          int.parse(crop['activity_count']?.toString() ?? '0');
    } catch (_) {}

    int obsCount = 0;
    try {
      obsCount =
          int.parse(crop['observation_count']?.toString() ?? '0');
    } catch (_) {}

    final lastIrrigation =
        _fmtLastIrrigation(crop['last_irrigation']?.toString());

    return GestureDetector(
      onTap: () {
        final cropId =
            int.tryParse(crop['crop_id']?.toString() ?? '') ?? 0;
        context.go('/crops/$cropId?name=${Uri.encodeComponent(cropName)}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome + tipo + chevron
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cropName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (cropType.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          cropType,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary, size: 20),
              ],
            ),

            // Terrenos
            if (landsLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.terrain,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      landsLabel,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Chips
            Row(
              children: [
                _StatChip(
                  value: areaHa % 1 == 0
                      ? areaHa.toInt().toString()
                      : areaHa.toStringAsFixed(1),
                  label: 'Hectares',
                  color: const Color(0xFFD4EDDA),
                  textColor: const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  value: activityCount.toString(),
                  label: 'Atividades',
                  color: const Color(0xFFE8D5F5),
                  textColor: const Color(0xFF7B1FA2),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  value: obsCount.toString(),
                  label: 'Observações',
                  color: const Color(0xFFCCE5FF),
                  textColor: const Color(0xFF0D47A1),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                _StatChip(
                  value: lastIrrigation,
                  label: 'Última Rega',
                  color: AppTheme.surface,
                  textColor: AppTheme.textPrimary,
                  bordered: true,
                  flex: 1,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  value: lands.length.toString(),
                  label: 'Terrenos',
                  color: const Color(0xFFFFF3CD),
                  textColor: const Color(0xFFE65100),
                  flex: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip de estatística ────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color textColor;
  final bool bordered;
  final int flex;

  const _StatChip({
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
    this.bordered = false,
    this.flex = 0,
  });

  Widget _chip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: bordered ? Border.all(color: AppTheme.divider) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (flex > 0) return Expanded(child: _chip());
    return _chip();
  }
}

// ── Empty state ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_outlined,
                size: 64,
                color: AppTheme.textSecondary.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            const Text(
              'Sem culturas',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adiciona a tua primeira cultura\npara começar.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48,
                color: AppTheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
