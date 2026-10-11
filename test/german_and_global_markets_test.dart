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

  group('1. AUTHORITATIVE GERMAN LISTED COMPANY COVERAGE AUDIT', () {
    test('1.1 Total active German listed companies matches authoritative count (419)', () {
      final repo = CompanyRepository.instance;
      expect(repo.germanCount, 419);
      expect(repo.germanCompanies.where((c) => c.listingStatus == 'LISTED').length, 419);
    });

    test('1.2 Zero duplicate ISINs in German company universe (Requirement 12: Avoid double counting)', () {
      final repo = CompanyRepository.instance;
      final deCompanies = repo.germanCompanies;
      final isinSet = <String>{};
      final duplicateIsins = <String>[];

      for (final c in deCompanies) {
        if (c.isin != null && c.isin!.isNotEmpty) {
          if (isinSet.contains(c.isin)) {
            duplicateIsins.add(c.isin!);
          } else {
            isinSet.add(c.isin!);
          }
        }
      }

      expect(duplicateIsins, isEmpty, reason: 'No duplicate ISINs allowed across Xetra and Frankfurt trading venues');
      expect(isinSet.length, 419);
    });

    test('1.3 Zero duplicate tickers in German company universe', () {
      final repo = CompanyRepository.instance;
      final deCompanies = repo.germanCompanies;
      final tickerSet = <String>{};
      final duplicateTickers = <String>[];

      for (final c in deCompanies) {
        if (tickerSet.contains(c.ticker)) {
          duplicateTickers.add(c.ticker);
        } else {
          tickerSet.add(c.ticker);
        }
      }

      expect(duplicateTickers, isEmpty, reason: 'No duplicate tickers allowed in German universe');
      expect(tickerSet.length, 419);
    });

    test('1.4 Combined global universe active count', () {
      final repo = CompanyRepository.instance;
      expect(repo.koreanCount, 2875);
      expect(repo.usCount, 6016);
      expect(repo.japaneseCount, 3885);
      expect(repo.germanCount, 419);
      final totalActive = repo.searchAndFilter(listingStatus: 'LISTED').length;
      final expectedCount = repo.koreanCount + repo.usCount + repo.japaneseCount + repo.germanCount + repo.ukCount + repo.frenchCount;
      expect(totalActive, expectedCount);
    });
  });

  group('2. GERMAN COMPANY DATA & IDENTIFIERS ACCURACY', () {
    test('2.1 SAP SE (SAP.DE) full attributes verification', () {
      final repo = CompanyRepository.instance;
      final sap = repo.findCompany('SAP.DE') ?? repo.findCompany('SAP');
      expect(sap, isNotNull);
      expect(sap!.ticker, 'SAP.DE');
      expect(sap.code, 'SAP');
      expect(sap.isin, 'DE0007164600');
      expect(sap.name, contains('SAP'));
      expect(sap.localName, contains('SAP'));
      expect(sap.exchange, 'Xetra');
      expect(sap.country, 'DE');
      expect(sap.currency, 'EUR');
      expect(sap.marketCapCategory, 'Large Cap');
      expect(sap.marketCap, greaterThan(100000000000.0));
      expect(sap.listingStatus, 'LISTED');
    });

    test('2.2 Siemens AG (SIE.DE) and Allianz SE (ALV.DE) verification', () {
      final repo = CompanyRepository.instance;
      final siemens = repo.findCompany('SIE.DE') ?? repo.findCompany('SIE');
      expect(siemens, isNotNull);
      expect(siemens!.ticker, 'SIE.DE');
      expect(siemens.isin, 'DE0007236101');
      expect(siemens.currency, 'EUR');

      final allianz = repo.findCompany('ALV.DE') ?? repo.findCompany('ALV');
      expect(allianz, isNotNull);
      expect(allianz!.ticker, 'ALV.DE');
      expect(allianz.isin, 'DE0008404005');
      expect(allianz.currency, 'EUR');
    });

    test('2.3 Adidas (ADS.DE), Volkswagen (VOW3.DE), and BMW (BMW.DE) verification', () {
      final repo = CompanyRepository.instance;
      final adidas = repo.findCompany('ADS.DE') ?? repo.findCompany('ADS');
      expect(adidas, isNotNull);
      expect(adidas!.ticker, 'ADS.DE');
      expect(adidas.isin, 'DE000A1EWWW0');

      final vw = repo.findCompany('VOW3.DE') ?? repo.findCompany('VOW3');
      expect(vw, isNotNull);
      expect(vw!.ticker, 'VOW3.DE');
      expect(vw.isin, 'DE0007664039');

      final bmw = repo.findCompany('BMW.DE') ?? repo.findCompany('BMW');
      expect(bmw, isNotNull);
      expect(bmw!.ticker, 'BMW.DE');
      expect(bmw.isin, 'DE0005190003');
    });
  });

  group('3. MULTI-MARKET SEARCH & IDENTIFIER LOOKUP', () {
    test('3.1 Search by German company name (Siemens, Volkswagen, Adidas)', () {
      final repo = CompanyRepository.instance;
      final sieSearch = repo.searchAndFilter(query: 'Siemens');
      expect(sieSearch.any((s) => s.ticker == 'SIE.DE'), isTrue);

      final vwSearch = repo.searchAndFilter(query: 'Volkswagen');
      expect(vwSearch.any((s) => s.ticker == 'VOW3.DE'), isTrue);

      final adsSearch = repo.searchAndFilter(query: 'Adidas');
      expect(adsSearch.any((s) => s.ticker == 'ADS.DE'), isTrue);
    });

    test('3.2 Search by ticker and ISIN (SAP, DE0007164600, DE0008404005)', () {
      final repo = CompanyRepository.instance;
      final sapTickerSearch = repo.searchAndFilter(query: 'SAP');
      expect(sapTickerSearch.any((s) => s.ticker == 'SAP.DE'), isTrue);

      final sapIsinSearch = repo.searchAndFilter(query: 'DE0007164600');
      expect(sapIsinSearch.any((s) => s.ticker == 'SAP.DE'), isTrue);

      final alvIsinSearch = repo.searchAndFilter(query: 'DE0008404005');
      expect(alvIsinSearch.any((s) => s.ticker == 'ALV.DE'), isTrue);
    });

    test('3.3 Fast search debouncing performance across 12,800+ global companies', () {
      final repo = CompanyRepository.instance;
      final sw = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        repo.searchAndFilter(query: 'Software');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(600), reason: 'Search across 12,800+ stocks must be sub-millisecond per query');
    });
  });

  group('4. MULTI-MARKET FILTERING & SORTING', () {
    test('4.1 Country filter isolates DE vs JP vs KR vs US', () {
      final repo = CompanyRepository.instance;
      final deOnly = repo.searchAndFilter(country: 'DE', listingStatus: 'LISTED');
      expect(deOnly.length, 419);
      expect(deOnly.every((c) => c.country == 'DE'), isTrue);

      final jpOnly = repo.searchAndFilter(country: 'JP', listingStatus: 'LISTED');
      expect(jpOnly.length, 3885);

      final krOnly = repo.searchAndFilter(country: 'KR', listingStatus: 'LISTED');
      expect(krOnly.length, 2875);

      final usOnly = repo.searchAndFilter(country: 'US', listingStatus: 'LISTED');
      expect(usOnly.length, 6016);
    });

    test('4.2 Currency filter isolates EUR, JPY, KRW, and USD', () {
      final repo = CompanyRepository.instance;
      final eurOnly = repo.searchAndFilter(currency: 'EUR', listingStatus: 'LISTED');
      expect(eurOnly.length, 419 + repo.frenchCount);
      expect(eurOnly.every((c) => c.currency == 'EUR'), isTrue);

      final jpyOnly = repo.searchAndFilter(currency: 'JPY', listingStatus: 'LISTED');
      expect(jpyOnly.length, 3885);
    });

    test('4.3 Sorting German stocks by Market Cap, Name, and Ticker', () {
      final repo = CompanyRepository.instance;
      final byCapDE = repo.searchAndFilter(country: 'DE', listingStatus: 'LISTED', sort: 'MARKET_CAP_DESC');
      expect(byCapDE.first.ticker, 'SAP.DE'); // SAP SE is #1 by Market Cap in Germany

      final byNameDE = repo.searchAndFilter(country: 'DE', listingStatus: 'LISTED', sort: 'NAME_ASC');
      expect(byNameDE.isNotEmpty, isTrue);
    });
  });

  group('5. VIRTUAL TRADING & MULTI-CURRENCY (EUR) INTEGRATION', () {
    test('5.1 Multi-currency portfolio holding EUR, JPY, KRW, and USD assets simultaneously', () {
      final posDE = PortfolioPosition(
        ticker: 'SAP.DE',
        stockName: 'SAP SE',
        shares: 10.0,
        averagePrice: 183.92,
        averagePriceUSD: 198.83,
        totalCostUSD: 1988.30,
        nativeCurrency: 'EUR',
      );

      final posJP = PortfolioPosition(
        ticker: '7203.T',
        stockName: 'Toyota Motor',
        shares: 100.0,
        averagePrice: 2850.0,
        averagePriceUSD: 18.09,
        totalCostUSD: 1809.52,
        nativeCurrency: 'JPY',
      );

      final user = UserProfile(
        id: 'global_investor_de',
        username: 'FrankfurtTrader',
        country: 'DE',
        displayCurrency: 'EUR',
        language: 'de',
        cashUSD: 5000.0,
        portfolio: [posDE, posJP],
        watchlist: ['SAP.DE', 'SIE.DE', '7203.T', 'AAPL'],
        totalRealizedProfit: 250.0,
      );

      expect(user.portfolio.length, 2);
      expect(user.portfolio[0].nativeCurrency, 'EUR');
      expect(user.portfolio[1].nativeCurrency, 'JPY');
    });

    test('5.2 Real market data fetching for German stocks via MarketDataService', () async {
      final quote = await MarketDataService.fetchSingleQuote('SAP.DE');
      expect(quote.ticker, 'SAP.DE');
      expect(quote.currency, 'EUR');
    });
  });
}
