import '../models/land_model.dart';
import '../models/sensor_association_model.dart';
import '../models/sensor_reading_model.dart';
import 'firebase_sensor_service.dart';

class SensorAverages {
  final double? temperaturaAr;
  final double? humidadeAr;
  final double? humidadeSolo;
  final double? pressao;
  final int readingsCount;
  final DateTime? latestTimestamp;

  const SensorAverages({
    this.temperaturaAr,
    this.humidadeAr,
    this.humidadeSolo,
    this.pressao,
    this.readingsCount = 0,
    this.latestTimestamp,
  });

  bool get hasValues =>
      temperaturaAr != null ||
      humidadeAr != null ||
      humidadeSolo != null ||
      pressao != null;

  static SensorAverages fromReadings(List<SensorReadingModel> readings) {
    double tempSum = 0, humArSum = 0, humSoloSum = 0, pressaoSum = 0;
    int tempN = 0, humArN = 0, humSoloN = 0, pressaoN = 0;
    DateTime? latest;

    for (final reading in readings) {
      final ts = reading.timestamp;
      if (ts != null && (latest == null || ts.isAfter(latest))) {
        latest = ts;
      }
      if (reading.temperaturaAr != null) {
        tempSum += reading.temperaturaAr!;
        tempN++;
      }
      if (reading.humidadeAr != null) {
        humArSum += reading.humidadeAr!;
        humArN++;
      }
      if (reading.humidadeSolo != null) {
        humSoloSum += reading.humidadeSolo!;
        humSoloN++;
      }
      if (reading.pressao != null) {
        pressaoSum += reading.pressao!;
        pressaoN++;
      }
    }

    return SensorAverages(
      temperaturaAr: tempN > 0 ? tempSum / tempN : null,
      humidadeAr: humArN > 0 ? humArSum / humArN : null,
      humidadeSolo: humSoloN > 0 ? humSoloSum / humSoloN : null,
      pressao: pressaoN > 0 ? pressaoSum / pressaoN : null,
      readingsCount: readings.length,
      latestTimestamp: latest,
    );
  }
}

class LandSensorData {
  final List<SensorAssociationModel> associations;
  final Map<int, List<SensorReadingModel>> readingsByAssociationId;
  final SensorAverages averages;
  final bool firebaseFailed;

  const LandSensorData({
    required this.associations,
    required this.readingsByAssociationId,
    required this.averages,
    this.firebaseFailed = false,
  });

  bool get hasSensors => associations.isNotEmpty;
  bool get hasReadings => averages.hasValues;
}

class SensorDataResolverService {
  final FirebaseSensorService _firebase;

  SensorDataResolverService(this._firebase);

  Future<LandSensorData> resolveLandSensorData({
    required LandModel land,
    required List<SensorAssociationModel> associations,
  }) async {
    if (associations.isEmpty) {
      return const LandSensorData(
        associations: [],
        readingsByAssociationId: {},
        averages: SensorAverages(),
      );
    }

    final readingsByAssociationId = <int, List<SensorReadingModel>>{};
    final allReadings = <SensorReadingModel>[];
    bool failed = false;

    await Future.wait(associations.map((association) async {
      try {
        final readings = await _firebase.recentReadingsForAssociation(
          association,
          limit: 24,
        );
        readingsByAssociationId[association.associationId] = readings;
        allReadings.addAll(readings);
      } catch (_) {
        failed = true;
        readingsByAssociationId[association.associationId] = const [];
      }
    }));

    return LandSensorData(
      associations: associations,
      readingsByAssociationId: readingsByAssociationId,
      averages: SensorAverages.fromReadings(allReadings),
      firebaseFailed: failed,
    );
  }

  Future<SensorAverages> farmAverages(
    List<SensorAssociationModel> associations,
  ) async {
    final readings = <SensorReadingModel>[];
    await Future.wait(associations.map((association) async {
      final latest = await _firebase.latestReadingForAssociation(association);
      if (latest != null) readings.add(latest);
    }));
    return SensorAverages.fromReadings(readings);
  }

  /// Devolve média por terreno (key = landId).
  Future<Map<int, SensorAverages>> landsAverages(
    List<SensorAssociationModel> associations,
  ) async {
    final byLand = <int, List<SensorAssociationModel>>{};
    for (final association in associations) {
      byLand.putIfAbsent(association.landId, () => []).add(association);
    }

    final entries = await Future.wait(byLand.entries.map((entry) async {
      final readings = <SensorReadingModel>[];
      await Future.wait(entry.value.map((association) async {
        final latest = await _firebase.latestReadingForAssociation(association);
        if (latest != null) readings.add(latest);
      }));
      return MapEntry(entry.key, SensorAverages.fromReadings(readings));
    }));

    return Map.fromEntries(entries);
  }
}
