import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/market_reopen_summary.dart';
import 'package:flutter_app/models/user.dart';
import 'package:flutter_app/models/stock.dart';
import 'package:flutter_app/services/market_reopen_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('APP REOPEN MARKET SUMMARY — VERIFICATION & AUDIT', () {
    test('1. MarketSessionBaseline serializes and deserializes accurately', () {
      final baseline = MarketSessionBaseline(
        timestampMs: 1700000000000,
        portfolioTotalUSD: 1500.50,
        stockValueUSD: 800.25,
        cashUSD: 700.25,
        stockPrices: {
          '005930.KS': 75000.0,
          'NVDA': 120.50,
          'SAP.DE': 180.20,
        },
        stockCurrencies: {
          '005930.KS': 'KRW',
          'NVDA': 'USD',
          'SAP.DE': 'EUR',
        },
      );

      final json = baseline.toJson();
      final restored = MarketSessionBaseline.fromJson(json);

      expect(restored.timestampMs, 1700000000000);
      expect(restored.portfolioTotalUSD, 1500.50);
      expect(restored.stockValueUSD, 800.25);
      expect(restored.cashUSD, 700.25);
      expect(restored.stockPrices['005930.KS'], 75000.0);
      expect(restored.stockPrices['NVDA'], 120.50);
      expect(restored.stockCurrencies['SAP.DE'], 'EUR');
    });

    test('2. StockPriceMovement accurately computes absolute and percentage differences', () {
      const movement = StockPriceMovement(
        ticker: 'NVDA',
        name: 'NVIDIA Corporation',
        currency: 'USD',
        previousPrice: 100.0,
        currentPrice: 105.0,
        absoluteChange: 5.0,
        percentChange: 5.0,
        isHolding: true,
        isWatchlist: false,
        shares: 10.0,
        isMarketOpen: true,
        country: 'US',
      );

      expect(movement.isGainer, isTrue);
      expect(movement.isLoser, isFalse);
      expect(movement.absoluteChange, 5.0);
      expect(movement.percentChange, 5.0);
      expect(movement.isHolding, isTrue);
    });

    test('3. MarketReopenSummary correctly categorizes gainers, losers, holdings, and watchlist', () {
      final now = DateTime.now();
      final lastSession = now.subtract(const Duration(hours: 2, minutes: 15));

      final movements = [
        const StockPriceMovement(
          ticker: 'NVDA',
          name: 'NVIDIA',
          currency: 'USD',
          previousPrice: 100.0,
          currentPrice: 108.0,
          absoluteChange: 8.0,
          percentChange: 8.0,
          isHolding: true,
          isWatchlist: false,
          shares: 5.0,
          isMarketOpen: true,
          country: 'US',
        ),
        const StockPriceMovement(
          ticker: 'AAPL',
          name: 'Apple',
          currency: 'USD',
          previousPrice: 200.0,
          currentPrice: 194.0,
          absoluteChange: -6.0,
          percentChange: -3.0,
          isHolding: false,
          isWatchlist: true,
          isMarketOpen: true,
          country: 'US',
        ),
        const StockPriceMovement(
          ticker: '005930.KS',
          name: 'Samsung Electronics',
          currency: 'KRW',
          previousPrice: 70000.0,
          currentPrice: 71400.0,
          absoluteChange: 1400.0,
          percentChange: 2.0,
          isHolding: true,
          isWatchlist: false,
          shares: 20.0,
          isMarketOpen: false,
          country: 'KR',
          marketClosureNotice: 'Market closed; latest closing price shown',
        ),
      ];

      final summary = MarketReopenSummary(
        sessionElapsedMinutes: 135,
        lastSessionTimestamp: lastSession,
        currentSessionTimestamp: now,
        previousPortfolioValueUSD: 2000.0,
        currentPortfolioValueUSD: 2060.0,
        portfolioChangeUSD: 60.0,
        portfolioChangePercent: 3.0,
        movements: movements,
        recentNews: const [],
        hasSignificantChanges: true,
      );

      expect(summary.sessionElapsedMinutes, 135);
      expect(summary.portfolioChangeUSD, 60.0);
      expect(summary.portfolioChangePercent, 3.0);
      expect(summary.heldStockMovements.length, 2);
      expect(summary.watchlistMovements.length, 1);
      expect(summary.topGainers.first.ticker, 'NVDA');
      expect(summary.topLosers.first.ticker, 'AAPL');
      expect(summary.closedMarkets.contains('KR'), isTrue);
    });

    test('4. Unavailable state handles data retrieval failure safely without zeroing baseline', () {
      final lastSession = DateTime.now().subtract(const Duration(hours: 1));
      final unavail = MarketReopenSummary.unavailable(
        message: 'No network connection',
        lastSessionTimestamp: lastSession,
      );

      expect(unavail.isDataUnavailable, isTrue);
      expect(unavail.unavailableMessage, 'No network connection');
      expect(unavail.movements.isEmpty, isTrue);
      expect(unavail.hasSignificantChanges, isFalse);
    });

    test('5. MarketReopenService respects absence duration and session idempotence', () async {
      await MarketReopenService.instance.init();
      expect(MarketReopenService.instance.isEnabled, isTrue);

      final user = UserProfile(
        id: 'test_user',
        username: 'Tester',
        country: 'KR',
        displayCurrency: 'KRW',
        language: 'ko',
        cashUSD: 1000.0,
        initialCashKRW: 1000000.0,
        portfolio: [
          Position(
            ticker: 'NVDA',
            name: 'Nvidia',
            shares: 2,
            averagePriceUSD: 100,
            nativeCurrency: 'USD',
          ),
        ],
        watchlist: ['AAPL'],
        totalRealizedProfit: 0.0,
      );

      final mockQuotes = {
        'NVDA': StockQuote(
          ticker: 'NVDA',
          name: 'Nvidia',
          price: 110.0,
          previousClose: 100.0,
          change: 10.0,
          changePercent: 10.0,
          currency: 'USD',
          marketState: 'REGULAR',
          dataStatus: 'live',
          lastUpdated: 'Live',
          lastUpdatedMs: DateTime.now().millisecondsSinceEpoch,
        ),
      };

      // Save baseline
      await MarketReopenService.instance.saveCurrentAsBaseline(user, mockQuotes, {'USD': 1.0, 'KRW': 1353.68});
      expect(MarketReopenService.instance.currentBaseline, isNotNull);

      // Force evaluation (as if user just returned or tapped preview)
      final summary = await MarketReopenService.instance.evaluateSummary(
        user: user,
        currentQuotes: mockQuotes,
        rates: {'USD': 1.0, 'KRW': 1353.68},
        language: 'ko',
        force: true,
      );

      expect(summary, isNotNull);
      expect(summary!.hasSignificantChanges, isTrue);
      expect(MarketReopenService.instance.hasShownInCurrentSession, isTrue);

      // Second immediate call without force returns null (prevents repetitive spam)
      final secondCall = await MarketReopenService.instance.evaluateSummary(
        user: user,
        currentQuotes: mockQuotes,
        rates: {'USD': 1.0, 'KRW': 1353.68},
        language: 'ko',
        force: false,
      );

      expect(secondCall, isNull);
    });
  });
}
