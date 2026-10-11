import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/user.dart';
import 'package:flutter_app/models/quest.dart';
import 'package:flutter_app/services/quest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QUEST SYSTEM - REAL SIMULATOR LOGIC & VERIFICATION', () {
    const rateKRW = 1353.68;
    final rates = {'USD': 1.0, 'KRW': rateKRW};

    setUp(() async {
      await QuestService.instance.resetQuests();
    });

    test('1. Initial state has 0 profit and all profit quests are inProgress', () {
      final user = UserProfile(
        id: 'test_user',
        username: 'Tester',
        country: 'KR',
        displayCurrency: 'KRW',
        language: 'ko',
        cashUSD: 1000000.0 / rateKRW,
        initialCashKRW: 1000000.0,
        portfolio: [],
        watchlist: [],
        totalRealizedProfit: 0.0,
      );

      final quests = QuestService.instance.evaluateQuests(
        user: user,
        transactions: [],
        totalPortfolioValueUSD: 1000000.0 / rateKRW,
        rates: rates,
      );

      final firstProfit = quests.firstWhere((q) => q.id == 'first_profit');
      final growingInvestor = quests.firstWhere((q) => q.id == 'growing_investor');
      final investmentExpert = quests.firstWhere((q) => q.id == 'investment_expert');

      expect(firstProfit.status, QuestStatus.inProgress);
      expect(firstProfit.currentValue, 0.0);
      expect(firstProfit.targetValue, 10000.0);
      expect(firstProfit.rewardKRW, 2000);

      expect(growingInvestor.status, QuestStatus.inProgress);
      expect(growingInvestor.targetValue, 50000.0);
      expect(growingInvestor.rewardKRW, 8000);

      expect(investmentExpert.status, QuestStatus.inProgress);
      expect(investmentExpert.targetValue, 100000.0);
      expect(investmentExpert.rewardKRW, 20000);
    });

    test('2. Realized profit milestones correctly complete First Profit, Growing Investor, and Investment Expert', () {
      // 2.1 First profit reached (₩12,000 profit)
      final user1 = UserProfile(
        id: 'test_user',
        username: 'Tester',
        country: 'KR',
        displayCurrency: 'KRW',
        language: 'ko',
        cashUSD: 1012000.0 / rateKRW,
        initialCashKRW: 1000000.0,
        portfolio: [],
        watchlist: [],
        totalRealizedProfit: 12000.0 / rateKRW,
      );

      final quests1 = QuestService.instance.evaluateQuests(
        user: user1,
        transactions: [],
        totalPortfolioValueUSD: 1012000.0 / rateKRW,
        rates: rates,
      );

      final qFirstProfit = quests1.firstWhere((q) => q.id == 'first_profit');
      expect(qFirstProfit.canClaim, isTrue);
      expect(qFirstProfit.status, QuestStatus.completed);

      final qGrowing1 = quests1.firstWhere((q) => q.id == 'growing_investor');
      expect(qGrowing1.status, QuestStatus.inProgress);

      // 2.2 Growing investor reached (₩55,000 profit)
      final user2 = user1.copyWith(totalRealizedProfit: 55000.0 / rateKRW);
      final quests2 = QuestService.instance.evaluateQuests(
        user: user2,
        transactions: [],
        totalPortfolioValueUSD: 1055000.0 / rateKRW,
        rates: rates,
      );

      expect(quests2.firstWhere((q) => q.id == 'first_profit').canClaim, isTrue);
      expect(quests2.firstWhere((q) => q.id == 'growing_investor').canClaim, isTrue);
      expect(quests2.firstWhere((q) => q.id == 'investment_expert').status, QuestStatus.inProgress);

      // 2.3 Investment expert reached (₩105,000 profit)
      final user3 = user1.copyWith(totalRealizedProfit: 105000.0 / rateKRW);
      final quests3 = QuestService.instance.evaluateQuests(
        user: user3,
        transactions: [],
        totalPortfolioValueUSD: 1105000.0 / rateKRW,
        rates: rates,
      );

      expect(quests3.firstWhere((q) => q.id == 'investment_expert').canClaim, isTrue);
      expect(quests3.firstWhere((q) => q.id == 'investment_expert').status, QuestStatus.completed);
    });

    test('3. Diversification Beginner requires simultaneously holding 5 distinct companies', () {
      // 4 distinct holdings
      final user4 = UserProfile(
        id: 'test_user',
        username: 'Tester',
        country: 'KR',
        displayCurrency: 'KRW',
        language: 'ko',
        cashUSD: 500000.0 / rateKRW,
        initialCashKRW: 1000000.0,
        portfolio: [
          Position(ticker: '005930.KS', name: 'Samsung', shares: 10, averagePriceUSD: 50, nativeCurrency: 'KRW'),
          Position(ticker: 'AAPL', name: 'Apple', shares: 5, averagePriceUSD: 150, nativeCurrency: 'USD'),
          Position(ticker: '7203.T', name: 'Toyota', shares: 100, averagePriceUSD: 20, nativeCurrency: 'JPY'),
          Position(ticker: 'SAP.DE', name: 'SAP', shares: 10, averagePriceUSD: 100, nativeCurrency: 'EUR'),
        ],
        watchlist: [],
        totalRealizedProfit: 0.0,
      );

      final quests4 = QuestService.instance.evaluateQuests(
        user: user4,
        transactions: [],
        totalPortfolioValueUSD: 1000000.0 / rateKRW,
        rates: rates,
      );

      final qDiv4 = quests4.firstWhere((q) => q.id == 'diversification_beginner');
      expect(qDiv4.currentValue, 4.0);
      expect(qDiv4.targetValue, 5.0);
      expect(qDiv4.status, QuestStatus.inProgress);

      // Add 5th distinct holding
      final user5 = user4.copyWith(
        portfolio: [
          ...user4.portfolio,
          Position(ticker: 'AZN.L', name: 'AstraZeneca', shares: 5, averagePriceUSD: 100, nativeCurrency: 'GBP'),
        ],
      );

      final quests5 = QuestService.instance.evaluateQuests(
        user: user5,
        transactions: [],
        totalPortfolioValueUSD: 1000000.0 / rateKRW,
        rates: rates,
      );

      final qDiv5 = quests5.firstWhere((q) => q.id == 'diversification_beginner');
      expect(qDiv5.currentValue, 5.0);
      expect(qDiv5.canClaim, isTrue);
      expect(qDiv5.rewardKRW, 3000);
    });

    test('4. Global Investor requires holding stocks from all 6 markets (KR, US, JP, DE, GB, FR)', () {
      // 5 markets (missing FR)
      final user5Markets = UserProfile(
        id: 'test_user',
        username: 'Tester',
        country: 'KR',
        displayCurrency: 'KRW',
        language: 'ko',
        cashUSD: 500000.0 / rateKRW,
        initialCashKRW: 1000000.0,
        portfolio: [
          Position(ticker: '005930.KS', name: 'Samsung', shares: 10, averagePriceUSD: 50, nativeCurrency: 'KRW'), // KR
          Position(ticker: 'NVDA', name: 'Nvidia', shares: 5, averagePriceUSD: 120, nativeCurrency: 'USD'), // US
          Position(ticker: '7203.T', name: 'Toyota', shares: 10, averagePriceUSD: 20, nativeCurrency: 'JPY'), // JP
          Position(ticker: 'SAP.DE', name: 'SAP', shares: 10, averagePriceUSD: 100, nativeCurrency: 'EUR'), // DE
          Position(ticker: 'AZN.L', name: 'AstraZeneca', shares: 5, averagePriceUSD: 100, nativeCurrency: 'GBP'), // GB
        ],
        watchlist: [],
        totalRealizedProfit: 0.0,
      );

      final quests5M = QuestService.instance.evaluateQuests(
        user: user5Markets,
        transactions: [],
        totalPortfolioValueUSD: 1000000.0 / rateKRW,
        rates: rates,
      );

      final qGlobal5 = quests5M.firstWhere((q) => q.id == 'global_investor');
      expect(qGlobal5.currentValue, 5.0);
      expect(qGlobal5.targetValue, 6.0);
      expect(qGlobal5.status, QuestStatus.inProgress);

      // Add French stock (MC.PA)
      final user6Markets = user5Markets.copyWith(
        portfolio: [
          ...user5Markets.portfolio,
          Position(ticker: 'MC.PA', name: 'LVMH', shares: 2, averagePriceUSD: 700, nativeCurrency: 'EUR'), // FR
        ],
      );

      final quests6M = QuestService.instance.evaluateQuests(
        user: user6Markets,
        transactions: [],
        totalPortfolioValueUSD: 1000000.0 / rateKRW,
        rates: rates,
      );

      final qGlobal6 = quests6M.firstWhere((q) => q.id == 'global_investor');
      expect(qGlobal6.currentValue, 6.0);
      expect(qGlobal6.canClaim, isTrue);
      expect(qGlobal6.rewardKRW, 15000);
    });

    test('5. Growing Assets requires ₩50,000 real market growth and discounts claimed quest rewards', () {
      // User with ₩60,000 total gain
      final user = UserProfile(
        id: 'test_user',
        username: 'Tester',
        country: 'KR',
        displayCurrency: 'KRW',
        language: 'ko',
        cashUSD: 1060000.0 / rateKRW,
        initialCashKRW: 1000000.0,
        portfolio: [],
        watchlist: [],
        totalRealizedProfit: 60000.0 / rateKRW,
      );

      final quests = QuestService.instance.evaluateQuests(
        user: user,
        transactions: [],
        totalPortfolioValueUSD: 1060000.0 / rateKRW,
        rates: rates,
      );

      final qAssets = quests.firstWhere((q) => q.id == 'growing_assets');
      expect(qAssets.currentValue >= 50000.0, isTrue);
      expect(qAssets.canClaim, isTrue);
      expect(qAssets.rewardKRW, 5000);
    });

    test('6. Claiming reward credits cash, prevents duplicate claims, and records claim history', () async {
      final user = UserProfile(
        id: 'test_user',
        username: 'Tester',
        country: 'KR',
        displayCurrency: 'KRW',
        language: 'ko',
        cashUSD: 1000000.0 / rateKRW,
        initialCashKRW: 1000000.0,
        portfolio: [],
        watchlist: [],
        totalRealizedProfit: 15000.0 / rateKRW, // Eligible for First Profit
      );

      final initialQuests = QuestService.instance.evaluateQuests(
        user: user,
        transactions: [],
        totalPortfolioValueUSD: 1015000.0 / rateKRW,
        rates: rates,
      );

      // Claim First Profit (₩2,000 reward)
      final claimResult = await QuestService.instance.claimReward(
        questId: 'first_profit',
        user: user,
        activeQuests: initialQuests,
        rates: rates,
      );

      expect(claimResult.success, isTrue);
      expect(claimResult.rewardKRW, 2000);
      expect(claimResult.updatedUser.cashUSD > user.cashUSD, isTrue);

      // Verify streak state recorded claim
      final streak = QuestService.instance.streakState;
      expect(streak.totalClaimedRewardsKRW, 2000);
      expect(streak.claimedQuestIds.contains('first_profit'), isTrue);
      expect(streak.claimHistory.length, 1);
      expect(streak.claimHistory.first.questId, 'first_profit');
      expect(streak.claimHistory.first.rewardKRW, 2000);

      // Re-evaluating quests should now show first_profit as claimed
      final updatedQuests = QuestService.instance.evaluateQuests(
        user: claimResult.updatedUser,
        transactions: [],
        totalPortfolioValueUSD: 1017000.0 / rateKRW,
        rates: rates,
      );

      final rechecked = updatedQuests.firstWhere((q) => q.id == 'first_profit');
      expect(rechecked.status, QuestStatus.claimed);
      expect(rechecked.canClaim, isFalse);
      expect(rechecked.isClaimed, isTrue);

      // Attempting to claim again fails gracefully
      final secondClaim = await QuestService.instance.claimReward(
        questId: 'first_profit',
        user: claimResult.updatedUser,
        activeQuests: updatedQuests,
        rates: rates,
      );

      expect(secondClaim.success, isFalse);
      expect(secondClaim.rewardKRW, 0);
    });
  });
}
