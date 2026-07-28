import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ascend.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE player (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ign TEXT NOT NULL,
        level INTEGER DEFAULT 1,
        xp INTEGER DEFAULT 0,
        shop_unlock_level INTEGER DEFAULT 30,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        target_outcome TEXT,
        deadline TEXT,
        status TEXT DEFAULT 'active',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE quests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER,
        description TEXT NOT NULL,
        quest_type TEXT DEFAULT 'daily',
        target_amount REAL DEFAULT 1,
        current_amount REAL DEFAULT 0,
        unit TEXT DEFAULT 'unit',
        xp_reward INTEGER DEFAULT 50,
        status TEXT DEFAULT 'active',
        quest_date TEXT,
        expires_at TEXT,
        FOREIGN KEY (goal_id) REFERENCES goals (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE proof (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quest_id INTEGER,
        file_path TEXT NOT NULL,
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (quest_id) REFERENCES quests (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE buffs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        xp_bonus_percent INTEGER DEFAULT 0,
        unlocked_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE completion_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quest_id INTEGER,
        completed_on TEXT,
        was_success INTEGER,
        xp_change INTEGER,
        FOREIGN KEY (quest_id) REFERENCES quests (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE shop_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        xp_cost INTEGER NOT NULL,
        redeemed_count INTEGER DEFAULT 0
      )
    ''');
  }

  // ---- Player ----

  Future<Map<String, dynamic>?> getPlayer() async {
    final db = await database;
    final rows = await db.query('player', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> createPlayer(String ign) async {
    final db = await database;
    return await db.insert('player', {'ign': ign});
  }

  Future<void> updatePlayerXp(int playerId, int newXp, int newLevel) async {
    final db = await database;
    await db.update(
      'player',
      {'xp': newXp, 'level': newLevel},
      where: 'id = ?',
      whereArgs: [playerId],
    );
  }

  // ---- Goals ----

  Future<List<Map<String, dynamic>>> getActiveGoals() async {
    final db = await database;
    return await db.query('goals', where: 'status = ?', whereArgs: ['active']);
  }

  Future<int> addGoal(String name, String category, String? targetOutcome, String? deadline) async {
    final db = await database;
    return await db.insert('goals', {
      'name': name,
      'category': category,
      'target_outcome': targetOutcome,
      'deadline': deadline,
    });
  }

  // ---- Quests ----

  Future<List<Map<String, dynamic>>> getTodaysQuests(String todayStr) async {
    final db = await database;
    return await db.query('quests', where: 'quest_date = ? AND status = ?', whereArgs: [todayStr, 'active']);
  }

  Future<int> addQuest(Map<String, dynamic> quest) async {
    final db = await database;
    return await db.insert('quests', quest);
  }

  Future<void> logProgress(int questId, double amountToAdd) async {
    final db = await database;
    final rows = await db.query('quests', where: 'id = ?', whereArgs: [questId]);
    if (rows.isEmpty) return;
    final current = (rows.first['current_amount'] as num).toDouble();
    final updated = current + amountToAdd;
    await db.update('quests', {'current_amount': updated}, where: 'id = ?', whereArgs: [questId]);
  }

  Future<void> completeQuest(int questId) async {
    final db = await database;
    await db.update('quests', {'status': 'completed'}, where: 'id = ?', whereArgs: [questId]);
  }

  Future<void> failQuest(int questId) async {
    final db = await database;
    await db.update('quests', {'status': 'failed'}, where: 'id = ?', whereArgs: [questId]);
  }

  // ---- Buffs ----

  Future<List<Map<String, dynamic>>> getBuffs() async {
    final db = await database;
    return await db.query('buffs');
  }

  Future<void> addBuff(String name, String description, int xpBonusPercent) async {
    final db = await database;
    await db.insert('buffs', {
      'name': name,
      'description': description,
      'xp_bonus_percent': xpBonusPercent,
    });
  }

  // ---- Completion history (used for AI trend analysis) ----

  Future<void> logHistory(int questId, bool success, int xpChange) async {
    final db = await database;
    await db.insert('completion_history', {
      'quest_id': questId,
      'completed_on': DateTime.now().toIso8601String(),
      'was_success': success ? 1 : 0,
      'xp_change': xpChange,
    });
  }

  Future<double> getRecentCompletionRate(int days) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final rows = await db.query('completion_history', where: 'completed_on >= ?', whereArgs: [cutoff]);
    if (rows.isEmpty) return 1.0;
    final successCount = rows.where((r) => r['was_success'] == 1).length;
    return successCount / rows.length;
  }

  // ---- Shop ----

  Future<List<Map<String, dynamic>>> getShopItems() async {
    final db = await database;
    return await db.query('shop_items');
  }

  Future<void> setShopItems(List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.delete('shop_items');
    for (final item in items) {
      await db.insert('shop_items', item);
    }
  }
}
