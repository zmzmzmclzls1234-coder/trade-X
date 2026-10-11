import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/stock.dart';
import 'market_data_service.dart';

class CompanyRepository {
  static final CompanyRepository instance = CompanyRepository._internal();
  CompanyRepository._internal();

  bool _isInitialized = false;
  List<StockSecurity> _allCompanies = [];
  List<StockSecurity> _krCompanies = [];
  List<StockSecurity> _usCompanies = [];
  List<StockSecurity> _jpCompanies = [];
  List<StockSecurity> _deCompanies = [];
  List<StockSecurity> _ukCompanies = [];
  List<StockSecurity> _frCompanies = [];
  final Map<String, StockSecurity> _byTicker = {};
  final Map<String, StockSecurity> _byCode = {};
  final Map<String, StockSecurity> _byIsin = {};

  bool get isInitialized => _isInitialized;
  List<StockSecurity> get allCompanies => List.unmodifiable(_allCompanies);
  int get totalCount => _allCompanies.length;
  int get koreanCount => _krCompanies.length;
  int get usCount => _usCompanies.length;
  int get japaneseCount => _jpCompanies.where((c) => c.listingStatus == 'LISTED').length;
  int get japaneseTotalWithHistorical => _jpCompanies.length;
  int get germanCount => _deCompanies.where((c) => c.listingStatus == 'LISTED').length;
  int get ukCount => _ukCompanies.where((c) => c.listingStatus == 'LISTED').length;
  int get frenchCount => _frCompanies.where((c) => c.listingStatus == 'LISTED').length;

  List<StockSecurity> get koreanCompanies => List.unmodifiable(_krCompanies);
  List<StockSecurity> get usCompanies => List.unmodifiable(_usCompanies);
  List<StockSecurity> get japaneseCompanies => List.unmodifiable(_jpCompanies);
  List<StockSecurity> get germanCompanies => List.unmodifiable(_deCompanies);
  List<StockSecurity> get ukCompanies => List.unmodifiable(_ukCompanies);
  List<StockSecurity> get frenchCompanies => List.unmodifiable(_frCompanies);

  /// Initialize and load the comprehensive Korean, US, and Japanese companies database
  Future<void> initialize() async {
    if (_isInitialized) return;

    final loadedList = <StockSecurity>[];

    // 1. Try loading bundled comprehensive KRX dataset (2,875 companies)
    try {
      String jsonStr;
      try {
        jsonStr = await rootBundle.loadString('assets/data/korean_companies.json');
      } catch (_) {
        final f = File('assets/data/korean_companies.json');
        if (f.existsSync()) {
          jsonStr = f.readAsStringSync();
        } else {
          jsonStr = '[]';
        }
      }
      final List<dynamic> rawKR = jsonDecode(jsonStr);
      final krSecurities = rawKR.map((item) => StockSecurity.fromJson(item as Map<String, dynamic>)).toList();
      loadedList.addAll(krSecurities);
      debugPrint('[CompanyRepository] Loaded ${krSecurities.length} Korean listed companies.');
    } catch (e) {
      debugPrint('[CompanyRepository] Error loading Korean asset: $e');
    }

    // 2. Try loading bundled comprehensive US dataset (6,016 companies from NASDAQ, NYSE, AMEX)
    try {
      String jsonStr;
      try {
        jsonStr = await rootBundle.loadString('assets/data/us_companies.json');
      } catch (_) {
        final f = File('assets/data/us_companies.json');
        if (f.existsSync()) {
          jsonStr = f.readAsStringSync();
        } else {
          jsonStr = '[]';
        }
      }
      final List<dynamic> rawUS = jsonDecode(jsonStr);
      final usSecurities = rawUS.map((item) => StockSecurity.fromJson(item as Map<String, dynamic>)).toList();
      loadedList.addAll(usSecurities);
      debugPrint('[CompanyRepository] Loaded ${usSecurities.length} US listed companies.');
    } catch (e) {
      debugPrint('[CompanyRepository] Error loading US asset: $e');
    }

    // 3. Try loading bundled comprehensive JPX dataset (3,885 listed companies across Prime, Standard, Growth, TOKYO PRO Market)
    try {
      String jsonStr;
      try {
        jsonStr = await rootBundle.loadString('assets/data/japanese_companies.json');
      } catch (_) {
        final f = File('assets/data/japanese_companies.json');
        if (f.existsSync()) {
          jsonStr = f.readAsStringSync();
        } else {
          jsonStr = '[]';
        }
      }
      final List<dynamic> rawJP = jsonDecode(jsonStr);
      final jpSecurities = rawJP.map((item) => StockSecurity.fromJson(item as Map<String, dynamic>)).toList();
      loadedList.addAll(jpSecurities);
      debugPrint('[CompanyRepository] Loaded ${jpSecurities.length} Japanese listed companies.');
    } catch (e) {
      debugPrint('[CompanyRepository] Error loading Japanese asset: $e');
    }

    // 4. Try loading bundled comprehensive German dataset (Xetra & Frankfurt Stock Exchange)
    try {
      String jsonStr;
      try {
        jsonStr = await rootBundle.loadString('assets/data/german_companies.json');
      } catch (_) {
        final f = File('assets/data/german_companies.json');
        if (f.existsSync()) {
          jsonStr = f.readAsStringSync();
        } else {
          jsonStr = '[]';
        }
      }
      final List<dynamic> rawDE = jsonDecode(jsonStr);
      final deSecurities = rawDE.map((item) => StockSecurity.fromJson(item as Map<String, dynamic>)).toList();
      loadedList.addAll(deSecurities);
      debugPrint('[CompanyRepository] Loaded ${deSecurities.length} German listed companies.');
    } catch (e) {
      debugPrint('[CompanyRepository] Error loading German asset: $e');
    }

    // 5. Try loading bundled comprehensive UK dataset (London Stock Exchange Main Market & AIM)
    try {
      String jsonStr;
      try {
        jsonStr = await rootBundle.loadString('assets/data/uk_companies.json');
      } catch (_) {
        final f = File('assets/data/uk_companies.json');
        if (f.existsSync()) {
          jsonStr = f.readAsStringSync();
        } else {
          jsonStr = '[]';
        }
      }
      final List<dynamic> rawUK = jsonDecode(jsonStr);
      final ukSecurities = rawUK.map((item) => StockSecurity.fromJson(item as Map<String, dynamic>)).toList();
      loadedList.addAll(ukSecurities);
      debugPrint('[CompanyRepository] Loaded ${ukSecurities.length} UK listed companies.');
    } catch (e) {
      debugPrint('[CompanyRepository] Error loading UK asset: $e');
    }

    // 6. Try loading bundled comprehensive French dataset (Euronext Paris)
    try {
      String jsonStr;
      try {
        jsonStr = await rootBundle.loadString('assets/data/french_companies.json');
      } catch (_) {
        final f = File('assets/data/french_companies.json');
        if (f.existsSync()) {
          jsonStr = f.readAsStringSync();
        } else {
          jsonStr = '[]';
        }
      }
      final List<dynamic> rawFR = jsonDecode(jsonStr);
      final frSecurities = rawFR.map((item) => StockSecurity.fromJson(item as Map<String, dynamic>)).toList();
      loadedList.addAll(frSecurities);
      debugPrint('[CompanyRepository] Loaded ${frSecurities.length} French listed companies.');
    } catch (e) {
      debugPrint('[CompanyRepository] Error loading French asset: $e');
    }

    if (loadedList.isNotEmpty) {
      _allCompanies = loadedList;
      _buildIndexes();
      _isInitialized = true;
      debugPrint('[CompanyRepository] Successfully initialized ${_allCompanies.length} total listed companies (KR: $koreanCount, US: $usCount, JP: $japaneseCount, DE: $germanCount, UK: $ukCount, FR: $frenchCount).');
    }

    // Background sync check with backend if available
    _syncWithBackend();
  }

  void _buildIndexes() {
    _byTicker.clear();
    _byCode.clear();
    _byIsin.clear();

    _krCompanies = _allCompanies.where((c) => c.country == 'KR').toList();
    _usCompanies = _allCompanies.where((c) => c.country == 'US').toList();
    _jpCompanies = _allCompanies.where((c) => c.country == 'JP').toList();
    _deCompanies = _allCompanies.where((c) => c.country == 'DE').toList();
    _ukCompanies = _allCompanies.where((c) => c.country == 'GB').toList();
    _frCompanies = _allCompanies.where((c) => c.country == 'FR').toList();

    for (final c in _allCompanies) {
      _byTicker[c.ticker.toUpperCase()] = c;
      if (c.code != null && c.code!.isNotEmpty) {
        _byCode[c.code!.toUpperCase()] = c;
      }
      if (c.isin != null && c.isin!.isNotEmpty) {
        _byIsin[c.isin!.toUpperCase()] = c;
      }
      // Seed baseline quote into MarketDataService for instant 0ms cached display
      MarketDataService.seedBaselineQuote(c);
    }
  }

  /// Optional background synchronization with server API
  Future<void> _syncWithBackend() async {
    try {
      final endpoints = [
        'http://localhost:3000/api/stocks/all-companies',
        'http://10.0.2.2:3000/api/stocks/all-companies',
      ];

      for (final ep in endpoints) {
        try {
          final res = await http.get(Uri.parse(ep)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final data = jsonDecode(utf8.decode(res.bodyBytes));
            if (data['success'] == true && data['companies'] is List) {
              final List<dynamic> remoteList = data['companies'];
              if (remoteList.length >= _allCompanies.length) {
                _allCompanies = remoteList.map((item) => StockSecurity.fromJson(item as Map<String, dynamic>)).toList();
                _buildIndexes();
                debugPrint('[CompanyRepository] Synced ${remoteList.length} companies from backend.');
                break;
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Lookup single company by ticker, code, or ISIN
  StockSecurity? findCompany(String identifier) {
    final clean = identifier.trim().toUpperCase();
    if (_byTicker.containsKey(clean)) return _byTicker[clean];
    if (_byCode.containsKey(clean)) return _byCode[clean];
    if (_byIsin.containsKey(clean)) return _byIsin[clean];

    // If ticker missing suffix for Korean stocks, try .KS then .KQ
    if (_byTicker.containsKey('$clean.KS')) return _byTicker['$clean.KS'];
    if (_byTicker.containsKey('$clean.KQ')) return _byTicker['$clean.KQ'];

    // If ticker missing suffix for Japanese stocks, try .T
    if (_byTicker.containsKey('$clean.T')) return _byTicker['$clean.T'];

    // If ticker missing suffix for German stocks, try .DE then .F
    if (_byTicker.containsKey('$clean.DE')) return _byTicker['$clean.DE'];
    if (_byTicker.containsKey('$clean.F')) return _byTicker['$clean.F'];

    // If ticker missing suffix for UK stocks, try .L
    if (_byTicker.containsKey('$clean.L')) return _byTicker['$clean.L'];

    // If ticker missing suffix for French stocks, try .PA
    if (_byTicker.containsKey('$clean.PA')) return _byTicker['$clean.PA'];

    // If ticker has hyphen/dot interchange (e.g. BRK.B <-> BRK-B)
    final dotAlt = clean.replaceAll('-', '.');
    if (_byTicker.containsKey(dotAlt)) return _byTicker[dotAlt];
    final dashAlt = clean.replaceAll('.', '-');
    if (_byTicker.containsKey(dashAlt)) return _byTicker[dashAlt];

    return null;
  }

  /// Search, filter, and sort companies across KR, US, JP, DE, and UK markets
  List<StockSecurity> searchAndFilter({
    String query = '',
    String country = 'ALL', // ALL, KR, US, JP, DE, GB/UK
    String exchange = 'ALL', // ALL, Main Market, AIM, Xetra, Frankfurt, Prime, Standard, Growth, TOKYO PRO Market, NASDAQ, NYSE, AMEX, KOSPI, KOSDAQ, KONEX
    String sector = 'ALL',
    String marketCapCategory = 'ALL', // Large Cap, Mid Cap, Small Cap
    String listingStatus = 'ALL', // ALL, LISTED
    String currency = 'ALL', // ALL, EUR, GBP, JPY, KRW, USD
    String sort = 'MARKET_CAP_DESC',
  }) {
    Iterable<StockSecurity> list = _allCompanies;

    // 1. Fast country filter using pre-partitioned lists
    final cUpper = country.toUpperCase();
    if (cUpper == 'KR') {
      list = _krCompanies;
    } else if (cUpper == 'US') {
      list = _usCompanies;
    } else if (cUpper == 'JP') {
      list = _jpCompanies;
    } else if (cUpper == 'DE') {
      list = _deCompanies;
    } else if (cUpper == 'GB' || cUpper == 'UK') {
      list = _ukCompanies;
    } else if (cUpper == 'FR') {
      list = _frCompanies;
    } else if (cUpper != 'ALL') {
      list = list.where((c) => c.country.toUpperCase() == cUpper);
    }

    // 2. Exchange / Market filter
    if (exchange != 'ALL') {
      final exUpper = exchange.toUpperCase();
      list = list.where((c) {
        final cEx = c.exchange.toUpperCase();
        final cDept = (c.dept ?? '').toUpperCase();
        if (cEx == exUpper || cDept == exUpper) return true;
        if (exUpper == 'MAIN MARKET' || exUpper == 'AIM') {
          return cDept == exUpper || cEx.contains(exUpper);
        }
        if (exUpper == 'PRO MARKET' || exUpper == 'TOKYO PRO MARKET') {
          return cEx.contains('PRO MARKET');
        }
        return false;
      });
    }

    // 3. Currency filter
    if (currency != 'ALL') {
      final currUpper = currency.toUpperCase();
      list = list.where((c) => c.currency.toUpperCase() == currUpper);
    }

    // 4. Sector filter with smart cross-market mapping
    if (sector != 'ALL') {
      list = list.where((c) => c.matchesSector(sector));
    }

    // 5. Market Cap Category filter
    if (marketCapCategory != 'ALL') {
      final catUpper = marketCapCategory.toUpperCase();
      list = list.where((c) => c.marketCapCategory.toUpperCase() == catUpper);
    }

    // 6. Listing Status filter
    if (listingStatus != 'ALL') {
      final stUpper = listingStatus.toUpperCase();
      list = list.where((c) => c.listingStatus.toUpperCase() == stUpper);
    }

    // 7. Fast search query filter via pre-indexed search tokens
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((c) => c.searchIndex.contains(q));
    }

    final result = list.toList();

    // 7. Sorting
    final cachedQuotes = MarketDataService.getAllQuotes();

    switch (sort) {
      case 'NAME_ASC':
        result.sort((a, b) => (a.localName ?? a.name).compareTo(b.localName ?? b.name));
        break;
      case 'NAME_DESC':
        result.sort((a, b) => (b.localName ?? b.name).compareTo(a.localName ?? a.name));
        break;
      case 'TICKER_ASC':
        result.sort((a, b) => a.ticker.compareTo(b.ticker));
        break;
      case 'PRICE_DESC':
        result.sort((a, b) {
          final pA = cachedQuotes[a.ticker]?.price ?? 0.0;
          final pB = cachedQuotes[b.ticker]?.price ?? 0.0;
          return pB.compareTo(pA);
        });
        break;
      case 'PRICE_ASC':
        result.sort((a, b) {
          final pA = cachedQuotes[a.ticker]?.price ?? double.infinity;
          final pB = cachedQuotes[b.ticker]?.price ?? double.infinity;
          return pA.compareTo(pB);
        });
        break;
      case 'GAINERS':
        result.sort((a, b) {
          final gA = cachedQuotes[a.ticker]?.changePercent ?? -999.0;
          final gB = cachedQuotes[b.ticker]?.changePercent ?? -999.0;
          return gB.compareTo(gA);
        });
        break;
      case 'LOSERS':
        result.sort((a, b) {
          final gA = cachedQuotes[a.ticker]?.changePercent ?? 999.0;
          final gB = cachedQuotes[b.ticker]?.changePercent ?? 999.0;
          return gA.compareTo(gB);
        });
        break;
      case 'MARKET_CAP_DESC':
        result.sort((a, b) => (b.marketCap ?? 0.0).compareTo(a.marketCap ?? 0.0));
        break;
      case 'VOLUME_DESC':
        result.sort((a, b) {
          final vA = cachedQuotes[a.ticker]?.volume ?? 0;
          final vB = cachedQuotes[b.ticker]?.volume ?? 0;
          return vB.compareTo(vA);
        });
        break;
      default:
        result.sort((a, b) => (a.rank ?? 9999).compareTo(b.rank ?? 9999));
    }

    return result;
  }

  /// Get paginated slice of companies
  List<StockSecurity> getPaginatedList({
    required int page,
    required int pageSize,
    String query = '',
    String country = 'ALL',
    String exchange = 'ALL',
    String sector = 'ALL',
    String marketCapCategory = 'ALL',
    String listingStatus = 'ALL',
    String currency = 'ALL',
    String sort = 'MARKET_CAP_DESC',
  }) {
    final filtered = searchAndFilter(
      query: query,
      country: country,
      exchange: exchange,
      sector: sector,
      marketCapCategory: marketCapCategory,
      listingStatus: listingStatus,
      currency: currency,
      sort: sort,
    );

    final start = (page - 1) * pageSize;
    if (start >= filtered.length) return [];
    final end = (start + pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }
}
