class FarmModel {
  final int farmId;
  final String farmName;
  final String? farmCity;
  final String? farmDistrict;
  final String? farmGps;
  final String? farmDescription;
  final String? farmSlug;
  final int farmStatus;
  final int userRole;
  final double? farmSize; // área em ha

  FarmModel({
    required this.farmId,
    required this.farmName,
    this.farmCity,
    this.farmDistrict,
    this.farmGps,
    this.farmDescription,
    this.farmSlug,
    this.farmStatus = 1,
    this.userRole = 1,
    this.farmSize,
  });

  bool get isManager      => userRole == 1; // Gestor
  bool get isColaborador  => userRole == 2; // Colaborador
  bool get isConsultor    => userRole == 3; // Consultor

  /// Pode criar/editar terrenos, culturas, regas, agenda, convites
  bool get canManage => isManager;

  /// Pode criar observações, abrir/fechar atividades
  bool get canContribute => isManager || isColaborador;

  /// Pode apenas consultar dados (+ atividades para Consultor)
  bool get canView => true;

  static String roleLabel(int role) {
    const labels = {1: 'Gestor', 2: 'Colaborador', 3: 'Consultor'};
    return labels[role] ?? 'Membro';
  }

  factory FarmModel.fromJson(Map<String, dynamic> json) => FarmModel(
    farmId: json['farm_id'],
    farmName: json['farm_name'],
    farmCity: json['farm_city'],
    farmDistrict: json['farm_district'],
    farmGps: json['farm_gps'],
    farmDescription: json['farm_description'],
    farmSlug: json['farm_slug'],
    farmStatus: json['farm_status'] ?? 1,
    userRole: json['user_role'] ?? 1,
    farmSize: json['farm_size'] != null
        ? double.tryParse(json['farm_size'].toString())
        : null,
  );
}