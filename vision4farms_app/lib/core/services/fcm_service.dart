import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_constants.dart';
import 'api_service.dart';

/// Notificação local recebida via FCM enquanto a app está em foreground.
/// Para Android, criamos um canal explícito para que a notificação seja
/// mostrada com som/vibração mesmo com a app aberta.
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'vision4farms_default',
  'Notificações Vision4Farms',
  description: 'Notificações de pragas, atividades e alertas da exploração.',
  importance: Importance.high,
);

class FcmService {
  static FcmService? _instance;
  static FcmService get instance => _instance ??= FcmService._();
  FcmService._();

  final _api = ApiService();
  final _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _currentToken;

  /// Callback chamado quando o utilizador toca numa notificação.
  /// Pode receber `data` (mapa enviado pelo backend) para navegação.
  ValueChanged<Map<String, dynamic>>? onNotificationTap;

  /// Inicializa o serviço: pede permissões, obtém token, regista handlers.
  /// Chamar **depois** do user fazer login (precisa de auth para registar
  /// o token no backend).
  Future<void> initialize() async {
    if (_initialized) {
      // Já inicializado, só envia o token de novo (caso tenha mudado)
      await _refreshAndSendToken();
      return;
    }
    _initialized = true;

    // 1. Permissões (iOS pede prompt; Android 13+ também)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Inicializar flutter_local_notifications (para foreground)
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        _handleTap(payload);
      },
    );

    // 3. Criar canal Android
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    // 4. Handler de mensagens em foreground → mostra notification local
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 5. Handler de notificação tocada (app em background, aberta pela noti)
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _handleData(msg.data);
    });

    // 6. Caso a app tenha sido aberta a partir de uma notificação (terminated)
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleData(initialMessage.data);
    }

    // 7. Listener de refresh de token
    messaging.onTokenRefresh.listen(_sendTokenToBackend);

    // 8. Obter token e enviar
    await _refreshAndSendToken();
  }

  Future<void> _refreshAndSendToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      if (token == _currentToken) return;
      _currentToken = token;
      await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('[FcmService] erro a obter token: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _api.post(
        AppConstants.fcmRegister,
        data: {
          'token': token,
          'device': Platform.operatingSystem,
        },
      );
      debugPrint('[FcmService] token registado no backend');
    } catch (e) {
      debugPrint('[FcmService] falha a registar token: $e');
    }
  }

  /// Chamar no logout — remove o token deste device no backend.
  Future<void> unregister() async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await _api.delete(AppConstants.fcmUnregister(token));
    } catch (_) {}
    _currentToken = null;
  }

  void _onForegroundMessage(RemoteMessage msg) {
    final n = msg.notification;
    final title = n?.title ?? msg.data['title']?.toString() ?? 'Vision4Farms';
    final body = n?.body ?? msg.data['body']?.toString() ?? '';
    _local.show(
      msg.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: _encodeData(msg.data),
    );
  }

  void _handleData(Map<String, dynamic> data) {
    onNotificationTap?.call(data);
  }

  void _handleTap(String payload) {
    final data = <String, dynamic>{};
    for (final pair in payload.split('|')) {
      final i = pair.indexOf('=');
      if (i > 0) data[pair.substring(0, i)] = pair.substring(i + 1);
    }
    onNotificationTap?.call(data);
  }

  String _encodeData(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join('|');
}
