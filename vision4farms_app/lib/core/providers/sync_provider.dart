import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/sync_service.dart';

/// Estado da fila de operações offline.
/// Notifica listeners sempre que a contagem de pendentes muda ou quando uma
/// sincronização termina.
class SyncProvider extends ChangeNotifier {
  final SyncService _service;

  int _pendingCount = 0;
  int _failedCount = 0;
  bool _isSyncing = false;
  DateTime? _lastSyncAt;
  String? _lastError;

  SyncProvider(ApiService api) : _service = SyncService(api) {
    refreshCounts();
  }

  int get pendingCount => _pendingCount;
  int get failedCount => _failedCount;
  bool get isSyncing => _isSyncing;
  bool get hasPending => _pendingCount > 0;
  bool get hasFailures => _failedCount > 0;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;

  SyncService get service => _service;

  /// Atualiza apenas as contagens (não corre a sync).
  Future<void> refreshCounts() async {
    try {
      final pending = await LocalDatabase.getPendingOperations();
      final failed = await LocalDatabase.getFailedOperations();
      _pendingCount = pending.length;
      _failedCount = failed.length;
      notifyListeners();
    } catch (e) {
      debugPrint('SyncProvider.refreshCounts error: $e');
    }
  }

  /// Drena a fila. Idempotente — só corre uma sync de cada vez.
  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    try {
      await _service.processPendingQueue();
      _lastSyncAt = DateTime.now();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('SyncProvider.sync error: $e');
    } finally {
      _isSyncing = false;
      await refreshCounts();
    }
  }

  /// Re-tenta operações que ficaram em failed (reset do retries) + corre sync.
  Future<void> retryFailed() async {
    await LocalDatabase.requeueFailedOperations();
    await sync();
  }

  /// Descarta uma operação específica.
  Future<void> discard(int id) async {
    await LocalDatabase.deleteOperation(id);
    await refreshCounts();
  }

  /// Descarta todas as falhas.
  Future<void> discardAllFailed() async {
    await LocalDatabase.deleteFailedOperations();
    await refreshCounts();
  }
}
