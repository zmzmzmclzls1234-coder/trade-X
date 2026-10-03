import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock.dart';
import '../models/user.dart';

class ApiService {
  // Base URL pointing to the secure backend server
  static String baseUrl = 'http://localhost:3000/api/v1';

  static Future<Map<String, double>> fetchCurrencyRates() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/currency-rates'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        Map<String, double> rates = {};
        if (data['rates'] != null) {
          data['rates'].forEach((k, v) {
            rates[k] = (v as num).toDouble();
          });
        }
        return rates;
      }
    } catch (e) {
      print('Rates error: $e');
    }
    return {'USD': 1.0, 'KRW': 1350.0, 'JPY': 145.0, 'EUR': 0.92, 'GBP': 0.78};
  }

  static Future<Map<String, StockQuote>> fetchQuotes(List<String> tickers) async {
    if (tickers.isEmpty) return {};
    try {
      final res = await http.get(Uri.parse('$baseUrl/quotes?tickers=${tickers.join(',')}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        Map<String, StockQuote> quotes = {};
        if (data['quotes'] != null) {
          data['quotes'].forEach((k, v) {
            quotes[k] = StockQuote.fromJson(v);
          });
        }
        return quotes;
      }
    } catch (e) {
      print('Quotes error: $e');
    }
    return {};
  }

  static Future<Map<String, dynamic>> fetchStockDirectory({
    String country = 'GLOBAL',
    String exchange = 'ALL',
    String sector = 'ALL',
    String industry = 'ALL',
    String cap = 'ALL',
    String search = '',
    String sort = 'NAME_ASC',
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/securities').replace(queryParameters: {
        'country': country,
        'exchange': exchange,
        'sector': sector,
        'industry': industry,
        'cap': cap,
        'search': search,
        'sort': sort,
        'page': page.toString(),
        'limit': limit.toString(),
      });

      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<StockSecurity> items = [];
        if (data['items'] != null) {
          items = (data['items'] as List).map((i) => StockSecurity.fromJson(i)).toList();
        }
        return {
          'items': items,
          'total': data['total'] ?? 0,
          'totalPages': data['totalPages'] ?? 1,
          'exchanges': List<String>.from(data['exchanges'] ?? []),
          'sectors': List<String>.from(data['sectors'] ?? []),
          'industries': List<String>.from(data['industries'] ?? []),
        };
      }
    } catch (e) {
      print('Directory error: $e');
    }
    return {'items': <StockSecurity>[], 'total': 0, 'totalPages': 1, 'exchanges': [], 'sectors': [], 'industries': []};
  }

  static Future<UserProfile> fetchUserProfile(String userId) async {
    final res = await http.get(Uri.parse('$baseUrl/user?userId=$userId'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return UserProfile.fromJson(data['user']);
    }
    throw Exception('Failed to fetch user profile');
  }

  static Future<UserProfile> createOrLoginUser({required String username, required String country, String displayCurrency = 'KRW'}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/user/init'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'country': country,
        'displayCurrency': displayCurrency,
      }),
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return UserProfile.fromJson(data['user']);
    }
    throw Exception('Failed to initialize user');
  }

  static Future<Map<String, dynamic>> executeTrade({
    required String userId,
    required String ticker,
    required String type, // BUY or SELL
    required double shares,
    required double price,
    required String currency,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/trade'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'ticker': ticker,
        'type': type,
        'shares': shares,
        'price': price,
        'currency': currency,
      }),
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return {
        'success': data['success'] ?? false,
        'user': UserProfile.fromJson(data['user']),
        'message': data['message'] ?? '',
      };
    } else {
      final data = json.decode(res.body);
      throw Exception(data['error'] ?? 'Trade failed');
    }
  }

  static Future<List<String>> toggleWatchlist(String userId, String ticker) async {
    final res = await http.post(
      Uri.parse('$baseUrl/watchlist/toggle'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId, 'ticker': ticker}),
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<String>.from(data['watchlist'] ?? []);
    }
    return [];
  }
}
