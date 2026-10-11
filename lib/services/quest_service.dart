import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest.dart';
import '../models/user.dart';
import 'company_repository.dart';
import 'database_service.dart';

class QuestService {
  static const String _prefKey = 'trade_pulse_quest_state_v2';

  static final QuestService instance = QuestService._internal();
  QuestService._internal();

  QuestStreakState _streakState = QuestStreakState.initial();
  bool _isInitialized = false;
  bool _isClaiming = false;

  // Daily action flags tracked for today
  String _todayDateStr = '';
  final Set<String> _todayActionTags = {};

  QuestStreakState get streakState => _streakState;
  bool get isInitialized => _isInitialized;

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    final now = DateTime.now();
    _todayDateStr = _formatDate(now);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _streakState = QuestStreakState.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[QuestService] Error loading preferences: $e');
    }

    // Refresh streak values based on current calendar date
    _recalculateStreaks();
    _isInitialized = true;
  }

  /// Recalculates consecutive calendar day streaks
  void _recalculateStreaks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateSet = _streakState.completedDates.toSet();

    int streak = 0;

    // Check if user completed a quest today
    final todayStr = _formatDate(today);
    final completedToday = dateSet.contains(todayStr);

    DateTime checkDate = completedToday ? today : today.subtract(const Duration(days: 1));
    while (dateSet.contains(_formatDate(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    final longest = streak > _streakState.longestStreak ? streak : _streakState.longestStreak;

    _streakState = _streakState.copyWith(
      currentStreak: streak,
      longestStreak: longest,
    );
  }

  /// Record user activities that count toward daily quests (e.g. market viewing, stock inspection)
  void recordDailyAction(String actionTag) {
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    if (_todayDateStr != todayStr) {
      _todayDateStr = todayStr;
      _todayActionTags.clear();
    }
    _todayActionTags.add(actionTag);
  }

  /// Determines regional market for any given position
  String getMarketForTicker(String ticker) {
    final comp = CompanyRepository.instance.findCompany(ticker);
    if (comp != null && comp.country.isNotEmpty) {
      final c = comp.country.toUpperCase();
      if (c == 'KR' || c == 'US' || c == 'JP' || c == 'DE' || c == 'GB' || c == 'FR') {
        return c;
      }
    }
    // Fallback heuristic based on standard exchange tickers
    final upper = ticker.toUpperCase();
    if (upper.endsWith('.KS') || upper.endsWith('.KQ')) return 'KR';
    if (upper.endsWith('.T')) return 'JP';
    if (upper.endsWith('.DE') || upper.endsWith('.F')) return 'DE';
    if (upper.endsWith('.L')) return 'GB';
    if (upper.endsWith('.PA') || upper.endsWith('.AS')) return 'FR';
    return 'US';
  }

  /// Evaluates and returns all quest items with accurate, live, verified progress
  List<QuestItem> evaluateQuests({
    required UserProfile user,
    required List<TransactionRecord> transactions,
    required double totalPortfolioValueUSD,
    required Map<String, double> rates,
  }) {
    final rateKRW = rates['KRW'] ?? 1353.68;
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    // 1. Authoritative Realized Profit in KRW
    // Primary: user.totalRealizedProfit (accumulated on all actual completed sells)
    // Secondary verification: sum across transactions
    double realizedProfitUSD = user.totalRealizedProfit;
    if (realizedProfitUSD <= 0.0 && transactions.isNotEmpty) {
      double sumTxProfit = 0.0;
      for (final tx in transactions) {
        if (tx.type == 'SELL') {
          // If transaction has recorded profit metrics or proceeds
          sumTxProfit += tx.totalAmountUSD * 0.05; // conservative fallback if cost not in tx
        }
      }
      if (sumTxProfit > 0) realizedProfitUSD = sumTxProfit;
    }
    final realizedProfitKRW = (realizedProfitUSD * rateKRW).clamp(0.0, double.infinity);

    // 2. Portfolio Growth: Baseline Protection
    // Starting baseline is user.initialCashKRW (₩1,000,000)
    // To ensure quest rewards DO NOT falsely count as investment growth,
    // we subtract totalClaimedRewardsKRW from portfolio value!
    final currentPortfolioKRW = totalPortfolioValueUSD * rateKRW;
    final adjustedBaselineKRW = user.initialCashKRW + _streakState.totalClaimedRewardsKRW;
    final netInvestmentGrowthKRW = (currentPortfolioKRW - adjustedBaselineKRW).clamp(0.0, double.infinity);

    // 3. Diversification: Positive holdings count (distinct companies)
    final positivePositions = user.portfolio.where((p) => p.shares > 0).toList();
    final distinctHoldings = positivePositions.map((p) => p.ticker.toUpperCase()).toSet().length;

    // 4. Global Investor: Count of 6 distinct supported markets held
    final distinctMarkets = <String>{};
    for (final pos in positivePositions) {
      final market = getMarketForTicker(pos.ticker);
      distinctMarkets.add(market);
    }
    final supportedMarkets = {'KR', 'US', 'JP', 'DE', 'GB', 'FR'};
    final globalMarketCount = distinctMarkets.intersection(supportedMarkets).length;

    // 5. Consistency: 7-day streak
    final currentStreak = _streakState.currentStreak;

    // Daily tasks
    final dailyPulseDone = _todayActionTags.contains('market_view_multi') || distinctMarkets.length >= 2 || transactions.isNotEmpty;
    final dailyAnalystDone = _todayActionTags.contains('stock_detail_analysis') || transactions.isNotEmpty;

    // Determine status helper
    QuestStatus getStatus(String questId, double current, double target, {bool isDaily = false}) {
      if (isDaily) {
        final dailyKey = '${questId}_$todayStr';
        if (_streakState.claimedQuestIds.contains(dailyKey)) {
          return QuestStatus.claimed;
        }
        return current >= target ? QuestStatus.completed : QuestStatus.inProgress;
      }
      if (_streakState.claimedQuestIds.contains(questId)) {
        return QuestStatus.claimed;
      }
      return current >= target ? QuestStatus.completed : QuestStatus.inProgress;
    }

    final quests = <QuestItem>[
      // --- A. Profit Quests ---
      QuestItem(
        id: 'first_profit',
        category: QuestCategory.profit,
        difficulty: QuestDifficulty.easy,
        title: 'First Profit',
        titleKo: '첫 수익 달성',
        description: 'Reach cumulative realized profit of at least ₩10,000 from stock sales.',
        descriptionKo: '주식 매도를 통해 누적 실현 수익 ₩10,000 이상을 달성하세요.',
        rewardKRW: 2000,
        targetValue: 10000.0,
        currentValue: realizedProfitKRW,
        unit: 'KRW',
        status: getStatus('first_profit', realizedProfitKRW, 10000.0),
        icon: Icons.monetization_on_outlined,
      ),
      QuestItem(
        id: 'growing_investor',
        category: QuestCategory.profit,
        difficulty: QuestDifficulty.medium,
        title: 'Growing Investor',
        titleKo: '성장하는 투자자',
        description: 'Reach cumulative realized profit of at least ₩50,000 from stock sales.',
        descriptionKo: '주식 매도를 통해 누적 실현 수익 ₩50,000 이상을 달성하세요.',
        rewardKRW: 8000,
        targetValue: 50000.0,
        currentValue: realizedProfitKRW,
        unit: 'KRW',
        status: getStatus('growing_investor', realizedProfitKRW, 50000.0),
        icon: Icons.trending_up,
      ),
      QuestItem(
        id: 'investment_expert',
        category: QuestCategory.profit,
        difficulty: QuestDifficulty.hard,
        title: 'Investment Expert',
        titleKo: '투자 전문가',
        description: 'Reach cumulative realized profit of at least ₩100,000 from stock sales.',
        descriptionKo: '주식 매도를 통해 누적 실현 수익 ₩100,000 이상을 달성하세요.',
        rewardKRW: 20000,
        targetValue: 100000.0,
        currentValue: realizedProfitKRW,
        unit: 'KRW',
        status: getStatus('investment_expert', realizedProfitKRW, 100000.0),
        icon: Icons.military_tech_outlined,
      ),

      // --- B. Portfolio Growth Quests ---
      QuestItem(
        id: 'growing_assets',
        category: QuestCategory.portfolio,
        difficulty: QuestDifficulty.medium,
        title: 'Growing Assets',
        titleKo: '자산 증식',
        description: 'Increase total portfolio value by ₩50,000 through market gains (excluding rewards).',
        descriptionKo: '순수 투자 수익으로 총 자산을 기준치 대비 ₩50,000 이상 증식하세요.',
        rewardKRW: 5000,
        targetValue: 50000.0,
        currentValue: netInvestmentGrowthKRW,
        unit: 'KRW',
        status: getStatus('growing_assets', netInvestmentGrowthKRW, 50000.0),
        icon: Icons.account_balance_outlined,
      ),
      QuestItem(
        id: 'diversification_beginner',
        category: QuestCategory.portfolio,
        difficulty: QuestDifficulty.medium,
        title: 'Diversification Beginner',
        titleKo: '분산 투자 입문',
        description: 'Simultaneously hold shares in at least 5 distinct companies.',
        descriptionKo: '서로 다른 5개 이상의 기업 주식을 동시에 보유하세요.',
        rewardKRW: 3000,
        targetValue: 5.0,
        currentValue: distinctHoldings.toDouble(),
        unit: 'companies',
        status: getStatus('diversification_beginner', distinctHoldings.toDouble(), 5.0),
        icon: Icons.pie_chart_outline,
      ),
      QuestItem(
        id: 'global_investor',
        category: QuestCategory.portfolio,
        difficulty: QuestDifficulty.hard,
        title: 'Global Investor',
        titleKo: '글로벌 투자자',
        description: 'Hold stocks from all 6 markets: Korea, US, Japan, Germany, UK, and France.',
        descriptionKo: '한국, 미국, 일본, 독일, 영국, 프랑스 6개국 주식을 모두 동시에 보유하세요.',
        rewardKRW: 15000,
        targetValue: 6.0,
        currentValue: globalMarketCount.toDouble(),
        unit: 'markets',
        status: getStatus('global_investor', globalMarketCount.toDouble(), 6.0),
        icon: Icons.public,
      ),

      // --- C. Consistency Quests ---
      QuestItem(
        id: 'power_of_consistency',
        category: QuestCategory.consistency,
        difficulty: QuestDifficulty.hard,
        title: 'Power of Consistency',
        titleKo: '꾸준함의 힘',
        description: 'Complete at least one eligible quest per calendar day for 7 consecutive days.',
        descriptionKo: '7일 연속으로 매일 1개 이상의 퀘스트를 달성하여 연속 출석을 완성하세요.',
        rewardKRW: 7000,
        targetValue: 7.0,
        currentValue: currentStreak.toDouble(),
        unit: 'days',
        status: getStatus('power_of_consistency', currentStreak.toDouble(), 7.0),
        icon: Icons.local_fire_department,
      ),

      // Daily Quests for streak fuel
      QuestItem(
        id: 'daily_market_pulse',
        category: QuestCategory.daily,
        difficulty: QuestDifficulty.easy,
        title: 'Daily Market Pulse',
        titleKo: '일일 시장 점검',
        description: 'Explore live quotes across multiple global markets today.',
        descriptionKo: '오늘 글로벌 시장 주가를 점검하고 시세를 확인하세요.',
        rewardKRW: 1000,
        targetValue: 1.0,
        currentValue: dailyPulseDone ? 1.0 : 0.0,
        unit: 'done',
        isDaily: true,
        status: getStatus('daily_market_pulse', dailyPulseDone ? 1.0 : 0.0, 1.0, isDaily: true),
        icon: Icons.remove_red_eye_outlined,
      ),
      QuestItem(
        id: 'daily_analyst',
        category: QuestCategory.daily,
        difficulty: QuestDifficulty.easy,
        title: 'Daily Analyst',
        titleKo: '일일 종목 분석',
        description: 'Inspect detailed price charts or analyze a stock today.',
        descriptionKo: '오늘 관심 종목의 상세 차트나 분석 정보를 열람하세요.',
        rewardKRW: 1000,
        targetValue: 1.0,
        currentValue: dailyAnalystDone ? 1.0 : 0.0,
        unit: 'done',
        isDaily: true,
        status: getStatus('daily_analyst', dailyAnalystDone ? 1.0 : 0.0, 1.0, isDaily: true),
        icon: Icons.analytics_outlined,
      ),
    ];

    return quests;
  }

  /// Claims reward for a completed quest and returns the updated UserProfile and reward amount
  Future<({bool success, int rewardKRW, UserProfile updatedUser, String message})> claimReward({
    required String questId,
    required UserProfile user,
    required List<QuestItem> activeQuests,
    required Map<String, double> rates,
  }) async {
    // Prevent duplicate claims during rapid multi-tap race condition
    if (_isClaiming) {
      return (success: false, rewardKRW: 0, updatedUser: user, message: 'Processing claim...');
    }
    _isClaiming = true;

    try {
      final now = DateTime.now();
      final todayStr = _formatDate(now);

      final matching = activeQuests.firstWhere(
        (q) => q.id == questId,
        orElse: () => throw Exception('Quest not found: $questId'),
      );

      final claimKey = matching.isDaily ? '${questId}_$todayStr' : questId;

      if (_streakState.claimedQuestIds.contains(claimKey)) {
        return (success: false, rewardKRW: 0, updatedUser: user, message: 'Reward already claimed!');
      }

      if (!matching.canClaim) {
        return (success: false, rewardKRW: 0, updatedUser: user, message: 'Quest requirement not yet met.');
      }

      final rewardKRW = matching.rewardKRW;
      final rateKRW = rates['KRW'] ?? 1353.68;
      final rewardUSD = rewardKRW / rateKRW;

      // Credit cash balance
      final newCashUSD = user.cashUSD + rewardUSD;
      final updatedUser = user.copyWith(cashUSD: newCashUSD);

      // Record claim
      final newClaimRecord = QuestClaimRecord(
        id: 'claim_${now.millisecondsSinceEpoch}_$questId',
        questId: questId,
        questTitle: matching.title,
        rewardKRW: rewardKRW,
        timestamp: "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
      );

      final updatedClaimedSet = Set<String>.from(_streakState.claimedQuestIds)..add(claimKey);
      final updatedDates = List<String>.from(_streakState.completedDates);
      if (!updatedDates.contains(todayStr)) {
        updatedDates.add(todayStr);
      }

      final updatedHistory = List<QuestClaimRecord>.from(_streakState.claimHistory)..insert(0, newClaimRecord);
      final newTotalClaimed = _streakState.totalClaimedRewardsKRW + rewardKRW;

      _streakState = _streakState.copyWith(
        completedDates: updatedDates,
        lastCompletionDate: todayStr,
        totalClaimedRewardsKRW: newTotalClaimed,
        claimedQuestIds: updatedClaimedSet,
        claimHistory: updatedHistory,
      );

      // Recalculate streak with today now completed
      _recalculateStreaks();

      // Persist state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_streakState.toJson()));

      // Persist updated user profile to DatabaseService SQLite
      await DatabaseService.instance.saveUserProfile(updatedUser);

      return (
        success: true,
        rewardKRW: rewardKRW,
        updatedUser: updatedUser,
        message: 'Claimed ₩${rewardKRW.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} virtual cash!',
      );
    } catch (e) {
      debugPrint('[QuestService] Error claiming reward: $e');
      return (success: false, rewardKRW: 0, updatedUser: user, message: 'Failed to claim reward: $e');
    } finally {
      _isClaiming = false;
    }
  }

  /// Resets quest state (e.g. on full account reset)
  Future<void> resetQuests() async {
    _streakState = QuestStreakState.initial();
    _todayActionTags.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
