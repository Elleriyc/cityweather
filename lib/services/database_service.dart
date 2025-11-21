import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FavoriteCity {
  final int? id;
  final String name;
  final String country;
  final double latitude;
  final double longitude;
  final String? admin1; // Région/État

  FavoriteCity({
    this.id,
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    this.admin1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'admin1': admin1,
    };
  }

  factory FavoriteCity.fromMap(Map<String, dynamic> map) {
    return FavoriteCity(
      id: map['id'],
      name: map['name'],
      country: map['country'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      admin1: map['admin1'],
    );
  }

  factory FavoriteCity.fromApiData(Map<String, dynamic> cityData) {
    return FavoriteCity(
      name: cityData['name'],
      country: cityData['country'] ?? '',
      latitude: (cityData['latitude'] as num).toDouble(),
      longitude: (cityData['longitude'] as num).toDouble(),
      admin1: cityData['admin1'],
    );
  }
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  static bool _initialized = false;

  DatabaseService._init();

  Future<Database> get database async {
    if (!_initialized) {
      if (kIsWeb) {
        databaseFactory = databaseFactoryFfiWeb;
      }
      _initialized = true;
    }
    
    if (_database != null) return _database!;
    _database = await _initDB('favorites.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        country TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        admin1 TEXT
      )
    ''');
  }

  Future<int> addFavorite(FavoriteCity city) async {
    final db = await database;
    
    final count = await getFavoritesCount();
    if (count >= 10) {
      throw Exception('Maximum de 10 villes favorites atteint');
    }
    
    final exists = await isFavorite(city.name, city.country);
    if (exists) {
      throw Exception('Cette ville est déjà dans les favoris');
    }
    
    return await db.insert('favorites', city.toMap());
  }

  Future<List<FavoriteCity>> getFavorites() async {
    final db = await database;
    final result = await db.query('favorites', orderBy: 'name ASC');
    return result.map((map) => FavoriteCity.fromMap(map)).toList();
  }

  Future<int> getFavoritesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM favorites');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> isFavorite(String name, String country) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'name = ? AND country = ?',
      whereArgs: [name, country],
    );
    return result.isNotEmpty;
  }

  Future<int> deleteFavorite(int id) async {
    final db = await database;
    return await db.delete(
      'favorites',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
