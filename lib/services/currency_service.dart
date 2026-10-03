import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyRateItem {
  final String code;
  final String name;
  final String flag;
  final double rate;
  final double inverseRate;

  CurrencyRateItem({
    required this.code,
    required this.name,
    required this.flag,
    required this.rate,
    required this.inverseRate,
  });
}

class CurrencyRateResult {
  final String baseCurrency;
  final List<CurrencyRateItem> items;
  final DateTime marketObservationTime;
  final DateTime deviceFetchTime;
  final String providerName;
  final bool isCached;
  final String? error;

  CurrencyRateResult({
    required this.baseCurrency,
    required this.items,
    required this.marketObservationTime,
    required this.deviceFetchTime,
    required this.providerName,
    this.isCached = false,
    this.error,
  });
}

class CurrencyService {
  static final CurrencyService instance = CurrencyService._internal();
  CurrencyService._internal();

  static const String _cachePrefix = 'tradePulse_fx_cache_';
  final Map<String, CurrencyRateResult> _memoryCache = {};

  static final Map<String, Map<String, String>> knownCurrencyMeta = {
    'USD': {'name': 'US Dollar', 'flag': '🇺🇸'},
    'KRW': {'name': 'South Korean Won', 'flag': '🇰🇷'},
    'JPY': {'name': 'Japanese Yen', 'flag': '🇯🇵'},
    'EUR': {'name': 'Euro', 'flag': '🇪🇺'},
    'GBP': {'name': 'British Pound', 'flag': '🇬🇧'},
    'CAD': {'name': 'Canadian Dollar', 'flag': '🇨🇦'},
    'AUD': {'name': 'Australian Dollar', 'flag': '🇦🇺'},
    'CHF': {'name': 'Swiss Franc', 'flag': '🇨🇭'},
    'CNY': {'name': 'Chinese Yuan', 'flag': '🇨🇳'},
    'HKD': {'name': 'Hong Kong Dollar', 'flag': '🇭🇰'},
    'SGD': {'name': 'Singapore Dollar', 'flag': '🇸🇬'},
    'INR': {'name': 'Indian Rupee', 'flag': '🇮🇳'},
    'TWD': {'name': 'New Taiwan Dollar', 'flag': '🇹🇼'},
    'VND': {'name': 'Vietnamese Dong', 'flag': '🇻🇳'},
    'PKR': {'name': 'Pakistani Rupee', 'flag': '🇵🇰'},
    'BRL': {'name': 'Brazilian Real', 'flag': '🇧🇷'},
    'MXN': {'name': 'Mexican Peso', 'flag': '🇲🇽'},
    'SEK': {'name': 'Swedish Krona', 'flag': '🇸🇪'},
    'NOK': {'name': 'Norwegian Krone', 'flag': '🇳🇴'},
    'DKK': {'name': 'Danish Krone', 'flag': '🇩🇰'},
    'NZD': {'name': 'New Zealand Dollar', 'flag': '🇳🇿'},
    'ZAR': {'name': 'South African Rand', 'flag': '🇿🇦'},
    'AED': {'name': 'UAE Dirham', 'flag': '🇦🇪'},
    'SAR': {'name': 'Saudi Riyal', 'flag': '🇸🇦'},
    'THB': {'name': 'Thai Baht', 'flag': '🇹🇭'},
    'MYR': {'name': 'Malaysian Ringgit', 'flag': '🇲🇾'},
    'IDR': {'name': 'Indonesian Rupiah', 'flag': '🇮🇩'},
    'PHP': {'name': 'Philippine Peso', 'flag': '🇵🇭'},
    'TRY': {'name': 'Turkish Lira', 'flag': '🇹🇷'},
    'PLN': {'name': 'Polish Zloty', 'flag': '🇵🇱'},
    'ILS': {'name': 'Israeli Shekel', 'flag': '🇮🇱'},
    'CLP': {'name': 'Chilean Peso', 'flag': '🇨🇱'},
    'COP': {'name': 'Colombian Peso', 'flag': '🇨🇴'},
    'EGP': {'name': 'Egyptian Pound', 'flag': '🇪🇬'},
    'HUF': {'name': 'Hungarian Forint', 'flag': '🇭🇺'},
    'CZK': {'name': 'Czech Koruna', 'flag': '🇨🇿'},
  };

  // Supported base currency options
  static const List<String> supportedBaseCurrencies = [
    'USD', 'KRW', 'JPY', 'EUR', 'GBP', 'CAD', 'AUD', 'CHF', 'CNY', 'HKD', 'SGD', 'INR'
  ];

  Future<CurrencyRateResult> fetchExchangeRates({
    String baseCurrency = 'USD',
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();

    // Check memory cache (5-minute TTL to respect API limits)
    if (!forceRefresh && _memoryCache.containsKey(baseCurrency)) {
      final cached = _memoryCache[baseCurrency]!;
      if (now.difference(cached.deviceFetchTime).inMinutes < 5) {
        return cached;
      }
    }

    try {
      final uri = Uri.parse('https://open.er-api.com/v6/latest/$baseCurrency');
      final res = await http.get(uri, headers: {
        'User-Agent': 'TradePulse/1.0 (Mobile FX Monitor)',
      }).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['result'] == 'success' && data['rates'] != null && data['rates'] is Map) {
          final Map<String, dynamic> rawRates = data['rates'];
          final observationUnix = (data['time_last_update_unix'] as num?)?.toInt();
          final observationTime = observationUnix != null
              ? DateTime.fromMillisecondsSinceEpoch(observationUnix * 1000)
              : now;

          final List<CurrencyRateItem> items = [];

          rawRates.forEach((code, rateVal) {
            if (rateVal is num && rateVal > 0) {
              final r = rateVal.toDouble();
              final meta = knownCurrencyMeta[code];
              final name = meta?['name'] ?? code;
              final flag = meta?['flag'] ?? '🌐';
              final inverse = r > 0 ? (1.0 / r) : 0.0;

              items.add(CurrencyRateItem(
                code: code,
                name: name,
                flag: flag,
                rate: r,
                inverseRate: inverse,
              ));
            }
          });

          // Prioritize known primary currencies at the top, followed by alphabetical order
          items.sort((a, b) {
            final aKnown = knownCurrencyMeta.containsKey(a.code);
            final bKnown = knownCurrencyMeta.containsKey(b.code);
            if (aKnown && !bKnown) return -1;
            if (!aKnown && bKnown) return 1;
            return a.code.compareTo(b.code);
          });

          final result = CurrencyRateResult(
            baseCurrency: baseCurrency,
            items: items,
            marketObservationTime: observationTime,
            deviceFetchTime: now,
            providerName: 'Open Exchange Rates (open.er-api.com)',
            isCached: false,
          );

          _memoryCache[baseCurrency] = result;

          // Save to local storage for offline resilience
          _saveToDisk(baseCurrency, data, observationTime, now);

          return result;
        }
      }
    } catch (e) {
      debugPrint('Currency API network error: $e');
    }

    // Fallback to disk cache if network request failed
    final diskCached = await _loadFromDisk(baseCurrency);
    if (diskCached != null) {
      return diskCached;
    }

    // If both network and disk fail, return explicit error state without fabricating fake rates
    return CurrencyRateResult(
      baseCurrency: baseCurrency,
      items: [],
      marketObservationTime: now,
      deviceFetchTime: now,
      providerName: 'Exchange Rate Service (Unavailable)',
      isCached: false,
      error: 'Unable to connect to live exchange rate service. Check network connection.',
    );
  }

  Future<void> _saveToDisk(String baseCurrency, Map<String, dynamic> data, DateTime obsTime, DateTime fetchTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheObj = {
        'data': data,
        'obsTime': obsTime.millisecondsSinceEpoch,
        'fetchTime': fetchTime.millisecondsSinceEpoch,
      };
      await prefs.setString('$_cachePrefix$baseCurrency', json.encode(cacheObj));
    } catch (_) {}
  }

  Future<CurrencyRateResult?> _loadFromDisk(String baseCurrency) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$baseCurrency');
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        final data = decoded['data'] as Map<String, dynamic>;
        final rawRates = data['rates'] as Map<String, dynamic>;
        final obsTime = DateTime.fromMillisecondsSinceEpoch(decoded['obsTime']);
        final fetchTime = DateTime.fromMillisecondsSinceEpoch(decoded['fetchTime']);

        final List<CurrencyRateItem> items = [];
        rawRates.forEach((code, rateVal) {
          if (rateVal is num && rateVal > 0) {
            final r = rateVal.toDouble();
            final meta = knownCurrencyMeta[code];
            items.add(CurrencyRateItem(
              code: code,
              name: meta?['name'] ?? code,
              flag: meta?['flag'] ?? '🌐',
              rate: r,
              inverseRate: r > 0 ? 1.0 / r : 0.0,
            ));
          }
        });

        items.sort((a, b) {
          final aKnown = knownCurrencyMeta.containsKey(a.code);
          final bKnown = knownCurrencyMeta.containsKey(b.code);
          if (aKnown && !bKnown) return -1;
          if (!aKnown && bKnown) return 1;
          return a.code.compareTo(b.code);
        });

        return CurrencyRateResult(
          baseCurrency: baseCurrency,
          items: items,
          marketObservationTime: obsTime,
          deviceFetchTime: fetchTime,
          providerName: 'Open Exchange Rates (Cached)',
          isCached: true,
        );
      }
    } catch (_) {}
    return null;
  }
}
