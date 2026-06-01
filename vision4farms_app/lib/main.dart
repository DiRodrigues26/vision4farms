import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/services/api_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/firebase_alert_service.dart';
import 'core/services/local_database.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/farm_provider.dart';
import 'core/providers/map_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/sensor_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/firebase_sensor_service.dart';
import 'core/services/sensor_association_service.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/offline_banner.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Opções da Firebase secundária usada para LER os dados dos sensores
/// (colecções `nos`, `leituras`, `alertas`, `decisoes`) do projeto do colega.
/// O projeto principal (default) é o `vision4farms-app`, configurado via
/// `google-services.json` e usado para FCM (push notifications).
const FirebaseOptions kSensorsFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCpxyQXyZN-oGSqgQ26GVAGljNIiBT7g2Y',
  appId: '1:858763953573:android:da731202805894a144944c',
  messagingSenderId: '858763953573',
  projectId: 'vision4farms-f7ffc',
  storageBucket: 'vision4farms-f7ffc.firebasestorage.app',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDateFormatting('pt_PT', null);
  } catch (e) {
    debugPrint('[main] initializeDateFormatting falhou: $e');
  }

  // Firebase principal — vision4farms-app (FCM). Nunca deve bloquear o arranque.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[main] Firebase default init falhou: $e');
  }

  // Firebase secundária — vision4farms-f7ffc (sensores, leituras, alertas)
  try {
    await Firebase.initializeApp(
      name: 'sensors',
      options: kSensorsFirebaseOptions,
    );
  } catch (e) {
    debugPrint('[main] Firebase "sensors" init falhou: $e');
  }

  // Inicializa a base de dados SQLite local
  try {
    await LocalDatabase.db;
  } catch (e) {
    debugPrint('[main] LocalDatabase init falhou: $e');
  }

  try {
    MapboxOptions.setAccessToken(
      'pk.eyJ1IjoiZGlvZ28yNiIsImEiOiJjbW11c3hkcWQxdGg4MnByMjk4dGxwMGRhIn0.fPZGRiR_C_d2JKuxExKBhw',
    );
  } catch (e) {
    debugPrint('[main] Mapbox token falhou: $e');
  }

  runApp(const Vision4FarmsApp());
}

class Vision4FarmsApp extends StatefulWidget {
  const Vision4FarmsApp({super.key});

  @override
  State<Vision4FarmsApp> createState() => _Vision4FarmsAppState();
}

class _Vision4FarmsAppState extends State<Vision4FarmsApp> {
  final _appLinks               = AppLinks();
  final _apiService             = ApiService();
  late final AuthProvider         _authProvider;
  late final FarmProvider         _farmProvider;
  late final MapProvider          _mapProvider;
  late final ConnectivityProvider _connectivityProvider;
  late final SensorProvider       _sensorProvider;
  late final SyncProvider         _syncProvider;
  late final GoRouter             _router;

  @override
  void initState() {
    super.initState();
    _authProvider         = AuthProvider(_apiService)..checkAuth();
    _farmProvider         = FarmProvider(_apiService);
    _mapProvider          = MapProvider(_apiService);
    _connectivityProvider = ConnectivityProvider();
    _sensorProvider       = SensorProvider(
      associations: SensorAssociationService(_apiService),
      firebase: FirebaseSensorService(),
    );
    _syncProvider         = SyncProvider(_apiService);
    _router               = AppRouter.router(_authProvider);

    // A notificação de praga é guardada no backend pelo FirebaseAlertService
    // e aparece na lista de notificações como qualquer outra.
    // (Sem SnackBar — a UX é igual às restantes notificações.)

    // Sempre que a farm selecionada muda, carrega as associações e
    // alimenta o FirebaseAlertService para que filtre alertas só
    // dos sensores que pertencem a esta exploração.
    _farmProvider.addListener(_syncAlertSubscription);
    _sensorProvider.addListener(_syncAlertSubscription);

    // FCM — arrancar quando autenticado, terminar ao logout
    _authProvider.addListener(_syncFcm);

    // Quando o user toca numa push notification, navegar para o sítio certo.
    FcmService.instance.onNotificationTap = (data) {
      final type = data['type']?.toString() ?? '';
      switch (type) {
        case 'sensor_alert':
          _router.go('/sensors');
          break;
        case 'activity':
          _router.go('/activities');
          break;
        case 'agenda':
          _router.go('/agenda');
          break;
        default:
          break;
      }
    };

    // Ao reconectar → drena fila de operações offline + atualiza dashboard
    _connectivityProvider.onReconnected = () {
      _syncProvider.sync();
      _farmProvider.syncWhenOnline();
    };

    // Tentativa imediata no arranque (caso a app abra já online com pendentes)
    if (_connectivityProvider.isOnline) {
      _syncProvider.sync();
    }

    _initDeepLinks();
    _syncAlertSubscription();
    _syncFcm();
  }

  int? _lastSyncedFarmId;
  bool _loadingAssociationsForAlerts = false;
  bool _fcmInitialized = false;

  void _syncFcm() {
    final isAuth = _authProvider.isAuthenticated;
    if (isAuth && !_fcmInitialized) {
      _fcmInitialized = true;
      FcmService.instance.initialize();
    } else if (!isAuth && _fcmInitialized) {
      _fcmInitialized = false;
      FcmService.instance.unregister();
    }
  }

  void _syncAlertSubscription() {
    final farm = _farmProvider.selectedFarm;
    final farmId = farm?.farmId;
    if (farmId == null) {
      FirebaseAlertService.instance.updateAssociations(
        farmId: null,
        associations: const [],
      );
      _lastSyncedFarmId = null;
      return;
    }

    final cached = _sensorProvider.associationsForFarm(farmId);
    FirebaseAlertService.instance.updateAssociations(
      farmId: farmId,
      associations: cached,
    );

    // Carrega só uma vez por farm e nunca enquanto outra carga decorre.
    // Usa notify: false para não disparar este mesmo listener em loop.
    if (_lastSyncedFarmId == farmId || _loadingAssociationsForAlerts) return;
    _lastSyncedFarmId = farmId;
    _loadingAssociationsForAlerts = true;
    _sensorProvider
        .loadFarmAssociations(farmId, notify: false)
        .then((list) {
      _loadingAssociationsForAlerts = false;
      FirebaseAlertService.instance.updateAssociations(
        farmId: farmId,
        associations: list,
      );
    }).catchError((_) {
      _loadingAssociationsForAlerts = false;
    });
  }

  void _initDeepLinks() {
    _appLinks.uriLinkStream.listen(_handleDeepLink);
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'vision4farms') return;
    if (uri.host == 'reset-password') {
      final token = uri.queryParameters['token'] ?? '';
      final email = uri.queryParameters['email'] ?? '';
      _router.go(
        '/auth/password-reset?token=${Uri.encodeComponent(token)}'
        '&email=${Uri.encodeComponent(email)}',
      );
    } else if (uri.host == 'register') {
      final code = uri.queryParameters['code'] ?? '';
      _router.go('/auth/register?code=$code');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _farmProvider),
        ChangeNotifierProvider.value(value: _mapProvider),
        ChangeNotifierProvider.value(value: _connectivityProvider),
        ChangeNotifierProvider.value(value: _sensorProvider),
        ChangeNotifierProvider.value(value: _syncProvider),
      ],
      child: MaterialApp.router(
        title: 'Vision4Farms',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        // OfflineBanner envolve toda a app — aparece em qualquer ecrã
        builder: (context, child) => OfflineBanner(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
