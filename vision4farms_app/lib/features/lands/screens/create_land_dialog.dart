import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/local_database.dart';
import '../../../core/services/offline_mutation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../../shared/theme/app_theme.dart';
import 'draw_polygon_screen.dart';

class CreateLandDialog extends StatefulWidget {
  const CreateLandDialog({super.key});

  @override
  State<CreateLandDialog> createState() => _CreateLandDialogState();
}

class _CreateLandDialogState extends State<CreateLandDialog> {
  final _api        = ApiService();
  final _nameCtrl   = TextEditingController();
  final _sizeCtrl   = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  bool _submitting  = false;
  bool _locatingGps = false;
  String? _error;
  Position? _gpsPosition;
  String? _polygonGeoJson; // GeoJSON Polygon string

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sizeCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _getGpsLocation() async {
    setState(() { _locatingGps = true; _error = null; });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _error = 'Permissão de localização negada.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Permissão de localização permanentemente negada. Ativa nas definições.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() => _gpsPosition = pos);
    } catch (_) {
      setState(() => _error = 'Não foi possível obter a localização.');
    } finally {
      if (mounted) setState(() => _locatingGps = false);
    }
  }

  Future<void> _openDrawPolygon() async {
    final geoJson = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const DrawPolygonScreen()),
    );
    if (geoJson != null && mounted) {
      setState(() {
        _polygonGeoJson = geoJson;
        final area = _calculatePolygonAreaHa(geoJson);
        if (area != null) {
          _sizeCtrl.text = area.toStringAsFixed(3);
        }
      });
    }
  }

  /// Calcula a área de um polígono GeoJSON em hectares usando a fórmula
  /// do Surveyor (Shoelace) com projeção esférica simplificada.
  double? _calculatePolygonAreaHa(String geoJsonStr) {
    try {
      final parsed = jsonDecode(geoJsonStr) as Map<String, dynamic>;
      final ring = (parsed['coordinates'] as List).first as List;
      if (ring.length < 4) return null; // mínimo triângulo + fecho

      // Converter graus para metros (projeção local)
      final latRef = (ring[0] as List)[1] as num;
      const double deg2rad = 3.141592653589793 / 180.0;
      final metersPerDegLat = 111320.0;
      final metersPerDegLng = 111320.0 * (deg2rad * latRef.toDouble()).abs() < 1.5
          ? 111320.0 * _cos(latRef.toDouble() * deg2rad)
          : 111320.0 * _cos(latRef.toDouble() * deg2rad);

      // Shoelace formula em metros
      double area = 0;
      for (int i = 0; i < ring.length - 1; i++) {
        final x1 = ((ring[i] as List)[0] as num).toDouble() * metersPerDegLng;
        final y1 = ((ring[i] as List)[1] as num).toDouble() * metersPerDegLat;
        final x2 = ((ring[i + 1] as List)[0] as num).toDouble() * metersPerDegLng;
        final y2 = ((ring[i + 1] as List)[1] as num).toDouble() * metersPerDegLat;
        area += (x1 * y2 - x2 * y1);
      }
      area = area.abs() / 2.0;
      return area / 10000.0; // m² → ha
    } catch (_) {
      return null;
    }
  }

  static double _cos(double radians) => math.cos(radians);

  int _polygonVertexCount() {
    if (_polygonGeoJson == null) return 0;
    try {
      final parsed = jsonDecode(_polygonGeoJson!) as Map<String, dynamic>;
      final coords = (parsed['coordinates'] as List).first as List;
      return coords.length - 1; // -1 because the ring is closed
    } catch (_) {
      return 0;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });

    final farm = context.read<FarmProvider>().selectedFarm;
    if (farm == null) {
      setState(() {
        _submitting = false;
        _error = 'Sem exploração selecionada.';
      });
      return;
    }

    double? size;
    if (_sizeCtrl.text.isNotEmpty) {
      size = double.tryParse(_sizeCtrl.text.replaceAll(',', '.'));
    }

    final clientUuid = UuidHelper.v4();
    final payload = <String, dynamic>{
      'client_uuid':  clientUuid,
      'land_name':    _nameCtrl.text.trim(),
      'current_farm': farm.farmId,
      if (_locationCtrl.text.isNotEmpty)
        'land_location': _locationCtrl.text.trim(),
      if (size != null) 'land_size': size,
      if (_gpsPosition != null)
        'land_gps': '${_gpsPosition!.latitude},${_gpsPosition!.longitude}',
      if (_polygonGeoJson != null) 'land_sketch': _polygonGeoJson,
      'land_status': 1,
    };

    final result = await OfflineMutation.run(
      apiCall: () => _api.post(AppConstants.landsCreate, data: payload),
      operationType: 'create_land',
      queueData: payload,
      applyOptimistic: () async {
        await LocalDatabase.appendLocalWrite(
          entityType: 'land',
          parentId: farm.farmId,
          clientUuid: clientUuid,
          data: payload,
        );
      },
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.success) {
      setState(() => _error = result.errorMessage ?? 'Erro ao criar terreno.');
      return;
    }

    // Atualiza contadores da fila para o banner/UI
    context.read<SyncProvider>().refreshCounts();

    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.queued
            ? 'Terreno criado offline — sincroniza quando voltares online.'
            : 'Terreno criado com sucesso!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Expanded(
                    child: Text('Novo Terreno',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 22),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Nome *
              _FieldLabel(label: 'Nome'),
              const SizedBox(height: 6),
              _InputField(
                controller: _nameCtrl,
                hint: 'Insira o nome',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),

              const SizedBox(height: 16),

              // Localização
              _FieldLabel(label: 'Localização'),
              const SizedBox(height: 6),
              _InputField(
                controller: _locationCtrl,
                hint: 'Ex: Ribatejo, Lisboa...',
              ),

              const SizedBox(height: 16),

              // Coordenadas GPS
              _FieldLabel(label: 'Coordenadas GPS'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Icon(
                      _gpsPosition != null ? Icons.location_on : Icons.location_off_outlined,
                      color: _gpsPosition != null ? AppTheme.primary : AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _gpsPosition != null
                            ? '${_gpsPosition!.latitude.toStringAsFixed(6)}, ${_gpsPosition!.longitude.toStringAsFixed(6)}'
                            : 'Sem coordenadas definidas',
                        style: TextStyle(
                          fontSize: 13,
                          color: _gpsPosition != null
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (_gpsPosition != null)
                      GestureDetector(
                        onTap: () => setState(() => _gpsPosition = null),
                        child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _locatingGps ? null : _getGpsLocation,
                  icon: _locatingGps
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(_gpsPosition != null ? 'Atualizar localização' : 'Usar localização atual'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Polígono (desenhar no mapa)
              _FieldLabel(label: 'Polígono do terreno'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    Icon(
                      _polygonGeoJson != null ? Icons.check_circle : Icons.crop_square_outlined,
                      color: _polygonGeoJson != null ? AppTheme.primary : AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _polygonGeoJson != null
                            ? 'Polígono definido (${_polygonVertexCount()} vértices)'
                            : 'Sem polígono definido',
                        style: TextStyle(
                          fontSize: 13,
                          color: _polygonGeoJson != null
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (_polygonGeoJson != null)
                      GestureDetector(
                        onTap: () => setState(() => _polygonGeoJson = null),
                        child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _openDrawPolygon,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(_polygonGeoJson != null ? 'Redesenhar no mapa' : 'Desenhar no mapa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tamanho (após polígono para mostrar valor calculado)
              _FieldLabel(label: 'Tamanho do terreno'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _sizeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null) return 'Valor inválido';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Insira o tamanho do terreno',
                  hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
                  suffixText: 'ha',
                  suffixStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.error),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ],

              const SizedBox(height: 24),

              // Botão
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Adicionar',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ],
                        ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary),
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
    ),
  );
}