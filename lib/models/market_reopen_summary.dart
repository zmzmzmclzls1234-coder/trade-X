import '../models/news_video.dart';

class MarketSessionBaseline {
  final int timestampMs;
  final double portfolioTotalUSD;
  final double stockValueUSD;
  final double cashUSD;
  final Map<String, double> stockPrices; // ticker -> native price
  final Map<String, String> stockCurrencies; // ticker -> currency code

  MarketSessionBaseline({
    required this.timestampMs,
    required this.portfolioTotalUSD,
    required this.stockValueUSD,
    required this.cashUSD,
    required this.stockPrices,
    required this.stockCurrencies,
  });

  Map<String, dynamic> toJson() => {
    'timestampMs': timestampMs,
    'portfolioTotalUSD': portfolioTotalUSD,
    'stockValueUSD': stockValueUSD,
    'cashUSD': cashUSD,
    'stockPrices': stockPrices,
    'stockCurrencies': stockCurrencies,
  };

  factory MarketSessionBaseline.fromJson(Map<String, dynamic> json) {
    return MarketSessionBaseline(
      timestampMs: json['timestampMs'] as int? ?? 0,
      portfolioTotalUSD: (json['portfolioTotalUSD'] as num?)?.toDouble() ?? 0.0,
      stockValueUSD: (json['stockValueUSD'] as num?)?.toDouble() ?? 0.0,
      cashUSD: (json['cashUSD'] as num?)?.toDouble() ?? 0.0,
      stockPrices: (json['stockPrices'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ) ?? {},
      stockCurrencies: (json['stockCurrencies'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ) ?? {},
    );
  }
}

class StockPriceMovement {
  final String ticker;
  final String name;
  final String currency;
  final double previousPrice;
  final double currentPrice;
  final double absoluteChange;
  final double percentChange;
  final bool isHolding;
  final bool isWatchlist;
  final double? shares;
  final bool isMarketOpen;
  final String country;
  final String? marketClosureNotice;

  const StockPriceMovement({
    required this.ticker,
    required this.name,
    required this.currency,
    required this.previousPrice,
    required this.currentPrice,
    required this.absoluteChange,
    required this.percentChange,
    required this.isHolding,
    required this.isWatchlist,
    this.shares,
    required this.isMarketOpen,
    required this.country,
    this.marketClosureNotice,
  });

  bool get isGainer => percentChange > 0;
  bool get isLoser => percentChange < 0;
}

class MarketReopenSummary {
  final int sessionElapsedMinutes;
  final DateTime lastSessionTimestamp;
  final DateTime currentSessionTimestamp;
  final double previousPortfolioValueUSD;
  final double currentPortfolioValueUSD;
  final double portfolioChangeUSD;
  final double portfolioChangePercent;
  final List<StockPriceMovement> movements;
  final List<NewsVideo> recentNews;
  final bool hasSignificantChanges;
  final bool isDataUnavailable;
  final String? unavailableMessage;

  const MarketReopenSummary({
    required this.sessionElapsedMinutes,
    required this.lastSessionTimestamp,
    required this.currentSessionTimestamp,
    required this.previousPortfolioValueUSD,
    required this.currentPortfolioValueUSD,
    required this.portfolioChangeUSD,
    required this.portfolioChangePercent,
    required this.movements,
    required this.recentNews,
    required this.hasSignificantChanges,
    this.isDataUnavailable = false,
    this.unavailableMessage,
  });

  List<StockPriceMovement> get heldStockMovements =>
      movements.where((m) => m.isHolding).toList();

  List<StockPriceMovement> get watchlistMovements =>
      movements.where((m) => m.isWatchlist && !m.isHolding).toList();

  List<StockPriceMovement> get topGainers {
    final list = movements.where((m) => m.percentChange > 0.05).toList();
    list.sort((a, b) => b.percentChange.compareTo(a.percentChange));
    return list;
  }

  List<StockPriceMovement> get topLosers {
    final list = movements.where((m) => m.percentChange < -0.05).toList();
    list.sort((a, b) => a.percentChange.compareTo(b.percentChange));
    return list;
  }

  Set<String> get closedMarkets => movements
      .where((m) => !m.isMarketOpen && m.country.isNotEmpty)
      .map((m) => m.country.toUpperCase())
      .toSet();

  factory MarketReopenSummary.unavailable({
    required String message,
    required DateTime lastSessionTimestamp,
  }) {
    final now = DateTime.now();
    return MarketReopenSummary(
      sessionElapsedMinutes: now.difference(lastSessionTimestamp).inMinutes,
      lastSessionTimestamp: lastSessionTimestamp,
      currentSessionTimestamp: now,
      previousPortfolioValueUSD: 0.0,
      currentPortfolioValueUSD: 0.0,
      portfolioChangeUSD: 0.0,
      portfolioChangePercent: 0.0,
      movements: const [],
      recentNews: const [],
      hasSignificantChanges: false,
      isDataUnavailable: true,
      unavailableMessage: message,
    );
  }
}
