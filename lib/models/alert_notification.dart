class AlertNotification {
  final String id;
  final String ticker;
  final String stockName;
  final double percentChange;
  final double amountChange;
  final String currency;
  final bool isUp;
  final String timePeriod;
  final String timestamp;
  final String message;

  AlertNotification({
    required this.id,
    required this.ticker,
    required this.stockName,
    required this.percentChange,
    required this.amountChange,
    required this.currency,
    required this.isUp,
    required this.timePeriod,
    required this.timestamp,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'ticker': ticker,
    'stockName': stockName,
    'percentChange': percentChange,
    'amountChange': amountChange,
    'currency': currency,
    'isUp': isUp,
    'timePeriod': timePeriod,
    'timestamp': timestamp,
    'message': message,
  };

  factory AlertNotification.fromJson(Map<String, dynamic> json) => AlertNotification(
    id: json['id']?.toString() ?? '',
    ticker: json['ticker']?.toString() ?? '',
    stockName: json['stockName']?.toString() ?? '',
    percentChange: (json['percentChange'] as num?)?.toDouble() ?? 0.0,
    amountChange: (json['amountChange'] as num?)?.toDouble() ?? 0.0,
    currency: json['currency']?.toString() ?? 'USD',
    isUp: json['isUp'] == true || json['isUp'] == 1,
    timePeriod: json['timePeriod']?.toString() ?? '1h',
    timestamp: json['timestamp']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
  );
}
