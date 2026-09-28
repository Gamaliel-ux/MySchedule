import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance =
      DatabaseHelper._internal();

  static Database? _database;

  DatabaseHelper._internal();

  // ==========================================================
  // DATABASE INSTANCE
  // ==========================================================

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    return _database!;
  }

  // ==========================================================
  // INITIALIZE DATABASE
  // ==========================================================

  Future<Database> _initDatabase() async {
    final databasePath =
        await getDatabasesPath();

    final path = join(
      databasePath,
      'schedule_planner.db',
    );

    return await openDatabase(
      path,

      // Database version 3
      version: 3,

      onCreate: _createDatabase,

      onUpgrade: _upgradeDatabase,
    );
  }

  // ==========================================================
  // CREATE DATABASE
  // ==========================================================

  Future<void> _createDatabase(
    Database db,
    int version,
  ) async {
    // ========================================================
    // TASKS
    // ========================================================

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        due_date TEXT NOT NULL,
        due_time TEXT NOT NULL,
        priority TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Kuliah',
        completed INTEGER NOT NULL DEFAULT 0,
        reminder_minutes INTEGER NOT NULL DEFAULT 10,
        alarm_sound TEXT NOT NULL DEFAULT 'default_alarm'
      )
    ''');

    // ========================================================
    // SCHEDULES
    // ========================================================

    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        location TEXT,
        reminder_minutes INTEGER NOT NULL DEFAULT 60,
        alarm_sound TEXT NOT NULL DEFAULT 'default_alarm'
      )
    ''');
  }

  // ==========================================================
  // DATABASE UPGRADE
  // ==========================================================

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE tasks
        ADD COLUMN reminder_minutes
        INTEGER NOT NULL DEFAULT 10
      ''');

      await db.execute('''
        ALTER TABLE schedules
        ADD COLUMN reminder_minutes
        INTEGER NOT NULL DEFAULT 10
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE tasks
        ADD COLUMN category
        TEXT NOT NULL DEFAULT 'Kuliah'
      ''');

      await db.execute('''
        ALTER TABLE tasks
        ADD COLUMN alarm_sound
        TEXT NOT NULL DEFAULT 'default_alarm'
      ''');

      await db.execute('''
        ALTER TABLE schedules
        ADD COLUMN alarm_sound
        TEXT NOT NULL DEFAULT 'default_alarm'
      ''');
    }
  }

  // ==========================================================
  // TASK
  // ==========================================================

  // ==========================================================
  // ADD TASK
  // ==========================================================

  Future<int> insertTask(
    Map<String, dynamic> task,
  ) async {
    final db = await database;

    return await db.insert(
      'tasks',
      task,
    );
  }

  // ==========================================================
  // GET ALL TASKS
  // ==========================================================

  Future<List<Map<String, dynamic>>> getTasks() async {
    final db = await database;

    return await db.query(
      'tasks',
      orderBy: 'id DESC',
    );
  }

  // ==========================================================
  // GET TASK BY ID
  // ==========================================================

  Future<Map<String, dynamic>?> getTaskById(
    int id,
  ) async {
    final db = await database;

    final result = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ==========================================================
  // UPDATE TASK
  // ==========================================================

  Future<int> updateTask(
    int id,
    Map<String, dynamic> task,
  ) async {
    final db = await database;

    return await db.update(
      'tasks',
      task,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================================
  // UPDATE TASK COMPLETED STATUS
  // ==========================================================

  Future<int> updateTaskCompleted(int id, bool completed) async {
    final db = await database;

    return await db.update(
      'tasks',
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================================
  // DELETE TASK
  // ==========================================================

  Future<int> deleteTask(
    int id,
  ) async {
    final db = await database;

    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================================
  // SCHEDULE
  // ==========================================================

  // ==========================================================
  // ADD SCHEDULE
  // ==========================================================

  Future<int> insertSchedule(
    Map<String, dynamic> schedule,
  ) async {
    final db = await database;

    return await db.insert(
      'schedules',
      schedule,
    );
  }

  // ==========================================================
  // GET ALL SCHEDULES
  // ==========================================================

  Future<List<Map<String, dynamic>>>
      getSchedules() async {
    final db = await database;

    return await db.query(
      'schedules',
      orderBy: 'id DESC',
    );
  }

  // ==========================================================
  // GET SCHEDULE BY ID
  // ==========================================================

  Future<Map<String, dynamic>?>
      getScheduleById(
    int id,
  ) async {
    final db = await database;

    final result =
        await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ==========================================================
  // UPDATE SCHEDULE
  // ==========================================================

  Future<int> updateSchedule(
    int id,
    Map<String, dynamic> schedule,
  ) async {
    final db = await database;

    return await db.update(
      'schedules',
      schedule,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================================
  // DELETE SCHEDULE
  // ==========================================================

  Future<int> deleteSchedule(
    int id,
  ) async {
    final db = await database;

    return await db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================================
  // CLOSE DATABASE
  // ==========================================================

  Future<void> closeDatabase() async {
    final db = await database;

    await db.close();

    _database = null;
  }
}
