import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Base de dados SQLite local da Vision4Farms.
/// Guarda os dados da API para uso offline.
class LocalDatabase {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  // ── Abrir / criar a BD ────────────────────────────────────

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'vision4farms.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS activity_detail_cache (
          activity_id INTEGER PRIMARY KEY,
          raw_json    TEXT NOT NULL,
          synced_at   TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          operation_type  TEXT NOT NULL,
          data            TEXT NOT NULL,
          status          TEXT NOT NULL DEFAULT 'pending',
          retries         INTEGER NOT NULL DEFAULT 0,
          error_message   TEXT,
          created_at      TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await _createMissingCacheTables(db);
    }
    if (oldVersion < 4) {
      await _createLocalWritesTable(db);
    }
    if (oldVersion < 5) {
      await _createListCacheTable(db);
    }
  }

  /// Cache genérico para qualquer lista vinda da API. Cada lista é
  /// identificada por uma chave (ex: 'observations:farm_42').
  static Future<void> _createListCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS list_cache (
        cache_key TEXT PRIMARY KEY,
        raw_json  TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');
  }

  /// Tabela única para escritas otimistas (offline). Cada linha representa
  /// um registo local que ainda não foi sincronizado com o servidor.
  /// O campo `entity_type` identifica que tipo é ('observation', 'activity',
  /// 'harvest'...) e `parent_id` permite filtrar (ex: observações por land_id).
  static Future<void> _createLocalWritesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_writes (
        local_id     INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type  TEXT NOT NULL,
        parent_id    INTEGER,
        client_uuid  TEXT NOT NULL,
        raw_json     TEXT NOT NULL,
        photo_path   TEXT,
        created_at   TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_writes_entity '
      'ON local_writes(entity_type, parent_id)',
    );
  }

  /// Tabelas usadas pelo app mas que nunca foram incluídas no _onCreate
  /// original. Criadas defensivamente para instalações frescas e upgrades.
  static Future<void> _createMissingCacheTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS land_detail_cache (
        land_id   INTEGER PRIMARY KEY,
        raw_json  TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS crop_detail_cache (
        crop_id   INTEGER PRIMARY KEY,
        raw_json  TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS map_cache (
        farm_id   INTEGER PRIMARY KEY,
        raw_json  TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        notification_id    INTEGER PRIMARY KEY,
        farm_id            INTEGER NOT NULL,
        notification_title TEXT,
        notification_body  TEXT,
        notification_read  INTEGER DEFAULT 0,
        created_at         TEXT,
        synced_at          TEXT
      )
    ''');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE farms (
        farm_id       INTEGER PRIMARY KEY,
        farm_name     TEXT NOT NULL,
        farm_city     TEXT,
        farm_district TEXT,
        farm_gps      TEXT,
        farm_slug     TEXT,
        farm_status   INTEGER DEFAULT 1,
        user_role     INTEGER DEFAULT 2,
        farm_size     REAL,
        synced_at     TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE lands (
        land_id      INTEGER PRIMARY KEY,
        farm_id      INTEGER NOT NULL,
        land_name    TEXT NOT NULL,
        land_slug    TEXT,
        land_location TEXT,
        land_gps     TEXT,
        land_sketch  TEXT,
        land_size    REAL,
        land_water   INTEGER DEFAULT 0,
        land_notes   TEXT,
        land_status  INTEGER DEFAULT 1,
        synced_at    TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE crops (
        crop_id          INTEGER PRIMARY KEY,
        farm_id          INTEGER NOT NULL,
        crop_name        TEXT NOT NULL,
        crop_type        TEXT,
        land_ids         TEXT,
        total_area_ha    REAL,
        last_irrigation  TEXT,
        raw_json         TEXT,
        synced_at        TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE activities (
        activity_id          INTEGER PRIMARY KEY,
        farm_id              INTEGER NOT NULL,
        land_id              INTEGER,
        land_name            TEXT,
        activity_name        TEXT,
        activity_type        TEXT,
        activity_description TEXT,
        activity_date_planned TEXT,
        activity_status      INTEGER DEFAULT 0,
        activity_priority    INTEGER DEFAULT 1,
        assigned_to          TEXT,
        synced_at            TEXT
      )
    ''');

    // Dashboard guardado como JSON (estrutura complexa)
    await db.execute('''
      CREATE TABLE dashboard_cache (
        farm_id   INTEGER PRIMARY KEY,
        raw_json  TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');

    // Cache de detalhe de atividade (JSON completo)
    await db.execute('''
      CREATE TABLE activity_detail_cache (
        activity_id INTEGER PRIMARY KEY,
        raw_json    TEXT NOT NULL,
        synced_at   TEXT NOT NULL
      )
    ''');

    // Fila de operações offline
    await db.execute('''
      CREATE TABLE sync_queue (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type  TEXT NOT NULL,
        data            TEXT NOT NULL,
        status          TEXT NOT NULL DEFAULT 'pending',
        retries         INTEGER NOT NULL DEFAULT 0,
        error_message   TEXT,
        created_at      TEXT NOT NULL
      )
    ''');

    // Caches que ficaram fora do _onCreate original
    await _createMissingCacheTables(db);
    // Tabela de escritas otimistas
    await _createLocalWritesTable(db);
    // Cache genérico de listas
    await _createListCacheTable(db);
  }

  // ══════════════════════════════════════════════════════════
  // FARMS
  // ══════════════════════════════════════════════════════════

  static Future<void> saveFarms(List<dynamic> data) async {
    final d  = await db;
    final ts = DateTime.now().toIso8601String();
    final batch = d.batch();
    for (final f in data) {
      batch.insert('farms', {
        'farm_id':      f['farm_id'],
        'farm_name':    f['farm_name'],
        'farm_city':    f['farm_city'],
        'farm_district':f['farm_district'],
        'farm_gps':     f['farm_gps'],
        'farm_slug':    f['farm_slug'],
        'farm_status':  f['farm_status'] ?? 1,
        'user_role':    f['user_role'] ?? 2,
        'farm_size':    (f['farm_size'] as num?)?.toDouble(),
        'synced_at':    ts,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getFarms() async {
    final d = await db;
    return d.query('farms', where: 'farm_status = 1',
        orderBy: 'farm_name ASC');
  }

  // ══════════════════════════════════════════════════════════
  // DASHBOARD
  // ══════════════════════════════════════════════════════════

  static Future<void> saveDashboard(int farmId, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert('dashboard_cache', {
      'farm_id':  farmId,
      'raw_json': jsonEncode(data),
      'synced_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getDashboard(int farmId) async {
    final d    = await db;
    final rows = await d.query('dashboard_cache',
        where: 'farm_id = ?', whereArgs: [farmId], limit: 1);
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['raw_json'] as String)
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> dashboardSyncedAt(int farmId) async {
    final d    = await db;
    final rows = await d.query('dashboard_cache',
        columns: ['synced_at'],
        where: 'farm_id = ?', whereArgs: [farmId], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['synced_at'] as String?;
  }

  // ══════════════════════════════════════════════════════════
  // LANDS
  // ══════════════════════════════════════════════════════════

  static Future<void> saveLands(int farmId, List<dynamic> data) async {
    final d  = await db;
    final ts = DateTime.now().toIso8601String();
    // Limpa os antigos desta exploração antes de inserir
    await d.delete('lands', where: 'farm_id = ?', whereArgs: [farmId]);
    final batch = d.batch();
    for (final l in data) {
      double? size;
      try { size = double.parse(l['land_size']?.toString() ?? ''); }
      catch (_) {}
      batch.insert('lands', {
        'land_id':      l['land_id'],
        'farm_id':      farmId,
        'land_name':    l['land_name'],
        'land_slug':    l['land_slug'],
        'land_location':l['land_location'],
        'land_gps':     l['land_gps'],
        'land_sketch':  l['land_sketch'],
        'land_size':    size,
        'land_water':   l['land_water'] ?? 0,
        'land_notes':   l['land_notes'],
        'land_status':  l['land_status'] ?? 1,
        'synced_at':    ts,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getLands(int farmId) async {
    final d = await db;
    return d.query('lands',
        where: 'farm_id = ? AND land_status = 1',
        whereArgs: [farmId],
        orderBy: 'land_name ASC');
  }

  // ══════════════════════════════════════════════════════════
  // CROPS
  // ══════════════════════════════════════════════════════════

  static Future<void> saveCrops(int farmId, List<dynamic> data) async {
    final d  = await db;
    final ts = DateTime.now().toIso8601String();
    await d.delete('crops', where: 'farm_id = ?', whereArgs: [farmId]);
    final batch = d.batch();
    for (final c in data) {
      double? area;
      try { area = double.parse(c['total_area_ha']?.toString() ?? ''); }
      catch (_) {}
      batch.insert('crops', {
        'crop_id':        c['crop_id'],
        'farm_id':        farmId,
        'crop_name':      c['crop_name'],
        'crop_type':      c['crop_type'],
        'total_area_ha':  area,
        'last_irrigation':c['last_irrigation']?.toString(),
        'raw_json':       jsonEncode(c),
        'synced_at':      ts,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCrops(int farmId) async {
    final d    = await db;
    final rows = await d.query('crops',
        where: 'farm_id = ?', whereArgs: [farmId],
        orderBy: 'crop_name ASC');
    // Desserializa raw_json para devolver o mesmo formato que a API
    return rows.map((r) {
      try {
        return jsonDecode(r['raw_json'] as String) as Map<String, dynamic>;
      } catch (_) {
        return Map<String, dynamic>.from(r);
      }
    }).toList();
  }

  // ══════════════════════════════════════════════════════════
  // ACTIVITIES
  // ══════════════════════════════════════════════════════════

  static Future<void> saveActivities(int farmId, List<dynamic> data) async {
    final d  = await db;
    final ts = DateTime.now().toIso8601String();
    await d.delete('activities', where: 'farm_id = ?', whereArgs: [farmId]);
    final batch = d.batch();
    for (final a in data) {
      batch.insert('activities', {
        'activity_id':          a['activity_id'],
        'farm_id':              farmId,
        'land_id':              a['land_id'],
        'land_name':            a['land_name'],
        'activity_name':        a['activity_name'],
        'activity_type':        a['activity_type'],
        'activity_description': a['activity_description'],
        'activity_date_planned':a['activity_date_planned']?.toString(),
        'activity_status':      a['activity_status'] ?? 0,
        'activity_priority':    a['activity_priority'] ?? 1,
        'assigned_to':          a['assigned_to']?.toString(),
        'synced_at':            ts,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getActivities(int farmId) async {
    final d = await db;
    return d.query('activities',
        where: 'farm_id = ?', whereArgs: [farmId],
        orderBy: 'activity_date_planned ASC');
  }

  // Filtro por terreno
  static Future<List<Map<String, dynamic>>> getActivitiesForLand(
      int farmId, int landId) async {
    final d = await db;
    return d.query('activities',
        where: 'farm_id = ? AND land_id = ?',
        whereArgs: [farmId, landId],
        orderBy: 'activity_date_planned ASC');
  }

  // ══════════════════════════════════════════════════════════
  // UTILS
  // ══════════════════════════════════════════════════════════


  // ══════════════════════════════════════════════════════════
  // LAND DETAIL
  // ══════════════════════════════════════════════════════════

  static Future<void> saveLandDetail(int landId, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert('land_detail_cache', {
      'land_id':  landId,
      'raw_json': jsonEncode(data),
      'synced_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getLandDetail(int landId) async {
    final d    = await db;
    final rows = await d.query('land_detail_cache',
        where: 'land_id = ?', whereArgs: [landId], limit: 1);
    if (rows.isEmpty) return null;
    try { return jsonDecode(rows.first['raw_json'] as String); } catch (_) { return null; }
  }

  // ══════════════════════════════════════════════════════════
  // CROP DETAIL
  // ══════════════════════════════════════════════════════════

  static Future<void> saveCropDetail(int cropId, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert('crop_detail_cache', {
      'crop_id':  cropId,
      'raw_json': jsonEncode(data),
      'synced_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getCropDetail(int cropId) async {
    final d    = await db;
    final rows = await d.query('crop_detail_cache',
        where: 'crop_id = ?', whereArgs: [cropId], limit: 1);
    if (rows.isEmpty) return null;
    try { return jsonDecode(rows.first['raw_json'] as String); } catch (_) { return null; }
  }

  // ══════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════════════════

  static Future<void> saveNotifications(int farmId, List<dynamic> data) async {
    final d  = await db;
    final ts = DateTime.now().toIso8601String();
    await d.delete('notifications', where: 'farm_id = ?', whereArgs: [farmId]);
    final batch = d.batch();
    for (final n in data) {
      batch.insert('notifications', {
        'notification_id':    n['notification_id'],
        'farm_id':            farmId,
        'notification_title': n['notification_title'],
        'notification_body':  n['notification_body'],
        'notification_read':  n['notification_read'] ?? 0,
        'created_at':         n['created_at']?.toString(),
        'synced_at':          ts,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getNotifications(int farmId) async {
    final d = await db;
    return d.query('notifications',
        where: 'farm_id = ?', whereArgs: [farmId],
        orderBy: 'created_at DESC');
  }

  static Future<void> markNotificationRead(int notificationId) async {
    final d = await db;
    await d.update('notifications',
        {'notification_read': 1},
        where: 'notification_id = ?', whereArgs: [notificationId]);
  }

  // ══════════════════════════════════════════════════════════
  // MAP DATA
  // ══════════════════════════════════════════════════════════

  static Future<void> saveMapData(int farmId, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert('map_cache', {
      'farm_id':  farmId,
      'raw_json': jsonEncode(data),
      'synced_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getMapData(int farmId) async {
    final d    = await db;
    final rows = await d.query('map_cache',
        where: 'farm_id = ?', whereArgs: [farmId], limit: 1);
    if (rows.isEmpty) return null;
    try { return jsonDecode(rows.first['raw_json'] as String); } catch (_) { return null; }
  }

  // ══════════════════════════════════════════════════════════
  // ACTIVITY DETAIL CACHE
  // ══════════════════════════════════════════════════════════

  static Future<void> saveActivityDetail(int activityId, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert('activity_detail_cache', {
      'activity_id': activityId,
      'raw_json': jsonEncode(data),
      'synced_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getActivityDetail(int activityId) async {
    final d = await db;
    final rows = await d.query('activity_detail_cache',
        where: 'activity_id = ?', whereArgs: [activityId], limit: 1);
    if (rows.isEmpty) return null;
    try { return jsonDecode(rows.first['raw_json'] as String); } catch (_) { return null; }
  }

  // ══════════════════════════════════════════════════════════
  // LIST CACHE (cache genérico para qualquer endpoint de lista)
  // ══════════════════════════════════════════════════════════

  static Future<void> saveList(String key, List<dynamic> data) async {
    final d = await db;
    await d.insert(
      'list_cache',
      {
        'cache_key': key,
        'raw_json': jsonEncode(data),
        'synced_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<dynamic>> getList(String key) async {
    final d = await db;
    final rows = await d.query(
      'list_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    try {
      return jsonDecode(rows.first['raw_json'] as String) as List<dynamic>;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveJson(String key, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert(
      'list_cache',
      {
        'cache_key': key,
        'raw_json': jsonEncode(data),
        'synced_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getJson(String key) async {
    final d = await db;
    final rows = await d.query(
      'list_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['raw_json'] as String)
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════
  // LOCAL WRITES (escritas otimistas — registos ainda não sincronizados)
  // ══════════════════════════════════════════════════════════

  /// Insere uma escrita otimista. Devolve o `local_id` (negativo) que pode
  /// ser usado como ID temporário no UI até o servidor confirmar.
  static Future<int> appendLocalWrite({
    required String entityType,
    required Map<String, dynamic> data,
    required String clientUuid,
    int? parentId,
    String? photoPath,
  }) async {
    final d = await db;
    final id = await d.insert('local_writes', {
      'entity_type': entityType,
      'parent_id':   parentId,
      'client_uuid': clientUuid,
      'raw_json':    jsonEncode(data),
      'photo_path':  photoPath,
      'created_at':  DateTime.now().toIso8601String(),
    });
    // ID temporário que o UI pode usar (negativo para não chocar com IDs do servidor)
    return -id;
  }

  /// Lista todas as escritas otimistas de um tipo, opcionalmente filtradas
  /// por parent_id.
  static Future<List<Map<String, dynamic>>> getLocalWrites({
    required String entityType,
    int? parentId,
  }) async {
    final d = await db;
    final where = StringBuffer('entity_type = ?');
    final args = <dynamic>[entityType];
    if (parentId != null) {
      where.write(' AND parent_id = ?');
      args.add(parentId);
    }
    final rows = await d.query(
      'local_writes',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'created_at ASC',
    );
    return rows.map((r) {
      Map<String, dynamic> data;
      try {
        data = jsonDecode(r['raw_json'] as String) as Map<String, dynamic>;
      } catch (_) {
        data = {};
      }
      // Anexa metadados do registo local (ID temporário negativo etc.)
      return {
        ...data,
        '_local_id':    -(r['local_id'] as int),
        '_client_uuid': r['client_uuid'],
        '_pending':     true,
        '_photo_path':  r['photo_path'],
        '_created_at':  r['created_at'],
      };
    }).toList();
  }

  /// Remove uma escrita otimista (após sincronização bem-sucedida) pelo
  /// `client_uuid`.
  static Future<void> removeLocalWriteByUuid(String clientUuid) async {
    final d = await db;
    await d.delete(
      'local_writes',
      where: 'client_uuid = ?',
      whereArgs: [clientUuid],
    );
  }

  /// Remove uma escrita otimista pelo seu local_id (positivo na BD,
  /// negativo no UI — passa o positivo).
  static Future<void> removeLocalWriteById(int localIdPositive) async {
    final d = await db;
    await d.delete(
      'local_writes',
      where: 'local_id = ?',
      whereArgs: [localIdPositive],
    );
  }

  static Future<int> localWritesCount() async {
    final d = await db;
    final rows = await d.rawQuery('SELECT COUNT(*) AS c FROM local_writes');
    return (rows.first['c'] as int?) ?? 0;
  }

  // ══════════════════════════════════════════════════════════
  // SYNC QUEUE (operações offline)
  // ══════════════════════════════════════════════════════════

  static Future<void> enqueueOperation(String type, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert('sync_queue', {
      'operation_type': type,
      'data': jsonEncode(data),
      'status': 'pending',
      'retries': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final d = await db;
    return d.query('sync_queue',
        where: 'status = ?', whereArgs: ['pending'],
        orderBy: 'created_at ASC');
  }

  static Future<List<Map<String, dynamic>>> getFailedOperations() async {
    final d = await db;
    return d.query('sync_queue',
        where: 'status = ?', whereArgs: ['failed'],
        orderBy: 'created_at DESC');
  }

  static Future<List<Map<String, dynamic>>> getAllOperations() async {
    final d = await db;
    return d.query('sync_queue', orderBy: 'created_at DESC');
  }

  /// Volta a colocar em pending todas as operações com status=failed.
  /// Reset ao contador de retries para nova tentativa limpa.
  static Future<void> requeueFailedOperations() async {
    final d = await db;
    await d.update(
      'sync_queue',
      {'status': 'pending', 'retries': 0, 'error_message': null},
      where: 'status = ?',
      whereArgs: ['failed'],
    );
  }

  static Future<void> deleteOperation(int id) async {
    final d = await db;
    await d.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteFailedOperations() async {
    final d = await db;
    await d.delete('sync_queue', where: 'status = ?', whereArgs: ['failed']);
  }

  static Future<void> markOperationDone(int id) async {
    final d = await db;
    await d.update('sync_queue', {'status': 'done'},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> markOperationFailed(int id, String error) async {
    final d = await db;
    await d.update('sync_queue', {
      'status': 'failed',
      'error_message': error,
    }, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> incrementRetry(int id) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE sync_queue SET retries = retries + 1 WHERE id = ?',
      [id],
    );
  }

  /// Limpa todos os dados (ex: ao fazer logout). Resiliente a tabelas em
  /// falta — instalações antigas podem não ter todas as tabelas criadas.
  static Future<void> clearAll() async {
    final d = await db;
    const tables = [
      'farms', 'lands', 'crops', 'activities',
      'dashboard_cache', 'land_detail_cache', 'crop_detail_cache',
      'notifications', 'map_cache', 'activity_detail_cache',
      'sync_queue', 'local_writes', 'list_cache',
    ];
    for (final t in tables) {
      try { await d.delete(t); } catch (_) {}
    }
  }

  /// Verifica se há dados para uma exploração
  static Future<bool> hasCachedData(int farmId) async {
    final d    = await db;
    final rows = await d.query('dashboard_cache',
        where: 'farm_id = ?', whereArgs: [farmId], limit: 1);
    return rows.isNotEmpty;
  }
}
