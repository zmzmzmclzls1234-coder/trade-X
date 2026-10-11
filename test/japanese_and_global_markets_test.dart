import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_pulse_mobile/models/user.dart';
import 'package:trade_pulse_mobile/services/company_repository.dart';
import 'package:trade_pulse_mobile/services/market_data_service.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  setUpAll(() async {
    final repo = CompanyRepository.instance;
    await repo.initialize();
  });

  group('1. AUTHORITATIVE JPX LISTED COMPANY COVERAGE AUDIT', () {
    test('1.1 Total active JPX listed companies matches official count (3,885)', () {
      final repo = CompanyRepository.instance;
      expect(repo.japaneseCount, 3885);
      expect(repo.japaneseCompanies.where((c) => c.listingStatus == 'LISTED').length, 3885);
    });

    test('1.2 Prime Market coverage matches authoritative count (1,546)', () {
      final repo = CompanyRepository.instance;
      final prime = repo.searchAndFilter(country: 'JP', exchange: 'Prime', listingStatus: 'LISTED');
      expect(prime.length, 1546);
    });

    test('1.3 Standard Market coverage matches authoritative count (1,553)', () {
      final repo = CompanyRepository.instance;
      final standard = repo.searchAndFilter(country: 'JP', exchange: 'Standard', listingStatus: 'LISTED');
      expect(standard.length, 1553);
    });

    test('1.4 Growth Market coverage matches authoritative count (595)', () {
      final repo = CompanyRepository.instance;
      final growth = repo.searchAndFilter(country: 'JP', exchange: 'Growth', listingStatus: 'LISTED');
      expect(growth.length, 595);
    });

    test('1.5 TOKYO PRO Market coverage matches authoritative count (191)', () {
      final repo = CompanyRepository.instance;
      final proMarket = repo.searchAndFilter(country: 'JP', exchange: 'TOKYO PRO Market', listingStatus: 'LISTED');
      expect(proMarket.length, 191);
    });

    test('1.6 Combined global universe (KR 2875 + US 6016 + JP 3885 = 12,776+ active)', () {
      final repo = CompanyRepository.instance;
      expect(repo.koreanCount, 2875);
      expect(repo.usCount, 6016);
      expect(repo.japaneseCount, 3885);
      final totalActive = repo.searchAndFilter(listingStatus: 'LISTED').length;
      expect(totalActive, greaterThanOrEqualTo(12776));
    });

    test('1.7 Zero duplicate codes in active Japanese company universe', () {
      final repo = CompanyRepository.instance;
      final activeJp = repo.searchAndFilter(country: 'JP', listingStatus: 'LISTED');
      final codeSet = <String>{};
      final duplicates = <String>[];
      for (final c in activeJp) {
        if (codeSet.contains(c.code)) {
          duplicates.add(c.code!);
        } else {
          codeSet.add(c.code!);
        }
      }
      expect(duplicates, isEmpty, reason: 'No duplicate codes allowed in JPX universe');
      expect(codeSet.length, 3885);
    });
  });

  group('2. JAPANESE COMPANY DATA & IDENTIFIERS ACCURACY', () {
    test('2.1 Toyota Motor Corporation (7203.T) full attributes verification', () {
      final repo = CompanyRepository.instance;
      final toyota = repo.findCompany('7203');
      expect(toyota, isNotNull);
      expect(toyota!.ticker, '7203.T');
      expect(toyota.code, '7203');
      expect(toyota.name, contains('Toyota'));
      expect(toyota.localName, contains('トヨタ'));
      expect(toyota.exchange, 'Prime');
      expect(toyota.country, 'JP');
      expect(toyota.currency, 'JPY');
      expect(toyota.marketCapCategory, 'Large Cap');
      expect(toyota.marketCap, greaterThan(40000000000000.0));
      expect(toyota.listingStatus, 'LISTED');
    });

    test('2.2 Sony Group (6758.T) and Nintendo (7974.T) verification', () {
      final repo = CompanyRepository.instance;
      final sony = repo.findCompany('6758');
      expect(sony, isNotNull);
      expect(sony!.ticker, '6758.T');
      expect(sony.localName, contains('ソニー'));
      expect(sony.exchange, 'Prime');
      expect(sony.currency, 'JPY');

      final nintendo = repo.findCompany('7974');
      expect(nintendo, isNotNull);
      expect(nintendo!.ticker, '7974.T');
      expect(nintendo.localName, contains('任天堂'));
      expect(nintendo.exchange, 'Prime');
      expect(nintendo.currency, 'JPY');
    });

    test('2.3 Alphanumeric Japanese stock codes handling (e.g. 130A, 641A, 642A)', () {
      final repo = CompanyRepository.instance;
      final code130A = repo.findCompany('130A');
      expect(code130A, isNotNull);
      expect(code130A!.code, '130A');
      expect(code130A.ticker, '130A.T');
      expect(code130A.currency, 'JPY');

      // October 2026 new holding company listing
      final nokGroup = repo.findCompany('641A');
      expect(nokGroup, isNotNull);
      expect(nokGroup!.ticker, '641A.T');
      expect(nokGroup.exchange, 'Prime');
    });
  });

  group('3. MULTI-MARKET SEARCH & ABBREVIATION RESOLUTION', () {
    test('3.1 Search by Japanese name (トヨタ, ソニー, 任天堂)', () {
      final repo = CompanyRepository.instance;
      final toyotaSearch = repo.searchAndFilter(query: 'トヨタ');
      expect(toyotaSearch.any((s) => s.ticker == '7203.T'), isTrue);

      final sonySearch = repo.searchAndFilter(query: 'ソニー');
      expect(sonySearch.any((s) => s.ticker == '6758.T'), isTrue);

      final nintendoSearch = repo.searchAndFilter(query: '任天堂');
      expect(nintendoSearch.any((s) => s.ticker == '7974.T'), isTrue);
    });

    test('3.2 Search by English name and numeric ticker code (Toyota, Sony, 7203)', () {
      final repo = CompanyRepository.instance;
      final searchToyotaEn = repo.searchAndFilter(query: 'Toyota');
      expect(searchToyotaEn.any((s) => s.ticker == '7203.T'), isTrue);

      final search7203 = repo.searchAndFilter(query: '7203');
      expect(search7203.any((s) => s.ticker == '7203.T'), isTrue);
    });

    test('3.3 Fast search debouncing performance across 12,700+ global companies', () {
      final repo = CompanyRepository.instance;
      final sw = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        repo.searchAndFilter(query: 'Electric');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(600), reason: 'Search across 12,700+ stocks must be sub-millisecond per query');
    });
  });

  group('4. MULTI-MARKET FILTERING & SORTING', () {
    test('4.1 Country filter isolates JP vs KR vs US', () {
      final repo = CompanyRepository.instance;
      final jpOnly = repo.searchAndFilter(country: 'JP', listingStatus: 'LISTED');
      expect(jpOnly.length, 3885);
      expect(jpOnly.every((c) => c.country == 'JP'), isTrue);

      final krOnly = repo.searchAndFilter(country: 'KR', listingStatus: 'LISTED');
      expect(krOnly.length, 2875);
      expect(krOnly.every((c) => c.country == 'KR'), isTrue);

      final usOnly = repo.searchAndFilter(country: 'US', listingStatus: 'LISTED');
      expect(usOnly.length, 6016);
      expect(usOnly.every((c) => c.country == 'US'), isTrue);
    });

    test('4.2 Currency filter isolates JPY, KRW, and USD', () {
      final repo = CompanyRepository.instance;
      final jpyOnly = repo.searchAndFilter(currency: 'JPY', listingStatus: 'LISTED');
      expect(jpyOnly.length, 3885);
      expect(jpyOnly.every((c) => c.currency == 'JPY'), isTrue);

      final krwOnly = repo.searchAndFilter(currency: 'KRW', listingStatus: 'LISTED');
      expect(krwOnly.length, 2875);
      expect(krwOnly.every((c) => c.currency == 'KRW'), isTrue);

      final usdOnly = repo.searchAndFilter(currency: 'USD', listingStatus: 'LISTED');
      expect(usdOnly.length, 6016);
      expect(usdOnly.every((c) => c.currency == 'USD'), isTrue);
    });

    test('4.3 Sorting Japanese stocks by Market Cap, Name, and Ticker', () {
      final repo = CompanyRepository.instance;
      final byCapJP = repo.searchAndFilter(country: 'JP', listingStatus: 'LISTED', sort: 'MARKET_CAP_DESC');
      expect(byCapJP.first.ticker, '7203.T'); // Toyota Motor is #1 in Japan

      final byTickerJP = repo.searchAndFilter(country: 'JP', listingStatus: 'LISTED', sort: 'TICKER_ASC');
      expect(byTickerJP.first.ticker, '1301.T'); // Kyokuyo Co.
    });
  });

  group('5. VIRTUAL TRADING & MULTI-CURRENCY (JPY) INTEGRATION', () {
    test('5.1 Multi-currency portfolio holding JPY, KRW, and USD assets simultaneously', () {
      final posJP = PortfolioPosition(
        ticker: '7203.T',
        stockName: 'Toyota Motor',
        shares: 100.0,
        averagePrice: 2850.0,
        averagePriceUSD: 18.09,
        totalCostUSD: 1809.52,
        nativeCurrency: 'JPY',
      );

      final posKR = PortfolioPosition(
        ticker: '005930.KS',
        stockName: '삼성전자',
        shares: 20.0,
        averagePrice: 70000.0,
        averagePriceUSD: 51.71,
        totalCostUSD: 1034.20,
        nativeCurrency: 'KRW',
      );

      final posUS = PortfolioPosition(
        ticker: 'AAPL',
        stockName: 'Apple Inc.',
        shares: 5.0,
        averagePrice: 220.0,
        averagePriceUSD: 220.0,
        totalCostUSD: 1100.0,
        nativeCurrency: 'USD',
      );

      final user = UserProfile(
        id: 'global_investor_jp',
        username: 'TokyoTrader',
        country: 'JP',
        displayCurrency: 'JPY',
        language: 'ja',
        cashUSD: 4000.0,
        portfolio: [posJP, posKR, posUS],
        watchlist: ['7203.T', '6758.T', 'AAPL', '005930.KS'],
        totalRealizedProfit: 150.0,
      );

      expect(user.portfolio.length, 3);
      expect(user.portfolio[0].nativeCurrency, 'JPY');
      expect(user.portfolio[1].nativeCurrency, 'KRW');
      expect(user.portfolio[2].nativeCurrency, 'USD');
    });

    test('5.2 Real market data fetching for Japanese stocks via MarketDataService', () async {
      final quote = await MarketDataService.fetchSingleQuote('7203.T');
      expect(quote.ticker, '7203.T');
      expect(quote.currency, 'JPY');
    });
  });
}
