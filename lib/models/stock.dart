class StockQuote {
  final String ticker;
  final String name;
  final double? price;
  final double? previousClose;
  final double? change;
  final double? changePercent;
  final int? volume;
  final String currency;
  final String marketState;
  final String dataStatus;
  final String lastUpdated;
  final int lastUpdatedMs;

  StockQuote({
    required this.ticker,
    required this.name,
    this.price,
    this.previousClose,
    this.change,
    this.changePercent,
    this.volume,
    required this.currency,
    required this.marketState,
    required this.dataStatus,
    required this.lastUpdated,
    required this.lastUpdatedMs,
  });

  factory StockQuote.fromJson(Map<String, dynamic> json) {
    return StockQuote(
      ticker: json['ticker'] ?? '',
      name: json['name'] ?? '',
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      previousClose: json['previousClose'] != null ? (json['previousClose'] as num).toDouble() : null,
      change: json['change'] != null ? (json['change'] as num).toDouble() : null,
      changePercent: json['changePercent'] != null ? (json['changePercent'] as num).toDouble() : null,
      volume: json['volume'] != null ? (json['volume'] as num).toInt() : null,
      currency: json['currency'] ?? 'USD',
      marketState: json['marketState'] ?? 'REGULAR',
      dataStatus: json['dataStatus'] ?? 'live',
      lastUpdated: json['lastUpdated'] ?? '',
      lastUpdatedMs: json['lastUpdatedMs'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'ticker': ticker,
    'name': name,
    'price': price,
    'previousClose': previousClose,
    'change': change,
    'changePercent': changePercent,
    'volume': volume,
    'currency': currency,
    'marketState': marketState,
    'dataStatus': dataStatus,
    'lastUpdated': lastUpdated,
    'lastUpdatedMs': lastUpdatedMs,
  };

  StockQuote copyWith({
    String? ticker,
    String? name,
    double? price,
    double? previousClose,
    double? change,
    double? changePercent,
    int? volume,
    String? currency,
    String? marketState,
    String? dataStatus,
    String? lastUpdated,
    int? lastUpdatedMs,
  }) {
    return StockQuote(
      ticker: ticker ?? this.ticker,
      name: name ?? this.name,
      price: price ?? this.price,
      previousClose: previousClose ?? this.previousClose,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      volume: volume ?? this.volume,
      currency: currency ?? this.currency,
      marketState: marketState ?? this.marketState,
      dataStatus: dataStatus ?? this.dataStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastUpdatedMs: lastUpdatedMs ?? this.lastUpdatedMs,
    );
  }
}

class StockSecurity {
  final String ticker;
  final String name;
  final String? localName;
  final String country;
  final String countryName;
  final String exchange;
  final String sector;
  final String? industry;
  final String marketCapCategory;
  final String currency;
  final double? marketCap;
  final int? rank;

  StockSecurity({
    required this.ticker,
    required this.name,
    this.localName,
    required this.country,
    required this.countryName,
    required this.exchange,
    required this.sector,
    this.industry,
    required this.marketCapCategory,
    required this.currency,
    this.marketCap,
    this.rank,
  });

  factory StockSecurity.fromJson(Map<String, dynamic> json) {
    return StockSecurity(
      ticker: json['ticker'] ?? '',
      name: json['name'] ?? '',
      localName: json['localName'],
      country: json['country'] ?? 'US',
      countryName: json['countryName'] ?? 'United States',
      exchange: json['exchange'] ?? 'NYSE',
      sector: json['sector'] ?? 'Technology',
      industry: json['industry'],
      marketCapCategory: json['marketCapCategory'] ?? 'Large Cap',
      currency: json['currency'] ?? 'USD',
      marketCap: json['marketCap'] != null ? (json['marketCap'] as num).toDouble() : null,
      rank: json['rank'] != null ? (json['rank'] as num).toInt() : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'ticker': ticker,
    'name': name,
    'localName': localName,
    'country': country,
    'countryName': countryName,
    'exchange': exchange,
    'sector': sector,
    'industry': industry,
    'marketCapCategory': marketCapCategory,
    'currency': currency,
    'marketCap': marketCap,
    'rank': rank,
  };
}

class StockChartPoint {
  final int timestamp;
  final String dateStr;
  final double price;
  final int? volume;

  StockChartPoint({
    required this.timestamp,
    required this.dateStr,
    required this.price,
    this.volume,
  });

  factory StockChartPoint.fromJson(Map<String, dynamic> json) {
    return StockChartPoint(
      timestamp: json['timestamp'] ?? 0,
      dateStr: json['dateStr'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'dateStr': dateStr,
    'price': price,
    'volume': volume,
  };
}

class StockChartData {
  final String ticker;
  final String range;
  final String currency;
  final double? currentPrice;
  final double? previousClose;
  final double? change;
  final double? changePercent;
  final List<StockChartPoint> points;

  StockChartData({
    required this.ticker,
    required this.range,
    required this.currency,
    this.currentPrice,
    this.previousClose,
    this.change,
    this.changePercent,
    required this.points,
  });

  factory StockChartData.fromJson(Map<String, dynamic> json) {
    var rawPoints = json['points'] as List? ?? [];
    return StockChartData(
      ticker: json['ticker'] ?? '',
      range: json['range'] ?? '1M',
      currency: json['currency'] ?? 'USD',
      currentPrice: (json['currentPrice'] as num?)?.toDouble(),
      previousClose: (json['previousClose'] as num?)?.toDouble(),
      change: (json['change'] as num?)?.toDouble(),
      changePercent: (json['changePercent'] as num?)?.toDouble(),
      points: rawPoints.map((p) => StockChartPoint.fromJson(p)).toList(),
    );
  }
}
