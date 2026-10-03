import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/user.dart';
import '../i18n/translations.dart';

class PortfolioAnalysisView extends StatelessWidget {
  const PortfolioAnalysisView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.user;
    final lang = provider.activeLanguage;
    final portfolio = user?.portfolio ?? [];
    final totalPortfolioUSD = provider.totalPortfolioValueUSD;
    final totalProfitLossUSD = provider.totalProfitLossUSD;
    final totalReturnPct = provider.totalReturnPercent;
    final cashUSD = user?.cashUSD ?? 0.0;
    final isProfit = totalProfitLossUSD >= 0;

    final cashRatio = totalPortfolioUSD > 0 ? (cashUSD / totalPortfolioUSD) * 100 : 100.0;
    final stockRatio = 100.0 - cashRatio;

    if (portfolio.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics_outlined, size: 64, color: Color(0xFF64748B)),
              const SizedBox(height: 16),
              Text(
                AppTranslations.get('portfolioAnalysis', lang),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                AppTranslations.get('noHoldingsForAnalysis', lang),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Compute Holding Breakdown
    PortfolioPosition? bestPerformer;
    double bestReturnPct = -999999.0;
    PortfolioPosition? worstPerformer;
    double worstReturnPct = 999999.0;
    double maxWeight = 0.0;
    PortfolioPosition? largestHolding;

    final List<Map<String, dynamic>> holdingStats = [];

    for (final pos in portfolio) {
      final quote = provider.quotes[pos.ticker];
      final currentPrice = quote?.price ?? pos.averagePrice;
      final rate = provider.rates[pos.nativeCurrency.toUpperCase()] ?? 1.0;
      final currentPriceUSD = currentPrice / rate;
      final totalCurrentValUSD = currentPriceUSD * pos.shares;
      final pnlUSD = totalCurrentValUSD - pos.totalCostUSD;
      final retPct = pos.totalCostUSD > 0 ? (pnlUSD / pos.totalCostUSD) * 100 : 0.0;
      final weight = totalPortfolioUSD > 0 ? (totalCurrentValUSD / totalPortfolioUSD) * 100 : 0.0;

      if (retPct > bestReturnPct) {
        bestReturnPct = retPct;
        bestPerformer = pos;
      }
      if (retPct < worstReturnPct) {
        worstReturnPct = retPct;
        worstPerformer = pos;
      }
      if (weight > maxWeight) {
        maxWeight = weight;
        largestHolding = pos;
      }

      holdingStats.add({
        'pos': pos,
        'currentPrice': currentPrice,
        'currentValUSD': totalCurrentValUSD,
        'pnlUSD': pnlUSD,
        'returnPct': retPct,
        'weight': weight,
      });
    }

    // Diversification score (out of 100)
    int diversificationScore = 40;
    if (portfolio.length >= 2) diversificationScore += 20;
    if (portfolio.length >= 4) diversificationScore += 20;
    if (maxWeight < 40.0) diversificationScore += 20;
    if (diversificationScore > 100) diversificationScore = 100;

    // Identified Strengths & Weaknesses
    final List<String> strengths = [];
    final List<String> risks = [];

    if (isProfit) {
      strengths.add(lang == 'ko'
          ? '전체 포트폴리오가 ${totalReturnPct.toStringAsFixed(1)}%의 플러스 수익률을 유지하고 있습니다.'
          : 'Total portfolio is yielding positive returns (+${totalReturnPct.toStringAsFixed(1)}%).');
    }
    if (cashRatio >= 15.0 && cashRatio <= 40.0) {
      strengths.add(lang == 'ko'
          ? '적정 현금 비중(${cashRatio.toStringAsFixed(0)}%)을 확보하여 하락장 방어력이 높습니다.'
          : 'Healthy cash buffer (${cashRatio.toStringAsFixed(0)}%) provides downside liquidity.');
    }
    if (portfolio.length >= 3) {
      strengths.add(lang == 'ko'
          ? '3개 이상의 종목으로 자산이 분산되어 단일 종목 위험을 분산했습니다.'
          : 'Portfolio is spread across ${portfolio.length} securities to dampen single-stock volatility.');
    }

    if (maxWeight > 45.0) {
      risks.add(lang == 'ko'
          ? '단일 종목(${largestHolding?.stockName}) 비중이 ${maxWeight.toStringAsFixed(0)}%로 집중되어 있어 변동성이 클 수 있습니다.'
          : 'High single-stock concentration in ${largestHolding?.stockName} (${maxWeight.toStringAsFixed(0)}%).');
    }
    if (cashRatio > 70.0) {
      risks.add(lang == 'ko'
          ? '현금 비중(${cashRatio.toStringAsFixed(0)}%)이 과도하여 시장 상승기 기회비용이 발생할 수 있습니다.'
          : 'High cash drag (${cashRatio.toStringAsFixed(0)}%) may underperform rising market benchmarks.');
    }
    if (worstReturnPct < -5.0 && worstPerformer != null) {
      risks.add(lang == 'ko'
          ? '${worstPerformer.stockName} 종목의 손실률이 ${worstReturnPct.toStringAsFixed(1)}%입니다. 손절선 또는 추가 매수 여부를 점검하세요.'
          : '${worstPerformer.stockName} is down ${worstReturnPct.toStringAsFixed(1)}%. Review cost-averaging or stop-loss.');
    }

    if (strengths.isEmpty) {
      strengths.add(lang == 'ko'
          ? '초기 포지션을 구축하는 단계입니다. 꾸준한 분할 매수로 포트폴리오를 육성하세요.'
          : 'Portfolio is in early formation phase. Continue disciplined dollar-cost averaging.');
    }
    if (risks.isEmpty) {
      risks.add(lang == 'ko'
          ? '현재 포트폴리오의 리스크 지표가 안정적인 균형을 이루고 있습니다.'
          : 'Risk indicators are balanced within normal parameters.');
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Overall Performance Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('portfolioAnalysis', lang),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.get('totalPortfolio', lang),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.formatValue(totalPortfolioUSD),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${isProfit ? "+" : ""}${totalReturnPct.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Cash vs Invested Visual Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${AppTranslations.get('availableCash', lang)}: ${cashRatio.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${AppTranslations.get('investedAssets', lang)}: ${stockRatio.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (cashRatio * 10).toInt().clamp(1, 1000),
                        child: Container(color: const Color(0xFF0284C7)),
                      ),
                      Expanded(
                        flex: (stockRatio * 10).toInt().clamp(1, 1000),
                        child: Container(color: const Color(0xFF8B5CF6)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Diversification & Top/Worst Performer
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.get('diversificationScore', lang),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          diversificationScore >= 70 ? Icons.verified : Icons.tune,
                          color: diversificationScore >= 70 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$diversificationScore / 100',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.get('topGainer', lang),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bestPerformer?.stockName ?? '-',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${bestReturnPct >= 0 ? "+" : ""}${bestReturnPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: bestReturnPct >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Strengths Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF064E3B).withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF059669).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppTranslations.get('portfolioStrengths', lang),
                    style: const TextStyle(color: Color(0xFF34D399), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...strengths.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Risks & Improvement Suggestions Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF7F1D1D).withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppTranslations.get('portfolioRisks', lang),
                    style: const TextStyle(color: Color(0xFFF87171), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...risks.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        r,
                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Holding Concentration List
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('holdingConcentration', lang),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...holdingStats.map((stat) {
                final pos = stat['pos'] as PortfolioPosition;
                final weight = stat['weight'] as double;
                final retPct = stat['returnPct'] as double;
                final currentPrice = stat['currentPrice'] as double;
                final isRetPos = retPct >= 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              pos.stockName,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${weight.toStringAsFixed(1)}% of Portfolio',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${pos.shares.toInt()} ${AppTranslations.get('shares', lang)} • Avg ${pos.averagePrice.toStringAsFixed(0)} ${pos.nativeCurrency} ➔ ${currentPrice.toStringAsFixed(0)} ${pos.nativeCurrency}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                          ),
                          Text(
                            '${isRetPos ? "+" : ""}${retPct.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isRetPos ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (weight / 100).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFF1E293B),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            weight > 40 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
