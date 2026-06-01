import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/services/local_database.dart';
import '../../../core/services/offline_mutation.dart';
import '../../../core/services/offline_read.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../../shared/theme/app_theme.dart';

/// Mostra o popup de criação de observação.
/// Retorna `true` se foi criada com sucesso.
Future<bool?> showCreateObservationDialog(
  BuildContext context, {
  int? preselectedLandId,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _CreateObservationDialog(preselectedLandId: preselectedLandId),
  );
}

class _CreateObservationDialog extends StatefulWidget {
  final int? preselectedLandId;
  const _CreateObservationDialog({this.preselectedLandId});

  @override
  State<_CreateObservationDialog> createState() => _CreateObservationDialogState();
}

class _CreateObservationDialogState extends State<_CreateObservationDialog> {
  final _api = ApiService();
  final _textController = TextEditingController();
  final _estadoFenController = TextEditingController();
  final _armadilhaController = TextEditingController();
  final _qtController = TextEditingController();

  int? _selectedLandId;
  int? _selectedYieldId;
  int? _selectedActivityId;
  String? _selectedPragaFungo;

  List<dynamic> _lands = [];
  List<dynamic> _yields = [];
  List<dynamic> _activities = [];
  bool _isLoadingLands = true;
  bool _isLoadingYields = false;
  bool _isLoadingActivities = false;
  bool _isSubmitting = false;

  // Fotos (múltiplas)
  final List<XFile> _pickedPhotos = [];

  // GPS
  String? _gpsCoords;
  bool _isLoadingGps = false;

  static const List<Map<String, String>> _pragaFungoOptions = [
    {'value': 'praga',    'label': 'Praga'},
    {'value': 'fungo',    'label': 'Fungo'},
    {'value': 'virus',    'label': 'Vírus'},
    {'value': 'bacteria', 'label': 'Bactéria'},
    {'value': 'outro',    'label': 'Outro'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLandId = widget.preselectedLandId;
    _loadLands();
    _captureGps();
  }

  @override
  void dispose() {
    _textController.dispose();
    _estadoFenController.dispose();
    _armadilhaController.dispose();
    _qtController.dispose();
    super.dispose();
  }

  // ── GPS ──────────────────────────────────────────────────

  Future<void> _captureGps() async {
    setState(() => _isLoadingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingGps = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _gpsCoords = '${position.latitude},${position.longitude}';
          _isLoadingGps = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  // ── Foto ────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Adicionar foto'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const ListTile(
              leading: Icon(Icons.camera_alt_outlined),
              title: Text('Câmara'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const ListTile(
              leading: Icon(Icons.photo_library_outlined),
              title: Text('Galeria'),
            ),
          ),
        ],
      ),
    );
    if (source == null) return;
    final xFile = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (xFile != null && mounted) {
      setState(() => _pickedPhotos.add(xFile));
    }
  }

  // ── Dados ───────────────────────────────────────────────

  Future<void> _loadLands() async {
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isLoadingLands = false); return; }
    final result = await OfflineRead.list(
      cacheKey: 'lands:farm_${farm.farmId}',
      apiCall: () => _api.get(
        AppConstants.lands,
        params: {'farm_id': farm.farmId.toString()},
      ),
    );
    if (!mounted) return;
    setState(() { _lands = result.items; _isLoadingLands = false; });
    if (_selectedLandId != null) {
      _loadYieldsForLand(_selectedLandId!);
      _loadActivitiesForLand(_selectedLandId!);
    }
  }

  Future<void> _loadYieldsForLand(int landId) async {
    setState(() { _isLoadingYields = true; _selectedYieldId = null; _yields = []; });
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isLoadingYields = false); return; }
    final result = await OfflineRead.list(
      cacheKey: 'yields:farm_${farm.farmId}:land_$landId',
      apiCall: () => _api.get(
        AppConstants.yields,
        params: {'farm_id': farm.farmId.toString(), 'land_id': landId.toString()},
      ),
    );
    if (!mounted) return;
    setState(() { _yields = result.items; _isLoadingYields = false; });
  }

  Future<void> _loadActivitiesForLand(int landId) async {
    setState(() {
      _isLoadingActivities = true;
      _selectedActivityId = null;
      _activities = [];
    });
    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isLoadingActivities = false); return; }
    final result = await OfflineRead.list(
      cacheKey: 'activities:farm_${farm.farmId}:land_${landId}:status_0',
      apiCall: () => _api.get(
        AppConstants.activities,
        params: {
          'farm_id': farm.farmId.toString(),
          'land_id': landId.toString(),
          'status': '0',
        },
      ),
    );
    if (!mounted) return;
    setState(() { _activities = result.items; _isLoadingActivities = false; });
  }

  // ── Submit ──────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedLandId == null || _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preenche o terreno e a descrição.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) { setState(() => _isSubmitting = false); return; }

    final clientUuid = UuidHelper.v4();
    final photoPaths = _pickedPhotos.map((p) => p.path).toList();

    // Payload "API-puro" (sem campos privados)
    final apiPayload = <String, dynamic>{
      'farm': farm.farmId,
      'land': _selectedLandId,
      'observation_text': _textController.text.trim(),
      if (_selectedYieldId != null) 'yield_id': _selectedYieldId,
      if (_selectedPragaFungo != null) 'praga_fungo': _selectedPragaFungo,
      if (_estadoFenController.text.trim().isNotEmpty)
        'estado_fenologico': _estadoFenController.text.trim(),
      if (_armadilhaController.text.trim().isNotEmpty)
        'numero_armadilha': _armadilhaController.text.trim(),
      if (_qtController.text.trim().isNotEmpty)
        'qt_detetada': double.tryParse(_qtController.text.trim()),
      if (_gpsCoords != null) 'observation_gps': _gpsCoords,
    };

    // Payload da queue: inclui metadados privados para o replay
    final queueData = <String, dynamic>{
      ...apiPayload,
      'client_uuid': clientUuid,
      if (photoPaths.isNotEmpty) '_photo_paths': photoPaths,
      if (_selectedActivityId != null)
        '_link_activity_id': _selectedActivityId,
    };

    final result = await OfflineMutation.run(
      apiCall: () async {
        // Online → criar + uploads + link atividade tudo aqui.
        final response =
            await _api.post(AppConstants.observations, data: apiPayload);
        final obsId = response.data['observation_id'] as int;
        for (final photo in _pickedPhotos) {
          try {
            final formData = FormData.fromMap({
              'photo': await MultipartFile.fromFile(
                photo.path,
                filename: photo.name,
              ),
            });
            await _api.post(
              AppConstants.observationImageUpload(obsId),
              data: formData,
            );
          } catch (_) {
            // Foto falhada não impede o sucesso da observação
          }
        }
        if (_selectedActivityId != null) {
          try {
            await _api.patch(
              AppConstants.activityDetail(_selectedActivityId!),
              data: {'observation': obsId},
            );
          } catch (_) {}
        }
        return response;
      },
      operationType: 'create_observation',
      queueData: queueData,
      applyOptimistic: () async {
        await LocalDatabase.appendLocalWrite(
          entityType: 'observation',
          parentId: farm.farmId,
          clientUuid: clientUuid,
          data: {
            ...apiPayload,
            'land_id': _selectedLandId,
            'farm_id': farm.farmId,
            'created_at': DateTime.now().toIso8601String(),
          },
          photoPath: photoPaths.isNotEmpty ? photoPaths.first : null,
        );
      },
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Erro ao criar observação.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    context.read<SyncProvider>().refreshCounts();
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.queued
            ? 'Observação guardada offline — sincroniza quando voltares online.'
            : 'Observação registada.'),
        backgroundColor: result.queued
            ? const Color(0xFF7B1FA2)
            : AppTheme.primary,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Nova Observação',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.divider),

            // Conteúdo
            Flexible(
              child: _isLoadingLands
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Terreno
                          const _Label(text: 'Terreno *'),
                          const SizedBox(height: 6),
                          _buildDropdown<int>(
                            hint: 'Seleciona um terreno',
                            value: _selectedLandId,
                            items: _lands.map((l) => DropdownMenuItem<int>(
                              value: l['land_id'] as int,
                              child: Text(l['land_name']?.toString() ?? ''),
                            )).toList(),
                            onChanged: (v) {
                              setState(() => _selectedLandId = v);
                              if (v != null) {
                                _loadYieldsForLand(v);
                                _loadActivitiesForLand(v);
                              }
                            },
                          ),

                          // Cultura (yield)
                          if (_yields.isNotEmpty || _isLoadingYields) ...[
                            const SizedBox(height: 16),
                            const _Label(text: 'Cultura'),
                            const SizedBox(height: 6),
                            _isLoadingYields
                                ? const _MiniLoader()
                                : _buildDropdown<int>(
                                    hint: 'Seleciona uma cultura (opcional)',
                                    value: _selectedYieldId,
                                    items: _yields.map((y) => DropdownMenuItem<int>(
                                      value: y['yield_id'] as int,
                                      child: Text(y['yield_name']?.toString() ?? ''),
                                    )).toList(),
                                    onChanged: (v) => setState(() => _selectedYieldId = v),
                                  ),
                          ],

                          // Atividade associada
                          if (_activities.isNotEmpty || _isLoadingActivities) ...[
                            const SizedBox(height: 16),
                            const _Label(text: 'Atividade associada'),
                            const SizedBox(height: 6),
                            _isLoadingActivities
                                ? const _MiniLoader()
                                : _buildDropdown<int>(
                                    hint: 'Associar a uma atividade (opcional)',
                                    value: _selectedActivityId,
                                    items: _activities.map((a) => DropdownMenuItem<int>(
                                      value: a['activity_id'] as int,
                                      child: Text(a['activity_name']?.toString() ?? ''),
                                    )).toList(),
                                    onChanged: (v) => setState(() => _selectedActivityId = v),
                                  ),
                          ],

                          const SizedBox(height: 16),

                          // Descrição
                          const _Label(text: 'Descrição *'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: 'Descreve o que observaste no campo...',
                            ),
                            maxLines: 4,
                            minLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 16),

                          // Fotos
                          const _Label(text: 'Fotos'),
                          const SizedBox(height: 8),
                          _buildPhotoSelector(),

                          const SizedBox(height: 16),

                          // Praga/Fungo
                          const _Label(text: 'Tipo de problema'),
                          const SizedBox(height: 8),
                          _buildPragaFungoSelector(),

                          const SizedBox(height: 16),

                          // Estado fenológico
                          const _Label(text: 'Estado fenológico'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _estadoFenController,
                            decoration: const InputDecoration(
                              hintText: 'Ex: Floração, Maturação...',
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 16),

                          // Armadilha + Quantidade
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _Label(text: 'N.o armadilha'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _armadilhaController,
                                      decoration: const InputDecoration(
                                        hintText: 'Ex: A12',
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
                                    const _Label(text: 'Qt. detetada'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _qtController,
                                      decoration: const InputDecoration(
                                        hintText: '0.00',
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // GPS
                          _buildGpsChip(),

                          const SizedBox(height: 24),

                          // Botão
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                                : const Text('Registar observação'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets auxiliares ──────────────────────────────────

  Widget _buildPhotoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pickedPhotos.isNotEmpty) ...[
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pickedPhotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_pickedPhotos[i].path),
                        height: 110,
                        width: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _pickedPhotos.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider, style: BorderStyle.solid),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined, color: AppTheme.textSecondary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _pickedPhotos.isEmpty
                        ? 'Tirar foto ou escolher da galeria'
                        : 'Adicionar mais fotos',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGpsChip() {
    if (_isLoadingGps) {
      return Row(
        children: [
          const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('A obter localização...',
              style: TextStyle(fontSize: 12,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7))),
        ],
      );
    }
    if (_gpsCoords != null) {
      return Row(
        children: [
          const Icon(Icons.location_on, color: AppTheme.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_gpsCoords!,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          GestureDetector(
            onTap: _captureGps,
            child: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 16),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: _captureGps,
      child: Row(
        children: [
          Icon(Icons.location_off_outlined, color: AppTheme.textSecondary.withValues(alpha: 0.5), size: 16),
          const SizedBox(width: 6),
          Text('GPS não disponível — toca para tentar',
              style: TextStyle(fontSize: 12,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildPragaFungoSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _pragaFungoOptions.map((opt) {
        final selected = _selectedPragaFungo == opt['value'];
        return GestureDetector(
          onTap: () => setState(() {
            _selectedPragaFungo = selected ? null : opt['value'];
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.divider,
              ),
            ),
            child: Text(
              opt['label']!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint,
            style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14)),
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
  );
}

class _MiniLoader extends StatelessWidget {
  const _MiniLoader();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Center(
      child: SizedBox(width: 20, height: 20,
        child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
    ),
  );
}
