import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../models/user.dart';
import '../models/alert_notification.dart';
import '../services/database_service.dart';
import '../services/market_data_service.dart';
import '../services/alert_service.dart';
import '../i18n/translations.dart';

class AppProvider with ChangeNotifier {
  static const String _onboardingKey = 'tradePulse_hasCompletedOnboarding';

  // Synchronously initialize with verified starting assets (1,000,000 KRW = ~$740.74 USD)
  UserProfile _user = UserProfile(
    id: 'investor_default',
    username: 'Investor',
    country: 'KR',
    displayCurrency: 'KRW',
    language: 'ko',
    cashUSD: 1000000.0 / 1353.68,
    initialCashKRW: 1000000.0,
    portfolio: [],
    watchlist: ['005930.KS', 'AAPL', 'NVDA', 'TSLA', '000660.KS'],
    totalRealizedProfit: 0.0,
  );

  List<TransactionRecord> _transactions = [];
  
  // Real in-memory quotes verified against real API
  final Map<String, StockQuote> _quotes = MarketDataService.getAllQuotes();
  
  Map<String, double> _rates = {
    'USD': 1.0,
    'KRW': 1353.68,
    'JPY': 157.39,
    'EUR': 0.88,
    'GBP': 0.76,
  };
  bool _isLoading = false;
  bool _isCheckingOnboarding = true;
  bool _hasCompletedOnboarding = false;
  String _activeLanguage = 'ko';
  
  Timer? _apiPollTimer;
  Timer? _secondsTicker;
  DateTime _lastApiFetchTime = DateTime.now();
  int _secondsSinceLastFetch = 0;

  UserProfile? get user => _user;
  List<TransactionRecord> get transactions => _transactions;
  Map<String, StockQuote> get quotes => _quotes;
  Map<String, double> get rates => _rates;
  bool get isLoading => _isLoading;
  bool get isCheckingOnboarding => _isCheckingOnboarding;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  String get activeLanguage => _activeLanguage;
  int get secondsSinceLastFetch => _secondsSinceLastFetch;
  DateTime get lastApiFetchTime => _lastApiFetchTime;

  bool get hourlyAlertsEnabled => AlertService.instance.isEnabled;
  List<AlertNotification> get alerts => AlertService.instance.alerts;

  String tr(String key) => AppTranslations.get(key, _activeLanguage);

  // Return StockQuote for any company
  StockQuote getQuote(String ticker) {
    if (_quotes.containsKey(ticker)) {
      return _quotes[ticker]!;
    }
    final q = MarketDataService.getQuote(ticker);
    _quotes[ticker] = q;
    return q;
  }

  AppProvider() {
    init();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _hasCompletedOnboarding = prefs.getBool(_onboardingKey) ?? false;

      final hasDbUser = await DatabaseService.instance.hasUserProfile();
      if (hasDbUser) {
        _hasCompletedOnboarding = true;
        await prefs.setBool(_onboardingKey, true);
      }

      if (_hasCompletedOnboarding) {
        final loadedUser = await DatabaseService.instance.loadUserProfile();
        _user = loadedUser;
        _transactions = await DatabaseService.instance.loadTransactions();
        _activeLanguage = _user.language;
      }

      await AlertService.instance.init();
      _isCheckingOnboarding = false;
      _rates = await MarketDataService.fetchCurrencyRates();
      await refreshData();
      startPolling();

      // Start background hourly alert monitoring for owned stocks
      AlertService.instance.startHourlyMonitoring(onTrigger: () {
        triggerHourlyAlert(forceTest: false);
      });
    } catch (e) {
      debugPrint('AppProvider init error: $e');
      _isCheckingOnboarding = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create account during Onboarding
  Future<void> createAccount({
    required String username,
    required String country,
    required String currency,
    required String language,
  }) async {
    final initialRate = _rates['KRW'] ?? 1353.68;
    final newUser = UserProfile(
      id: 'investor_${DateTime.now().millisecondsSinceEpoch}',
      username: username.trim().isEmpty ? 'Investor' : username.trim(),
      country: country,
      displayCurrency: currency,
      language: language,
      cashUSD: 1000000.0 / initialRate,
      initialCashKRW: 1000000.0,
      portfolio: [],
      watchlist: country == 'KR'
          ? ['005930.KS', '000660.KS', 'NVDA', 'AAPL', 'TSLA']
          : ['NVDA', 'AAPL', 'MSFT', 'AMZN', 'TSLA'],
      totalRealizedProfit: 0.0,
    );

    _user = newUser;
    _activeLanguage = language;
    _hasCompletedOnboarding = true;

    // Save to SQLite and local prefs
    await DatabaseService.instance.saveUserProfile(newUser);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);

    await refreshData();
    notifyListeners();
  }

  // Real market data polling respecting API limits (every 20s) with 1s elapsed timer
  void startPolling() {
    _apiPollTimer?.cancel();
    _secondsTicker?.cancel();

    // 1-second elapsed counter for UI freshness display
    _secondsTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsSinceLastFetch = DateTime.now().difference(_lastApiFetchTime).inSeconds;
      notifyListeners();
    });

    // 20-second real API fetch
    _apiPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      refreshData();
    });
  }

  // Refresh real quotes for watchlist, portfolio, and active market leaders
  Future<void> refreshData() async {
    final tickers = <String>{
      '005930.KS', 'NVDA', 'AAPL', '000660.KS', 'TSLA', 'MSFT', 'AMZN', '7203.T', '6758.T', 'SAP.DE', 'MC.PA', 'AZN.L'
    };
    tickers.addAll(_user.portfolio.map((p) => p.ticker));
    tickers.addAll(_user.watchlist);

    try {
      final newQuotes = await MarketDataService.fetchQuotes(tickers.toList());
      _quotes.addAll(newQuotes);
      _lastApiFetchTime = DateTime.now();
      _secondsSinceLastFetch = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Quote refresh error: $e');
    }
  }

  // Fetch or refresh a single stock quote on-demand with instant state update
  Future<StockQuote> fetchQuoteForTicker(String ticker) async {
    try {
      final q = await MarketDataService.fetchSingleQuote(ticker);
      _quotes[ticker] = q;
      notifyListeners();
      return q;
    } catch (e) {
      debugPrint('Error fetching quote for $ticker: $e');
      return getQuote(ticker);
    }
  }

  // Fetch or refresh quotes for a list of securities (e.g. current page/category in MarketsTab)
  Future<void> fetchQuotesForSecurities(List<String> tickers) async {
    if (tickers.isEmpty) return;
    try {
      final results = await MarketDataService.fetchQuotes(tickers);
      _quotes.addAll(results);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching batch quotes: $e');
    }
  }

  // Trigger Hourly Portfolio Alert (either automatic or manual test)
  Future<List<AlertNotification>> triggerHourlyAlert({bool forceTest = false}) async {
    final results = await AlertService.instance.checkPortfolioAlerts(
      user: _user,
      quotes: _quotes,
      rates: _rates,
      language: _activeLanguage,
      forceTest: forceTest,
    );
    notifyListeners();
    return results;
  }

  Future<void> toggleHourlyAlerts(bool enabled) async {
    await AlertService.instance.setEnabled(enabled);
    notifyListeners();
  }

  Future<void> clearAlerts() async {
    await AlertService.instance.clearAlerts();
    notifyListeners();
  }

  // Real Virtual Stock Order Execution (BUY / SELL)
  Future<String> executeTrade({
    required String ticker,
    required String type, // BUY or SELL
    required double shares,
  }) async {
    if (shares <= 0) throw Exception('Quantity must be greater than zero');

    final quote = getQuote(ticker);
    if (quote.price == null || quote.price! <= 0 || quote.dataStatus == 'unavailable') {
      throw Exception('Trading unavailable: current market price could not be verified from provider.');
    }

    final currentPriceNative = quote.price!;
    final nativeCurrency = quote.currency;
    final rateToUSD = _rates[nativeCurrency.toUpperCase()] ?? 1.0;
    final pricePerShareUSD = currentPriceNative / rateToUSD;
    final totalUSD = pricePerShareUSD * shares;

    final now = DateTime.now();
    final timeStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    var updatedPortfolio = List<PortfolioPosition>.from(_user.portfolio);
    double newCashUSD = _user.cashUSD;
    double newRealizedProfit = _user.totalRealizedProfit;

    if (type == 'BUY') {
      if (newCashUSD < totalUSD) {
        final shortUSD = totalUSD - newCashUSD;
        final curr = _user.displayCurrency;
        final rate = _rates[curr] ?? 1.0;
        final shortDisplay = shortUSD * rate;
        throw Exception('Insufficient virtual cash balance. Needs ${shortDisplay.toStringAsFixed(0)} $curr more.');
      }

      newCashUSD -= totalUSD;

      final existingIndex = updatedPortfolio.indexWhere((p) => p.ticker == ticker);
      if (existingIndex >= 0) {
        final existing = updatedPortfolio[existingIndex];
        final totalShares = existing.shares + shares;
        final totalCost = existing.totalCostUSD + totalUSD;
        final avgUSD = totalCost / totalShares;
        final avgNative = avgUSD * rateToUSD;

        updatedPortfolio[existingIndex] = existing.copyWith(
          shares: totalShares,
          averagePrice: avgNative,
          averagePriceUSD: avgUSD,
          totalCostUSD: totalCost,
        );
      } else {
        updatedPortfolio.add(PortfolioPosition(
          ticker: ticker,
          stockName: quote.name,
          shares: shares,
          averagePrice: currentPriceNative,
          averagePriceUSD: pricePerShareUSD,
          totalCostUSD: totalUSD,
          nativeCurrency: nativeCurrency,
        ));
      }
    } else if (type == 'SELL') {
      final existingIndex = updatedPortfolio.indexWhere((p) => p.ticker == ticker);
      if (existingIndex < 0 || updatedPortfolio[existingIndex].shares < shares) {
        final owned = existingIndex >= 0 ? updatedPortfolio[existingIndex].shares : 0.0;
        throw Exception('Insufficient shares to sell. You currently own $owned shares of $ticker.');
      }

      final existing = updatedPortfolio[existingIndex];
      final costFraction = (existing.totalCostUSD / existing.shares) * shares;
      final profitUSD = totalUSD - costFraction;

      newCashUSD += totalUSD;
      newRealizedProfit += profitUSD;

      final remainingShares = existing.shares - shares;
      if (remainingShares <= 0) {
        updatedPortfolio.removeAt(existingIndex);
      } else {
        updatedPortfolio[existingIndex] = existing.copyWith(
          shares: remainingShares,
          totalCostUSD: existing.totalCostUSD - costFraction,
        );
      }
    } else {
      throw Exception('Invalid order type: $type');
    }

    // Record Transaction
    final tx = TransactionRecord(
      id: 'tx_${now.millisecondsSinceEpoch}_${ticker.replaceAll('.', '_')}',
      userId: _user.id,
      ticker: ticker,
      stockName: quote.name,
      type: type,
      shares: shares,
      price: currentPriceNative,
      currency: nativeCurrency,
      totalAmountNative: currentPriceNative * shares,
      totalAmountUSD: totalUSD,
      timestamp: timeStr,
    );

    _transactions.insert(0, tx);

    _user = _user.copyWith(
      cashUSD: newCashUSD,
      portfolio: updatedPortfolio,
      totalRealizedProfit: newRealizedProfit,
    );

    // Save to SQLite database layer immediately
    await DatabaseService.instance.insertTransaction(tx);
    await DatabaseService.instance.saveUserProfile(_user);

    notifyListeners();

    final successMsg = type == 'BUY'
        ? 'Bought ${shares.toInt()} shares of ${quote.name} ($ticker)'
        : 'Sold ${shares.toInt()} shares of ${quote.name} ($ticker)';
    return successMsg;
  }

  // Toggle Watchlist with SQLite persistence
  Future<void> toggleWatchlist(String ticker) async {
    final updatedList = await DatabaseService.instance.toggleWatchlist(_user.id, ticker);
    _user = _user.copyWith(watchlist: updatedList);
    notifyListeners();
  }

  // Update Preferred Currency
  Future<void> updateCurrency(String currency) async {
    _user = _user.copyWith(displayCurrency: currency);
    await DatabaseService.instance.saveUserProfile(_user);
    notifyListeners();
  }

  // Update Language
  Future<void> updateLanguage(String lang) async {
    _activeLanguage = lang;
    _user = _user.copyWith(language: lang);
    await DatabaseService.instance.saveUserProfile(_user);
    notifyListeners();
  }

  // Reset Account back to initial ₩1,000,000 cash in SQLite
  Future<void> resetAccount() async {
    _user = await DatabaseService.instance.resetDatabase(
      username: _user.username,
      country: _user.country,
      currency: _user.displayCurrency,
      language: _user.language,
    );
    _transactions = [];
    await clearAlerts();
    await refreshData();
    notifyListeners();
  }

  // Portfolio calculations
  double get totalStockValueUSD {
    if (_user.portfolio.isEmpty) return 0.0;
    double sum = 0.0;
    for (final pos in _user.portfolio) {
      final q = getQuote(pos.ticker);
      if (q.price != null && q.price! > 0) {
        final rate = _rates[pos.nativeCurrency.toUpperCase()] ?? 1.0;
        final priceUSD = q.price! / rate;
        sum += pos.shares * priceUSD;
      } else {
        sum += pos.shares * pos.averagePriceUSD;
      }
    }
    return sum;
  }

  double get totalPortfolioValueUSD {
    return _user.cashUSD + totalStockValueUSD;
  }

  double get initialCashUSD {
    return _user.initialCashKRW / (_rates['KRW'] ?? 1353.68);
  }

  double get totalProfitLossUSD {
    return totalPortfolioValueUSD - initialCashUSD;
  }

  double get totalReturnPercent {
    if (initialCashUSD <= 0) return 0.0;
    return (totalProfitLossUSD / initialCashUSD) * 100.0;
  }

  // Format value into user's display currency
  String formatValue(double valueUSD, {bool showSign = false}) {
    final curr = _user.displayCurrency;
    final rate = _rates[curr] ?? 1.0;
    final converted = valueUSD * rate;
    final sign = showSign && converted > 0 ? '+' : '';

    if (curr == 'KRW' || curr == 'JPY') {
      final formatted = converted.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      final symbol = curr == 'KRW' ? '₩' : '¥';
      return '$sign$symbol$formatted';
    } else {
      final symbol = curr == 'EUR' ? '€' : (curr == 'GBP' ? '£' : '\$');
      return '$sign$symbol${converted.toStringAsFixed(2)}';
    }
  }

  // Format stock price with null-safety
  String formatStockPrice(double? price, String currency) {
    if (price == null || price <= 0) {
      return '—';
    }
    if (currency == 'KRW' || currency == 'JPY' || currency == 'VND') {
      return price.toStringAsFixed(0);
    }
    return price.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _apiPollTimer?.cancel();
    _secondsTicker?.cancel();
    AlertService.instance.dispose();
    super.dispose();
  }
}
