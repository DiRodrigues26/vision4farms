import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/password_reset_screen.dart';
import '../../features/onboarding/screens/role_select_screen.dart';
import '../../features/onboarding/screens/worker_join_screen.dart';
import '../../features/company/screens/company_create_screen.dart';
import '../../features/farms/screens/farm_list_screen.dart';
import '../../features/farms/screens/farm_create_screen.dart';
import '../../features/dashboard/screens/main_shell_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/lands/screens/land_list_screen.dart';
import '../../features/lands/screens/land_detail_screen.dart';
import '../../features/activities/screens/activities_screen.dart';
import '../../features/activities/screens/activity_detail_screen.dart';
import '../../features/irrigation/screens/irrigation_screen.dart';
import '../../features/irrigation/screens/irrigation_land_screen.dart';
import '../../features/irrigation/screens/irrigation_yield_screen.dart';
import '../../features/irrigation/screens/irrigation_planned_detail_screen.dart';
import '../../features/water/screens/water_sources_list_screen.dart';
import '../../features/water/screens/water_source_detail_screen.dart';
import '../../features/crops/screens/crops_list_screen.dart';
import '../../features/crops/screens/crop_detail_screen.dart';
import '../../features/yields/screens/yield_harvests_screen.dart';
import '../../features/observations/screens/observations_screen.dart';
import '../../features/agenda/screens/agenda_screen.dart';
import '../../features/sensors/screens/sensor_association_screen.dart';
import '../../features/sensors/screens/sensors_screen.dart';
import '../../features/sync/screens/pending_operations_screen.dart';
import '../../map/screens/map_screen.dart';

class AppRouter {
  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final status   = authProvider.status;
        final location = state.matchedLocation;

        if (status == AuthStatus.unknown) return '/splash';

        if (status == AuthStatus.unauthenticated) {
          if (location.startsWith('/auth')) return null;
          return '/auth/login';
        }

        if (location.startsWith('/onboarding') ||
            location.startsWith('/company') ||
            location.startsWith('/worker') ||
            location.startsWith('/sync') ||
            location == '/sensor-setup' ||
            location == '/farms/create' ||
            location == '/farms' ||
            location == '/profile') {
          return null;
        }

        if (location == '/splash' || location.startsWith('/auth')) {
          final farmProvider = context.read<FarmProvider>();
          if (farmProvider.selectedFarm == null) return '/farms';
          return '/home';
        }

        return null;
      },
      routes: [
        // ── Auth & Onboarding ──────────────────────────────
        GoRoute(path: '/splash',      builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/auth/login',  builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/auth/register',
          builder: (_, state) => RegisterScreen(
            inviteCode: state.uri.queryParameters['code'],
          ),
        ),
        GoRoute(
          path: '/auth/password-reset',
          builder: (_, state) => PasswordResetScreen(
            token: state.uri.queryParameters['token'],
            email: state.uri.queryParameters['email'],
          ),
        ),
        GoRoute(path: '/onboarding/role', builder: (_, __) => const RoleSelectScreen()),
        GoRoute(path: '/worker/join',     builder: (_, __) => const WorkerJoinScreen()),
        GoRoute(path: '/company/create',  builder: (_, __) => const CompanyCreateScreen()),
        GoRoute(path: '/farms',           builder: (_, __) => const FarmListScreen()),
        GoRoute(path: '/farms/create',    builder: (_, __) => const FarmCreateScreen()),
        GoRoute(path: '/profile',         builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/sync/pending',    builder: (_, __) => const PendingOperationsScreen()),
        GoRoute(path: '/sensor-setup',     builder: (_, __) => const SensorAssociationScreen()),

        // ── Shell — mantém bottom bar + FAB em todas as sub-rotas ──
        ShellRoute(
          builder: (context, state, child) => MainShellScreen(child: child),
          routes: [

            // Dashboard (tab central — ícone casa / +)
            GoRoute(
              path: '/home',
              builder: (_, __) => const DashboardContent(),
            ),

            // Mapa
            GoRoute(
              path: '/map',
              builder: (_, __) => const MapScreen(),
            ),

            // Terrenos
            GoRoute(
              path: '/lands',
              builder: (_, __) => const LandListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => LandDetailScreen(
                    landId:     int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                    landName:   state.uri.queryParameters['name'] ?? 'Terreno',
                    apiService: ApiService(),
                  ),
                ),
              ],
            ),

            // Atividades
            GoRoute(
              path: '/activities',
              builder: (_, __) => const ActivitiesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => ActivityDetailScreen(
                    activityId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                  ),
                ),
              ],
            ),

            // Observações
            GoRoute(
              path: '/observations',
              builder: (_, __) => const ObservationsScreen(),
            ),

            // Agenda
            GoRoute(
              path: '/agenda',
              builder: (_, __) => const AgendaScreen(),
            ),

            // Rega
            GoRoute(
              path: '/irrigation',
              builder: (_, __) => const IrrigationScreen(),
              routes: [
                GoRoute(
                  path: 'land/:id',
                  builder: (_, state) => IrrigationLandScreen(
                    landId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                    landName: state.uri.queryParameters['name'] ?? 'Terreno',
                  ),
                ),
                GoRoute(
                  path: 'yield/:id',
                  builder: (_, state) => IrrigationYieldScreen(
                    yieldId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                    landId: int.tryParse(
                            state.uri.queryParameters['landId'] ?? '') ??
                        0,
                    yieldName: state.uri.queryParameters['name'] ?? 'Cultura',
                    landName:
                        state.uri.queryParameters['landName'] ?? 'Terreno',
                  ),
                ),
                GoRoute(
                  path: 'planned/:id',
                  builder: (_, state) => IrrigationPlannedDetailScreen(
                    plannedId:
                        int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                  ),
                ),
              ],
            ),

            // Fontes de água
            GoRoute(
              path: '/water/sources',
              builder: (_, __) => const WaterSourcesListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => WaterSourceDetailScreen(
                    sourceId:
                        int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                  ),
                ),
              ],
            ),

            // Sensores
            GoRoute(
              path: '/sensors',
              builder: (_, __) => const SensorsScreen(),
            ),

            // Culturas
            GoRoute(
              path: '/crops',
              builder: (_, __) => const CropsListScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => CropDetailScreen(
                    cropId:     int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                    cropName:   state.uri.queryParameters['name'] ?? '',
                    apiService: ApiService(),
                  ),
                ),
              ],
            ),

            // Colheitas por cultura (yield)
            GoRoute(
              path: '/yields/:id/harvests',
              builder: (_, state) => YieldHarvestsScreen(
                yieldId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                yieldName:
                    state.uri.queryParameters['name'] ?? 'Cultura',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
