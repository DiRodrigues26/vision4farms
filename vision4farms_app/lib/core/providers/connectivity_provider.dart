import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline        = true;
  bool _justReconnected = false;

  bool get isOnline        => _isOnline;
  bool get isOffline       => !_isOnline;
  bool get justReconnected => _justReconnected;

  /// Chamado automaticamente quando a ligação é restabelecida.
  VoidCallback? onReconnected;

  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = _hasConnection(result);

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online == _isOnline) return;
      _isOnline = online;
      if (online) {
        _justReconnected = true;
        notifyListeners();
        onReconnected?.call();
        Future.delayed(const Duration(seconds: 3), () {
          _justReconnected = false;
          notifyListeners();
        });
      } else {
        _justReconnected = false;
        notifyListeners();
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi   ||
        r == ConnectivityResult.ethernet);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
