class TrustedNewsSources {
  // Country-specific allowlist of reputable, verified financial & news organizations
  static const Map<String, List<String>> _approvedSourcesByCountry = {
    // South Korea (대한민국 주요 경제 및 종합 보도 채널)
    'KR': [
      '한국경제TV',
      'SBS Biz',
      '연합뉴스TV',
      'KBS News',
      'KBS 뉴스',
      'MBC 뉴스',
      'MBCNEWS',
      'YTN',
      'YTN news',
      '매일경제TV',
      '매경TV',
      '삼프로TV_경제의신과함께',
      '삼프로TV',
      'JTBC News',
      'JTBC 뉴스',
      '머니투데이방송',
      'MTN 머니투데이방송',
      '이데일리TV',
      'edaily TV',
      '한경 코리아마켓',
      '조선비즈',
      'ChosunBiz',
      '서울경제썸',
      '동아일보',
    ],

    // United States
    'US': [
      'CNBC',
      'CNBC Television',
      'Bloomberg Television',
      'Bloomberg Technology',
      'Bloomberg Markets and Finance',
      'Bloomberg',
      'Reuters',
      'Yahoo Finance',
      'The Wall Street Journal',
      'Wall Street Journal',
      'WSJ',
      'Financial Times',
      'Fox Business',
      'Forbes',
      'MarketWatch',
      'CNN Business',
      'Associated Press',
      'AP Archive',
      'Barron\'s',
      'The Economist',
    ],

    // Japan (日本)
    'JP': [
      '日本経済新聞',
      '日経',
      '日経テレ東大学',
      'テレビ東京 ニュース',
      'テレ東BIZ',
      'NHKニュース',
      'NHK',
      'TBS NEWS DIG Powered by JNN',
      'TBS NEWS DIG',
      'ANNnewsCH',
      '日テレNEWS',
      'FNNプライムオンライン',
      'ロイター',
    ],

    // Germany (Deutschland)
    'DE': [
      'tagesschau',
      'Handelsblatt',
      'DER SPIEGEL',
      'ZDFheute Nachrichten',
      'ZDF',
      'DW Deutsch',
      'Deutsche Welle',
      'ntv Nachrichten',
      'ntv',
      'WELT Nachrichtensender',
      'WELT',
      'manager magazin',
      'Börse Frankfurt',
    ],

    // United Kingdom
    'GB': [
      'BBC News',
      'BBC',
      'Sky News',
      'Financial Times',
      'Reuters',
      'The Guardian',
      'The Telegraph',
      'Bloomberg',
      'ITV News',
      'Channel 4 News',
    ],

    // France
    'FR': [
      'BFM Business',
      'BFMTV',
      'FRANCE 24',
      'Les Echos',
      'Le Figaro',
      'Le Monde',
      'France Info',
      'Euronews',
      'La Tribune',
    ],
  };

  // Global reputable financial institutions accepted across all regions
  static const List<String> _globalReputableSources = [
    'Bloomberg',
    'Bloomberg Television',
    'Bloomberg Technology',
    'Reuters',
    'CNBC',
    'Financial Times',
    'Wall Street Journal',
    'The Wall Street Journal',
    'Yahoo Finance',
    'Forbes',
    'Associated Press',
  ];

  // Negative keywords to filter out non-financial, clickbait, gaming, or scam content
  static const List<String> _negativeKeywords = [
    // Clickbait & Hype
    '1000배', '100배', '벼락부자', '원금 10배', '인생역전 대박',
    '1000x', '100x gem', 'to the moon', 'guaranteed pump',
    'free money', 'get rich quick', 'secret hack',
    // Crypto meme & scams
    'shiba inu pump', 'pepe coin', 'doge moon', 'pump and dump',
    // Entertainment & Vlogs
    'vlog', 'mukbang', '먹방', 'asmr', 'prank', 'minecraft', 'gameplay',
    'k-pop idol', 'fancam', 'music video', 'cover dance', 'song lyrics',
    'highlights match', 'full fight', 'trailer teaser', 'movie recap',
  ];

  // Financial relevance keywords for market news validation
  static const Map<String, List<String>> _marketKeywordsByCountry = {
    'KR': [
      '주식', '증시', '코스피', '코스닥', '상승', '하락', '금리', '환율',
      '실적', '영업이익', '매출', '배당', '한국은행', '투자', '매수',
      '외국인', '기관', '순매수', '반도체', '배터리', '기업', '상장',
      'KOSPI', 'KOSDAQ', 'FOMC', '경제',
    ],
    'US': [
      'stock', 'market', 'nasdaq', 's&p 500', 'dow', 'shares', 'earnings',
      'revenue', 'profit', 'fed', 'interest rate', 'inflation', 'rally',
      'slump', 'investors', 'quarterly', 'dividend', 'guidance', 'ipo',
      'sec', 'yield', 'treasury', 'wall street',
    ],
    'JP': [
      '株価', '東証', '日経平均', '株式', '円安', '円高', '決算', '営業利益',
      '日銀', '金利', '業績', '配当', '銘柄', '投資', '景気', 'TOPIX',
    ],
    'DE': [
      'aktie', 'börse', 'dax', 'kurs', 'inflation', 'ezb', 'zinsen',
      'gewinn', 'umsatz', 'dividende', 'wirtschaft', 'anleger',
    ],
    'GB': [
      'shares', 'ftse', 'market', 'bank of england', 'interest rates',
      'inflation', 'earnings', 'revenue', 'investors', 'economy', 'gilt',
    ],
    'FR': [
      'action', 'bourse', 'cac 40', 'taux', 'inflation', 'résultats',
      'bénéfice', 'dividende', 'économie', 'investisseurs', 'bce',
    ],
  };

  /// Check if a channel name is in our approved allowlist for the given country
  static bool isTrustedSource(String channelTitle, String country) {
    if (channelTitle.trim().isEmpty) return false;
    final normalized = _normalize(channelTitle);

    // 1. Check country-specific approved channels
    final countrySources = _approvedSourcesByCountry[country.toUpperCase()] ?? [];
    for (final src in countrySources) {
      if (_matches(normalized, src)) return true;
    }

    // 2. Check global reputable sources
    for (final src in _globalReputableSources) {
      if (_matches(normalized, src)) return true;
    }

    return false;
  }

  /// Get approved news channels for a country
  static List<String> getApprovedChannels(String country) {
    return _approvedSourcesByCountry[country.toUpperCase()] ?? _approvedSourcesByCountry['US']!;
  }

  /// Check whether video title/description contains negative or clickbait keywords
  static bool hasNegativeKeywords(String title, String description) {
    final lowerTitle = title.toLowerCase();
    final lowerDesc = description.toLowerCase();

    for (final kw in _negativeKeywords) {
      final lkw = kw.toLowerCase();
      if (lowerTitle.contains(lkw) || lowerDesc.contains(lkw)) {
        return true;
      }
    }
    return false;
  }

  /// Validate if news video is genuinely relevant to the specified company
  static bool isRelevantToCompany({
    required String title,
    required String description,
    required String companyName,
    String? localName,
    String? ticker,
  }) {
    if (hasNegativeKeywords(title, description)) return false;

    final lowerTitle = title.toLowerCase();
    final lowerDesc = description.toLowerCase();

    // Check ticker (clean without .KS or exchange suffix)
    if (ticker != null && ticker.isNotEmpty) {
      final cleanTicker = ticker.split('.').first.toLowerCase();
      if (cleanTicker.length >= 3) {
        if (lowerTitle.contains(cleanTicker) || lowerDesc.contains(cleanTicker)) {
          return true;
        }
      }
    }

    // Check localized name (e.g. '삼성전자', 'SK하이닉스')
    if (localName != null && localName.trim().isNotEmpty) {
      final cleanLocal = localName.trim().toLowerCase();
      if (lowerTitle.contains(cleanLocal) || lowerDesc.contains(cleanLocal)) {
        return true;
      }

      // Check common Korean market abbreviations
      if (cleanLocal.contains('현대자동차') && (lowerTitle.contains('현대차') || lowerDesc.contains('현대차'))) return true;
      if (cleanLocal.contains('lg에너지솔루션') && (lowerTitle.contains('lg엔솔') || lowerDesc.contains('lg엔솔') || lowerTitle.contains('엔솔'))) return true;
      if (cleanLocal.contains('삼성바이오로직스') && (lowerTitle.contains('삼바') || lowerTitle.contains('삼성바이오'))) return true;
      if (cleanLocal.contains('sk하이닉스') && (lowerTitle.contains('하이닉스') || lowerDesc.contains('하이닉스'))) return true;
      if (cleanLocal.contains('포스코홀딩스') && (lowerTitle.contains('포스코') || lowerDesc.contains('포스코') || lowerTitle.contains('posco'))) return true;
      if (cleanLocal.contains('카카오뱅크') && (lowerTitle.contains('카뱅') || lowerDesc.contains('카뱅'))) return true;
      if (cleanLocal.contains('한국항공우주') && (lowerTitle.contains('kai') || lowerDesc.contains('kai'))) return true;
      if (cleanLocal.contains('한화에어로스페이스') && (lowerTitle.contains('한화에어로') || lowerDesc.contains('한화에어로'))) return true;
    }

    // Check company name (e.g. 'Samsung Electronics', 'Apple')
    if (companyName.trim().isNotEmpty) {
      final cleanName = companyName.trim().toLowerCase();
      if (lowerTitle.contains(cleanName) || lowerDesc.contains(cleanName)) {
        return true;
      }

      if (cleanName.contains('alphabet') && (lowerTitle.contains('google') || lowerDesc.contains('google'))) return true;
      if (cleanName.contains('meta platforms') && (lowerTitle.contains('facebook') || lowerTitle.contains('meta'))) return true;
      if (cleanName.contains('taiwan semiconductor') && (lowerTitle.contains('tsmc') || lowerDesc.contains('tsmc'))) return true;
      if (cleanName.contains('berkshire') && (lowerTitle.contains('buffett') || lowerDesc.contains('buffett'))) return true;

      // Check first main word of company name (e.g. 'Samsung' or 'Nvidia')
      final firstWord = cleanName.split(' ').first;
      if (firstWord.length >= 4) {
        if (lowerTitle.contains(firstWord)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Validate if video is genuinely relevant to financial/stock markets of country
  static bool isRelevantToMarket({
    required String title,
    required String description,
    required String country,
  }) {
    if (hasNegativeKeywords(title, description)) return false;

    final lowerTitle = title.toLowerCase();
    final lowerDesc = description.toLowerCase();

    final keywords = _marketKeywordsByCountry[country.toUpperCase()] ?? _marketKeywordsByCountry['US']!;
    for (final kw in keywords) {
      if (lowerTitle.contains(kw.toLowerCase()) || lowerDesc.contains(kw.toLowerCase())) {
        return true;
      }
    }

    // General fallback financial terms
    const generalTerms = ['stock', 'market', 'shares', 'earnings', 'economy', 'invest', '증시', '주식'];
    for (final t in generalTerms) {
      if (lowerTitle.contains(t)) return true;
    }

    return false;
  }

  static bool _matches(String normalizedChannel, String sourcePattern) {
    final normPattern = _normalize(sourcePattern);
    return normalizedChannel.contains(normPattern) || normPattern.contains(normalizedChannel);
  }

  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[\s\-_・·|:：]'), '');
  }
}
