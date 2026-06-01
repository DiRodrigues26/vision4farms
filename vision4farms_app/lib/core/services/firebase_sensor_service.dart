import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/sensor_association_model.dart';
import '../models/sensor_node_model.dart';
import '../models/sensor_reading_model.dart';

class FirebaseSensorService {
  final FirebaseFirestore _db;

  FirebaseSensorService({FirebaseFirestore? firestore})
      : _db = firestore ??
            FirebaseFirestore.instanceFor(app: Firebase.app('sensors'));

  Future<List<SensorNodeModel>> findNodesByGatewayCode(String gatewayCode) async {
    final code = gatewayCode.trim().toUpperCase();
    if (code.isEmpty) return const [];

    final snap = await _db
        .collection('nos')
        .where('gateway_code', isEqualTo: code)
        .get();

    return snap.docs.map(SensorNodeModel.fromFirestore).toList();
  }

  Future<List<SensorReadingModel>> recentReadingsForAssociation(
    SensorAssociationModel association, {
    int limit = 24,
  }) async {
    final byNoId = await _readingsByNoId(association, limit: limit);
    if (byNoId.isNotEmpty || !association.hasStableNoId) {
      return byNoId;
    }
    return _readingsByName(association.sensorNome, limit: limit);
  }

  Future<SensorReadingModel?> latestReadingForAssociation(
    SensorAssociationModel association,
  ) async {
    final readings = await recentReadingsForAssociation(association, limit: 1);
    return readings.isEmpty ? null : readings.first;
  }

  Future<List<SensorReadingModel>> _readingsByNoId(
    SensorAssociationModel association, {
    required int limit,
  }) async {
    final candidates = _candidateIds(association);
    if (candidates.isEmpty) return const [];

    for (final candidate in candidates) {
      final readings = await _queryByField(
        field: 'no_id',
        value: candidate,
        limit: limit,
      );
      if (readings.isNotEmpty) return readings;
    }
    return const [];
  }

  Future<List<SensorReadingModel>> _readingsByName(
    String nome, {
    required int limit,
  }) async {
    if (nome.trim().isEmpty) return const [];
    return _queryByField(field: 'no_nome', value: nome, limit: limit);
  }

  /// Executa a query com orderBy. Se falhar (ex: índice composto em falta),
  /// faz fallback sem orderBy e ordena em memória.
  Future<List<SensorReadingModel>> _queryByField({
    required String field,
    required dynamic value,
    required int limit,
  }) async {
    // Estratégia 1: with orderBy (rápido, precisa de índice composto)
    try {
      final snap = await _db
          .collection('leituras')
          .where(field, isEqualTo: value)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      final list = snap.docs
          .map((doc) => SensorReadingModel.fromJson(doc.data()))
          .where((reading) => reading.hasValues)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {
      // Sem índice composto — tenta sem orderBy
    }

    // Estratégia 2: sem orderBy, ordena em memória
    try {
      final snap = await _db
          .collection('leituras')
          .where(field, isEqualTo: value)
          .limit(limit * 3)
          .get();
      final readings = snap.docs
          .map((doc) => SensorReadingModel.fromJson(doc.data()))
          .where((reading) => reading.hasValues)
          .toList();
      readings.sort((a, b) {
        final ta = a.timestamp;
        final tb = b.timestamp;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return readings.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Devolve as várias representações possíveis do no_id para esta associação:
  /// firebase doc id (int e string) + sensor_no_id (int e string).
  /// Garante que apanhamos o valor independentemente de como foi guardado.
  List<dynamic> _candidateIds(SensorAssociationModel association) {
    final result = <dynamic>[];
    final seen = <String>{};

    void addCandidate(dynamic value) {
      if (value == null) return;
      final key = '${value.runtimeType}:$value';
      if (seen.add(key)) result.add(value);
    }

    final firebaseId = association.sensorFirebaseId.trim();
    if (firebaseId.isNotEmpty) {
      final parsed = int.tryParse(firebaseId);
      if (parsed != null) addCandidate(parsed);
      addCandidate(firebaseId);
    }
    final noId = association.sensorNoId?.trim();
    if (noId != null && noId.isNotEmpty) {
      final parsed = int.tryParse(noId);
      if (parsed != null) addCandidate(parsed);
      addCandidate(noId);
    }
    return result;
  }
}
