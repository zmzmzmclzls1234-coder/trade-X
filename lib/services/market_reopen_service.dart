import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/market_reopen_summary.dart';
import '../models/news_video.dart';
import '../models/stock.dart';
import '../models/user.dart';
import 'market_data_service.dart';
import 'news_service.dart';
import 'company_repository.dart';

class MarketReopenService {
  static final MarketReopenService instance = MarketReopenService._internal();
  MarketReopenService._internal();

  static const String _baselinePrefKey = 'tradePulse_market_reopen_baseline_v1';
  static const String _enabledPrefKey = 'tradePulse_market_reopen_enabled_v1';
  static const String _lastActivePrefKey = 'tradePulse_last_active_timestamp_ms';

  bool _isEnabled = true;
  bool _isEvaluating = false;
  bool _hasShownInCurrentSession = false;
  DateTime _lastActiveTime = DateTime.now();
  MarketSessionBaseline? _cachedBaseline;

  // Minimum absence in minutes before triggering summary (e.g. 5 minutes)
  static const int minAbsenceMinutes = 5;
  // Significance threshold for stock price movement percentage (0.25%)
  static const double significanceThresholdPercent = 0.25;

  bool get isEnabled => _isEnabled;
  bool get hasShownInCurrentSession => _hasShownInCurrentSession;
  DateTime get lastActiveTime => _lastActiveTime;
  MarketSessionBaseline? get currentBaseline => _cachedBaseline;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_enabledPrefKey) ?? true;

      final lastMs = prefs.getInt(_lastActivePrefKey);
      if (lastMs != null && lastMs > 0) {
        _lastActiveTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }

      final rawBaseline = prefs.getString(_baselinePrefKey);
      if (rawBaseline != null && rawBaseline.isNotEmpty) {
        _cachedBaseline = MarketSessionBaseline.fromJson(jsonDecode(rawBaseline));
      }
    } catch (e) {
      debugPrint('[MarketReopenService] init error: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledPrefKey, enabled);
  }

  /// Called when the app transitions to background/paused
  Future<void> recordAppPaused(UserProfile user, Map<String, StockQuote> quotes, Map<String, double> rates) async {
    _lastActiveTime = DateTime.now();
    _hasShownInCurrentSession = false; // Reset so next meaningful reopen can evaluate

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastActivePrefKey, _lastActiveTime.millisecondsSinceEpoch);
      await saveCurrentAsBaseline(user, quotes, rates);
    } catch (e) {
      debugPrint('[MarketReopenService] recordAppPaused error: $e');
    }
  }

  /// Saves the current market and portfolio state as the baseline for future comparisons
  Future<void> saveCurrentAsBaseline(
    UserProfile user,
    Map<String, StockQuote> quotes,
    Map<String, double> rates,
  ) async {
    final now = DateTime.now();
    final prices = <String, double>{};
    final currencies = <String, String>{};

    double currentStockValueUSD = 0.0;
    for (final pos in user.portfolio) {
      final q = quotes[pos.ticker];
      final price = (q?.price != null && q!.price! > 0) ? q.price! : pos.averagePrice;
      prices[pos.ticker] = price;
      currencies[pos.ticker] = pos.nativeCurrency;

      final rate = rates[pos.nativeCurrency.toUpperCase()] ?? 1.0;
      currentStockValueUSD += pos.shares * (price / rate);
    }

    for (final ticker in user.watchlist) {
      if (!prices.containsKey(ticker)) {
        final q = quotes[ticker];
        if (q?.price != null && q!.price! > 0) {
          prices[ticker] = q.price!;
          currencies[ticker] = q.currency;
        }
      }
    }

    final totalUSD = user.cashUSD + currentStockValueUSD;

    _cachedBaseline = MarketSessionBaseline(
      timestampMs: now.millisecondsSinceEpoch,
      portfolioTotalUSD: totalUSD,
      stockValueUSD: currentStockValueUSD,
      cashUSD: user.cashUSD,
      stockPrices: prices,
      stockCurrencies: currencies,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_baselinePrefKey, jsonEncode(_cachedBaseline!.toJson()));
    } catch (e) {
      debugPrint('[MarketReopenService] saveCurrentAsBaseline error: $e');
    }
  }

  /// Helper to determine the country for market hours inspection
  String _getCountryForTicker(String ticker) {
    final comp = CompanyRepository.instance.findCompany(ticker);
    if (comp != null && comp.country.isNotEmpty) {
      return comp.country.toUpperCase();
    }
    final upper = ticker.toUpperCase();
    if (upper.endsWith('.KS') || upper.endsWith('.KQ')) return 'KR';
    if (upper.endsWith('.T')) return 'JP';
    if (upper.endsWith('.DE') || upper.endsWith('.F')) return 'DE';
    if (upper.endsWith('.L')) return 'GB';
    if (upper.endsWith('.PA') || upper.endsWith('.AS')) return 'FR';
    return 'US';
  }

  /// Generates the market comparison summary between the stored baseline and live data
  Future<MarketReopenSummary?> evaluateSummary({
    required UserProfile user,
    required Map<String, StockQuote> currentQuotes,
    required Map<String, double> rates,
    required String language,
    bool force = false,
  }) async {
    if (!_isEnabled && !force) return null;
    if (_hasShownInCurrentSession && !force) return null;
    if (_isEvaluating) return null;

    final now = DateTime.now();

    // Check absence threshold
    if (!force) {
      final elapsedMinutes = now.difference(_lastActiveTime).inMinutes;
      if (elapsedMinutes < minAbsenceMinutes) {
        return null; // Not absent long enough
      }
    }

    _isEvaluating = true;

    try {
      // If no stored baseline exists, establish current state as baseline and exit
      if (_cachedBaseline == null) {
        await saveCurrentAsBaseline(user, currentQuotes, rates);
        return null;
      }

      final baseline = _cachedBaseline!;
      final baselineTimestamp = DateTime.fromMillisecondsSinceEpoch(baseline.timestampMs);
      final sessionElapsedMinutes = now.difference(baselineTimestamp).inMinutes;

      // Collect tracked tickers: user holdings + watchlist
      final trackedTickers = <String>{};
      final heldTickersMap = <String, double>{}; // ticker -> shares
      for (final p in user.portfolio) {
        trackedTickers.add(p.ticker);
        heldTickersMap[p.ticker] = p.shares;
      }
      for (final w in user.watchlist) {
        trackedTickers.add(w);
      }

      // If user has no holdings and no watchlist, add top global leaders as reference
      if (trackedTickers.isEmpty) {
        trackedTickers.addAll(['005930.KS', 'AAPL', 'NVDA', '7203.T', 'SAP.DE', 'MC.PA']);
      }

      // Fetch fresh quotes for all tracked stocks
      Map<String, StockQuote> freshQuotes = {};
      try {
        freshQuotes = await MarketDataService.fetchQuotes(trackedTickers.toList());
      } catch (e) {
        debugPrint('[MarketReopenService] Failed to retrieve fresh quotes: $e');
        // Do NOT overwrite baseline on failure. Return unavailable state
        return MarketReopenSummary.unavailable(
          message: 'Unable to retrieve fresh market data. Check your internet connection.',
          lastSessionTimestamp: baselineTimestamp,
        );
      }

      // Calculate current portfolio value using existing accounting logic
      double currentStockValueUSD = 0.0;
      for (final pos in user.portfolio) {
        final q = freshQuotes[pos.ticker] ?? currentQuotes[pos.ticker];
        final price = (q?.price != null && q!.price! > 0) ? q.price! : pos.averagePrice;
        final rate = rates[pos.nativeCurrency.toUpperCase()] ?? 1.0;
        currentStockValueUSD += pos.shares * (price / rate);
      }
      final currentPortfolioValueUSD = user.cashUSD + currentStockValueUSD;
      final portfolioChangeUSD = currentPortfolioValueUSD - baseline.portfolioTotalUSD;
      final portfolioChangePercent = baseline.portfolioTotalUSD > 0
          ? (portfolioChangeUSD / baseline.portfolioTotalUSD) * 100.0
          : 0.0;

      // Analyze price movements against the stored baseline
      final movements = <StockPriceMovement>[];
      bool foundSignificantStockChange = false;

      for (final ticker in trackedTickers) {
        final prevPrice = baseline.stockPrices[ticker];
        final freshQuote = freshQuotes[ticker] ?? currentQuotes[ticker];
        final currentPrice = freshQuote?.price;

        // Skip missing or invalid prices - NEVER assume 0 or 100% change for missing data!
        if (freshQuote == null || prevPrice == null || prevPrice <= 0 || currentPrice == null || currentPrice <= 0) {
          continue;
        }

        final absDiff = currentPrice - prevPrice;
        final pctDiff = (absDiff / prevPrice) * 100.0;

        final isHolding = heldTickersMap.containsKey(ticker);
        final isWatchlist = user.watchlist.contains(ticker);
        final country = _getCountryForTicker(ticker);
        final isOpen = MarketDataService.isMarketOpen(country);

        String? closureNotice;
        if (!isOpen) {
          closureNotice = language == 'ko'
              ? '장 마감: 최근 종가 반영'
              : 'Market closed; latest closing price shown';
        }

        if (pctDiff.abs() >= significanceThresholdPercent) {
          foundSignificantStockChange = true;
        }

        final company = CompanyRepository.instance.findCompany(ticker);
        final String resolvedName;
        if (freshQuote != null && freshQuote.name.isNotEmpty) {
          resolvedName = freshQuote.name;
        } else if (company != null && company.name.isNotEmpty) {
          resolvedName = company.name;
        } else {
          resolvedName = ticker;
        }

        final String resolvedCurrency;
        if (freshQuote != null && freshQuote.currency.isNotEmpty) {
          resolvedCurrency = freshQuote.currency;
        } else if (baseline.stockCurrencies.containsKey(ticker) && baseline.stockCurrencies[ticker]!.isNotEmpty) {
          resolvedCurrency = baseline.stockCurrencies[ticker]!;
        } else if (company != null && company.currency.isNotEmpty) {
          resolvedCurrency = company.currency;
        } else {
          resolvedCurrency = 'USD';
        }

        movements.add(StockPriceMovement(
          ticker: ticker,
          name: resolvedName,
          currency: resolvedCurrency,
          previousPrice: prevPrice,
          currentPrice: currentPrice,
          absoluteChange: absDiff,
          percentChange: pctDiff,
          isHolding: isHolding,
          isWatchlist: isWatchlist,
          shares: heldTickersMap[ticker],
          isMarketOpen: isOpen,
          country: country,
          marketClosureNotice: closureNotice,
        ));
      }

      // Sort movements by magnitude of percentage change
      movements.sort((a, b) => b.percentChange.abs().compareTo(a.percentChange.abs()));

      // Check news for top held stocks published since previous session
      final recentNews = <NewsVideo>[];
      if (user.portfolio.isNotEmpty) {
        try {
          final topHolding = user.portfolio.first;
          final newsList = await NewsService.instance.fetchCompanyNews(
            ticker: topHolding.ticker,
            companyName: topHolding.stockName,
            country: _getCountryForTicker(topHolding.ticker),
            language: language,
          );
          if (newsList.isNotEmpty) {
            recentNews.addAll(newsList.take(3));
          }
        } catch (e) {
          debugPrint('[MarketReopenService] news fetch error: $e');
        }
      }

      final hasSignificantPortfolioChange = portfolioChangeUSD.abs() >= 1.0 || portfolioChangePercent.abs() >= 0.1;
      final hasSignificantChanges = foundSignificantStockChange || hasSignificantPortfolioChange || recentNews.isNotEmpty;

      final summary = MarketReopenSummary(
        sessionElapsedMinutes: sessionElapsedMinutes > 0 ? sessionElapsedMinutes : 1,
        lastSessionTimestamp: baselineTimestamp,
        currentSessionTimestamp: now,
        previousPortfolioValueUSD: baseline.portfolioTotalUSD,
        currentPortfolioValueUSD: currentPortfolioValueUSD,
        portfolioChangeUSD: portfolioChangeUSD,
        portfolioChangePercent: portfolioChangePercent,
        movements: movements,
        recentNews: recentNews,
        hasSignificantChanges: hasSignificantChanges,
      );

      _hasShownInCurrentSession = true;
      return summary;
    } catch (e) {
      debugPrint('[MarketReopenService] evaluateSummary error: $e');
      return null;
    } finally {
      _isEvaluating = false;
    }
  }

  /// Mark the summary as acknowledged and update baseline to current time
  Future<void> acknowledgeSummary(UserProfile user, Map<String, StockQuote> quotes, Map<String, double> rates) async {
    _lastActiveTime = DateTime.now();
    await saveCurrentAsBaseline(user, quotes, rates);
  }
}
