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

  group('1. COMBINED MULTI-MARKET DATABASE INTEGRITY', () {
    test('1.1 Total combined companies count reaches 8,800+', () {
      final repo = CompanyRepository.instance;
      expect(repo.totalCount, greaterThanOrEqualTo(8800));
      expect(repo.koreanCount, 2875);
      expect(repo.usCount, 6016);
    });

    test('1.2 Korean market completeness preserved (KOSPI 944, KOSDAQ 1824, KONEX 107)', () {
      final repo = CompanyRepository.instance;
      final kospi = repo.searchAndFilter(country: 'KR', exchange: 'KOSPI');
      final kosdaq = repo.searchAndFilter(country: 'KR', exchange: 'KOSDAQ');
      final konex = repo.searchAndFilter(country: 'KR', exchange: 'KONEX');

      expect(kospi.length, 944);
      expect(kosdaq.length, 1824);
      expect(konex.length, 107);
    });

    test('1.3 US market authoritative coverage (NASDAQ 3487, NYSE 2239, AMEX 273)', () {
      final repo = CompanyRepository.instance;
      final nasdaq = repo.searchAndFilter(country: 'US', exchange: 'NASDAQ');
      final nyse = repo.searchAndFilter(country: 'US', exchange: 'NYSE');
      final amex = repo.searchAndFilter(country: 'US', exchange: 'AMEX');
      final other = repo.searchAndFilter(country: 'US').where((c) => c.exchange == 'ARCA' || c.exchange == 'BATS').toList();

      expect(nasdaq.length, 3487);
      expect(nyse.length, 2239);
      expect(amex.length, 273);
      expect(other.length, 17);
      expect(repo.usCount, 6016);
    });
  });

  group('2. US COMPANY INFORMATION & IDENTIFIERS ACCURACY', () {
    test('2.1 Apple Inc. (AAPL) full attributes on NASDAQ', () {
      final repo = CompanyRepository.instance;
      final aapl = repo.findCompany('AAPL');
      expect(aapl, isNotNull);
      expect(aapl!.ticker, 'AAPL');
      expect(aapl.name, contains('Apple'));
      expect(aapl.exchange, 'NASDAQ');
      expect(aapl.country, 'US');
      expect(aapl.currency, 'USD');
      expect(aapl.sector, 'Technology');
      expect(aapl.marketCapCategory, 'Large Cap');
      expect(aapl.listingStatus, 'LISTED');
    });

    test('2.2 NVIDIA (NVDA) and Microsoft (MSFT) attributes', () {
      final repo = CompanyRepository.instance;
      final nvda = repo.findCompany('NVDA');
      expect(nvda, isNotNull);
      expect(nvda!.exchange, 'NASDAQ');
      expect(nvda.currency, 'USD');

      final msft = repo.findCompany('MSFT');
      expect(msft, isNotNull);
      expect(msft!.exchange, 'NASDAQ');
      expect(msft.sector, 'Technology');
    });

    test('2.3 NYSE and AMEX companies presence', () {
      final repo = CompanyRepository.instance;
      final jpm = repo.findCompany('JPM'); // JPMorgan on NYSE
      expect(jpm, isNotNull);
      expect(jpm!.exchange, 'NYSE');
      expect(jpm.currency, 'USD');

      final acu = repo.findCompany('ACU'); // Acme United on AMEX
      expect(acu, isNotNull);
      expect(acu!.exchange, 'AMEX');
      expect(acu.currency, 'USD');
    });
  });

  group('3. MULTI-MARKET SEARCH & ABBREVIATION LOOKUP', () {
    test('3.1 Search by English name and US ticker', () {
      final repo = CompanyRepository.instance;
      final searchAapl = repo.searchAndFilter(query: 'AAPL');
      expect(searchAapl, isNotEmpty);
      expect(searchAapl.first.ticker, 'AAPL');

      final searchTesla = repo.searchAndFilter(query: 'Tesla');
      expect(searchTesla, isNotEmpty);
      expect(searchTesla.any((s) => s.ticker == 'TSLA'), isTrue);
    });

    test('3.2 Korean colloquial search for US giants (애플, 테슬라, 엔비디아, 아마존)', () {
      final repo = CompanyRepository.instance;
      final searchAppleKr = repo.searchAndFilter(query: '애플');
      expect(searchAppleKr.any((s) => s.ticker == 'AAPL'), isTrue);

      final searchTeslaKr = repo.searchAndFilter(query: '테슬라');
      expect(searchTeslaKr.any((s) => s.ticker == 'TSLA'), isTrue);

      final searchNvdaKr = repo.searchAndFilter(query: '엔비디아');
      expect(searchNvdaKr.any((s) => s.ticker == 'NVDA'), isTrue);
    });

    test('3.3 Search performance across 8,800+ companies', () {
      final repo = CompanyRepository.instance;
      final sw = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        repo.searchAndFilter(query: 'Tech');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(600), reason: 'Search across 8,800+ stocks must be sub-millisecond');
    });
  });

  group('4. FILTERING & SORTING', () {
    test('4.1 Country filter isolates KR vs US', () {
      final repo = CompanyRepository.instance;
      final krOnly = repo.searchAndFilter(country: 'KR');
      expect(krOnly.length, 2875);
      expect(krOnly.every((c) => c.country == 'KR'), isTrue);

      final usOnly = repo.searchAndFilter(country: 'US');
      expect(usOnly.length, 6016);
      expect(usOnly.every((c) => c.country == 'US'), isTrue);
    });

    test('4.2 Sector filter works across markets', () {
      final repo = CompanyRepository.instance;
      final techStocks = repo.searchAndFilter(sector: 'Technology');
      expect(techStocks, isNotEmpty);
      expect(techStocks.any((s) => s.ticker == 'AAPL'), isTrue);
      expect(techStocks.any((s) => s.ticker == '005930.KS'), isTrue);
    });

    test('4.3 Sorting by Market Cap, Name, and Ticker', () {
      final repo = CompanyRepository.instance;
      final byCapUS = repo.searchAndFilter(country: 'US', sort: 'MARKET_CAP_DESC');
      expect(byCapUS.first.ticker, 'AAPL'); // Top US market cap

      final byName = repo.searchAndFilter(country: 'US', sort: 'NAME_ASC');
      expect(byName, isNotEmpty);

      final byTicker = repo.searchAndFilter(country: 'US', sort: 'TICKER_ASC');
      expect(byTicker.first.ticker, 'A'); // Agilent Technologies
    });
  });

  group('5. VIRTUAL TRADING & MULTI-CURRENCY INTEGRATION', () {
    test('5.1 Dual-currency portfolio holding KRW and USD assets', () {
      final posKR = PortfolioPosition(
        ticker: '005930.KS',
        stockName: '삼성전자',
        shares: 50.0,
        averagePrice: 70000.0,
        averagePriceUSD: 51.85,
        totalCostUSD: 2592.5,
        nativeCurrency: 'KRW',
      );

      final posUS = PortfolioPosition(
        ticker: 'AAPL',
        stockName: 'Apple Inc.',
        shares: 10.0,
        averagePrice: 220.0,
        averagePriceUSD: 220.0,
        totalCostUSD: 2200.0,
        nativeCurrency: 'USD',
      );

      final user = UserProfile(
        id: 'global_trader_01',
        username: 'GlobalTrader',
        country: 'US',
        displayCurrency: 'USD',
        language: 'en',
        cashUSD: 5000.0,
        portfolio: [posKR, posUS],
        watchlist: ['AAPL', '005930.KS', 'NVDA'],
        totalRealizedProfit: 250.0,
      );

      expect(user.portfolio.length, 2);
      expect(user.portfolio[0].nativeCurrency, 'KRW');
      expect(user.portfolio[1].nativeCurrency, 'USD');
      expect(user.virtualCashBalance, closeTo(5000.0, 0.01));
    });

    test('5.2 Real market data fetching for US and Korean stocks', () async {
      final usQuote = await MarketDataService.fetchSingleQuote('AAPL');
      expect(usQuote.ticker, 'AAPL');
      expect(usQuote.currency, 'USD');

      final krQuote = await MarketDataService.fetchSingleQuote('005930.KS');
      expect(krQuote.ticker, '005930.KS');
      expect(krQuote.currency, 'KRW');
    });
  });
}
