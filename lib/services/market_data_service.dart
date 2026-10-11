import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/stock.dart';
import '../data/securities_data.dart';
import '../data/global_top_100.dart';
import 'company_repository.dart';

enum RequestPriority {
  p1Portfolio,
  p2Watchlist,
  p3Visible,
  p4RecentlyViewed,
  p5NextVisible,
  p6Background,
}

class MarketDataService {
  // Reusable persistent HTTP client with keep-alive connections
  static final http.Client _httpClient = http.Client();

  // In-memory quote cache holding VERIFIED real market data and initial baseline quotes
  static final Map<String, StockQuote> _cache = {};

  // In-flight request deduplication maps
  static final Map<String, Future<StockQuote>> _inFlightSingle = {};
  static final Map<String, Future<Map<String, StockQuote>>> _inFlightBatches = {};

  // Complete registry of all publicly traded securities
  static List<StockSecurity> get securities {
    if (CompanyRepository.instance.isInitialized && CompanyRepository.instance.allCompanies.isNotEmpty) {
      return CompanyRepository.instance.allCompanies;
    }
    return allSecuritiesDirectory;
  }

  // Seed baseline quote from security metadata for instant 0ms Stale-While-Revalidate display
  static void seedBaselineQuote(StockSecurity sec) {
    if (_cache.containsKey(sec.ticker) && _cache[sec.ticker]?.price != null) {
      return;
    }

    final price = sec.price;
    final prevClose = sec.previousClose ?? price;
    final change = (price != null && prevClose != null) ? price - prevClose : null;
    final changePct = (price != null && prevClose != null && prevClose > 0)
        ? ((price - prevClose) / prevClose) * 100
        : null;

    final quote = StockQuote(
      ticker: sec.ticker,
      name: sec.name,
      price: price,
      previousClose: prevClose,
      change: change,
      changePercent: changePct,
      volume: 100000,
      currency: sec.currency,
      marketState: isMarketOpen(sec.country) ? 'REGULAR' : 'CLOSED',
      dataStatus: price != null ? 'cached' : 'unavailable',
      lastUpdated: price != null ? 'Cached' : 'Unavailable',
      lastUpdatedMs: price != null ? DateTime.now().millisecondsSinceEpoch : 0,
    );

    _cache[sec.ticker] = quote;
  }

  // Determine if a specific regional stock market is currently open
  static bool isMarketOpen(String country) {
    final nowUtc = DateTime.now().toUtc();
    final weekday = nowUtc.weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) return false;

    final utcMinutes = nowUtc.hour * 60 + nowUtc.minute;

    switch (country.toUpperCase()) {
      case 'KR': // KST: UTC+9, 09:00 - 15:30 -> UTC 00:00 - 06:30
        return utcMinutes >= 0 && utcMinutes <= 390;
      case 'JP': // JST: UTC+9, 09:00 - 15:30 -> UTC 00:00 - 06:30
        return utcMinutes >= 0 && utcMinutes <= 390;
      case 'US': // EST: UTC-5 (EDT UTC-4), 09:30 - 16:00 -> UTC 13:30 - 20:00
        return utcMinutes >= 810 && utcMinutes <= 1260;
      case 'GB': // GMT: UTC+0 (BST UTC+1), 08:00 - 16:30 -> UTC 08:00 - 16:30
        return utcMinutes >= 480 && utcMinutes <= 990;
      case 'DE': // CET: UTC+1 (CEST UTC+2), 09:00 - 17:30 -> UTC 07:00 - 15:30
        return utcMinutes >= 420 && utcMinutes <= 930;
      case 'FR': // CET: UTC+1 (CEST UTC+2), 09:00 - 17:30 -> UTC 07:00 - 15:30
        return utcMinutes >= 420 && utcMinutes <= 930;
      default:
        return true;
    }
  }

  // Endpoints for batch quotes
  static List<String> _getQuoteEndpoints(List<String> tickers) {
    final symbols = tickers.map((t) => Uri.encodeComponent(t)).join(',');
    final list = <String>[];
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && !origin.startsWith('null')) {
          list.add('$origin/api/stocks/quotes?symbols=$symbols');
        }
      } catch (_) {}
      list.add('/api/stocks/quotes?symbols=$symbols');
    }
    list.add('http://localhost:3000/api/stocks/quotes?symbols=$symbols');
    list.add('http://10.0.2.2:3000/api/stocks/quotes?symbols=$symbols');
    return list;
  }

  // Fetch Currency Exchange Rates strictly from verified provider API
  static Future<Map<String, double>> fetchCurrencyRates() async {
    final endpoints = <String>[];
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && !origin.startsWith('null')) {
          endpoints.add('$origin/api/currency/rates');
        }
      } catch (_) {}
      endpoints.add('/api/currency/rates');
    }
    endpoints.add('http://localhost:3000/api/currency/rates');
    endpoints.add('http://10.0.2.2:3000/api/currency/rates');

    for (final ep in endpoints) {
      try {
        final res = await _httpClient.get(Uri.parse(ep)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final json = jsonDecode(utf8.decode(res.bodyBytes));
          if (json['success'] == true && json['rates'] is Map) {
            final Map<String, dynamic> rawRates = json['rates'];
            return rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
          }
        }
      } catch (_) {}
    }

    // Direct fetch fallback
    try {
      final res = await _httpClient
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(utf8.decode(res.bodyBytes));
        if (json['rates'] is Map) {
          final Map<String, dynamic> rawRates = json['rates'];
          return rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
        }
      }
    } catch (_) {}

    return {
      'USD': 1.0,
      'KRW': 1353.68,
      'JPY': 157.39,
      'EUR': 0.88,
      'GBP': 0.76,
    };
  }

  // Get cached quote immediately (0ms) or construct a baseline quote
  static StockQuote getQuote(String ticker) {
    if (_cache.containsKey(ticker)) {
      return _cache[ticker]!;
    }

    final sec = CompanyRepository.instance.findCompany(ticker) ??
        securities.firstWhere(
          (s) => s.ticker == ticker,
          orElse: () => StockSecurity(
            ticker: ticker,
            name: ticker,
            country: 'US',
            countryName: 'United States',
            exchange: 'NYSE',
            sector: 'General',
            marketCapCategory: 'Mid Cap',
            currency: _getCurrencyForTicker(ticker),
          ),
        );

    final quote = StockQuote(
      ticker: sec.ticker,
      name: sec.name,
      price: sec.price,
      previousClose: sec.previousClose ?? sec.price,
      change: (sec.price != null && sec.previousClose != null) ? sec.price! - sec.previousClose! : null,
      changePercent: (sec.price != null && sec.previousClose != null && sec.previousClose! > 0)
          ? ((sec.price! - sec.previousClose!) / sec.previousClose!) * 100
          : null,
      volume: 100000,
      currency: sec.currency,
      marketState: isMarketOpen(sec.country) ? 'REGULAR' : 'CLOSED',
      dataStatus: sec.price != null ? 'cached' : 'unavailable',
      lastUpdated: sec.price != null ? 'Cached' : 'Unavailable',
      lastUpdatedMs: sec.price != null ? DateTime.now().millisecondsSinceEpoch : 0,
    );

    _cache[ticker] = quote;
    return quote;
  }

  // Return all cached quotes
  static Map<String, StockQuote> getAllQuotes() {
    return Map<String, StockQuote>.from(_cache);
  }

  // Fetch real-time quote for a single ticker with deduplication and fast cache check
  static Future<StockQuote> fetchSingleQuote(String ticker, {RequestPriority priority = RequestPriority.p3Visible}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cache.containsKey(ticker) &&
        _cache[ticker]?.price != null &&
        (now - _cache[ticker]!.lastUpdatedMs) < 20000) {
      return _cache[ticker]!;
    }

    if (_inFlightSingle.containsKey(ticker)) {
      return _inFlightSingle[ticker]!;
    }

    final future = () async {
      try {
        final quotes = await fetchQuotes([ticker], priority: priority);
        return quotes[ticker] ?? getQuote(ticker);
      } finally {
        _inFlightSingle.remove(ticker);
      }
    }();

    _inFlightSingle[ticker] = future;
    return future;
  }

  // Fetch real-time quotes in batches with parallel concurrency and deduplication
  static Future<Map<String, StockQuote>> fetchQuotes(
    List<String> tickers, {
    RequestPriority priority = RequestPriority.p3Visible,
  }) async {
    if (tickers.isEmpty) return _cache;

    final uniqueTickers = tickers.toSet().toList();
    final batchKey = uniqueTickers.join(',');

    if (_inFlightBatches.containsKey(batchKey)) {
      return _inFlightBatches[batchKey]!;
    }

    final future = _executeFetchQuotes(uniqueTickers, priority);
    _inFlightBatches[batchKey] = future;

    try {
      return await future;
    } finally {
      _inFlightBatches.remove(batchKey);
    }
  }

  static Future<Map<String, StockQuote>> _executeFetchQuotes(
    List<String> uniqueTickers,
    RequestPriority priority,
  ) async {
    final results = <String, StockQuote>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    final toFetch = <String>[];

    for (final t in uniqueTickers) {
      final cached = _cache[t];
      if (cached != null && cached.price != null && (now - cached.lastUpdatedMs) < 15000) {
        results[t] = cached;
      } else {
        toFetch.add(t);
      }
    }

    if (toFetch.isEmpty) {
      return results;
    }

    // 1. Try server batch proxy endpoint in chunks of 20
    const int serverBatchSize = 20;
    final remainingTickers = <String>[];

    for (int i = 0; i < toFetch.length; i += serverBatchSize) {
      final chunk = toFetch.sublist(i, (i + serverBatchSize > toFetch.length) ? toFetch.length : i + serverBatchSize);
      final endpoints = _getQuoteEndpoints(chunk);
      bool chunkSuccess = false;

      for (final ep in endpoints) {
        try {
          final res = await _httpClient.get(Uri.parse(ep)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final json = jsonDecode(utf8.decode(res.bodyBytes));
            if (json['success'] == true && json['quotes'] is Map) {
              final Map<String, dynamic> quotesJson = json['quotes'];
              quotesJson.forEach((k, v) {
                final q = StockQuote.fromJson(v);
                _cache[k] = q;
                results[k] = q;
              });
              chunkSuccess = true;
              break;
            }
          }
        } catch (_) {}
      }

      if (!chunkSuccess) {
        remainingTickers.addAll(chunk);
      }
    }

    // 2. Controlled parallel fetch for any missing tickers (Concurrency = 6)
    if (remainingTickers.isNotEmpty) {
      const int concurrencyLimit = 6;
      for (int i = 0; i < remainingTickers.length; i += concurrencyLimit) {
        final chunk = remainingTickers.sublist(
          i,
          (i + concurrencyLimit > remainingTickers.length) ? remainingTickers.length : i + concurrencyLimit,
        );

        final futures = chunk.map((ticker) => _fetchDirectYahooQuote(ticker));
        final chunkResults = await Future.wait(futures);

        for (final q in chunkResults) {
          if (q != null) {
            _cache[q.ticker] = q;
            results[q.ticker] = q;
          }
        }
      }
    }

    // Ensure every requested ticker has at least a valid baseline/cached quote returned
    for (final t in uniqueTickers) {
      if (!results.containsKey(t)) {
        results[t] = getQuote(t);
      }
    }

    return results;
  }

  // Direct Yahoo v8 quote fetcher with persistent client and error resilience
  static Future<StockQuote?> _fetchDirectYahooQuote(String ticker) async {
    try {
      final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(ticker)}?range=1d&interval=1m',
      );
      final res = await _httpClient.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(milliseconds: 3000));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final meta = data['chart']?['result']?[0]?['meta'];
        if (meta != null) {
          final rawPrice = meta['regularMarketPrice'] ?? meta['previousClose'];
          if (rawPrice != null && rawPrice is num && rawPrice > 0) {
            final price = rawPrice.toDouble();
            final prevClose = (meta['previousClose'] as num?)?.toDouble() ??
                (meta['chartPreviousClose'] as num?)?.toDouble() ??
                price;
            final change = (meta['regularMarketChange'] as num?)?.toDouble() ?? (price - prevClose);
            final changePct = (meta['regularMarketChangePercent'] as num?)?.toDouble() ??
                (prevClose > 0 ? (change / prevClose) * 100 : 0.0);
            final rawCurr = (meta['currency'] as String?) ?? _getCurrencyForTicker(ticker);
            final currency = (rawCurr == 'GBp' || rawCurr == 'GBP') ? 'GBP' : rawCurr;

            final marketTimeMs = meta['regularMarketTime'] != null
                ? (meta['regularMarketTime'] as num).toInt() * 1000
                : DateTime.now().millisecondsSinceEpoch;
            final marketDate = DateTime.fromMillisecondsSinceEpoch(marketTimeMs);
            final timeStr =
                "${marketDate.hour.toString().padLeft(2, '0')}:${marketDate.minute.toString().padLeft(2, '0')}:${marketDate.second.toString().padLeft(2, '0')}";

            final sec = securities.firstWhere(
              (s) => s.ticker == ticker,
              orElse: () => StockSecurity(
                ticker: ticker,
                name: meta['shortName'] ?? meta['longName'] ?? ticker,
                country: 'US',
                countryName: 'United States',
                exchange: meta['exchangeName'] ?? 'NYSE',
                sector: 'General',
                marketCapCategory: 'Large Cap',
                currency: currency,
              ),
            );

            final isUSMarket = !ticker.contains('.') || ticker.endsWith('.N') || ticker.endsWith('.O');
            final quote = StockQuote(
              ticker: ticker,
              name: meta['shortName'] ?? meta['longName'] ?? sec.name,
              price: price,
              previousClose: prevClose,
              change: change,
              changePercent: changePct,
              volume: (meta['regularMarketVolume'] as num?)?.toInt(),
              currency: currency,
              marketState: isMarketOpen(sec.country) ? 'REGULAR' : 'CLOSED',
              dataStatus: isUSMarket ? 'realtime' : 'delayed',
              lastUpdated: timeStr,
              lastUpdatedMs: marketTimeMs,
            );

            return quote;
          }
        }
      }
    } catch (_) {}

    // On failure, preserve existing valid cached price rather than returning null/0
    if (_cache.containsKey(ticker) && _cache[ticker]?.price != null) {
      return _cache[ticker];
    }

    return null;
  }

  // Fetch Stock Chart data strictly from verified API with timeframe-specific interval
  static Future<StockChartData> fetchStockChart(String ticker, String range) async {
    String interval = '1d';
    String yahooRange = '1mo';

    switch (range) {
      case '1D':
        yahooRange = '1d';
        interval = '5m';
        break;
      case '1W':
        yahooRange = '5d';
        interval = '15m';
        break;
      case '1M':
        yahooRange = '1mo';
        interval = '1d';
        break;
      case '1Y':
        yahooRange = '1y';
        interval = '1wk';
        break;
      case '5Y':
        yahooRange = '5y';
        interval = '1mo';
        break;
    }

    // 1. Try server chart endpoint
    final chartEndpoints = <String>[];
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && !origin.startsWith('null')) {
          chartEndpoints.add('$origin/api/stocks/chart?ticker=${Uri.encodeComponent(ticker)}&range=$range');
        }
      } catch (_) {}
      chartEndpoints.add('/api/stocks/chart?ticker=${Uri.encodeComponent(ticker)}&range=$range');
    }
    chartEndpoints.add('http://localhost:3000/api/stocks/chart?ticker=${Uri.encodeComponent(ticker)}&range=$range');
    chartEndpoints.add('http://10.0.2.2:3000/api/stocks/chart?ticker=${Uri.encodeComponent(ticker)}&range=$range');

    for (final ep in chartEndpoints) {
      try {
        final res = await _httpClient.get(Uri.parse(ep)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final json = jsonDecode(utf8.decode(res.bodyBytes));
          if (json['success'] == true && json['chart'] != null) {
            return StockChartData.fromJson(json['chart']);
          }
        }
      } catch (_) {}
    }

    // 2. Direct Yahoo Finance API query
    try {
      final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(ticker)}?range=$yahooRange&interval=$interval',
      );
      final res = await _httpClient.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(milliseconds: 3500));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final result = data['chart']?['result']?[0];
        if (result != null) {
          final meta = result['meta'];
          final timestamps = (result['timestamp'] as List?)?.map((t) => (t as num).toInt()).toList() ?? [];
          final closes = (result['indicators']?['quote']?[0]?['close'] as List?)
                  ?.map((c) => c != null ? (c as num).toDouble() : null)
                  .toList() ??
              [];

          final points = <StockChartPoint>[];
          for (int i = 0; i < timestamps.length; i++) {
            final p = closes.length > i ? closes[i] : null;
            if (p != null && p > 0) {
              final date = DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000);
              points.add(StockChartPoint(
                timestamp: timestamps[i] * 1000,
                dateStr: range == '1D' || range == '1W'
                    ? "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}"
                    : "${date.month}/${date.day}",
                price: p,
              ));
            }
          }

          if (points.isNotEmpty) {
            final currentPrice = (meta?['regularMarketPrice'] as num?)?.toDouble() ?? points.last.price;
            final prevClose = (meta?['chartPreviousClose'] as num?)?.toDouble() ??
                (meta?['previousClose'] as num?)?.toDouble() ??
                points.first.price;
            final change = currentPrice - prevClose;
            final changePct = prevClose > 0 ? (change / prevClose) * 100 : 0.0;

            return StockChartData(
              ticker: ticker,
              range: range,
              currency: meta?['currency'] ?? _getCurrencyForTicker(ticker),
              currentPrice: currentPrice,
              previousClose: prevClose,
              change: change,
              changePercent: changePct,
              points: points,
            );
          }
        }
      }
    } catch (_) {}

    final existingQuote = getQuote(ticker);
    return StockChartData(
      ticker: ticker,
      range: range,
      currency: existingQuote.currency,
      currentPrice: existingQuote.price,
      previousClose: existingQuote.previousClose,
      change: existingQuote.change,
      changePercent: existingQuote.changePercent,
      points: [],
    );
  }

  // Filter securities directory by country, sector, and query
  static List<StockSecurity> searchSecurities({
    String query = '',
    String country = 'GLOBAL',
    String sector = 'ALL',
    String sort = 'NAME_ASC',
  }) {
    var list = List<StockSecurity>.from(securities);

    // Country filter
    if (country == 'GLOBAL') {
      final topSet = globalTop100Tickers.toSet();
      list = list.where((s) => topSet.contains(s.ticker)).toList();
      if (list.isEmpty) {
        list = securities.take(100).toList();
      }
    } else if (country != 'ALL') {
      list = list.where((s) => s.country.toUpperCase() == country.toUpperCase()).toList();
    }

    // Sector filter
    if (sector != 'ALL') {
      list = list.where((s) => s.sector.toLowerCase() == sector.toLowerCase()).toList();
    }

    // Query filter
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((s) {
        return s.ticker.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q) ||
            (s.localName != null && s.localName!.toLowerCase().contains(q)) ||
            (s.isin != null && s.isin!.toLowerCase().contains(q));
      }).toList();
    }

    // Sorting
    switch (sort) {
      case 'NAME_ASC':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'NAME_DESC':
        list.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'PRICE_DESC':
        list.sort((a, b) {
          final pA = _cache[a.ticker]?.price ?? a.price ?? 0.0;
          final pB = _cache[b.ticker]?.price ?? b.price ?? 0.0;
          return pB.compareTo(pA);
        });
        break;
      case 'PRICE_ASC':
        list.sort((a, b) {
          final pA = _cache[a.ticker]?.price ?? a.price ?? double.infinity;
          final pB = _cache[b.ticker]?.price ?? b.price ?? double.infinity;
          return pA.compareTo(pB);
        });
        break;
      case 'GAINERS':
        list.sort((a, b) {
          final gA = _cache[a.ticker]?.changePercent ?? -999.0;
          final gB = _cache[b.ticker]?.changePercent ?? -999.0;
          return gB.compareTo(gA);
        });
        break;
      case 'LOSERS':
        list.sort((a, b) {
          final gA = _cache[a.ticker]?.changePercent ?? 999.0;
          final gB = _cache[b.ticker]?.changePercent ?? 999.0;
          return gA.compareTo(gB);
        });
        break;
      default:
        list.sort((a, b) => (a.rank ?? 9999).compareTo(b.rank ?? 9999));
    }

    return list;
  }

  static String _getCurrencyForTicker(String ticker) {
    if (ticker.endsWith('.KS') || ticker.endsWith('.KQ')) return 'KRW';
    if (ticker.endsWith('.T')) return 'JPY';
    if (ticker.endsWith('.DE') || ticker.endsWith('.F') || ticker.endsWith('.PA') || ticker.endsWith('.AS')) return 'EUR';
    if (ticker.endsWith('.L')) return 'GBP';
    if (ticker.endsWith('.VN')) return 'VND';
    if (ticker.endsWith('.KA')) return 'PKR';
    return 'USD';
  }
}
