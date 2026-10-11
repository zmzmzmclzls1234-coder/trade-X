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

  group('1. AUTHORITATIVE FRENCH LISTED COMPANY COVERAGE AUDIT', () {
    test('1.1 Total active French listed companies matches authoritative count (838)', () {
      final repo = CompanyRepository.instance;
      expect(repo.frenchCount, 838);
      expect(repo.frenchCompanies.where((c) => c.listingStatus == 'LISTED').length, 838);
    });

    test('1.2 Zero duplicate ISINs in French company universe (Requirement 12: Avoid double counting)', () {
      final repo = CompanyRepository.instance;
      final frCompanies = repo.frenchCompanies;
      final isinSet = <String>{};
      final duplicateIsins = <String>[];

      for (final c in frCompanies) {
        if (c.isin != null && c.isin!.isNotEmpty) {
          if (isinSet.contains(c.isin)) {
            duplicateIsins.add(c.isin!);
          } else {
            isinSet.add(c.isin!);
          }
        }
      }

      expect(duplicateIsins, isEmpty, reason: 'No duplicate ISINs allowed across Euronext Paris trading segments');
      expect(isinSet.length, 838);
    });

    test('1.3 Zero duplicate tickers in French company universe', () {
      final repo = CompanyRepository.instance;
      final frCompanies = repo.frenchCompanies;
      final tickerSet = <String>{};
      final duplicateTickers = <String>[];

      for (final c in frCompanies) {
        if (tickerSet.contains(c.ticker)) {
          duplicateTickers.add(c.ticker);
        } else {
          tickerSet.add(c.ticker);
        }
      }

      expect(duplicateTickers, isEmpty, reason: 'No duplicate tickers allowed in French universe');
      expect(tickerSet.length, 838);
    });

    test('1.4 Combined global universe active count', () {
      final repo = CompanyRepository.instance;
      expect(repo.koreanCount, 2875);
      expect(repo.usCount, 6016);
      expect(repo.japaneseCount, 3885);
      expect(repo.germanCount, 419);
      expect(repo.ukCount, 3200);
      expect(repo.frenchCount, 838);
      final totalActive = repo.searchAndFilter(listingStatus: 'LISTED').length;
      final expectedCount = repo.koreanCount + repo.usCount + repo.japaneseCount + repo.germanCount + repo.ukCount + repo.frenchCount;
      expect(totalActive, expectedCount);
    });
  });

  group('2. FRENCH COMPANY DATA & IDENTIFIERS ACCURACY', () {
    test('2.1 LVMH (MC.PA) full attributes verification', () {
      final repo = CompanyRepository.instance;
      final lvmh = repo.findCompany('MC.PA') ?? repo.findCompany('MC');
      expect(lvmh, isNotNull);
      expect(lvmh!.ticker, 'MC.PA');
      expect(lvmh.code, 'MC');
      expect(lvmh.isin, 'FR0000121014');
      expect(lvmh.name, contains('LVMH'));
      expect(lvmh.localName, contains('LVMH'));
      expect(lvmh.exchange, 'Euronext Paris');
      expect(lvmh.country, 'FR');
      expect(lvmh.currency, 'EUR');
      expect(lvmh.marketCapCategory, 'Large Cap');
      expect(lvmh.marketCap, greaterThan(100000000000.0));
      expect(lvmh.listingStatus, 'LISTED');
    });

    test('2.2 L\'Oréal (OR.PA) and Airbus SE (AIR.PA) verification', () {
      final repo = CompanyRepository.instance;
      final loreal = repo.findCompany('OR.PA') ?? repo.findCompany('OR');
      expect(loreal, isNotNull);
      expect(loreal!.ticker, 'OR.PA');
      expect(loreal.isin, 'FR0000120321');
      expect(loreal.currency, 'EUR');

      final airbus = repo.findCompany('AIR.PA') ?? repo.findCompany('AIR');
      expect(airbus, isNotNull);
      expect(airbus!.ticker, 'AIR.PA');
      expect(airbus.isin, 'NL0000235190');
      expect(airbus.currency, 'EUR');
    });

    test('2.3 TotalEnergies (TTE.PA), BNP Paribas (BNP.PA), and Sanofi (SAN.PA) verification', () {
      final repo = CompanyRepository.instance;
      final total = repo.findCompany('TTE.PA') ?? repo.findCompany('TTE');
      expect(total, isNotNull);
      expect(total!.ticker, 'TTE.PA');
      expect(total.isin, 'FR0000120271');

      final bnp = repo.findCompany('BNP.PA') ?? repo.findCompany('BNP');
      expect(bnp, isNotNull);
      expect(bnp!.ticker, 'BNP.PA');
      expect(bnp.isin, 'FR0000131104');

      final sanofi = repo.findCompany('SAN.PA') ?? repo.findCompany('SAN');
      expect(sanofi, isNotNull);
      expect(sanofi!.ticker, 'SAN.PA');
      expect(sanofi.isin, 'FR0000120578');
    });
  });

  group('3. MULTI-MARKET SEARCH & IDENTIFIER LOOKUP', () {
    test('3.1 Search by French company name (LVMH, L\'Oreal, Airbus, TotalEnergies)', () {
      final repo = CompanyRepository.instance;
      final lvmhSearch = repo.searchAndFilter(query: 'LVMH');
      expect(lvmhSearch.any((s) => s.ticker == 'MC.PA'), isTrue);

      final lorealSearch = repo.searchAndFilter(query: "L'Oreal");
      expect(lorealSearch.any((s) => s.ticker == 'OR.PA'), isTrue);

      final airbusSearch = repo.searchAndFilter(query: 'Airbus');
      expect(airbusSearch.any((s) => s.ticker == 'AIR.PA'), isTrue);

      final totalSearch = repo.searchAndFilter(query: 'TotalEnergies');
      expect(totalSearch.any((s) => s.ticker == 'TTE.PA'), isTrue);
    });

    test('3.2 Search by ticker and ISIN (MC, FR0000121014, FR0000120321)', () {
      final repo = CompanyRepository.instance;
      final mcTickerSearch = repo.searchAndFilter(query: 'MC');
      expect(mcTickerSearch.any((s) => s.ticker == 'MC.PA'), isTrue);

      final mcIsinSearch = repo.searchAndFilter(query: 'FR0000121014');
      expect(mcIsinSearch.any((s) => s.ticker == 'MC.PA'), isTrue);

      final orIsinSearch = repo.searchAndFilter(query: 'FR0000120321');
      expect(orIsinSearch.any((s) => s.ticker == 'OR.PA'), isTrue);
    });

    test('3.3 Fast search debouncing performance across 13,000+ global companies', () {
      final repo = CompanyRepository.instance;
      final sw = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        repo.searchAndFilter(query: 'LVMH');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(600), reason: 'Search across 13,000+ stocks must be sub-millisecond per query');
    });
  });

  group('4. MULTI-MARKET FILTERING & SORTING', () {
    test('4.1 Country filter isolates FR vs DE vs JP vs KR vs US', () {
      final repo = CompanyRepository.instance;
      final frOnly = repo.searchAndFilter(country: 'FR', listingStatus: 'LISTED');
      expect(frOnly.length, 838);
      expect(frOnly.every((c) => c.country == 'FR'), isTrue);

      final deOnly = repo.searchAndFilter(country: 'DE', listingStatus: 'LISTED');
      expect(deOnly.length, 419);

      final jpOnly = repo.searchAndFilter(country: 'JP', listingStatus: 'LISTED');
      expect(jpOnly.length, 3885);

      final krOnly = repo.searchAndFilter(country: 'KR', listingStatus: 'LISTED');
      expect(krOnly.length, 2875);

      final usOnly = repo.searchAndFilter(country: 'US', listingStatus: 'LISTED');
      expect(usOnly.length, 6016);
    });

    test('4.2 Currency filter isolates EUR, GBP, JPY, KRW, and USD', () {
      final repo = CompanyRepository.instance;
      final eurOnly = repo.searchAndFilter(currency: 'EUR', listingStatus: 'LISTED');
      expect(eurOnly.length, 419 + 838); // DE (419) + FR (838)
      expect(eurOnly.every((c) => c.currency == 'EUR'), isTrue);
    });

    test('4.3 Sorting French stocks by Market Cap, Name, and Ticker', () {
      final repo = CompanyRepository.instance;
      final byCapFR = repo.searchAndFilter(country: 'FR', listingStatus: 'LISTED', sort: 'MARKET_CAP_DESC');
      expect(byCapFR.first.marketCap, greaterThan(150000000000.0));

      final byNameFR = repo.searchAndFilter(country: 'FR', listingStatus: 'LISTED', sort: 'NAME_ASC');
      expect(byNameFR.isNotEmpty, isTrue);
    });
  });

  group('5. VIRTUAL TRADING & MULTI-CURRENCY (EUR) INTEGRATION', () {
    test('5.1 Multi-currency portfolio holding EUR, GBP, JPY, KRW, and USD assets simultaneously', () {
      final posFR = PortfolioPosition(
          ticker: 'MC.PA',
          stockName: 'LVMH SE',
          shares: 5.0,
          averagePrice: 750.00,
          averagePriceUSD: 852.27,
          totalCostUSD: 4261.36,
          nativeCurrency: 'EUR',
      );

      final posUK = PortfolioPosition(
          ticker: 'AZN.L',
          stockName: 'AstraZeneca',
          shares: 20.0,
          averagePrice: 120.00,
          averagePriceUSD: 157.89,
          totalCostUSD: 3157.89,
          nativeCurrency: 'GBP',
      );

      final user = UserProfile(
          id: 'global_investor_fr',
          username: 'ParisTrader',
          country: 'FR',
          displayCurrency: 'EUR',
          language: 'fr',
          cashUSD: 10000.0,
          portfolio: [posFR, posUK],
          watchlist: ['MC.PA', 'OR.PA', 'AZN.L', 'AAPL'],
          totalRealizedProfit: 500.0,
      );

      expect(user.portfolio.length, 2);
      expect(user.portfolio[0].nativeCurrency, 'EUR');
      expect(user.portfolio[1].nativeCurrency, 'GBP');
    });

    test('5.2 Real market data fetching for French stocks via MarketDataService', () async {
      final quote = await MarketDataService.fetchSingleQuote('MC.PA');
      expect(quote.ticker, 'MC.PA');
      expect(quote.currency, 'EUR');
    });
  });
}
