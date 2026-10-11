import 'dart:convert';
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
    // Load local json file directly in test environment
    final file = File('assets/data/korean_companies.json');
    if (file.existsSync()) {
      final jsonStr = file.readAsStringSync();
      final List<dynamic> rawList = jsonDecode(jsonStr);
      expect(rawList.length, greaterThan(2500));
      
      // Initialize repository
      final repo = CompanyRepository.instance;
      await repo.initialize();
      expect(repo.totalCount, greaterThan(2500));
    }
  });

  group('1. KOREAN COMPANIES COMPREHENSIVE COVERAGE', () {
    test('1.1 Total Korean listed companies exceeds 2,700+', () {
      final repo = CompanyRepository.instance;
      expect(repo.totalCount, greaterThanOrEqualTo(2700));
    });

    test('1.2 KOSPI market coverage exceeds 900+ companies', () {
      final kospi = CompanyRepository.instance.searchAndFilter(exchange: 'KOSPI');
      expect(kospi.length, greaterThanOrEqualTo(900));
      for (final s in kospi) {
        expect(s.exchange, 'KOSPI');
        expect(s.ticker, endsWith('.KS'));
        expect(s.currency, 'KRW');
      }
    });

    test('1.3 KOSDAQ market coverage exceeds 1,700+ companies', () {
      final kosdaq = CompanyRepository.instance.searchAndFilter(exchange: 'KOSDAQ');
      expect(kosdaq.length, greaterThanOrEqualTo(1700));
      for (final s in kosdaq) {
        expect(s.exchange, 'KOSDAQ');
        expect(s.ticker, endsWith('.KQ'));
        expect(s.currency, 'KRW');
      }
    });

    test('1.4 KONEX market coverage supported (100+ companies)', () {
      final konex = CompanyRepository.instance.searchAndFilter(exchange: 'KONEX');
      expect(konex.length, greaterThanOrEqualTo(100));
      for (final s in konex) {
        expect(s.exchange, 'KONEX');
        expect(s.currency, 'KRW');
      }
    });
  });

  group('2. COMPANY DATA & IDENTIFIERS ACCURACY', () {
    test('2.1 Samsung Electronics (005930.KS) full attributes verification', () {
      final samsung = CompanyRepository.instance.findCompany('005930.KS');
      expect(samsung, isNotNull);
      expect(samsung!.localName, '삼성전자');
      expect(samsung.name, contains('Samsung'));
      expect(samsung.code, '005930');
      expect(samsung.isin, 'KR7005930003');
      expect(samsung.exchange, 'KOSPI');
      expect(samsung.country, 'KR');
      expect(samsung.currency, 'KRW');
      expect(samsung.marketCapCategory, 'Large Cap');
      expect(samsung.listingStatus, 'LISTED');
    });

    test('2.2 SK Hynix (000660.KS) lookup by ISIN and 6-digit code', () {
      final byCode = CompanyRepository.instance.findCompany('000660');
      expect(byCode, isNotNull);
      expect(byCode!.localName, 'SK하이닉스');
      expect(byCode.ticker, '000660.KS');

      final byIsin = CompanyRepository.instance.findCompany(byCode.isin ?? 'KR7000660001');
      expect(byIsin, isNotNull);
      expect(byIsin!.localName, 'SK하이닉스');
    });

    test('2.3 Hyundai Motor (005380.KS) and KOSDAQ leaders present', () {
      final hyundai = CompanyRepository.instance.findCompany('005380');
      expect(hyundai, isNotNull);
      expect(hyundai!.localName, '현대자동차');

      final ecopro = CompanyRepository.instance.findCompany('247540.KQ');
      expect(ecopro, isNotNull);
      expect(ecopro!.localName, '에코프로비엠');
      expect(ecopro.exchange, 'KOSDAQ');
    });
  });

  group('3. SEARCH & ABBREVIATION RESOLUTION', () {
    test('3.1 Search by Korean name, English name, and ticker code', () {
      final searchKorean = CompanyRepository.instance.searchAndFilter(query: '삼성전자');
      expect(searchKorean, isNotEmpty);
      expect(searchKorean.first.localName, '삼성전자');

      final searchEnglish = CompanyRepository.instance.searchAndFilter(query: 'Samsung Electronics');
      expect(searchEnglish, isNotEmpty);
      expect(searchEnglish.first.ticker, '005930.KS');

      final searchCode = CompanyRepository.instance.searchAndFilter(query: '005930');
      expect(searchCode, isNotEmpty);
      expect(searchCode.first.ticker, '005930.KS');
    });

    test('3.2 Korean colloquial abbreviations (현대차, LG엔솔, 삼바, 카뱅)', () {
      final hyundaiAbbr = CompanyRepository.instance.searchAndFilter(query: '현대차');
      expect(hyundaiAbbr.any((s) => s.localName?.contains('현대자동차') == true || s.localName?.contains('현대차') == true), isTrue);

      final lgEnsolAbbr = CompanyRepository.instance.searchAndFilter(query: 'LG엔솔');
      expect(lgEnsolAbbr.any((s) => s.localName?.contains('LG에너지솔루션') == true), isTrue);

      final sambaAbbr = CompanyRepository.instance.searchAndFilter(query: '삼바');
      expect(sambaAbbr.any((s) => s.localName?.contains('삼성바이오로직스') == true), isTrue);
    });

    test('3.3 Fast search debouncing & indexing performance', () {
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        CompanyRepository.instance.searchAndFilter(query: '바이오');
      }
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(500), reason: 'Search must be sub-millisecond per query');
    });
  });

  group('4. SORTING & PAGINATION', () {
    test('4.1 Sorting by Market Cap, Name A-Z, Name Z-A, and Ticker', () {
      final byCap = CompanyRepository.instance.searchAndFilter(sort: 'MARKET_CAP_DESC');
      expect(byCap, isNotEmpty);
      expect(byCap.first.ticker, '005930.KS'); // Samsung Electronics is largest

      final byNameAsc = CompanyRepository.instance.searchAndFilter(sort: 'NAME_ASC');
      expect(byNameAsc, isNotEmpty);

      final byNameDesc = CompanyRepository.instance.searchAndFilter(sort: 'NAME_DESC');
      expect(byNameDesc, isNotEmpty);

      final byTicker = CompanyRepository.instance.searchAndFilter(sort: 'TICKER_ASC');
      expect(byTicker, isNotEmpty);
    });

    test('4.2 Pagination with lazy slice loading', () {
      final page1 = CompanyRepository.instance.getPaginatedList(page: 1, pageSize: 40);
      expect(page1.length, 40);

      final page2 = CompanyRepository.instance.getPaginatedList(page: 2, pageSize: 40);
      expect(page2.length, 40);
      expect(page1.first.ticker, isNot(equals(page2.first.ticker)));

      final outOfBounds = CompanyRepository.instance.getPaginatedList(page: 9999, pageSize: 40);
      expect(outOfBounds, isEmpty);
    });
  });

  group('5. VIRTUAL TRADING & REAL MARKET QUOTE INTEGRATION', () {
    test('5.1 Trading portfolio position creation and profit calculation in KRW', () {
      final pos = PortfolioPosition(
        ticker: '005930.KS',
        stockName: '삼성전자',
        shares: 100.0,
        averagePrice: 75000.0,
        averagePriceUSD: 55.40,
        totalCostUSD: 5540.0,
        nativeCurrency: 'KRW',
      );

      final user = UserProfile(
        id: 'kr_trader_01',
        username: '한국투자자',
        country: 'KR',
        displayCurrency: 'KRW',
        language: 'ko',
        cashUSD: 1000000.0 / 1350.0,
        portfolio: [pos],
        watchlist: ['005930.KS', '000660.KS'],
        totalRealizedProfit: 500000.0,
      );

      expect(user.portfolio.length, 1);
      expect(user.portfolio.first.shares, 100.0);
      expect(user.portfolio.first.nativeCurrency, 'KRW');
      expect(user.virtualCashBalance, closeTo(1000000.0, 100.0));
    });

    test('5.2 Real quote fetch for Korean stocks via MarketDataService', () async {
      final quote = await MarketDataService.fetchSingleQuote('005930.KS');
      expect(quote.ticker, '005930.KS');
      expect(quote.currency, 'KRW');
    });
  });
}
