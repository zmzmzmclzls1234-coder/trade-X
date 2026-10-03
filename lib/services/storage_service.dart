import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import 'database_service.dart';

class StorageService {
  static Future<Database> get database => DatabaseService.instance.database;

  // Load User Profile from SQLite database with full portfolio & watchlist
  static Future<UserProfile> loadUserProfile() async {
    return await DatabaseService.instance.loadUserProfile();
  }

  // Save User Profile to SQLite database
  static Future<void> saveUserProfile(UserProfile user) async {
    await DatabaseService.instance.saveUserProfile(user);
  }

  // Load portfolio positions for a user directly using SQLite queries
  static Future<List<PortfolioPosition>> loadPortfolio(String userId) async {
    final db = await database;
    final rows = await db.query(
      'portfolio_positions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    return rows.map((row) {
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
  }

  // Save/Upsert a single portfolio position using SQLite
  static Future<void> savePortfolioPosition(String userId, PortfolioPosition position) async {
    final db = await database;
    await db.insert(
      'portfolio_positions',
      {
        'user_id': userId,
        'ticker': position.ticker,
        'stock_name': position.stockName,
        'shares': position.shares,
        'average_price': position.averagePrice,
        'average_price_usd': position.averagePriceUSD,
        'total_cost_usd': position.totalCostUSD,
        'native_currency': position.nativeCurrency,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Delete a portfolio position using SQLite
  static Future<void> removePortfolioPosition(String userId, String ticker) async {
    final db = await database;
    await db.delete(
      'portfolio_positions',
      where: 'user_id = ? AND ticker = ?',
      whereArgs: [userId, ticker],
    );
  }

  // Load watchlist tickers using SQLite
  static Future<List<String>> loadWatchlist(String userId) async {
    final db = await database;
    final rows = await db.query(
      'watchlist',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((r) => r['ticker'] as String).toList();
  }

  // Toggle watchlist in SQLite
  static Future<List<String>> toggleWatchlist(String userId, String ticker) async {
    return await DatabaseService.instance.toggleWatchlist(userId, ticker);
  }

  // Load transactions using SQLite
  static Future<List<TransactionRecord>> loadTransactions({int? limit}) async {
    return await DatabaseService.instance.loadTransactions(limit: limit);
  }

  // Insert a transaction using SQLite
  static Future<void> saveTransaction(TransactionRecord tx) async {
    await DatabaseService.instance.insertTransaction(tx);
  }

  // Save multiple transactions (for compatibility)
  static Future<void> saveTransactions(List<TransactionRecord> transactions) async {
    for (final tx in transactions) {
      await saveTransaction(tx);
    }
  }

  // Reset account in SQLite and reset to ₩1,000,000 cash
  static Future<UserProfile> resetAccount({String? username, String? country, String? currency, String? language}) async {
    return await DatabaseService.instance.resetDatabase(
      username: username,
      country: country,
      currency: currency,
      language: language,
    );
  }
}
