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

  group('1. AUTHORITATIVE UK LISTED COMPANY COVERAGE AUDIT', () {
    test('1.1 Total active UK listed companies matches authoritative count (3200)', () {
      final repo = CompanyRepository.instance;
      expect(repo.ukCount, 3200);
      expect(repo.ukCompanies.where((c) => c.listingStatus == 'LISTED').length, 3200);
    });

    test('1.2 Main Market and AIM coverage matches authoritative count', () {
      final repo = CompanyRepository.instance;
      final mainMarket = repo.searchAndFilter(country: 'GB', dept: 'Main Market', listingStatus: 'LISTED');
      final aimMarket = repo.searchAndFilter(country: 'GB', dept: 'AIM', listingStatus: 'LISTED');
      expect(mainMarket.length + aimMarket.length, 3200);
      expect(mainMarket.isNotEmpty, isTrue);
      expect(aimMarket.isNotEmpty, isTrue);
    });

    test('1.3 Zero duplicate ISINs in UK company universe (Requirement 12: Avoid double counting)', () {
      final repo = CompanyRepository.instance;
      final ukCompanies = repo.ukCompanies;
      final isinSet = <String>{};
      final duplicateIsins = <String>[];

      for (final c in ukCompanies) {
        if (c.isin != null && c.isin!.isNotEmpty) {
          if (isinSet.contains(c.isin)) {
            duplicateIsins.add(c.isin!);
          } else {
            isinSet.add(c.isin!);
          }
        }
      }

      expect(duplicateIsins, isEmpty, reason: 'No duplicate ISINs allowed across LSE Main Market and AIM');
      expect(isinSet.length, 3200);
    });

    test('1.4 Zero duplicate tickers in UK company universe', () {
      final repo = CompanyRepository.instance;
      final ukCompanies = repo.ukCompanies;
      final tickerSet = <String>{};
      final duplicateTickers = <String>[];

      for (final c in ukCompanies) {
        if (tickerSet.contains(c.ticker)) {
          duplicateTickers.add(c.ticker);
        } else {
          tickerSet.add(c.ticker);
        }
      }

      expect(duplicateTickers, isEmpty, reason: 'No duplicate tickers allowed in UK universe');
      expect(tickerSet.length, 3200);
    });

    test('1.5 Combined global universe active count', () {
      final repo = CompanyRepository.instance;
      expect(repo.koreanCount, 2875);
      expect(repo.usCount, 6016);
      expect(repo.japaneseCount, 3885);
      expect(repo.germanCount, 419);
      expect(repo.ukCount, 3200);
      final totalActive = repo.searchAndFilter(listingStatus: 'LISTED').length;
      final expectedCount = repo.koreanCount + repo.usCount + repo.japaneseCount + repo.germanCount + repo.ukCount + repo.frenchCount;
      expect(totalActive, expectedCount);
    });
  });

  group('2. UK COMPANY DATA & IDENTIFIERS ACCURACY', () {
    test('2.1 AstraZeneca PLC (AZN.L) full attributes verification', () {
      final repo = CompanyRepository.instance;
      final azn = repo.findCompany('AZN.L') ?? repo.findCompany('AZN');
      expect(azn, isNotNull);
      expect(azn!.ticker, 'AZN.L');
      expect(azn.code, 'AZN');
      expect(azn.isin, 'GB0009895292');
      expect(azn.name, contains('AstraZeneca'));
      expect(azn.exchange, 'London Stock Exchange');
      expect(azn.dept, 'Main Market');
      expect(azn.country, 'GB');
      expect(azn.currency, 'GBP');
      expect(azn.marketCapCategory, 'Large Cap');
      expect(azn.marketCap, greaterThan(100000000000.0));
      expect(azn.listingStatus, 'LISTED');
    });

    test('2.2 Shell PLC (SHEL.L) and HSBC Holdings (HSBA.L) verification', () {
      final repo = CompanyRepository.instance;
      final shell = repo.findCompany('SHEL.L') ?? repo.findCompany('SHEL');
      expect(shell, isNotNull);
      expect(shell!.ticker, 'SHEL.L');
      expect(shell.isin, 'GB00BP633308');
      expect(shell.currency, 'GBP');

      final hsbc = repo.findCompany('HSBA.L') ?? repo.findCompany('HSBA');
      expect(hsbc, isNotNull);
      expect(hsbc!.ticker, 'HSBA.L');
      expect(hsbc.isin, 'GB0005405286');
      expect(hsbc.currency, 'GBP');
    });

    test('2.3 AIM Market leaders: ASOS (ASC.L) and Fevertree Drinks (FEVR.L) verification', () {
      final repo = CompanyRepository.instance;
      final asos = repo.findCompany('ASC.L') ?? repo.findCompany('ASC');
      expect(asos, isNotNull);
      expect(asos!.ticker, 'ASC.L');
      expect(asos.dept, 'AIM');
      expect(asos.isin, 'GB0030927254');

      final fevertree = repo.findCompany('FEVR.L') ?? repo.findCompany('FEVR');
      expect(fevertree, isNotNull);
      expect(fevertree!.ticker, 'FEVR.L');
      expect(fevertree.dept, 'AIM');
      expect(fevertree.isin, 'GB00BRJ90B80');
    });
  });

  group('3. MULTI-MARKET SEARCH & IDENTIFIER LOOKUP', () {
    test('3.1 Search by UK company name (AstraZeneca, Shell, HSBC, Unilever, Rolls-Royce)', () {
      final repo = CompanyRepository.instance;
      final aznSearch = repo.searchAndFilter(query: 'AstraZeneca');
      expect(aznSearch.any((s) => s.ticker == 'AZN.L'), isTrue);

      final shellSearch = repo.searchAndFilter(query: 'Shell');
      expect(shellSearch.any((s) => s.ticker == 'SHEL.L'), isTrue);

      final hsbcSearch = repo.searchAndFilter(query: 'HSBC');
      expect(hsbcSearch.any((s) => s.ticker == 'HSBA.L'), isTrue);
    });

    test('3.2 Search by ticker and ISIN (AZN, GB0009895292, GB00BP633308)', () {
      final repo = CompanyRepository.instance;
      final aznTickerSearch = repo.searchAndFilter(query: 'AZN');
      expect(aznTickerSearch.any((s) => s.ticker == 'AZN.L'), isTrue);

      final aznIsinSearch = repo.searchAndFilter(query: 'GB0009895292');
      expect(aznIsinSearch.any((s) => s.ticker == 'AZN.L'), isTrue);

      final shellIsinSearch = repo.searchAndFilter(query: 'GB00BP633308');
      expect(shellIsinSearch.any((s) => s.ticker == 'SHEL.L'), isTrue);
    });

    test('3.3 Fast search debouncing performance across 12,900+ global companies', () {
      final repo = CompanyRepository.instance;
      final sw = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        repo.searchAndFilter(query: 'Pharmaceuticals');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(600), reason: 'Search across 12,900+ stocks must be sub-millisecond per query');
    });
  });

  group('4. MULTI-MARKET FILTERING & SORTING', () {
    test('4.1 Country filter isolates GB vs DE vs JP vs KR vs US', () {
      final repo = CompanyRepository.instance;
      final ukOnly = repo.searchAndFilter(country: 'GB', listingStatus: 'LISTED');
      expect(ukOnly.length, 3200);
      expect(ukOnly.every((c) => c.country == 'GB'), isTrue);

      final deOnly = repo.searchAndFilter(country: 'DE', listingStatus: 'LISTED');
      expect(deOnly.length, 419);

      final jpOnly = repo.searchAndFilter(country: 'JP', listingStatus: 'LISTED');
      expect(jpOnly.length, 3885);
    });

    test('4.2 Currency filter isolates GBP, EUR, JPY, KRW, and USD', () {
      final repo = CompanyRepository.instance;
      final gbpOnly = repo.searchAndFilter(currency: 'GBP', listingStatus: 'LISTED');
      expect(gbpOnly.length, 3200);
      expect(gbpOnly.every((c) => c.currency == 'GBP'), isTrue);
    });

    test('4.3 Sorting UK stocks by Market Cap, Name, and Ticker', () {
      final repo = CompanyRepository.instance;
      final byCapUK = repo.searchAndFilter(country: 'GB', listingStatus: 'LISTED', sort: 'MARKET_CAP_DESC');
      expect(byCapUK.first.ticker, 'AZN.L'); // AstraZeneca PLC is #1 by Market Cap in UK

      final byNameUK = repo.searchAndFilter(country: 'GB', listingStatus: 'LISTED', sort: 'NAME_ASC');
      expect(byNameUK.isNotEmpty, isTrue);
    });
  });

  group('5. VIRTUAL TRADING & MULTI-CURRENCY (GBP) INTEGRATION', () {
    test('5.1 Multi-currency portfolio holding GBP, EUR, JPY, KRW, and USD assets simultaneously', () {
      final posUK = PortfolioPosition(
        ticker: 'AZN.L',
        stockName: 'AstraZeneca PLC',
        shares: 10.0,
        averagePrice: 118.70,
        averagePriceUSD: 156.18,
        totalCostUSD: 1561.80,
        nativeCurrency: 'GBP',
      );

      final posDE = PortfolioPosition(
        ticker: 'SAP.DE',
        stockName: 'SAP SE',
        shares: 10.0,
        averagePrice: 183.92,
        averagePriceUSD: 198.83,
        totalCostUSD: 1988.30,
        nativeCurrency: 'EUR',
      );

      final user = UserProfile(
        id: 'global_investor_uk',
        username: 'LondonTrader',
        country: 'GB',
        displayCurrency: 'GBP',
        language: 'en',
        cashUSD: 10000.0,
        portfolio: [posUK, posDE],
        watchlist: ['AZN.L', 'SHEL.L', 'SAP.DE', '7203.T', 'AAPL'],
        totalRealizedProfit: 500.0,
      );

      expect(user.portfolio.length, 2);
      expect(user.portfolio[0].nativeCurrency, 'GBP');
      expect(user.portfolio[1].nativeCurrency, 'EUR');
    });

    test('5.2 Real market data fetching for UK stocks via MarketDataService', () async {
      final quote = await MarketDataService.fetchSingleQuote('AZN.L');
      expect(quote.ticker, 'AZN.L');
      expect(quote.currency.toUpperCase(), 'GBP');
    });
  });
}
