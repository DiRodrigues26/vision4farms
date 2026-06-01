// ══════════════════════════════════════════════════════════════
// Water — modelos para fontes de água, consumo e regas planeadas
// ══════════════════════════════════════════════════════════════

class WaterSourceType {
  final int waterTypeId;
  final String waterTypeName;

  WaterSourceType({required this.waterTypeId, required this.waterTypeName});

  factory WaterSourceType.fromJson(Map<String, dynamic> json) => WaterSourceType(
        waterTypeId: json['water_type_id'],
        waterTypeName: json['water_type_name'] ?? '',
      );
}

class WaterIrrigationMethod {
  final int waterIrrigationId;
  final String waterIrrigationName;

  WaterIrrigationMethod({
    required this.waterIrrigationId,
    required this.waterIrrigationName,
  });

  factory WaterIrrigationMethod.fromJson(Map<String, dynamic> json) =>
      WaterIrrigationMethod(
        waterIrrigationId: json['water_irrigation_id'],
        waterIrrigationName: json['water_irrigation_name'] ?? '',
      );
}

class WaterSource {
  final int waterSourceId;
  final int farmId;
  final String waterSourceName;
  final String? waterSourceSlug;
  final int waterTypeId;
  final String? waterTypeName;
  final String? locationDescription;
  final double? latitude;
  final double? longitude;
  final double? depthMeters;
  final double? capacity;
  final String? notes;
  final bool ownership;
  final bool hasCosts;
  final String? buildDate;
  final double? buildCost;
  final String? buildInvoice;
  final int status; // 1 = ativo, 0 = inativo
  final String? createdAt;

  WaterSource({
    required this.waterSourceId,
    required this.farmId,
    required this.waterSourceName,
    this.waterSourceSlug,
    required this.waterTypeId,
    this.waterTypeName,
    this.locationDescription,
    this.latitude,
    this.longitude,
    this.depthMeters,
    this.capacity,
    this.notes,
    this.ownership = true,
    this.hasCosts = false,
    this.buildDate,
    this.buildCost,
    this.buildInvoice,
    this.status = 1,
    this.createdAt,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  factory WaterSource.fromJson(Map<String, dynamic> json) => WaterSource(
        waterSourceId: json['water_source_id'],
        farmId: json['farm_id'],
        waterSourceName: json['water_source_name'] ?? '',
        waterSourceSlug: json['water_source_slug'],
        waterTypeId: json['water_type_id'] ?? 0,
        waterTypeName: json['water_type_name'],
        locationDescription: json['water_source_location_description'],
        latitude: _toDouble(json['water_source_latitude']),
        longitude: _toDouble(json['water_source_longitude']),
        depthMeters: _toDouble(json['water_source_depth_meters']),
        capacity: _toDouble(json['water_source_capacity']),
        notes: json['water_source_notes'],
        ownership: json['water_source_ownership'] == true ||
            json['water_source_ownership'] == 1,
        hasCosts: json['water_source_has_costs'] == true ||
            json['water_source_has_costs'] == 1,
        buildDate: json['water_source_build_date']?.toString(),
        buildCost: _toDouble(json['water_source_build_cost']),
        buildInvoice: json['water_source_build_invoice'],
        status: json['water_source_status'] ?? 1,
        createdAt: json['created_at']?.toString(),
      );
}

class WaterUsageLog {
  final int waterUsageId;
  final int waterSourceId;
  final int? landId;
  final String usageDate;
  final double volumeLiters;
  final double? cost;
  final int? method;
  final String? methodName;
  final String? purpose;
  final String? notes;
  final String? createdAt;

  WaterUsageLog({
    required this.waterUsageId,
    required this.waterSourceId,
    this.landId,
    required this.usageDate,
    required this.volumeLiters,
    this.cost,
    this.method,
    this.methodName,
    this.purpose,
    this.notes,
    this.createdAt,
  });

  factory WaterUsageLog.fromJson(Map<String, dynamic> json) => WaterUsageLog(
        waterUsageId: json['water_usage_id'],
        waterSourceId: json['water_source_id'],
        landId: json['land_id'],
        usageDate: json['water_usage_usage_date']?.toString() ?? '',
        volumeLiters: _toDouble(json['water_usage_volume_liters']) ?? 0,
        cost: _toDouble(json['water_usage_cost']),
        method: json['water_usage_method'],
        methodName: json['method_name'],
        purpose: json['water_usage_purpose'],
        notes: json['water_usage_notes'],
        createdAt: json['created_at']?.toString(),
      );
}

class WaterIrrigationPlan {
  final int plannedId;
  final int farmId;
  final int landId;
  final int? waterSourceId;
  final int? yieldId;
  final String plannedDate;
  final String? plannedTime;
  final int? durationMin;
  final double? volumeLiters;
  final int? method;
  final String? methodName;
  final int status; // 0=Planeada, 1=Executada, 2=Cancelada
  final String? executedAt;
  final int? waterUsageId;
  final String? notes;
  final String? createdAt;

  WaterIrrigationPlan({
    required this.plannedId,
    required this.farmId,
    required this.landId,
    this.waterSourceId,
    this.yieldId,
    required this.plannedDate,
    this.plannedTime,
    this.durationMin,
    this.volumeLiters,
    this.method,
    this.methodName,
    this.status = 0,
    this.executedAt,
    this.waterUsageId,
    this.notes,
    this.createdAt,
  });

  factory WaterIrrigationPlan.fromJson(Map<String, dynamic> json) =>
      WaterIrrigationPlan(
        plannedId: json['planned_id'],
        farmId: json['farm_id'],
        landId: json['land_id'],
        waterSourceId: json['water_source_id'],
        yieldId: json['yield_id'],
        plannedDate: json['planned_date']?.toString() ?? '',
        plannedTime: json['planned_time']?.toString(),
        durationMin: json['planned_duration_min'],
        volumeLiters: _toDouble(json['planned_volume_liters']),
        method: json['irrigation_method'],
        methodName: json['method_name'],
        status: json['irrigation_status'] ?? 0,
        executedAt: json['executed_at']?.toString(),
        waterUsageId: json['water_usage_id'],
        notes: json['planned_notes'],
        createdAt: json['created_at']?.toString(),
      );
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
