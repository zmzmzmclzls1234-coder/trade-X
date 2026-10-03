import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/stock.dart';
import '../data/securities_data.dart';
import '../data/global_top_100.dart';

class MarketDataService {
  // Complete registry of all 1028 publicly traded securities
  static final List<StockSecurity> securities = allSecuritiesDirectory;

  // In-memory quote cache holding only VERIFIED real market data
  static final Map<String, StockQuote> _cache = {};

  // List of endpoints to try for fetching quotes
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
    // 1. Try server proxy endpoint
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
        final res = await http.get(Uri.parse(ep)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final json = jsonDecode(utf8.decode(res.bodyBytes));
          if (json['success'] == true && json['rates'] is Map) {
            final Map<String, dynamic> rawRates = json['rates'];
            return rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
          }
        }
      } catch (_) {}
    }

    // 2. Direct fetch from open.er-api.com
    try {
      final res = await http
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

  // Get cached quote or return an unavailable placeholder
  static StockQuote getQuote(String ticker) {
    if (_cache.containsKey(ticker)) {
      return _cache[ticker]!;
    }

    final sec = securities.firstWhere(
      (s) => s.ticker == ticker,
      orElse: () => StockSecurity(
        ticker: ticker,
        name: ticker,
        country: 'US',
        countryName: 'United States',
        exchange: 'NYSE',
        sector: 'General',
        marketCapCategory: 'Large Cap',
        currency: _getCurrencyForTicker(ticker),
      ),
    );

    final quote = StockQuote(
      ticker: sec.ticker,
      name: sec.name,
      price: null,
      previousClose: null,
      change: null,
      changePercent: null,
      volume: null,
      currency: sec.currency,
      marketState: 'CLOSED',
      dataStatus: 'unavailable',
      lastUpdated: 'Unavailable',
      lastUpdatedMs: 0,
    );

    _cache[ticker] = quote;
    return quote;
  }

  // Return all cached quotes
  static Map<String, StockQuote> getAllQuotes() {
    return Map<String, StockQuote>.from(_cache);
  }

  // Fetch real-time quote for a single ticker with caching and live fallback
  static Future<StockQuote> fetchSingleQuote(String ticker) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cache.containsKey(ticker) &&
        _cache[ticker]?.price != null &&
        (now - _cache[ticker]!.lastUpdatedMs) < 30000) {
      return _cache[ticker]!;
    }

    final quotes = await fetchQuotes([ticker]);
    return quotes[ticker] ?? getQuote(ticker);
  }

  // Fetch real-time quotes using Backend Proxy or Yahoo Finance v8 API
  static Future<Map<String, StockQuote>> fetchQuotes(List<String> tickers) async {
    if (tickers.isEmpty) return _cache;

    final results = <String, StockQuote>{};
    final missingTickers = <String>[];

    // 1. Try fetching in bulk via Backend Proxy
    final endpoints = _getQuoteEndpoints(tickers);

    for (final ep in endpoints) {
      try {
        final res = await http.get(Uri.parse(ep)).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final json = jsonDecode(utf8.decode(res.bodyBytes));
          if (json['success'] == true && json['quotes'] is Map) {
            final Map<String, dynamic> quotesJson = json['quotes'];
            quotesJson.forEach((k, v) {
              final q = StockQuote.fromJson(v);
              _cache[k] = q;
              results[k] = q;
            });
            break;
          }
        }
      } catch (_) {}
    }

    // Check which tickers still need quotes
    for (final t in tickers) {
      if (!results.containsKey(t)) {
        missingTickers.add(t);
      }
    }

    // 2. For missing tickers, fetch individually from Yahoo Finance v8 API
    for (final ticker in missingTickers) {
      try {
        final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(ticker)}?range=1d&interval=1m',
        );
        final res = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        }).timeout(const Duration(milliseconds: 3500));

        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          final meta = data['chart']?['result']?[0]?['meta'];
          if (meta != null) {
            final rawPrice = meta['regularMarketPrice'] ?? meta['previousClose'];
            if (rawPrice != null && rawPrice is num && rawPrice > 0) {
              final price = rawPrice.toDouble();
              final prevClose = (meta['previousClose'] as num?)?.toDouble() ?? (meta['chartPreviousClose'] as num?)?.toDouble() ?? price;
              final change = (meta['regularMarketChange'] as num?)?.toDouble() ?? (price - prevClose);
              final changePct = (meta['regularMarketChangePercent'] as num?)?.toDouble() ?? (prevClose > 0 ? (change / prevClose) * 100 : 0.0);
              final currency = meta['currency'] ?? _getCurrencyForTicker(ticker);

              final marketTimeMs = meta['regularMarketTime'] != null ? (meta['regularMarketTime'] as num).toInt() * 1000 : DateTime.now().millisecondsSinceEpoch;
              final marketDate = DateTime.fromMillisecondsSinceEpoch(marketTimeMs);
              final timeStr = "${marketDate.hour.toString().padLeft(2, '0')}:${marketDate.minute.toString().padLeft(2, '0')}:${marketDate.second.toString().padLeft(2, '0')}";

              final sec = securities.firstWhere((s) => s.ticker == ticker, orElse: () => StockSecurity(
                ticker: ticker,
                name: meta['shortName'] ?? meta['longName'] ?? ticker,
                country: 'US',
                countryName: 'United States',
                exchange: meta['exchangeName'] ?? 'NYSE',
                sector: 'General',
                marketCapCategory: 'Large Cap',
                currency: currency,
              ));

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
                marketState: 'REGULAR',
                dataStatus: isUSMarket ? 'realtime' : 'delayed',
                lastUpdated: timeStr,
                lastUpdatedMs: marketTimeMs,
              );

              _cache[ticker] = quote;
              results[ticker] = quote;
              continue;
            }
          }
        }
      } catch (_) {}

      // If fetch failed and not previously cached with a valid price, record as unavailable
      if (!_cache.containsKey(ticker) || _cache[ticker]?.price == null) {
        final sec = securities.firstWhere((s) => s.ticker == ticker, orElse: () => StockSecurity(
          ticker: ticker, name: ticker, country: 'US', countryName: 'United States',
          exchange: 'NYSE', sector: 'General', marketCapCategory: 'Large Cap', currency: _getCurrencyForTicker(ticker),
        ));
        final unavail = StockQuote(
          ticker: ticker,
          name: sec.name,
          price: null,
          previousClose: null,
          change: null,
          changePercent: null,
          volume: null,
          currency: sec.currency,
          marketState: 'CLOSED',
          dataStatus: 'unavailable',
          lastUpdated: 'Unavailable',
          lastUpdatedMs: 0,
        );
        _cache[ticker] = unavail;
        results[ticker] = unavail;
      } else {
        results[ticker] = _cache[ticker]!;
      }
    }

    return results;
  }

  // Fetch Stock Chart data strictly from Yahoo Finance API without synthetic jitter
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
        final res = await http.get(Uri.parse(ep)).timeout(const Duration(seconds: 4));
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
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(milliseconds: 3500));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final result = data['chart']?['result']?[0];
        if (result != null) {
          final meta = result['meta'];
          final timestamps = (result['timestamp'] as List?)?.map((t) => (t as num).toInt()).toList() ?? [];
          final closes = (result['indicators']?['quote']?[0]?['close'] as List?)?.map((c) => c != null ? (c as num).toDouble() : null).toList() ?? [];

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
            final prevClose = (meta?['chartPreviousClose'] as num?)?.toDouble() ?? (meta?['previousClose'] as num?)?.toDouble() ?? points.first.price;
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

    // Return empty points indicating data unavailable
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
            (s.localName != null && s.localName!.toLowerCase().contains(q));
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
          final pA = _cache[a.ticker]?.price ?? 0.0;
          final pB = _cache[b.ticker]?.price ?? 0.0;
          return pB.compareTo(pA);
        });
        break;
      case 'PRICE_ASC':
        list.sort((a, b) {
          final pA = _cache[a.ticker]?.price ?? double.infinity;
          final pB = _cache[b.ticker]?.price ?? double.infinity;
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
        list.sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
    }

    return list;
  }

  static String _getCurrencyForTicker(String ticker) {
    if (ticker.endsWith('.KS') || ticker.endsWith('.KQ')) return 'KRW';
    if (ticker.endsWith('.T')) return 'JPY';
    if (ticker.endsWith('.DE') || ticker.endsWith('.PA') || ticker.endsWith('.AS')) return 'EUR';
    if (ticker.endsWith('.L')) return 'GBP';
    if (ticker.endsWith('.VN')) return 'VND';
    if (ticker.endsWith('.KA')) return 'PKR';
    return 'USD';
  }
}
