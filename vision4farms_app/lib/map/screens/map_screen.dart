import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/models/land_model.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/providers/map_provider.dart';
import '../../core/services/api_service.dart';
import '../../shared/theme/app_theme.dart';
import '../widgets/map_filter_chips.dart';
import '../widgets/land_bottom_sheet.dart';
import '../widgets/map_activity_badge.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  bool _mapReady = false;
  late final ApiService _apiService;

  static const String _polygonLayerId   = 'lands-polygon-layer';
  static const String _polygonFillLayerId = 'lands-fill-layer';
  static const String _polygonSourceId  = 'lands-source';

  // Badges: posição em ecrã calculada a cada frame
  final Map<int, ScreenCoordinate> _badgePositions = {};

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final farmProvider = context.read<FarmProvider>();
    final mapProvider  = context.read<MapProvider>();
    if (farmProvider.selectedFarm != null) {
      await mapProvider.loadMapData(farmProvider.selectedFarm!.farmId);
      if (_mapReady) {
        await _renderOverlays();
        await _updateBadgePositions();
      }
    }
  }

  String _getStyleUri(String style) {
    switch (style) {
      case 'satellite': return MapboxStyles.SATELLITE;
      case 'hybrid':    return MapboxStyles.SATELLITE_STREETS;
      default:          return MapboxStyles.SATELLITE_STREETS;
    }
  }

  CameraOptions _initialCamera() {
    final farm = context.read<FarmProvider>().selectedFarm;
    double lat = 39.5, lng = -8.0, zoom = 7.0;
    if (farm?.farmGps != null) {
      final parts = farm!.farmGps!.split(',');
      if (parts.length >= 2) {
        lat  = double.tryParse(parts[0].trim()) ?? lat;
        lng  = double.tryParse(parts[1].trim()) ?? lng;
        zoom = 13.0;
      }
    }
    return CameraOptions(
      center: Point(coordinates: Position(lng, lat)),
      zoom: zoom,
      pitch: 0,
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    mapboxMap.logo.updateSettings(LogoSettings(marginBottom: 4, marginLeft: 4));
    mapboxMap.attribution.updateSettings(AttributionSettings(marginBottom: 4, marginRight: 4));
    mapboxMap.compass.updateSettings(CompassSettings(marginTop: 80, marginRight: 12));
    mapboxMap.scaleBar.updateSettings(ScaleBarSettings(isMetricUnits: true, marginBottom: 8, marginLeft: 8));

    // Atualizar badges quando o mapa se move
    mapboxMap.setOnMapMoveListener((_) => _updateBadgePositions());

    setState(() => _mapReady = true);

    final mapProvider = context.read<MapProvider>();
    if (mapProvider.allLands.isNotEmpty) {
      _renderOverlays();
      _updateBadgePositions();
    }
  }

  Future<void> _updateBadgePositions() async {
    if (_mapboxMap == null) return;
    final mapProvider = context.read<MapProvider>();
    final lands = mapProvider.filteredLands
        .where((item) => item.hasActivities && item.land.hasEffectiveCoordinates)
        .toList();

    final Map<int, ScreenCoordinate> newPositions = {};
    for (final item in lands) {
      try {
        final screen = await _mapboxMap!.pixelForCoordinate(
          Point(coordinates: Position(item.land.effectiveLongitude!, item.land.effectiveLatitude!)),
        );
        newPositions[item.land.landId] = screen;
      } catch (_) {}
    }
    if (mounted) setState(() => _badgePositions
      ..clear()
      ..addAll(newPositions));
  }

  Future<void> _renderOverlays() async {
    if (_mapboxMap == null) return;
    final lands = context.read<MapProvider>().allLands;
    final features = <Map<String, dynamic>>[];

    for (final item in lands) {
      if (!item.land.hasPolygon) continue;
      final geoJson = item.land.geoJson!;
      Map<String, dynamic> feature;
      if (geoJson['type'] == 'Feature') {
        feature = Map<String, dynamic>.from(geoJson);
        feature['properties'] = Map<String, dynamic>.from(feature['properties'] ?? {});
      } else {
        feature = {'type': 'Feature', 'geometry': geoJson, 'properties': {}};
      }
      feature['properties']['land_id']    = item.land.landId;
      feature['properties']['land_name']  = item.land.landName;
      feature['properties']['has_overdue'] = item.hasOverdue;
      features.add(feature);
    }

    final featureCollection = {'type': 'FeatureCollection', 'features': features};

    try {
      final style = await _mapboxMap!.style;
      if (await style.styleSourceExists(_polygonSourceId)) {
        if (await style.styleLayerExists(_polygonFillLayerId)) await style.removeStyleLayer(_polygonFillLayerId);
        if (await style.styleLayerExists(_polygonLayerId))     await style.removeStyleLayer(_polygonLayerId);
        await style.removeStyleSource(_polygonSourceId);
      }

      await style.addSource(GeoJsonSource(
        id: _polygonSourceId,
        data: jsonEncode(featureCollection),
      ));

      await style.addLayer(FillLayer(
        id: _polygonFillLayerId,
        sourceId: _polygonSourceId,
        fillOpacity: 0.35,
        fillColor: 0xFF2E7D32,
      ));

      await style.addLayer(LineLayer(
        id: _polygonLayerId,
        sourceId: _polygonSourceId,
        lineColor: 0xFF1B5E20,
        lineWidth: 2.0,
        lineOpacity: 0.9,
      ));
    } catch (e) {
      debugPrint('Erro ao renderizar overlays: $e');
    }
  }

  void _onTapLand(LandMapItem item) {
    context.read<MapProvider>().selectLand(item.land);
    if (item.land.hasEffectiveCoordinates) {
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(item.land.effectiveLongitude!, item.land.effectiveLatitude!)),
          zoom: 15.0,
          pitch: 20,
        ),
        MapAnimationOptions(duration: 800),
      );
    }
    _showLandBottomSheet(item);
  }

  void _showLandBottomSheet(LandMapItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LandBottomSheet(
        item: item,
        apiService: _apiService,
        onClose: () {
          Navigator.pop(ctx);
          context.read<MapProvider>().clearSelection();
        },
      ),
    );
  }

  void _centerOnAllLands() {
    final lands = context.read<MapProvider>().allLands
        .where((l) => l.land.hasEffectiveCoordinates).toList();
    if (lands.isEmpty || _mapboxMap == null) return;

    if (lands.length == 1) {
      _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lands[0].land.effectiveLongitude!, lands[0].land.effectiveLatitude!)),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 600),
      );
      return;
    }

    double minLat = lands[0].land.effectiveLatitude!, maxLat = lands[0].land.effectiveLatitude!;
    double minLng = lands[0].land.effectiveLongitude!, maxLng = lands[0].land.effectiveLongitude!;
    for (final item in lands) {
      if (item.land.effectiveLatitude!  < minLat) minLat = item.land.effectiveLatitude!;
      if (item.land.effectiveLatitude!  > maxLat) maxLat = item.land.effectiveLatitude!;
      if (item.land.effectiveLongitude! < minLng) minLng = item.land.effectiveLongitude!;
      if (item.land.effectiveLongitude! > maxLng) maxLng = item.land.effectiveLongitude!;
    }

    _mapboxMap!.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng, minLat)),
        northeast: Point(coordinates: Position(maxLng, maxLat)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 120, left: 40, bottom: 200, right: 40),
      null, null, null, null,
    ).then((camera) => _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 800)));
  }

  void _handleMapTap(MapContentGestureContext gestureContext) async {
    if (_mapboxMap == null) return;

    // Usar a posição de ecrã do gesto
    final x = gestureContext.touchPosition.x;
    final y = gestureContext.touchPosition.y;

    final features = await _mapboxMap!.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(ScreenCoordinate(x: x, y: y)),
      RenderedQueryOptions(layerIds: [_polygonFillLayerId]),
    );

    if (features.isNotEmpty) {
      final props   = features.first?.queriedFeature.feature['properties'] as Map?;
      final landId  = props?['land_id'] as int?;
      if (landId != null) {
        final item = context.read<MapProvider>().allLands
            .where((l) => l.land.landId == landId)
            .firstOrNull;
        if (item != null) _onTapLand(item);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider  = context.watch<MapProvider>();
    final farmProvider = context.watch<FarmProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // ── Mapa ────────────────────────────────────
          MapWidget(
            key: const ValueKey('mapbox-map'),
            styleUri: _getStyleUri(mapProvider.mapStyle),
            cameraOptions: _initialCamera(),
            onMapCreated: _onMapCreated,
            onTapListener: _handleMapTap,
            onStyleLoadedListener: (_) async {
              await _renderOverlays();
              await _updateBadgePositions();
            },
          ),

          // ── AppBar ───────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildMapAppBar(farmProvider, mapProvider),
          ),

          // ── Filtros ──────────────────────────────────
          Positioned(
            top: 100, left: 0, right: 0,
            child: MapFilterChips(
              activeFilter: mapProvider.activeFilter,
              onFilterChanged: mapProvider.setFilter,
            ),
          ),

          // ── Badges fixos (posição atualizada a cada move) ──
          if (_mapReady)
            ..._buildActivityBadges(mapProvider),

          // ── Loading ──────────────────────────────────
          if (mapProvider.isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),

          // ── Legenda ──────────────────────────────────
          Positioned(
            right: 12, bottom: 160,
            child: _LegendCard(
              totalLands:      mapProvider.totalLands,
              withActivities:  mapProvider.landsWithActivities,
              withOverdue:     mapProvider.landsWithOverdue,
            ),
          ),

          // ── Erro ─────────────────────────────────────
          if (mapProvider.errorMessage != null)
            Positioned(
              bottom: 100, left: 16, right: 16,
              child: _buildErrorBanner(mapProvider.errorMessage!),
            ),
        ],
      ),
    );
  }

  Widget _buildMapAppBar(FarmProvider farmProvider, MapProvider mapProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.65), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmProvider.selectedFarm?.farmName ?? 'Exploração',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${mapProvider.totalLands} terrenos · ${mapProvider.totalAreaHa.toStringAsFixed(2)} ha',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
              _MapIconButton(icon: Icons.my_location,  tooltip: 'Centrar', onTap: _centerOnAllLands),
              const SizedBox(width: 8),
              _MapIconButton(
                icon: mapProvider.mapStyle == 'satellite' ? Icons.layers : Icons.satellite_alt,
                tooltip: mapProvider.mapStyle == 'satellite' ? 'Modo híbrido' : 'Modo satélite',
                onTap: () async {
                mapProvider.toggleMapStyle();
                await _mapboxMap?.loadStyleURI(_getStyleUri(mapProvider.mapStyle));
              },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActivityBadges(MapProvider mapProvider) {
    final badges = <Widget>[];
    for (final item in mapProvider.filteredLands) {
      if (!item.hasActivities || !item.land.hasEffectiveCoordinates) continue;
      final pos = _badgePositions[item.land.landId];
      if (pos == null) continue;
      badges.add(Positioned(
        left: pos.x - 14,
        top:  pos.y - 14,
        child: MapActivityBadge(
          pendingCount: item.pendingActivities,
          overdueCount: item.overdueActivities,
          onTap: () => _onTapLand(item),
        ),
      ));
    }
    return badges;
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13))),
      ]),
    );
  }
}

// ── Botão de ícone ───────────────────────────────────────────

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _MapIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}

// ── Legenda ──────────────────────────────────────────────────

class _LegendCard extends StatelessWidget {
  final int totalLands, withActivities, withOverdue;
  const _LegendCard({required this.totalLands, required this.withActivities, required this.withOverdue});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendRow(color: AppTheme.primary, label: 'Normal',      count: totalLands - withOverdue),
        const SizedBox(height: 4),
        _LegendRow(color: AppTheme.warning, label: 'Com atrasos', count: withOverdue),
        if (withActivities > 0) ...[
          const Divider(height: 12),
          Text(
            '$withActivities terreno${withActivities != 1 ? 's' : ''}\ncom atividades',
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ],
    ),
  );
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _LegendRow({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          color: color.withOpacity(0.4),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text('$label ($count)', style: const TextStyle(fontSize: 11)),
    ],
  );
}