class AppConstants {
  // API
static const String baseUrl = 'https://vision4farms-api-production.up.railway.app/api';
  // App
  static const String appVersion = '1.0.0';

  // Endpoints — Status
  static const String appStatus = '/status/';

  // Endpoints — Auth
  static const String login                = '/auth/login/';
  static const String register             = '/auth/register/';
  static const String refresh              = '/auth/refresh/';
  static const String me                   = '/auth/me/';
  static const String logout               = '/auth/logout/';
  static const String passwordReset        = '/auth/password-reset/';
  static const String passwordResetConfirm = '/auth/password-reset/confirm/';
  static const String profileUpdate        = '/auth/profile/';
  static const String profilePicture       = '/auth/profile/picture/';
  static const String passwordChange       = '/auth/password-change/';

  // Endpoints — Dashboard
  static const String dashboardFarms = '/dashboard/farms/';
  static String dashboardFarm(int farmId) => '/dashboard/$farmId/';

  // Endpoints — Map
  static String mapData(int farmId) => '/map/$farmId/';

  // Endpoints — Farms
  static const String farms       = '/farms/';
  static const String farmsCreate = '/farms/create/';
  static String farmDetail(int farmId) => '/farms/$farmId/';

  // Endpoints — Invites
  static String inviteGenerate(int farmId) => '/farms/$farmId/invite/generate/';
  static const String inviteJoin   = '/farms/invite/join/';
  static const String inviteList   = '/farms/invite/list/';
  static String inviteCancel(int inviteId) => '/farms/invite/$inviteId/cancel/';

  // Endpoints — Lands
  static const String lands       = '/lands/';
  static const String landsCreate = '/lands/create/';
  static String landDetail(int landId) => '/lands/$landId/';
  static String landIrrigation(int landId) => '/lands/$landId/irrigation/';

  // Endpoints — Soil analyses
  static String soilAnalysisList(int landId)   => '/lands/$landId/soil-analyses/';
  static String soilAnalysisCreate(int landId) => '/lands/$landId/soil-analyses/create/';
  static String soilAnalysisDetail(int id)     => '/lands/soil-analyses/$id/';
  static String soilAnalysisPdf(int id)        => '/lands/soil-analyses/$id/pdf/';

  // Endpoints — Crops (tipos de cultura)
  static const String crops = '/crops/';
  static String cropsFarm(int farmId) => '/crops/farm/$farmId/';
  static String cropDetail(int cropId) => '/crops/$cropId/';
  static String cropHub(int cropId) => '/crops/$cropId/hub/';

  // Endpoints — Yields (cultura num terreno = Crop + Land + Farm)
  static const String yields       = '/yields/';
  static const String yieldsCreate = '/yields/create/';
  static String yieldDetail(int yieldId) => '/yields/$yieldId/';

  // Endpoints — Foliar analyses
  static String foliarAnalysisList(int yieldId)   => '/yields/$yieldId/analyses/';
  static String foliarAnalysisCreate(int yieldId) => '/yields/$yieldId/analyses/create/';
  static String foliarAnalysisDetail(int id)      => '/yields/analyses/$id/';
  static String foliarAnalysisPdf(int id)         => '/yields/analyses/$id/pdf/';

  // Endpoints — Harvests
  static String harvestList(int yieldId)   => '/yields/$yieldId/harvests/';
  static String harvestCreate(int yieldId) => '/yields/$yieldId/harvests/create/';
  static String harvestDetail(int id)      => '/yields/harvests/$id/';
  static String harvestPdf(int id)         => '/yields/harvests/$id/pdf/';

  // Endpoints — Activities
  static const String activities       = '/activities/';
  static const String activitiesCreate = '/activities/create/';
  static String activityDetail(int id) => '/activities/$id/';
  static const String observations     = '/activities/observations/';
  static String observationImageUpload(int id) => '/activities/observations/$id/upload/';

  // Endpoints — Agenda
  static const String agenda       = '/agenda/';
  static const String agendaCreate = '/agenda/create/';
  static String agendaDetail(int id) => '/agenda/$id/';

  // Endpoints — Water (fontes, consumo, regas planeadas)
  static const String waterTypes        = '/water/types/';
  static const String waterMethods      = '/water/methods/';
  static const String waterSources      = '/water/sources/';
  static String waterSourceDetail(int id) => '/water/sources/$id/';
  static const String waterUsageLogs    = '/water/usage-logs/';
  static String waterUsageDetail(int id) => '/water/usage-logs/$id/';
  static const String waterPlanned      = '/water/planned/';
  static String waterPlannedDetail(int id) => '/water/planned/$id/';
  static String waterPlannedExecute(int id) => '/water/planned/$id/execute/';

  // Endpoints - Sensores
  static const String sensorAssociations = '/sensors/associations/';
  static const String sensorAssociationsBulk = '/sensors/associations/bulk/';
  static String sensorAssociationDetail(int id) => '/sensors/associations/$id/';

  // Endpoints — Notifications
  static const String notifications = '/notifications/';
  static String notificationRead(int id) => '/notifications/$id/read/';
  static String notificationToggleRead(int id) => '/notifications/$id/toggle-read/';
  static const String notificationPreferences = '/notifications/preferences/';

  // Endpoints — Push (FCM)
  static const String fcmRegister = '/notifications/devices/';
  static String fcmUnregister(String token) => '/notifications/devices/$token/';

  // Storage keys
  static const String accessTokenKey  = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey       = 'user_id';
  static const String usernameKey     = 'username';
}
