class SensorAssociationModel {
  final int associationId;
  final int farmId;
  final int landId;
  final String landName;
  final String gatewayCode;
  final String sensorFirebaseId;
  final String? sensorNoId;
  final String sensorNome;
  final String? sensorTipo;
  final String? sensorStatus;
  final String? ultimoContacto;

  const SensorAssociationModel({
    required this.associationId,
    required this.farmId,
    required this.landId,
    required this.landName,
    required this.gatewayCode,
    required this.sensorFirebaseId,
    required this.sensorNome,
    this.sensorNoId,
    this.sensorTipo,
    this.sensorStatus,
    this.ultimoContacto,
  });

  factory SensorAssociationModel.fromJson(Map<String, dynamic> json) {
    return SensorAssociationModel(
      associationId: int.tryParse(json['association_id']?.toString() ?? '') ?? 0,
      farmId: int.tryParse(json['farm_id']?.toString() ?? '') ?? 0,
      landId: int.tryParse(json['land_id']?.toString() ?? '') ?? 0,
      landName: json['land_name']?.toString() ?? '',
      gatewayCode: json['gateway_code']?.toString() ?? '',
      sensorFirebaseId: json['sensor_firebase_id']?.toString() ?? '',
      sensorNoId: json['sensor_no_id']?.toString(),
      sensorNome: json['sensor_nome']?.toString() ?? '',
      sensorTipo: json['sensor_tipo']?.toString(),
      sensorStatus: json['sensor_status']?.toString(),
      ultimoContacto: json['ultimo_contacto']?.toString(),
    );
  }

  bool get hasStableNoId =>
      sensorNoId != null && sensorNoId!.trim().isNotEmpty;
}
