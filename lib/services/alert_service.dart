import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_notification.dart';
import '../models/stock.dart';
import '../models/user.dart';
import '../services/notification_service.dart';

class HourlyPortfolioSnapshot {
  final int timestampMs;
  final double totalPortfolioUSD;
  final double cashUSD;
  final double stockValueUSD;
  final Map<String, double> stockPrices; // ticker -> native price
  final Map<String, double> stockShares; // ticker -> shares owned

  HourlyPortfolioSnapshot({
    required this.timestampMs,
    required this.totalPortfolioUSD,
    required this.cashUSD,
    required this.stockValueUSD,
    required this.stockPrices,
    required this.stockShares,
  });

  Map<String, dynamic> toJson() => {
    'timestampMs': timestampMs,
    'totalPortfolioUSD': totalPortfolioUSD,
    'cashUSD': cashUSD,
    'stockValueUSD': stockValueUSD,
    'stockPrices': stockPrices,
    'stockShares': stockShares,
  };

  factory HourlyPortfolioSnapshot.fromJson(Map<String, dynamic> json) {
    return HourlyPortfolioSnapshot(
      timestampMs: json['timestampMs'] as int? ?? 0,
      totalPortfolioUSD: (json['totalPortfolioUSD'] as num?)?.toDouble() ?? 0.0,
      cashUSD: (json['cashUSD'] as num?)?.toDouble() ?? 0.0,
      stockValueUSD: (json['stockValueUSD'] as num?)?.toDouble() ?? 0.0,
      stockPrices: (json['stockPrices'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ) ?? {},
      stockShares: (json['stockShares'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ) ?? {},
    );
  }
}

class AlertService {
  static final AlertService instance = AlertService._internal();
  AlertService._internal();

  static const String _alertsPrefKey = 'tradePulse_portfolio_alerts';
  static const String _enabledPrefKey = 'tradePulse_hourly_alerts_enabled';
  static const String _snapshotsPrefKey = 'tradePulse_hourly_snapshots';

  bool _isEnabled = true;
  List<AlertNotification> _alerts = [];
  List<HourlyPortfolioSnapshot> _snapshots = [];
  Timer? _hourlyTimer;

  bool get isEnabled => _isEnabled;
  List<AlertNotification> get alerts => List.unmodifiable(_alerts);

  final ValueNotifier<AlertNotification?> latestAlertNotifier = ValueNotifier<AlertNotification?>(null);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_enabledPrefKey) ?? true;

      final alertsJson = prefs.getString(_alertsPrefKey);
      if (alertsJson != null && alertsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(alertsJson);
        _alerts = decoded.map((e) => AlertNotification.fromJson(e)).toList();
      }

      final snapshotsJson = prefs.getString(_snapshotsPrefKey);
      if (snapshotsJson != null && snapshotsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(snapshotsJson);
        _snapshots = decoded.map((e) => HourlyPortfolioSnapshot.fromJson(e)).toList();
      }

      // Initialize native notification channel & permission check
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('[AlertService] init error: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledPrefKey, enabled);

    if (enabled) {
      // Prompt user for notification permission if not yet granted
      final granted = await NotificationService.instance.requestNotificationPermission();
      if (!granted) {
        debugPrint('[AlertService] Notification permission was not granted by user.');
      }
    } else {
      await NotificationService.instance.cancelNotifications();
    }
  }

  void startHourlyMonitoring({
    required Function() onTrigger,
  }) {
    _hourlyTimer?.cancel();
    // Run every 1 hour (3600 seconds)
    _hourlyTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (_isEnabled) {
        onTrigger();
      }
    });
  }

  void dispose() {
    _hourlyTimer?.cancel();
  }

  // Format currency value cleanly with appropriate symbol
  String _formatAmount(double amount, String currency) {
    final absVal = amount.abs();
    final sign = amount >= 0 ? '+' : '-';
    if (currency == 'KRW' || currency == 'JPY' || currency == 'VND') {
      final formatted = absVal.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      final sym = currency == 'KRW' ? '₩' : (currency == 'JPY' ? '¥' : '₫');
      return '$sign$sym$formatted';
    } else {
      final sym = currency == 'EUR' ? '€' : (currency == 'GBP' ? '£' : '\$');
      return '$sign$sym${absVal.toStringAsFixed(2)}';
    }
  }

  String _formatTotal(double amount, String currency) {
    if (currency == 'KRW' || currency == 'JPY' || currency == 'VND') {
      final formatted = amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      final sym = currency == 'KRW' ? '₩' : (currency == 'JPY' ? '¥' : '₫');
      return '$sym$formatted';
    } else {
      final sym = currency == 'EUR' ? '€' : (currency == 'GBP' ? '£' : '\$');
      return '$sym${amount.toStringAsFixed(2)}';
    }
  }

  // Compute live portfolio total from authoritative quotes
  double _calculateStockValueUSD(UserProfile user, Map<String, StockQuote> quotes, Map<String, double> rates) {
    double total = 0.0;
    for (final pos in user.portfolio) {
      final quote = quotes[pos.ticker];
      final currentPrice = (quote?.price != null && quote!.price! > 0) ? quote.price! : pos.averagePrice;
      final rate = rates[pos.nativeCurrency.toUpperCase()] ?? 1.0;
      final priceUSD = currentPrice / rate;
      total += pos.shares * priceUSD;
    }
    return total;
  }

  // Check and generate hourly notification based on REAL portfolio data
  Future<List<AlertNotification>> checkPortfolioAlerts({
    required UserProfile user,
    required Map<String, StockQuote> quotes,
    required Map<String, double> rates,
    required String language,
    bool forceTest = false,
  }) async {
    if (!_isEnabled && !forceTest) return [];

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final userCurrency = user.displayCurrency;
    final currencyRate = rates[userCurrency.toUpperCase()] ?? 1.0;

    final currentCashUSD = user.cashUSD;
    final currentStockValueUSD = _calculateStockValueUSD(user, quotes, rates);
    final currentTotalPortfolioUSD = currentCashUSD + currentStockValueUSD;

    // Collect current stock prices & shares
    final currentPrices = <String, double>{};
    final currentShares = <String, double>{};
    for (final pos in user.portfolio) {
      final quote = quotes[pos.ticker];
      if (quote?.price != null && quote!.price! > 0) {
        currentPrices[pos.ticker] = quote.price!;
      } else {
        currentPrices[pos.ticker] = pos.averagePrice;
      }
      currentShares[pos.ticker] = pos.shares;
    }

    // Current snapshot
    final currentSnapshot = HourlyPortfolioSnapshot(
      timestampMs: nowMs,
      totalPortfolioUSD: currentTotalPortfolioUSD,
      cashUSD: currentCashUSD,
      stockValueUSD: currentStockValueUSD,
      stockPrices: currentPrices,
      stockShares: currentShares,
    );

    // Find previous snapshot from ~1 hour ago (30 min - 180 min window)
    HourlyPortfolioSnapshot? baselineSnapshot;

    for (final s in _snapshots.reversed) {
      final ageMinutes = (nowMs - s.timestampMs) ~/ (60 * 1000);
      if (ageMinutes >= 30 && ageMinutes <= 180) {
        baselineSnapshot = s;
        break;
      }
    }

    // If no snapshot in window and this is the first run or test, use oldest snapshot or initial cost baseline
    if (baselineSnapshot == null) {
      if (_snapshots.isNotEmpty) {
        baselineSnapshot = _snapshots.first;
      } else {
        // Initial baseline based on user initial cash and portfolio cost basis
        double initialCostBasisUSD = user.cashUSD;
        for (final pos in user.portfolio) {
          initialCostBasisUSD += pos.totalCostUSD;
        }
        baselineSnapshot = HourlyPortfolioSnapshot(
          timestampMs: nowMs - (60 * 60 * 1000),
          totalPortfolioUSD: initialCostBasisUSD > 0 ? initialCostBasisUSD : currentTotalPortfolioUSD,
          cashUSD: user.cashUSD,
          stockValueUSD: currentStockValueUSD,
          stockPrices: currentPrices,
          stockShares: currentShares,
        );
      }
    }

    // Save snapshot to history (keep last 24 snapshots)
    _snapshots.add(currentSnapshot);
    if (_snapshots.length > 24) {
      _snapshots.removeRange(0, _snapshots.length - 24);
    }
    _saveSnapshots();

    // Exact hourly calculation
    final diffUSD = currentTotalPortfolioUSD - baselineSnapshot.totalPortfolioUSD;
    final baselineUSD = baselineSnapshot.totalPortfolioUSD;
    final percentChange = baselineUSD > 0 ? (diffUSD / baselineUSD) * 100.0 : 0.0;
    final isUp = diffUSD >= 0;

    final diffInUserCurrency = diffUSD * currencyRate;
    final formattedDiff = _formatAmount(diffInUserCurrency, userCurrency);
    final formattedTotal = _formatTotal(currentTotalPortfolioUSD * currencyRate, userCurrency);
    final pctStr = percentChange.abs().toStringAsFixed(1);

    // Analyze individual stock movements for owned stocks
    final stockMovementDetails = <String>[];
    for (final pos in user.portfolio) {
      final curPrice = currentPrices[pos.ticker] ?? pos.averagePrice;
      final basePrice = baselineSnapshot.stockPrices[pos.ticker] ?? pos.averagePrice;
      final stockDiff = curPrice - basePrice;
      final stockPct = basePrice > 0 ? (stockDiff / basePrice) * 100.0 : 0.0;
      final stockMonetary = stockDiff * pos.shares;

      if (stockDiff.abs() > 0.001 || forceTest) {
        final stockSign = stockDiff >= 0 ? '+' : '';
        final formattedStockMonetary = _formatAmount(stockMonetary, pos.nativeCurrency);
        stockMovementDetails.add('• ${pos.stockName}: $stockSign${stockPct.toStringAsFixed(1)}% ($formattedStockMonetary)');
      }
    }

    // Construct truthful, exact notification copy as specified in prompt:
    // Examples:
    // "Trade X — Hourly Update"
    // "Your portfolio increased by 2.4% (+₩24,000) during the last hour."
    // or:
    // "Trade X — Hourly Update"
    // "Your portfolio decreased by 1.7% (-₩17,000) during the last hour."
    String notificationTitle;
    String notificationBody;

    if (language == 'ko') {
      notificationTitle = 'Trade X — 시간별 포트폴리오 업데이트';
      if (diffInUserCurrency.abs() < 1 && percentChange.abs() < 0.1) {
        notificationBody = '지난 1시간 동안 포트폴리오 평가금액이 $formattedTotal(으)로 안정적으로 유지되었습니다.';
      } else if (isUp) {
        notificationBody = '지난 1시간 동안 포트폴리오가 $pctStr% 증가했습니다 ($formattedDiff).';
      } else {
        notificationBody = '지난 1시간 동안 포트폴리오가 $pctStr% 감소했습니다 ($formattedDiff).';
      }
    } else if (language == 'ja') {
      notificationTitle = 'Trade X — 1時間ごとの更新';
      if (isUp) {
        notificationBody = '過去1時間でポートフォリオが $pctStr% 増加しました ($formattedDiff)。';
      } else {
        notificationBody = '過去1時間でポートフォリオが $pctStr% 減少しました ($formattedDiff).';
      }
    } else if (language == 'de') {
      notificationTitle = 'Trade X — Stündliches Update';
      if (isUp) {
        notificationBody = 'Ihr Portfolio ist in der letzten Stunde um $pctStr% gestiegen ($formattedDiff).';
      } else {
        notificationBody = 'Ihr Portfolio ist in der letzten Stunde um $pctStr% gesunken ($formattedDiff).';
      }
    } else if (language == 'fr') {
      notificationTitle = 'Trade X — Bilan horaire';
      if (isUp) {
        notificationBody = 'Votre portefeuille a progressé de $pctStr% ($formattedDiff) au cours de la dernière heure.';
      } else {
        notificationBody = 'Votre portefeuille a diminué de $pctStr% ($formattedDiff) au cours de la dernière heure.';
      }
    } else {
      notificationTitle = 'Trade X — Hourly Update';
      if (diffInUserCurrency.abs() < 0.01 && percentChange.abs() < 0.05) {
        notificationBody = 'Your portfolio value remained steady at $formattedTotal over the last hour.';
      } else if (isUp) {
        notificationBody = 'Your portfolio increased by $pctStr% ($formattedDiff) during the last hour.';
      } else {
        notificationBody = 'Your portfolio decreased by $pctStr% ($formattedDiff) during the last hour.';
      }
    }

    final detailsString = stockMovementDetails.isNotEmpty ? stockMovementDetails.join('\n') : null;

    // Trigger REAL Android Phone System Notification
    await NotificationService.instance.showSystemNotification(
      id: 1001,
      title: notificationTitle,
      body: notificationBody,
      details: detailsString,
    );

    // Schedule next hour's background alarm
    await NotificationService.instance.scheduleHourlyNotification(
      title: notificationTitle,
      body: notificationBody,
      details: detailsString,
      intervalMinutes: 60,
    );

    // Record into in-app notification history
    final newAlert = AlertNotification(
      id: 'alert_${nowMs}',
      ticker: user.portfolio.isNotEmpty ? user.portfolio.first.ticker : 'PORTFOLIO',
      stockName: notificationTitle,
      percentChange: percentChange,
      amountChange: diffInUserCurrency,
      currency: userCurrency,
      isUp: isUp,
      timePeriod: '1h',
      message: notificationBody,
      timestamp: timeStr,
    );

    _alerts.insert(0, newAlert);
    if (_alerts.length > 50) {
      _alerts = _alerts.sublist(0, 50);
    }
    latestAlertNotifier.value = newAlert;
    _saveAlerts();

    return [newAlert];
  }

  Future<void> _saveSnapshots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _snapshots.map((s) => s.toJson()).toList();
      await prefs.setString(_snapshotsPrefKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[AlertService] _saveSnapshots error: $e');
    }
  }

  Future<void> _saveAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _alerts.map((a) => a.toJson()).toList();
      await prefs.setString(_alertsPrefKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[AlertService] _saveAlerts error: $e');
    }
  }

  Future<void> clearAlerts() async {
    _alerts.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_alertsPrefKey);
  }
}
