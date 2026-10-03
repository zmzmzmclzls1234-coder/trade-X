import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../i18n/translations.dart';
import 'stock_detail_screen.dart';
import 'portfolio_analysis_view.dart';

class PortfolioTab extends StatefulWidget {
  const PortfolioTab({super.key});

  @override
  State<PortfolioTab> createState() => _PortfolioTabState();
}

class _PortfolioTabState extends State<PortfolioTab> {
  int _selectedSubTab = 0; // 0: Holdings, 1: Analytics

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPortfolioQuotes();
    });
  }

  void _refreshPortfolioQuotes() {
    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final tickers = provider.user?.portfolio.map((p) => p.ticker).toList() ?? [];
    if (tickers.isNotEmpty) {
      provider.fetchQuotesForSecurities(tickers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.user;
    final lang = provider.activeLanguage;
    final portfolio = user?.portfolio ?? [];

    final totalPortfolioUSD = provider.totalPortfolioValueUSD;
    final totalProfitLossUSD = provider.totalProfitLossUSD;
    final totalReturnPct = provider.totalReturnPercent;
    final isProfit = totalProfitLossUSD >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppTranslations.get('portfolio', lang),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              // Subtab toggle (Holdings / Analytics)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _selectedSubTab = 0),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _selectedSubTab == 0 ? const Color(0xFF2563EB) : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          AppTranslations.get('holdingsTab', lang),
                          style: TextStyle(
                            color: _selectedSubTab == 0 ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _selectedSubTab = 1),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _selectedSubTab == 1 ? const Color(0xFF2563EB) : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          AppTranslations.get('analyticsTab', lang),
                          style: TextStyle(
                            color: _selectedSubTab == 1 ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_selectedSubTab == 1)
            const Expanded(child: PortfolioAnalysisView())
          else ...[
            // Portfolio Metric Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.get('totalPortfolio', lang),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isProfit ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${isProfit ? "+" : ""}${totalReturnPct.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      provider.formatValue(totalPortfolioUSD),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTranslations.get('availableCash', lang),
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                provider.formatValue(user?.cashUSD ?? 0.0),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTranslations.get('investedAssets', lang),
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                provider.formatValue(provider.totalStockValueUSD),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTranslations.get('totalProfitLoss', lang),
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                provider.formatValue(totalProfitLossUSD, showSign: true),
                                style: TextStyle(
                                  color: isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active Holdings List
            if (portfolio.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pie_chart_outline, color: Color(0xFF64748B), size: 56),
                        const SizedBox(height: 16),
                        Text(
                          AppTranslations.get('noHoldings', lang),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppTranslations.get('exploreMarketsToBuy', lang),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: portfolio.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final pos = portfolio[index];
                    final quote = provider.getQuote(pos.ticker);
                    final currentPrice = (quote.price != null && quote.price! > 0) ? quote.price! : pos.averagePrice;
                    final rateToUSD = provider.rates[pos.nativeCurrency.toUpperCase()] ?? 1.0;
                    final currentPriceUSD = currentPrice / rateToUSD;
                    final currentValueUSD = currentPriceUSD * pos.shares;
                    final profitLossUSD = currentValueUSD - pos.totalCostUSD;
                    final returnPct = pos.totalCostUSD > 0 ? (profitLossUSD / pos.totalCostUSD) * 100 : 0.0;
                    final isPosProfit = profitLossUSD >= 0;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StockDetailScreen(quote: quote)),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pos.stockName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${pos.ticker} • ${pos.shares.toInt()} ${AppTranslations.get('shares', lang)}',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${AppTranslations.get('avgCost', lang)}: ${pos.averagePrice.toStringAsFixed(2)} ${pos.nativeCurrency}',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(currentPrice * pos.shares).toStringAsFixed(0)} ${pos.nativeCurrency}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${isPosProfit ? "+" : ""}${returnPct.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: isPosProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  provider.formatValue(profitLossUSD, showSign: true),
                                  style: TextStyle(
                                    color: isPosProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
