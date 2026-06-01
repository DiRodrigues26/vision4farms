import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/sensor_association_model.dart';
import '../../../core/models/sensor_node_model.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sensor_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/theme/app_theme.dart';

class SensorAssociationScreen extends StatefulWidget {
  const SensorAssociationScreen({super.key});

  @override
  State<SensorAssociationScreen> createState() =>
      _SensorAssociationScreenState();
}

class _SensorAssociationScreenState extends State<SensorAssociationScreen> {
  final _api = ApiService();
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  List<SensorNodeModel> _foundNodes = [];
  List<Map<String, dynamic>> _lands = [];
  final Map<String, int?> _assignments = {};

  List<SensorAssociationModel> _existing = const [];
  bool _loadingExisting = true;

  bool _loadingLands = true;
  bool _searching = false;
  bool _saving = false;
  String? _error;
  bool _done = false;
  String? _lastSearchedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLands();
      _loadExisting();
    });
  }

  Future<void> _loadExisting() async {
    if (!mounted) return;
    try {
      final farm = context.read<FarmProvider>().selectedFarm;
      if (farm == null) {
        if (mounted) setState(() => _loadingExisting = false);
        return;
      }
      final list = await context
          .read<SensorProvider>()
          .loadFarmAssociations(farm.farmId, notify: false);
      if (!mounted) return;
      setState(() {
        _existing = list;
        _loadingExisting = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _removeAssociation(SensorAssociationModel assoc) async {
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover sensor?'),
        content: Text(
          '${assoc.sensorNome} será removido do terreno '
          '"${assoc.landName}". Podes voltar a associá-lo a outro terreno.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await context.read<SensorProvider>().deleteAssociation(
            associationId: assoc.associationId,
            farmId: farm.farmId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primary,
          content: Text('${assoc.sensorNome} removido.'),
          duration: const Duration(seconds: 2),
        ),
      );
      _loadExisting();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Erro ao remover: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  int get _assignedCount =>
      _assignments.values.where((v) => v != null).length;

  int get _currentStep {
    if (_done) return 2;
    if (_foundNodes.isNotEmpty) return 1;
    return 0;
  }

  Future<void> _loadLands() async {
    if (!mounted) return;
    try {
      final farm = context.read<FarmProvider>().selectedFarm;
      if (farm == null) {
        if (mounted) setState(() => _loadingLands = false);
        return;
      }
      final response = await _api.get(
        AppConstants.lands,
        params: {'farm_id': farm.farmId.toString()},
      );
      if (!mounted) return;
      final data = ApiService.extractResults(response.data);
      setState(() {
        _lands = data.cast<Map<String, dynamic>>();
        _loadingLands = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLands = false);
    }
  }

  Future<void> _search() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Introduz o código do gateway.');
      return;
    }
    _codeFocus.unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _foundNodes = [];
      _assignments.clear();
      _lastSearchedCode = code;
    });
    try {
      final nodes = await context
          .read<SensorProvider>()
          .findNodesByGatewayCode(code);
      if (!mounted) return;
      if (nodes.isEmpty) {
        setState(() {
          _error = 'Nenhum nó encontrado com o código "$code".\n'
              'Confirma que o código está correto e que o gateway está online.';
          _searching = false;
        });
        return;
      }
      for (final node in nodes) {
        _assignments[node.firebaseId] = null;
      }
      setState(() {
        _foundNodes = nodes;
        _searching = false;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao procurar nós: $e';
          _searching = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!mounted) return;
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) {
      setState(() => _error = 'Nenhuma exploração selecionada.');
      return;
    }

    if (_assignedCount < _foundNodes.length) {
      setState(() => _error = 'Atribui um terreno a todos os nós.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = _foundNodes.map((node) {
        return node.toAssociationPayload(
          farmId: farm.farmId,
          landId: _assignments[node.firebaseId]!,
        );
      }).toList();
      await context.read<SensorProvider>().saveAssociations(
            farmId: farm.farmId,
            associations: payload,
          );
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _saving = false;
          _done = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível guardar.\n$e';
          _saving = false;
        });
      }
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/sensors');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Associar sensores',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
      ),
      body: _done ? _buildDone() : _buildForm(),
    );
  }

  // ── Form ──────────────────────────────────────────────────

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (_existing.isNotEmpty) ...[
          _buildExistingSection(),
          const SizedBox(height: 24),
        ],
        _StepIndicator(currentStep: _currentStep),
        const SizedBox(height: 20),

        _SearchCard(
          controller: _codeCtrl,
          focusNode: _codeFocus,
          searching: _searching,
          onSearch: _search,
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: _error!),
        ],

        if (_loadingLands && _foundNodes.isEmpty) ...[
          const SizedBox(height: 20),
          _buildLandsLoading(),
        ],

        if (_foundNodes.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildNodesHeader(),
          const SizedBox(height: 14),
          ..._foundNodes.map(_buildNodeCard),
          const SizedBox(height: 8),
          _buildSaveButton(),
        ] else if (!_searching && _lastSearchedCode == null) ...[
          const SizedBox(height: 28),
          _buildHelpCard(),
        ],
      ],
    );
  }

  Widget _buildExistingSection() {
    // Agrupa associações por terreno
    final byLand = <int, List<SensorAssociationModel>>{};
    final landNames = <int, String>{};
    for (final a in _existing) {
      byLand.putIfAbsent(a.landId, () => []).add(a);
      landNames.putIfAbsent(a.landId, () => a.landName);
    }
    final sortedLandIds = byLand.keys.toList()
      ..sort((a, b) => (landNames[a] ?? '').compareTo(landNames[b] ?? ''));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sensores já associados',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_existing.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Toca no ícone do caixote para remover um sensor do terreno. '
            'Depois podes voltar a associá-lo a outro.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedLandIds.map((landId) {
            final name = landNames[landId] ?? 'Terreno $landId';
            final sensors = byLand[landId]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terrain,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...sensors.map((s) => _buildExistingRow(s)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExistingRow(SensorAssociationModel assoc) {
    final isOnline = assoc.sensorStatus == 'online';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sensors,
            size: 14,
            color: isOnline ? AppTheme.primary : AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assoc.sensorNome,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (assoc.gatewayCode.isNotEmpty)
                  Text(
                    'Gateway: ${assoc.gatewayCode}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeAssociation(assoc),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 20, color: AppTheme.error),
            tooltip: 'Remover do terreno',
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildLandsLoading() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'A carregar terrenos da exploração…',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Como funciona',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Cada gateway tem um código único impresso na etiqueta '
                  '(formato V4F-XXXX-XXXX). Ao procurares, vais ver os '
                  'sensores ligados a esse gateway. Depois é só atribuir '
                  'cada um ao terreno onde está instalado.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodesHeader() {
    final total = _foundNodes.length;
    final progress = total == 0 ? 0.0 : _assignedCount / total;
    final allAssigned = _assignedCount == total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allAssigned
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: allAssigned
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$total sensor(es) encontrado(s)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '$_assignedCount/$total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: allAssigned
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                allAssigned ? AppTheme.primary : AppTheme.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeCard(SensorNodeModel node) {
    final isOnline = node.status == 'online';
    final assignedLandId = _assignments[node.firebaseId];
    final isAssigned = assignedLandId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAssigned
              ? AppTheme.primary.withValues(alpha: 0.4)
              : AppTheme.divider,
          width: isAssigned ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do nó
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isOnline
                            ? AppTheme.primary
                            : AppTheme.textSecondary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.sensors,
                    color: isOnline
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if ((node.tipo ?? '').isNotEmpty)
                        Text(
                          'Tipo: ${node.tipo}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                _StatusBadge(isOnline: isOnline),
              ],
            ),
          ),

          // Divisor
          Container(
            height: 1,
            color: AppTheme.divider,
            margin: const EdgeInsets.symmetric(horizontal: 14),
          ),

          // Selector de terreno
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isAssigned ? Icons.check_circle : Icons.terrain,
                      size: 14,
                      color: isAssigned
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAssigned ? 'Terreno atribuído' : 'Atribuir terreno',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isAssigned
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  value: assignedLandId,
                  isExpanded: true,
                  hint: Text(
                    _lands.isEmpty
                        ? 'Sem terrenos disponíveis'
                        : 'Seleciona o terreno…',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isAssigned
                        ? AppTheme.primary.withValues(alpha: 0.04)
                        : AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isAssigned
                            ? AppTheme.primary.withValues(alpha: 0.3)
                            : AppTheme.divider,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isAssigned
                            ? AppTheme.primary.withValues(alpha: 0.3)
                            : AppTheme.divider,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: _lands.map((l) {
                    final id = l['land_id'] is int
                        ? l['land_id'] as int
                        : int.tryParse(l['land_id']?.toString() ?? '');
                    return DropdownMenuItem<int?>(
                      value: id,
                      child: Text(
                        l['land_name']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _lands.isEmpty
                      ? null
                      : (v) {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _assignments[node.firebaseId] = v,
                          );
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final allAssigned =
        _foundNodes.isNotEmpty && _assignedCount == _foundNodes.length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _saving || !allAssigned ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            disabledBackgroundColor: AppTheme.divider,
            disabledForegroundColor: AppTheme.textSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  allAssigned ? Icons.check_rounded : Icons.lock_outline,
                  color: allAssigned ? Colors.white : AppTheme.textSecondary,
                  size: 20,
                ),
          label: Text(
            _saving
                ? 'A guardar…'
                : allAssigned
                    ? 'Guardar associações'
                    : 'Falta atribuir ${_foundNodes.length - _assignedCount} sensor(es)',
            style: TextStyle(
              color: allAssigned ? Colors.white : AppTheme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ── Done ──────────────────────────────────────────────────

  Widget _buildDone() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.primary,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sensores associados!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_foundNodes.length} sensor(es) ligado(s) à exploração.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _close,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
                label: const Text(
                  'Ver sensores',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  _done = false;
                  _foundNodes = [];
                  _assignments.clear();
                  _codeCtrl.clear();
                  _lastSearchedCode = null;
                });
              },
              child: const Text(
                'Associar mais sensores',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Sub-widgets
// ══════════════════════════════════════════════════════════

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _step(0, 'Procurar', Icons.search_rounded),
        _connector(0),
        _step(1, 'Atribuir', Icons.terrain_rounded),
        _connector(1),
        _step(2, 'Concluir', Icons.check_rounded),
      ],
    );
  }

  Widget _step(int index, String label, IconData icon) {
    final active = currentStep >= index;
    final current = currentStep == index;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: active ? AppTheme.primary : AppTheme.divider,
              shape: BoxShape.circle,
              boxShadow: current
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: active ? Colors.white : AppTheme.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _connector(int afterIndex) {
    final active = currentStep > afterIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: SizedBox(
        width: 24,
        child: Container(
          height: 2,
          color: active ? AppTheme.primary : AppTheme.divider,
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final VoidCallback onSearch;

  const _SearchCard({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código do gateway',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Está na etiqueta do dispositivo',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  style: const TextStyle(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'V4F-XXXX-XXXX',
                    hintStyle: const TextStyle(
                      color: Color(0xFFBDBDBD),
                      letterSpacing: 1.2,
                    ),
                    filled: true,
                    fillColor: AppTheme.background,
                    prefixIcon: const Icon(
                      Icons.tag,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: searching ? null : onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(60, 54),
                  fixedSize: const Size(60, 54),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOnline;
  const _StatusBadge({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppTheme.primary : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
