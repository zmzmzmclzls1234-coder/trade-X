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
  final String? code;
  final String name;
  final String? localName;
  final String? isin;
  final String country;
  final String countryName;
  final String exchange;
  final String sector;
  final String? industry;
  final String marketCapCategory;
  final String currency;
  final double? marketCap;
  final double? price;
  final double? previousClose;
  final String listingStatus;
  final int? rank;
  final String? dept;
  final String? listingDate;
  final String? representative;
  final String? homepage;

  late final String searchIndex = _computeSearchIndex();

  String _computeSearchIndex() {
    final sb = StringBuffer();
    sb.write(ticker.toLowerCase());
    sb.write(' ');
    if (code != null) sb.write('${code!.toLowerCase()} ');
    sb.write('${name.toLowerCase()} ');
    if (localName != null) sb.write('${localName!.toLowerCase()} ');
    if (isin != null) sb.write('${isin!.toLowerCase()} ');

    // Fast Korean aliases for US giants
    final t = ticker.toUpperCase();
    if (t == 'AAPL') sb.write('애플 아이폰 ');
    if (t == 'TSLA') sb.write('테슬라 머스크 ');
    if (t == 'NVDA') sb.write('엔비디아 황인훈 ');
    if (t == 'MSFT') sb.write('마이크로소프트 엠에스 ');
    if (t == 'GOOGL' || t == 'GOOG') sb.write('구글 알파벳 ');
    if (t == 'AMZN') sb.write('아마존 ');
    if (t == 'META') sb.write('메타 페이스북 ');
    if (t == 'PLTR') sb.write('팔란티어 ');
    if (t == 'COIN') sb.write('코인베이스 ');

    // Fast Korean colloquial abbreviations
    if (localName != null) {
      final l = localName!;
      if (l.contains('현대자동차') || l.contains('현대차')) sb.write('현대차 현대자동차 ');
      if (l.contains('LG에너지솔루션')) sb.write('lg엔솔 엔솔 엘지에너지솔루션 ');
      if (l.contains('삼성바이오로직스')) sb.write('삼바 삼성바이오 ');
      if (l.contains('SK하이닉스')) sb.write('하이닉스 에스케이하이닉스 ');
      if (l.contains('포스코홀딩스')) sb.write('포스코 포스코홀딩스 ');
      if (l.contains('카카오뱅크')) sb.write('카뱅 카카오뱅크 ');
      if (l.contains('에코프로비엠')) sb.write('에코프로 에코비엠 ');
    }

    // Fast aliases for Japanese market giants (English, Kanji, Katakana, Korean)
    final jCode = (code ?? ticker).toUpperCase().replaceAll('.T', '');
    if (jCode == '7203') sb.write('toyota トヨタ トヨタ自動車 토요타 ');
    if (jCode == '6758') sb.write('sony ソニー ソニーグループ 소니 ');
    if (jCode == '7974') sb.write('nintendo 任天堂 닌텐도 ');
    if (jCode == '9984') sb.write('softbank ソフトバンク ソフトバンクグループ 소프트뱅크 ');
    if (jCode == '6857') sb.write('advantest アドバンテスト 어드반테스트 ');
    if (jCode == '8035') sb.write('tokyo electron 東京エレクトロン 도쿄일렉트론 ');
    if (jCode == '6501') sb.write('hitachi 日立 日立製作所 히타치 ');
    if (jCode == '6702') sb.write('fujitsu 富士通 후지쯔 ');
    if (jCode == '7267') sb.write('honda ホンダ 本田技研工業 혼다 ');
    if (jCode == '9432') sb.write('ntt 日本電信電話 엔티티 ');
    if (jCode == '8306') sb.write('mufg 三菱ufj 미쓰비시ufj ');
    if (jCode == '8058') sb.write('mitsubishi 三菱商事 미쓰비시상사 ');
    if (jCode == '6920') sb.write('lasertec レーザーテック 레이저텍 ');
    if (jCode == '6861') sb.write('keyence キーエンス 키엔스 ');
    if (jCode == '9983') sb.write('fast retailing ファーストリテイリング 유니클로 uniqlo ');
    if (jCode == '4063') sb.write('shin-etsu 信越化学工業 신에츠 ');

    // Fast aliases for German market giants (English, German, Korean)
    final gCode = (code ?? ticker).toUpperCase().replaceAll('.DE', '').replaceAll('.F', '');
    if (gCode == 'SAP') sb.write('sap software 에스エイ피 사프 소프트웨어 ');
    if (gCode == 'SIE') sb.write('siemens 지멘스 시멘스 ');
    if (gCode == 'ADS') sb.write('adidas 아디다스 아디다스 ');
    if (gCode == 'VOW3' || gCode == 'VOW') sb.write('volkswagen vw 폭스바겐 폴크스바겐 ');
    if (gCode == 'ALV') sb.write('allianz 알리안츠 아리안츠 ');
    if (gCode == 'BMW') sb.write('bmw 비엠더블유 베엠베 ');
    if (gCode == 'MBG') sb.write('mercedes benz 메르세데스 벤츠 벤츠 ');
    if (gCode == 'DTE') sb.write('deutsche telekom 도이치텔레콤 ');
    if (gCode == 'DBK') sb.write('deutsche bank 도이치방크 도이치은행 ');
    if (gCode == 'BAS') sb.write('basf 바스프 ');
    if (gCode == 'BAYN') sb.write('bayer 바이엘 ');
    if (gCode == 'AIR') sb.write('airbus 에어버스 ');
    if (gCode == 'P911') sb.write('porsche 포르쉐 ');
    if (gCode == 'RHM') sb.write('rheinmetall 라인메탈 ');

    // Fast aliases for UK market giants (English, Korean)
    final ukCode = (code ?? ticker).toUpperCase().replaceAll('.L', '');
    if (ukCode == 'AZN') sb.write('astrazeneca 아스트라제네카 ');
    if (ukCode == 'SHEL') sb.write('shell 쉘 셸 ');
    if (ukCode == 'HSBA') sb.write('hsbc 에이치에스비씨 ');
    if (ukCode == 'ULVR') sb.write('unilever 유니레버 ');
    if (ukCode == 'RR') sb.write('rolls royce 롤스로이스 ');
    if (ukCode == 'BP') sb.write('bp 비피 ');
    if (ukCode == 'RIO') sb.write('rio tinto 리오틴토 ');
    if (ukCode == 'GSK') sb.write('gsk 글락소스미스클라인 ');
    if (ukCode == 'BARC') sb.write('barclays 바클레이스 ');
    if (ukCode == 'LLOY') sb.write('lloyds 로이즈 ');
    if (ukCode == 'NWG') sb.write('natwest 넷웨스트 ');
    if (ukCode == 'TSCO') sb.write('tesco 테스코 ');
    if (ukCode == 'VOD') sb.write('vodafone 보더폰 보다가폰 ');

    return sb.toString();
  }

  bool matchesSector(String sectorQuery) {
    if (sectorQuery == 'ALL' || sectorQuery.isEmpty) return true;
    final sqLower = sectorQuery.toLowerCase();
    final secLower = sector.toLowerCase();
    final indLower = (industry ?? '').toLowerCase();

    if (secLower.contains(sqLower) || indLower.contains(sqLower)) return true;

    // Cross-market sector mapping across US, Korea, and Japan
    if (sqLower == 'technology' || sqLower == '기술' || sqLower == '전기전자') {
      return secLower.contains('technology') ||
          secLower.contains('electric appliances') ||
          secLower.contains('information & communication') ||
          secLower.contains('precision instruments') ||
          secLower.contains('전기') ||
          secLower.contains('전자') ||
          secLower.contains('it') ||
          indLower.contains('電気機器') ||
          indLower.contains('情報・通信業') ||
          indLower.contains('精密機器') ||
          indLower.contains('반도체') ||
          indLower.contains('통신') ||
          indLower.contains('전자') ||
          indLower.contains('소프트웨어') ||
          indLower.contains('컴퓨터') ||
          indLower.contains('방송 장비');
    }
    if (sqLower == 'healthcare' || sqLower == '헬스케어' || sqLower == '의약품') {
      return secLower.contains('healthcare') ||
          secLower.contains('pharmaceutical') ||
          secLower.contains('의약') ||
          indLower.contains('医薬品') ||
          indLower.contains('의약') ||
          indLower.contains('의료') ||
          indLower.contains('바이오') ||
          indLower.contains('제약');
    }
    if (sqLower == 'financials' || sqLower == '금융업') {
      return secLower.contains('financial') ||
          secLower.contains('banks') ||
          secLower.contains('insurance') ||
          secLower.contains('securities') ||
          secLower.contains('금융') ||
          indLower.contains('銀行業') ||
          indLower.contains('証券') ||
          indLower.contains('保険業') ||
          indLower.contains('その他金融業') ||
          indLower.contains('금융') ||
          indLower.contains('은행') ||
          indLower.contains('증권') ||
          indLower.contains('보험');
    }
    if (sqLower == 'industrials' || sqLower == '산업재') {
      return secLower.contains('industrial') ||
          secLower.contains('transportation equipment') ||
          secLower.contains('machinery') ||
          secLower.contains('construction') ||
          secLower.contains('metal products') ||
          secLower.contains('기계') ||
          secLower.contains('운수') ||
          indLower.contains('輸送用機器') ||
          indLower.contains('機械') ||
          indLower.contains('建設業') ||
          indLower.contains('金属製品') ||
          indLower.contains('기계') ||
          indLower.contains('장비') ||
          indLower.contains('철강') ||
          indLower.contains('조선') ||
          indLower.contains('건설');
    }
    if (sqLower == 'energy' || sqLower == '에너지') {
      return secLower.contains('energy') ||
          secLower.contains('oil & coal') ||
          secLower.contains('petroleum') ||
          secLower.contains('에너지') ||
          indLower.contains('石油・石炭製品') ||
          indLower.contains('鉱業') ||
          indLower.contains('에너지') ||
          indLower.contains('석유') ||
          indLower.contains('가스') ||
          indLower.contains('화학');
    }
    if (sqLower == 'consumer staples' || sqLower == '필수소비재') {
      return secLower.contains('staples') ||
          secLower.contains('foods') ||
          secLower.contains('fishery') ||
          indLower.contains('食料品') ||
          indLower.contains('水産・農林業') ||
          indLower.contains('식품') ||
          indLower.contains('음료') ||
          indLower.contains('농업');
    }
    if (sqLower == 'consumer discretionary' || sqLower == '임의소비재') {
      return secLower.contains('discretionary') ||
          secLower.contains('retail trade') ||
          secLower.contains('textiles') ||
          indLower.contains('小売業') ||
          indLower.contains('繊維製品') ||
          indLower.contains('자동차') ||
          indLower.contains('유통') ||
          indLower.contains('의류') ||
          indLower.contains('패션');
    }
    if (sqLower == 'materials' || sqLower == '소재') {
      return secLower.contains('materials') ||
          secLower.contains('chemicals') ||
          secLower.contains('iron & steel') ||
          secLower.contains('glass') ||
          indLower.contains('化学') ||
          indLower.contains('鉄鋼') ||
          indLower.contains('非鉄金属') ||
          indLower.contains('ガラス・土石製品') ||
          indLower.contains('소재') ||
          indLower.contains('화학물질') ||
          indLower.contains('광업');
    }
    if (sqLower == 'communication services' || sqLower == '통신') {
      return secLower.contains('communication') ||
          secLower.contains('information & communication') ||
          indLower.contains('情報・通信業') ||
          indLower.contains('통신') ||
          indLower.contains('방송') ||
          indLower.contains('포털');
    }
    if (sqLower == 'utilities' || sqLower == '유틸리티') {
      return secLower.contains('utilities') ||
          secLower.contains('electric power and gas') ||
          indLower.contains('電気・ガス業') ||
          indLower.contains('전력') ||
          indLower.contains('가스') ||
          indLower.contains('수도');
    }
    if (sqLower == 'real estate' || sqLower == '부동산') {
      return secLower.contains('real estate') ||
          indLower.contains('不動産業') ||
          indLower.contains('부동산') ||
          indLower.contains('리츠');
    }
    return false;
  }

  StockSecurity({
    required this.ticker,
    this.code,
    required this.name,
    this.localName,
    this.isin,
    required this.country,
    required this.countryName,
    required this.exchange,
    required this.sector,
    this.industry,
    required this.marketCapCategory,
    required this.currency,
    this.marketCap,
    this.price,
    this.previousClose,
    this.listingStatus = 'LISTED',
    this.rank,
    this.dept,
    this.listingDate,
    this.representative,
    this.homepage,
  });

  factory StockSecurity.fromJson(Map<String, dynamic> json) {
    return StockSecurity(
      ticker: json['ticker'] ?? '',
      code: json['code'],
      name: json['name'] ?? '',
      localName: json['localName'],
      isin: json['isin'],
      country: json['country'] ?? 'KR',
      countryName: json['countryName'] ?? 'South Korea',
      exchange: json['exchange'] ?? 'KOSPI',
      sector: json['sector'] ?? '제조업',
      industry: json['industry'],
      marketCapCategory: json['marketCapCategory'] ?? 'Mid Cap',
      currency: json['currency'] ?? 'KRW',
      marketCap: json['marketCap'] != null ? (json['marketCap'] as num).toDouble() : null,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      previousClose: json['previousClose'] != null ? (json['previousClose'] as num).toDouble() : null,
      listingStatus: json['listingStatus'] ?? 'LISTED',
      rank: json['rank'] != null ? (json['rank'] as num).toInt() : null,
      dept: json['dept'] ?? json['market'],
      listingDate: json['listingDate'],
      representative: json['representative'],
      homepage: json['homepage'],
    );
  }

  Map<String, dynamic> toJson() => {
    'ticker': ticker,
    'code': code,
    'name': name,
    'localName': localName,
    'isin': isin,
    'country': country,
    'countryName': countryName,
    'exchange': exchange,
    'sector': sector,
    'industry': industry,
    'marketCapCategory': marketCapCategory,
    'currency': currency,
    'marketCap': marketCap,
    'price': price,
    'previousClose': previousClose,
    'listingStatus': listingStatus,
    'rank': rank,
    'dept': dept,
    'listingDate': listingDate,
    'representative': representative,
    'homepage': homepage,
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
