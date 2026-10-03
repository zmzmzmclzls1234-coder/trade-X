class PortfolioPosition {
  final String ticker;
  final String stockName;
  final double shares;
  final double averagePrice;
  final double averagePriceUSD;
  final double totalCostUSD;
  final String nativeCurrency;

  PortfolioPosition({
    required this.ticker,
    required this.stockName,
    required this.shares,
    required this.averagePrice,
    required this.averagePriceUSD,
    required this.totalCostUSD,
    required this.nativeCurrency,
  });

  factory PortfolioPosition.fromJson(Map<String, dynamic> json) {
    final sharesVal = (json['shares'] as num?)?.toDouble() ?? 0.0;
    final avgUSD = (json['averagePriceUSD'] as num?)?.toDouble() ?? 0.0;
    final totalCost = (json['totalCostUSD'] as num?)?.toDouble() ?? (sharesVal * avgUSD);

    return PortfolioPosition(
      ticker: json['ticker'] ?? '',
      stockName: json['stockName'] ?? '',
      shares: sharesVal,
      averagePrice: (json['averagePrice'] as num?)?.toDouble() ?? 0.0,
      averagePriceUSD: avgUSD,
      totalCostUSD: totalCost,
      nativeCurrency: json['nativeCurrency'] ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() => {
    'ticker': ticker,
    'stockName': stockName,
    'shares': shares,
    'averagePrice': averagePrice,
    'averagePriceUSD': averagePriceUSD,
    'totalCostUSD': totalCostUSD,
    'nativeCurrency': nativeCurrency,
  };

  PortfolioPosition copyWith({
    String? ticker,
    String? stockName,
    double? shares,
    double? averagePrice,
    double? averagePriceUSD,
    double? totalCostUSD,
    String? nativeCurrency,
  }) {
    return PortfolioPosition(
      ticker: ticker ?? this.ticker,
      stockName: stockName ?? this.stockName,
      shares: shares ?? this.shares,
      averagePrice: averagePrice ?? this.averagePrice,
      averagePriceUSD: averagePriceUSD ?? this.averagePriceUSD,
      totalCostUSD: totalCostUSD ?? this.totalCostUSD,
      nativeCurrency: nativeCurrency ?? this.nativeCurrency,
    );
  }
}

class TransactionRecord {
  final String id;
  final String userId;
  final String ticker;
  final String stockName;
  final String type; // BUY or SELL
  final double shares;
  final double price;
  final String currency;
  final double totalAmountNative;
  final double totalAmountUSD;
  final String timestamp;

  TransactionRecord({
    required this.id,
    required this.userId,
    required this.ticker,
    required this.stockName,
    required this.type,
    required this.shares,
    required this.price,
    required this.currency,
    required this.totalAmountNative,
    required this.totalAmountUSD,
    required this.timestamp,
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      ticker: json['ticker'] ?? '',
      stockName: json['stockName'] ?? '',
      type: json['type'] ?? 'BUY',
      shares: (json['shares'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'USD',
      totalAmountNative: (json['totalAmountNative'] as num?)?.toDouble() ?? 0.0,
      totalAmountUSD: (json['totalAmountUSD'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'ticker': ticker,
    'stockName': stockName,
    'type': type,
    'shares': shares,
    'price': price,
    'currency': currency,
    'totalAmountNative': totalAmountNative,
    'totalAmountUSD': totalAmountUSD,
    'timestamp': timestamp,
  };
}

class UserProfile {
  final String id;
  final String username;
  final String country;
  final String displayCurrency;
  final String language;
  final double cashUSD; // Base cash stored in USD for precise conversion (~$740.74 = 1,000,000 KRW)
  final double initialCashKRW;
  final List<PortfolioPosition> portfolio;
  final List<String> watchlist;
  final double totalRealizedProfit;

  // Virtual cash balance in preferred display currency
  double get virtualCashBalance {
    if (displayCurrency == 'KRW') {
      return cashUSD * 1350.0;
    } else if (displayCurrency == 'JPY') {
      return cashUSD * 145.0;
    } else if (displayCurrency == 'EUR') {
      return cashUSD * 0.92;
    } else if (displayCurrency == 'GBP') {
      return cashUSD * 0.78;
    }
    return cashUSD;
  }

  UserProfile({
    required this.id,
    required this.username,
    required this.country,
    required this.displayCurrency,
    required this.language,
    required this.cashUSD,
    this.initialCashKRW = 1000000.0,
    required this.portfolio,
    required this.watchlist,
    required this.totalRealizedProfit,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    var rawPort = json['portfolio'] as List? ?? [];
    var rawWatch = json['watchlist'] as List? ?? [];

    double cash = (json['cashUSD'] as num?)?.toDouble() ?? 0.0;
    if (cash == 0.0 && json['virtualCashBalance'] != null) {
      double legacyBal = (json['virtualCashBalance'] as num).toDouble();
      cash = legacyBal / 1350.0;
    }
    if (cash <= 0.0) {
      cash = 1000000.0 / 1350.0; // 1,000,000 KRW baseline
    }

    return UserProfile(
      id: json['id'] ?? 'user_default',
      username: json['username'] ?? 'Investor',
      country: json['country'] ?? 'KR',
      displayCurrency: json['displayCurrency'] ?? 'KRW',
      language: json['language'] ?? 'ko',
      cashUSD: cash,
      initialCashKRW: (json['initialCashKRW'] as num?)?.toDouble() ?? 1000000.0,
      portfolio: rawPort.map((p) => PortfolioPosition.fromJson(p)).toList(),
      watchlist: rawWatch.map((w) => w.toString()).toList(),
      totalRealizedProfit: (json['totalRealizedProfit'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'country': country,
    'displayCurrency': displayCurrency,
    'language': language,
    'cashUSD': cashUSD,
    'initialCashKRW': initialCashKRW,
    'portfolio': portfolio.map((p) => p.toJson()).toList(),
    'watchlist': watchlist,
    'totalRealizedProfit': totalRealizedProfit,
  };

  UserProfile copyWith({
    String? id,
    String? username,
    String? country,
    String? displayCurrency,
    String? language,
    double? cashUSD,
    double? initialCashKRW,
    List<PortfolioPosition>? portfolio,
    List<String>? watchlist,
    double? totalRealizedProfit,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      country: country ?? this.country,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      language: language ?? this.language,
      cashUSD: cashUSD ?? this.cashUSD,
      initialCashKRW: initialCashKRW ?? this.initialCashKRW,
      portfolio: portfolio ?? this.portfolio,
      watchlist: watchlist ?? this.watchlist,
      totalRealizedProfit: totalRealizedProfit ?? this.totalRealizedProfit,
    );
  }
}
