import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/farm_provider.dart';
import '../../../shared/theme/app_theme.dart';

/// Ecrã de mapa onde o utilizador toca para marcar vértices de um polígono.
/// Devolve um GeoJSON `Polygon` via `Navigator.pop(context, geoJsonString)`.
class DrawPolygonScreen extends StatefulWidget {
  const DrawPolygonScreen({super.key});

  @override
  State<DrawPolygonScreen> createState() => _DrawPolygonScreenState();
}

class _DrawPolygonScreenState extends State<DrawPolygonScreen> {
  MapboxMap? _mapboxMap;
  final List<Position> _points = [];

  static const String _sourceId = 'draw-polygon-source';
  static const String _fillLayerId = 'draw-polygon-fill';
  static const String _lineLayerId = 'draw-polygon-line';
  static const String _pointsSourceId = 'draw-points-source';
  static const String _pointsLayerId = 'draw-points-layer';

  CameraOptions _initialCamera() {
    final farm = context.read<FarmProvider>().selectedFarm;
    double lat = 39.5, lng = -8.0, zoom = 7.0;
    if (farm?.farmGps != null) {
      final parts = farm!.farmGps!.split(',');
      if (parts.length >= 2) {
        lat = double.tryParse(parts[0].trim()) ?? lat;
        lng = double.tryParse(parts[1].trim()) ?? lng;
        zoom = 15.0;
      }
    }
    return CameraOptions(
      center: Point(coordinates: Position(lng, lat)),
      zoom: zoom,
    );
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // Tentar centrar na localização do utilizador
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.high),
      );
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 17.0,
        ),
        MapAnimationOptions(duration: 500),
      );
    } catch (_) {
      // Usar a câmara inicial (farm GPS)
    }

    // Listener de tap
    map.setOnMapTapListener(_onMapTap);
  }

  void _onMapTap(MapContentGestureContext gesture) {
    final coord = gesture.point.coordinates;
    setState(() {
      _points.add(Position(coord.lng, coord.lat));
    });
    _updateMapOverlays();
  }

  Future<void> _updateMapOverlays() async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;

    // Construir coordenadas para o polígono (fechar o anel se >= 3 pontos)
    final coords = _points.map((p) => [p.lng, p.lat]).toList();
    if (coords.length >= 3) {
      coords.add([_points.first.lng, _points.first.lat]); // fechar
    }

    // GeoJSON para o polígono (fill + line)
    final polygonGeoJson = jsonEncode({
      'type': 'Feature',
      'geometry': coords.length >= 4
          ? {'type': 'Polygon', 'coordinates': [coords]}
          : {'type': 'LineString', 'coordinates': coords},
      'properties': {},
    });

    // GeoJSON para os pontos (vértices)
    final pointFeatures = _points.asMap().entries.map((e) => {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [e.value.lng, e.value.lat],
          },
          'properties': {'index': e.key},
        }).toList();
    final pointsGeoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': pointFeatures,
    });

    // Atualizar ou criar source + layers para o polígono
    try {
      await style.setStyleSourceProperty(
          _sourceId, 'data', polygonGeoJson);
    } catch (_) {
      await style.addSource(GeoJsonSource(id: _sourceId, data: polygonGeoJson));
      if (coords.length >= 4) {
        await style.addLayer(FillLayer(
          id: _fillLayerId,
          sourceId: _sourceId,
          fillColor: const Color(0x402E7D32).toARGB32(),
        ));
      }
      await style.addLayer(LineLayer(
        id: _lineLayerId,
        sourceId: _sourceId,
        lineColor: AppTheme.primary.toARGB32(),
        lineWidth: 2.5,
      ));
    }

    // Se acabámos de atingir 3 pontos, adicionar fill layer
    if (coords.length == 4) {
      try {
        await style.addLayerAt(
          FillLayer(
            id: _fillLayerId,
            sourceId: _sourceId,
            fillColor: const Color(0x402E7D32).toARGB32(),
          ),
          LayerPosition(below: _lineLayerId),
        );
      } catch (_) {}
    }

    // Atualizar ou criar source + layer para os pontos
    try {
      await style.setStyleSourceProperty(
          _pointsSourceId, 'data', pointsGeoJson);
    } catch (_) {
      await style.addSource(
          GeoJsonSource(id: _pointsSourceId, data: pointsGeoJson));
      await style.addLayer(CircleLayer(
        id: _pointsLayerId,
        sourceId: _pointsSourceId,
        circleRadius: 7.0,
        circleColor: Colors.white.toARGB32(),
        circleStrokeColor: AppTheme.primary.toARGB32(),
        circleStrokeWidth: 2.5,
      ));
    }
  }

  void _undoLast() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
    _updateMapOverlays();
  }

  void _clearAll() {
    if (_points.isEmpty) return;
    setState(() => _points.clear());
    _updateMapOverlays();
  }

  void _confirm() {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca pelo menos 3 pontos para formar um polígono.')),
      );
      return;
    }
    final coords = _points.map((p) => [p.lng.toDouble(), p.lat.toDouble()]).toList();
    coords.add([_points.first.lng.toDouble(), _points.first.lat.toDouble()]);
    final geoJson = jsonEncode({
      'type': 'Polygon',
      'coordinates': [coords],
    });
    Navigator.pop(context, geoJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desenhar terreno'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Desfazer último ponto',
              onPressed: _undoLast,
            ),
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpar tudo',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            cameraOptions: _initialCamera(),
            styleUri: MapboxStyles.SATELLITE_STREETS,
            onMapCreated: _onMapCreated,
          ),

          // Instrução no topo
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _points.isEmpty
                          ? 'Toca no mapa para marcar os vértices do terreno'
                          : '${_points.length} ponto${_points.length == 1 ? '' : 's'} marcado${_points.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botão confirmar
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _points.length >= 3 ? _confirm : null,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Confirmar polígono'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor: Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
