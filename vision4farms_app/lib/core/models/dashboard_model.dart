class DashboardModel {
  final DashboardFarm farm;
  final int userRole;
  final DashboardSummary summary;
  final DashboardActivities activities;
  final DashboardAgenda agenda;
  final DashboardIrrigation irrigation;
  final List<DashboardYield> activeYields;
  final List<DashboardObservation> recentObservations;
  final DashboardAnalyses analyses;

  DashboardModel({
    required this.farm,
    required this.userRole,
    required this.summary,
    required this.activities,
    required this.agenda,
    required this.irrigation,
    required this.activeYields,
    required this.recentObservations,
    required this.analyses,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) => DashboardModel(
    farm: DashboardFarm.fromJson(json['farm']),
    userRole: json['user_role'] ?? 1,
    summary: DashboardSummary.fromJson(json['summary']),
    activities: DashboardActivities.fromJson(json['activities']),
    agenda: DashboardAgenda.fromJson(json['agenda'] ?? {}),
    irrigation: DashboardIrrigation.fromJson(json['irrigation'] ?? {}),
    activeYields: (json['active_yields'] as List? ?? [])
        .map((y) => DashboardYield.fromJson(y))
        .toList(),
    recentObservations: (json['recent_observations'] as List? ?? [])
        .map((o) => DashboardObservation.fromJson(o))
        .toList(),
    analyses: DashboardAnalyses.fromJson(json['analyses'] ?? {}),
  );
}

class DashboardAgenda {
  final int pending;
  final int thisMonth;

  DashboardAgenda({required this.pending, required this.thisMonth});

  factory DashboardAgenda.fromJson(Map<String, dynamic> json) => DashboardAgenda(
    pending: json['pending'] ?? 0,
    thisMonth: json['this_month'] ?? 0,
  );
}

class DashboardFarm {
  final int farmId;
  final String farmName;
  final String? farmCity;
  final String? farmDistrict;
  final String? farmGps;

  DashboardFarm({
    required this.farmId,
    required this.farmName,
    this.farmCity,
    this.farmDistrict,
    this.farmGps,
  });

  factory DashboardFarm.fromJson(Map<String, dynamic> json) => DashboardFarm(
    farmId: json['farm_id'],
    farmName: json['farm_name'],
    farmCity: json['farm_city'],
    farmDistrict: json['farm_district'],
    farmGps: json['farm_gps'],
  );
}

class DashboardSummary {
  final int totalLands;
  final double totalAreaHa;
  final int unreadNotifications;

  DashboardSummary({
    required this.totalLands,
    required this.totalAreaHa,
    required this.unreadNotifications,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
    totalLands: json['total_lands'] ?? 0,
    totalAreaHa: (json['total_area_ha'] as num?)?.toDouble() ?? 0.0,
    unreadNotifications: json['unread_notifications'] ?? 0,
  );
}

class DashboardActivities {
  final int pending;
  final int overdue;
  final int urgent;
  final int doneThisMonth;
  final List<DashboardNextActivity> next;

  DashboardActivities({
    required this.pending,
    required this.overdue,
    required this.urgent,
    required this.doneThisMonth,
    required this.next,
  });

  factory DashboardActivities.fromJson(Map<String, dynamic> json) => DashboardActivities(
    pending: json['pending'] ?? 0,
    overdue: json['overdue'] ?? 0,
    urgent: json['urgent'] ?? 0,
    doneThisMonth: json['done_this_month'] ?? 0,
    next: (json['next'] as List? ?? [])
        .map((a) => DashboardNextActivity.fromJson(a))
        .toList(),
  );
}

class DashboardNextActivity {
  final int activityId;
  final String activityName;
  final String activityType;
  final String activityDatePlanned;
  final int activityPriority;
  final int landId;
  final String landName;

  DashboardNextActivity({
    required this.activityId,
    required this.activityName,
    required this.activityType,
    required this.activityDatePlanned,
    required this.activityPriority,
    required this.landId,
    required this.landName,
  });

  factory DashboardNextActivity.fromJson(Map<String, dynamic> json) => DashboardNextActivity(
    activityId: json['activity_id'],
    activityName: json['activity_name'],
    activityType: json['activity_type'] ?? '',
    activityDatePlanned: json['activity_date_planned']?.toString() ?? '',
    activityPriority: json['activity_priority'] ?? 1,
    landId: json['land_id'] ?? 0,
    landName: json['land_name'] ?? '',
  );
}

class DashboardIrrigation {
  final Map<String, dynamic>? last;
  final List<Map<String, dynamic>> next;

  DashboardIrrigation({this.last, required this.next});

  factory DashboardIrrigation.fromJson(Map<String, dynamic> json) => DashboardIrrigation(
    last: json['last'] != null ? Map<String, dynamic>.from(json['last']) : null,
    next: (json['next'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
  );
}

class DashboardYield {
  final int yieldId;
  final String yieldName;
  final double? yieldSize;
  final int landId;
  final String landName;

  DashboardYield({
    required this.yieldId,
    required this.yieldName,
    this.yieldSize,
    required this.landId,
    required this.landName,
  });

  factory DashboardYield.fromJson(Map<String, dynamic> json) => DashboardYield(
    yieldId: json['yield_id'],
    yieldName: json['yield_name'],
    yieldSize: (json['yield_size'] as num?)?.toDouble(),
    landId: json['land_id'] ?? 0,
    landName: json['land_name'] ?? '',
  );
}

class DashboardObservation {
  final int observationId;
  final String observationText;
  final String? pragaFungo;
  final int landId;
  final String createdAt;

  DashboardObservation({
    required this.observationId,
    required this.observationText,
    this.pragaFungo,
    required this.landId,
    required this.createdAt,
  });

  factory DashboardObservation.fromJson(Map<String, dynamic> json) => DashboardObservation(
    observationId: json['observation_id'],
    observationText: json['observation_text'],
    pragaFungo: json['praga_fungo'],
    landId: json['land_id'] ?? 0,
    createdAt: json['created_at']?.toString() ?? '',
  );
}

class DashboardAnalyses {
  final List<Map<String, dynamic>> soil;
  final List<Map<String, dynamic>> foliar;

  DashboardAnalyses({required this.soil, required this.foliar});

  int get total => soil.length + foliar.length;

  factory DashboardAnalyses.fromJson(Map<String, dynamic> json) => DashboardAnalyses(
    soil: (json['soil'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
    foliar: (json['foliar'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
  );
}