import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/sensor_association_model.dart';
import 'api_service.dart';

/// Escuta a coleção 'alertas' do Firebase em tempo real.
/// Quando chega um alerta novo de praga/anomalia DEPOIS do arranque
/// e cujo nó está associado a um dos terrenos da exploração actual,
/// cria uma notificação no backend e dispara o callback para UI.
class FirebaseAlertService {
  static FirebaseAlertService? _instance;
  static FirebaseAlertService get instance =>
      _instance ??= FirebaseAlertService._();
  FirebaseAlertService._();

  final _api = ApiService();

  StreamSubscription<QuerySnapshot>? _sub;
  DateTime? _startedAt;

  int? _farmId;
  List<SensorAssociationModel> _associations = const [];
  final Set<String> _processedAlertIds = <String>{};

  /// Callback chamado com o alerta quando é detetado um novo
  /// (já filtrado para sensores associados).
  ValueChanged<Map<String, dynamic>>? onNewAlert;

  /// Define a exploração actual e as associações a observar.
  /// Se a exploração mudar, reinicia o histórico para evitar dispararmos
  /// alertas antigos como novos.
  void updateAssociations({
    required int? farmId,
    required List<SensorAssociationModel> associations,
  }) {
    final farmChanged = _farmId != farmId;
    _farmId = farmId;
    _associations = associations;
    if (farmChanged) {
      _processedAlertIds.clear();
    }
    if (_farmId != null && _associations.isNotEmpty) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    if (_sub != null) return;
    _startedAt ??= DateTime.now();
    final db = FirebaseFirestore.instanceFor(app: Firebase.app('sensors'));
    _sub = db
        .collection('alertas')
        .orderBy('criado_em', descending: true)
        .limit(20)
        .snapshots()
        .listen(_onSnapshot, onError: (e) {
      debugPrint('[FirebaseAlertService] erro: $e');
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _onSnapshot(QuerySnapshot snap) {
    if (_startedAt == null) return;
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final docId = change.doc.id;
      if (_processedAlertIds.contains(docId)) continue;

      final data = change.doc.data() as Map<String, dynamic>;
      final criadoEm = _parseTs(data['criado_em']?.toString());
      if (criadoEm == null || !criadoEm.isAfter(_startedAt!)) continue;

      final match = _findMatch(data);
      if (match == null) continue;

      _processedAlertIds.add(docId);
      _handleAlert(docId, data, match);
    }
  }

  SensorAssociationModel? _findMatch(Map<String, dynamic> alert) {
    if (_associations.isEmpty) return null;
    final noId = alert['no_id']?.toString();
    final noNome = alert['no_nome']?.toString();
    for (final assoc in _associations) {
      if (noId != null && noId.isNotEmpty && assoc.sensorNoId == noId) {
        return assoc;
      }
      if (noNome != null &&
          noNome.isNotEmpty &&
          assoc.sensorNome == noNome) {
        return assoc;
      }
    }
    return null;
  }

  bool _isPestAlert(Map<String, dynamic> alert) {
    final tipo = (alert['tipo']?.toString() ?? '').toLowerCase();
    final mensagem = (alert['mensagem']?.toString() ?? '').toLowerCase();
    return tipo.contains('praga') ||
        tipo.contains('anomalia') ||
        mensagem.contains('praga');
  }

  Future<void> _handleAlert(
    String docId,
    Map<String, dynamic> alert,
    SensorAssociationModel match,
  ) async {
    if (!_isPestAlert(alert)) return;
    final farmId = _farmId;
    if (farmId == null) return;

    final mensagem = alert['mensagem']?.toString() ?? '';
    final severidade = alert['severidade']?.toString() ?? '';
    final title = match.landName.isNotEmpty
        ? 'Praga detetada · ${match.landName}'
        : 'Praga detetada';
    final body = [
      if (match.sensorNome.isNotEmpty) 'Sensor: ${match.sensorNome}',
      if (severidade.isNotEmpty) 'Severidade: $severidade',
      if (mensagem.isNotEmpty) mensagem,
    ].join('\n');

    try {
      await _api.post(
        '/notifications/sensor-alert/',
        data: {
          'farm_id': farmId,
          'land_id': match.landId,
          'alert_key': docId,
          'title': title,
          'body': body.isEmpty ? title : body,
        },
      );
    } catch (e) {
      debugPrint('[FirebaseAlertService] falha ao criar notificação: $e');
    }

    onNewAlert?.call({
      ...alert,
      'land_name': match.landName,
      'sensor_nome': match.sensorNome,
    });
  }

  DateTime? _parseTs(String? ts) {
    if (ts == null || ts.isEmpty) return null;
    try {
      return DateTime.parse(ts);
    } catch (_) {
      try {
        return DateTime.parse(ts.replaceFirst(' ', 'T'));
      } catch (_) {
        return null;
      }
    }
  }
}
