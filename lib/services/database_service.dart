import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'tradepulse_v2.db';
  static const int _dbVersion = 1;

  // Singleton instance
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    return await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. User Profiles table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profiles (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        country TEXT NOT NULL,
        display_currency TEXT NOT NULL,
        language TEXT NOT NULL,
        cash_usd REAL NOT NULL,
        initial_cash_krw REAL NOT NULL,
        total_realized_profit REAL NOT NULL
      )
    ''');

    // 2. Portfolio Positions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS portfolio_positions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        ticker TEXT NOT NULL,
        stock_name TEXT NOT NULL,
        shares REAL NOT NULL,
        average_price REAL NOT NULL,
        average_price_usd REAL NOT NULL,
        total_cost_usd REAL NOT NULL,
        native_currency TEXT NOT NULL,
        UNIQUE(user_id, ticker)
      )
    ''');

    // 3. Transactions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        ticker TEXT NOT NULL,
        stock_name TEXT NOT NULL,
        type TEXT NOT NULL,
        shares REAL NOT NULL,
        price REAL NOT NULL,
        currency TEXT NOT NULL,
        total_amount_native REAL NOT NULL,
        total_amount_usd REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // 4. Watchlist table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS watchlist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        ticker TEXT NOT NULL,
        UNIQUE(user_id, ticker)
      )
    ''');

    // Create index for fast transaction querying
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_user_timestamp ON transactions(user_id, timestamp DESC)
    ''');
  }

  // Check if a registered user exists
  Future<bool> hasUserProfile() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM user_profiles'));
      return (count ?? 0) > 0;
    } catch (_) {
      return false;
    }
  }

  // Load complete UserProfile with portfolio positions & watchlist
  Future<UserProfile> loadUserProfile() async {
    try {
      final db = await database;

      final userMaps = await db.query('user_profiles', limit: 1);
      if (userMaps.isEmpty) {
        // Check if there is data in SharedPreferences to migrate from
        UserProfile initialUser;
        try {
          final prefs = await SharedPreferences.getInstance();
          final userJson = prefs.getString('tradePulse_userProfile_v2');
          if (userJson != null && userJson.isNotEmpty) {
            initialUser = UserProfile.fromJson(json.decode(userJson));
          } else {
            initialUser = createDefaultUser();
          }
        } catch (_) {
          initialUser = createDefaultUser();
        }

        // Guarantee starting assets are never zero
        if (initialUser.cashUSD <= 0) {
          initialUser = initialUser.copyWith(
            cashUSD: 1000000.0 / 1350.0,
            initialCashKRW: 1000000.0,
          );
        }

        await saveUserProfile(initialUser);
        return initialUser;
      }

      final userRow = userMaps.first;
      final userId = userRow['id'] as String;

      // Load portfolio positions for this user
      final posMaps = await db.query(
        'portfolio_positions',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      final portfolio = posMaps.map((row) {
        return PortfolioPosition(
          ticker: row['ticker'] as String,
          stockName: row['stock_name'] as String,
          shares: (row['shares'] as num).toDouble(),
          averagePrice: (row['average_price'] as num).toDouble(),
          averagePriceUSD: (row['average_price_usd'] as num).toDouble(),
          totalCostUSD: (row['total_cost_usd'] as num).toDouble(),
          nativeCurrency: row['native_currency'] as String,
        );
      }).toList();

      // Load watchlist for this user
      final watchMaps = await db.query(
        'watchlist',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      final watchlist = watchMaps.map((row) => row['ticker'] as String).toList();

      double cash = (userRow['cash_usd'] as num?)?.toDouble() ?? 0.0;
      double initialKRW = (userRow['initial_cash_krw'] as num?)?.toDouble() ?? 1000000.0;

      // Bug Fix: If starting cash somehow evaluated to <= 0, restore the correct ₩1,000,000 cash baseline
      if (cash <= 0.0) {
        cash = 1000000.0 / 1350.0;
        if (initialKRW <= 0.0) {
          initialKRW = 1000000.0;
        }
        // Update database immediately
        await db.update(
          'user_profiles',
          {'cash_usd': cash, 'initial_cash_krw': initialKRW},
          where: 'id = ?',
          whereArgs: [userId],
        );
      }

      return UserProfile(
        id: userId,
        username: userRow['username'] as String,
        country: userRow['country'] as String,
        displayCurrency: userRow['display_currency'] as String,
        language: userRow['language'] as String,
        cashUSD: cash,
        initialCashKRW: initialKRW,
        portfolio: portfolio,
        watchlist: watchlist.isNotEmpty ? watchlist : ['005930.KS', 'AAPL', 'NVDA', 'TSLA', '000660.KS'],
        totalRealizedProfit: (userRow['total_realized_profit'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      debugPrint('Error loading user profile from SQLite: $e');
      return createDefaultUser();
    }
  }

  // Load all registered real user profiles from SQLite
  Future<List<UserProfile>> loadAllUserProfiles() async {
    try {
      final db = await database;
      final userMaps = await db.query('user_profiles');
      if (userMaps.isEmpty) {
        final u = await loadUserProfile();
        return [u];
      }

      final List<UserProfile> list = [];
      for (final userRow in userMaps) {
        final userId = userRow['id'] as String;
        final posMaps = await db.query(
          'portfolio_positions',
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        final portfolio = posMaps.map((row) {
          return PortfolioPosition(
            ticker: row['ticker'] as String,
            stockName: row['stock_name'] as String,
            shares: (row['shares'] as num).toDouble(),
            averagePrice: (row['average_price'] as num).toDouble(),
            averagePriceUSD: (row['average_price_usd'] as num).toDouble(),
            totalCostUSD: (row['total_cost_usd'] as num).toDouble(),
            nativeCurrency: row['native_currency'] as String,
          );
        }).toList();

        final watchMaps = await db.query(
          'watchlist',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        final watchlist = watchMaps.map((row) => row['ticker'] as String).toList();

        final cash = (userRow['cash_usd'] as num?)?.toDouble() ?? (1000000.0 / 1350.0);
        final initialKRW = (userRow['initial_cash_krw'] as num?)?.toDouble() ?? 1000000.0;

        list.add(UserProfile(
          id: userId,
          username: userRow['username'] as String,
          country: userRow['country'] as String,
          displayCurrency: userRow['display_currency'] as String,
          language: userRow['language'] as String,
          cashUSD: cash > 0 ? cash : (1000000.0 / 1350.0),
          initialCashKRW: initialKRW > 0 ? initialKRW : 1000000.0,
          portfolio: portfolio,
          watchlist: watchlist,
          totalRealizedProfit: (userRow['total_realized_profit'] as num?)?.toDouble() ?? 0.0,
        ));
      }
      return list;
    } catch (e) {
      debugPrint('Error loading all user profiles: $e');
      return [];
    }
  }

  // Save or update UserProfile and synchronise portfolio & watchlist
  Future<void> saveUserProfile(UserProfile user) async {
    try {
      final db = await database;

      await db.transaction((txn) async {
        // Upsert User Profile
        await txn.insert(
          'user_profiles',
          {
            'id': user.id,
            'username': user.username,
            'country': user.country,
            'display_currency': user.displayCurrency,
            'language': user.language,
            'cash_usd': user.cashUSD > 0 ? user.cashUSD : (1000000.0 / 1350.0),
            'initial_cash_krw': user.initialCashKRW > 0 ? user.initialCashKRW : 1000000.0,
            'total_realized_profit': user.totalRealizedProfit,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Synchronise Portfolio Positions
        await txn.delete(
          'portfolio_positions',
          where: 'user_id = ?',
          whereArgs: [user.id],
        );

        for (final pos in user.portfolio) {
          await txn.insert(
            'portfolio_positions',
            {
              'user_id': user.id,
              'ticker': pos.ticker,
              'stock_name': pos.stockName,
              'shares': pos.shares,
              'average_price': pos.averagePrice,
              'average_price_usd': pos.averagePriceUSD,
              'total_cost_usd': pos.totalCostUSD,
              'native_currency': pos.nativeCurrency,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Synchronise Watchlist
        await txn.delete(
          'watchlist',
          where: 'user_id = ?',
          whereArgs: [user.id],
        );

        for (final ticker in user.watchlist) {
          await txn.insert(
            'watchlist',
            {
              'user_id': user.id,
              'ticker': ticker,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      // Mirror to SharedPreferences as backup
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tradePulse_userProfile_v2', json.encode(user.toJson()));
      } catch (_) {}
    } catch (e) {
      debugPrint('Error saving user profile to SQLite: $e');
    }
  }

  // Insert a transaction record into SQLite
  Future<void> insertTransaction(TransactionRecord tx) async {
    try {
      final db = await database;
      await db.insert(
        'transactions',
        {
          'id': tx.id,
          'user_id': tx.userId,
          'ticker': tx.ticker,
          'stock_name': tx.stockName,
          'type': tx.type,
          'shares': tx.shares,
          'price': tx.price,
          'currency': tx.currency,
          'total_amount_native': tx.totalAmountNative,
          'total_amount_usd': tx.totalAmountUSD,
          'timestamp': tx.timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting transaction into SQLite: $e');
    }
  }

  // Load all transactions ordered newest to oldest
  Future<List<TransactionRecord>> loadTransactions({int? limit}) async {
    try {
      final db = await database;
      final maps = await db.query(
        'transactions',
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return maps.map((row) {
        return TransactionRecord(
          id: row['id'] as String,
          userId: row['user_id'] as String,
          ticker: row['ticker'] as String,
          stockName: row['stock_name'] as String,
          type: row['type'] as String,
          shares: (row['shares'] as num).toDouble(),
          price: (row['price'] as num).toDouble(),
          currency: row['currency'] as String,
          totalAmountNative: (row['total_amount_native'] as num).toDouble(),
          totalAmountUSD: (row['total_amount_usd'] as num).toDouble(),
          timestamp: row['timestamp'] as String,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading transactions from SQLite: $e');
      return [];
    }
  }

  // Toggle stock in watchlist
  Future<List<String>> toggleWatchlist(String userId, String ticker) async {
    try {
      final db = await database;
      final existing = await db.query(
        'watchlist',
        where: 'user_id = ? AND ticker = ?',
        whereArgs: [userId, ticker],
      );

      if (existing.isNotEmpty) {
        await db.delete(
          'watchlist',
          where: 'user_id = ? AND ticker = ?',
          whereArgs: [userId, ticker],
        );
      } else {
        await db.insert(
          'watchlist',
          {'user_id': userId, 'ticker': ticker},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final all = await db.query(
        'watchlist',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return all.map((r) => r['ticker'] as String).toList();
    } catch (e) {
      debugPrint('Error toggling watchlist in SQLite: $e');
      return [];
    }
  }

  // Reset entire database back to default initial user profile (1,000,000 KRW baseline)
  Future<UserProfile> resetDatabase({String? username, String? country, String? currency, String? language}) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('user_profiles');
        await txn.delete('portfolio_positions');
        await txn.delete('transactions');
        await txn.delete('watchlist');
      });

      // Clear backup storage
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('tradePulse_transactions_v2');
      } catch (_) {}

      final defaultUser = createDefaultUser(
        username: username,
        country: country,
        currency: currency,
        language: language,
      );
      await saveUserProfile(defaultUser);
      return defaultUser;
    } catch (e) {
      debugPrint('Error resetting SQLite database: $e');
      return createDefaultUser(
        username: username,
        country: country,
        currency: currency,
        language: language,
      );
    }
  }

  // Canonical default user constructor: exactly ₩1,000,000 ($740.74 USD)
  static UserProfile createDefaultUser({
    String? username,
    String? country,
    String? currency,
    String? language,
  }) {
    return UserProfile(
      id: 'investor_${DateTime.now().millisecondsSinceEpoch}',
      username: username ?? 'Investor',
      country: country ?? 'KR',
      displayCurrency: currency ?? 'KRW',
      language: language ?? (country == 'KR' ? 'ko' : 'en'),
      cashUSD: 1000000.0 / 1350.0, // Initial ₩1,000,000 cash (~$740.74 USD)
      initialCashKRW: 1000000.0,
      portfolio: [],
      watchlist: ['005930.KS', 'AAPL', 'NVDA', 'TSLA', '000660.KS'],
      totalRealizedProfit: 0.0,
    );
  }
}
