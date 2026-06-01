import 'dart:convert';

class LandModel {
  final int landId;
  final String landName;
  final String? landSlug;
  final String? landLocation;
  final String? landGps; // "lat,lng"
  final String? landSketch; // GeoJSON string
  final double? landSize;
  final String? landInclination;
  final String? landSunExposure;
  final String? landElevation;
  final String? landLevels;
  final int landWater;
  final String? landNotes;
  final int landStatus;
  final int? currentFarm;
  final String? createdAt;

  // Parsed coordinates
  double? get latitude {
    if (landGps == null) return null;
    final parts = landGps!.split(',');
    if (parts.length >= 2) return double.tryParse(parts[0].trim());
    return null;
  }

  double? get longitude {
    if (landGps == null) return null;
    final parts = landGps!.split(',');
    if (parts.length >= 2) return double.tryParse(parts[1].trim());
    return null;
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  // GeoJSON polygon (land_sketch)
  Map<String, dynamic>? get geoJson {
    if (landSketch == null || landSketch!.isEmpty) return null;
    try {
      return jsonDecode(landSketch!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool get hasPolygon => geoJson != null;

  // Centróide calculado a partir do polígono GeoJSON
  // Usado quando land_gps está vazio
  List<double>? get polygonCentroid {
    try {
      final geo = geoJson;
      if (geo == null) return null;
      List coords;
      if (geo['type'] == 'Polygon') {
        coords = geo['coordinates'][0] as List;
      } else if (geo['type'] == 'Feature') {
        final geom = geo['geometry'] as Map;
        coords = geom['coordinates'][0] as List;
      } else {
        return null;
      }
      double sumLat = 0, sumLng = 0;
      int count = 0;
      for (final c in coords) {
        sumLng += (c[0] as num).toDouble();
        sumLat += (c[1] as num).toDouble();
        count++;
      }
      if (count == 0) return null;
      return [sumLat / count, sumLng / count];
    } catch (_) {
      return null;
    }
  }

  // Coordenada efetiva: land_gps ou centróide do polígono
  double? get effectiveLatitude => latitude ?? polygonCentroid?[0];
  double? get effectiveLongitude => longitude ?? polygonCentroid?[1];
  bool get hasEffectiveCoordinates => effectiveLatitude != null && effectiveLongitude != null;

  LandModel({
    required this.landId,
    required this.landName,
    this.landSlug,
    this.landLocation,
    this.landGps,
    this.landSketch,
    this.landSize,
    this.landInclination,
    this.landSunExposure,
    this.landElevation,
    this.landLevels,
    this.landWater = 0,
    this.landNotes,
    this.landStatus = 1,
    this.currentFarm,
    this.createdAt,
  });

  factory LandModel.fromJson(Map<String, dynamic> json) => LandModel(
    landId: json['land_id'],
    landName: json['land_name'],
    landSlug: json['land_slug'],
    landLocation: json['land_location'],
    landGps: json['land_gps'],
    landSketch: json['land_sketch'],
    landSize: json['land_size'] != null ? double.tryParse(json['land_size'].toString()) : null,
    landInclination: json['land_inclination'],
    landSunExposure: json['land_sun_exposure'],
    landElevation: json['land_elevation'],
    landLevels: json['land_levels']?.toString(),
    landWater: int.tryParse(json['land_water']?.toString() ?? '0') ?? 0,
    landNotes: json['land_notes'],
    landStatus: json['land_status'] ?? 1,
    currentFarm: json['current_farm'],
    createdAt: json['created_at']?.toString(),
  );
}

// Modelo leve para o mapa (terreno + contagem de atividades)
class LandMapItem {
  final LandModel land;
  final int pendingActivities;
  final int overdueActivities;
  final int doneActivities;
  final List<String> activityTypes;
  final String? cropName;

  LandMapItem({
    required this.land,
    this.pendingActivities = 0,
    this.overdueActivities = 0,
    this.doneActivities = 0,
    this.activityTypes = const [],
    this.cropName,
  });

  int get totalPending => pendingActivities + overdueActivities;
  bool get hasActivities => totalPending > 0;
  bool get hasOverdue => overdueActivities > 0;
  bool get hasDone => doneActivities > 0;
  bool hasType(String type) => activityTypes.contains(type);
}