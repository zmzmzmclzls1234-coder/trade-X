import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock.dart';
import '../providers/app_provider.dart';
import '../services/market_data_service.dart';
import '../i18n/translations.dart';
import 'stock_detail_screen.dart';
import 'transactions_screen.dart';
import 'leaderboard_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.user;
    final lang = provider.activeLanguage;

    final totalPortfolioUSD = provider.totalPortfolioValueUSD;
    final totalProfitLossUSD = provider.totalProfitLossUSD;
    final totalReturnPct = provider.totalReturnPercent;
    final isProfit = totalProfitLossUSD >= 0;

    // Featured stocks
    final featuredTickers = ['005930.KS', 'NVDA', 'AAPL', '000660.KS', 'TSLA', 'MSFT', '7203.T'];

    return RefreshIndicator(
      color: const Color(0xFF10B981),
      backgroundColor: const Color(0xFF0F172A),
      onRefresh: () => provider.refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.get('simulatorTitle', lang),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.username ?? AppTranslations.get('defaultInvestor', lang),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flash_on, color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        AppTranslations.get('live1s', lang),
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Simulation Disclaimer Notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppTranslations.get('riskFreeBanner', lang),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Total Portfolio Balance Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  )
                ],
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
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppTranslations.get('pnl', lang)}: ${provider.formatValue(totalProfitLossUSD, showSign: true)}',
                    style: TextStyle(
                      color: isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Cash vs Stock Holdings breakdown
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090D16).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppTranslations.get('availableCash', lang),
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  provider.formatValue(user?.cashUSD ?? 0.0),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090D16).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppTranslations.get('stockValue', lang),
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  provider.formatValue(provider.totalStockValueUSD),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Shortcuts Row
            Row(
              children: [
                Expanded(
                  child: _buildShortcutButton(
                    context,
                    icon: Icons.history,
                    label: AppTranslations.get('transactions', lang),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildShortcutButton(
                    context,
                    icon: Icons.emoji_events,
                    label: AppTranslations.get('leaderboard', lang),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Trending / Featured Stocks Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppTranslations.get('topMovers', lang),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  AppTranslations.get('liveQuotes', lang),
                  style: TextStyle(color: const Color(0xFF10B981).withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: featuredTickers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ticker = featuredTickers[index];
                final quote = provider.getQuote(ticker);
                final sec = MarketDataService.securities.firstWhere(
                  (s) => s.ticker == ticker,
                  orElse: () => StockSecurity(
                    ticker: ticker,
                    name: quote.name.isNotEmpty ? quote.name : ticker,
                    country: 'US',
                    countryName: 'US',
                    exchange: 'NYSE',
                    sector: 'Tech',
                    marketCapCategory: 'Large Cap',
                    currency: quote.currency,
                  ),
                );

                final hasPrice = quote.price != null && quote.price! > 0 && quote.dataStatus != 'unavailable';
                final formattedPrice = provider.formatStockPrice(quote.price, quote.currency);
                final changePercent = quote.changePercent ?? 0.0;
                final isStockPos = changePercent >= 0;

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockDetailScreen(quote: quote),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: Icon(
                            user?.watchlist.contains(ticker) == true ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          ),
                          onPressed: () => provider.toggleWatchlist(ticker),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sec.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$ticker • ${sec.exchange}',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace'),
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
                              hasPrice ? '$formattedPrice ${quote.currency}' : '—',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasPrice ? '${isStockPos ? "+" : ""}${changePercent.toStringAsFixed(2)}%' : AppTranslations.get('unavailable', lang),
                              style: TextStyle(
                                color: hasPrice ? (isStockPos ? const Color(0xFF34D399) : const Color(0xFFF87171)) : const Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF10B981), size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
