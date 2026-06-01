class SensorReadingModel {
  final String? noId;
  final String? noNome;
  final double? temperaturaAr;
  final double? humidadeAr;
  final double? humidadeSolo;
  final double? pressao;
  final double? latitude;
  final double? longitude;
  final DateTime? timestamp;

  const SensorReadingModel({
    this.noId,
    this.noNome,
    this.temperaturaAr,
    this.humidadeAr,
    this.humidadeSolo,
    this.pressao,
    this.latitude,
    this.longitude,
    this.timestamp,
  });

  factory SensorReadingModel.fromJson(Map<String, dynamic> json) {
    return SensorReadingModel(
      noId: json['no_id']?.toString(),
      noNome: json['no_nome']?.toString(),
      temperaturaAr: _toDouble(json['temperatura_ar']),
      humidadeAr: _toDouble(json['humidade_ar']),
      humidadeSolo: _toDouble(json['humidade_solo']),
      pressao: _toDouble(json['pressao']),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      timestamp: _parseTimestamp(json['timestamp']),
    );
  }

  bool get hasValues =>
      temperaturaAr != null ||
      humidadeAr != null ||
      humidadeSolo != null ||
      pressao != null;

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    return DateTime.tryParse(raw) ??
        DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }
}
