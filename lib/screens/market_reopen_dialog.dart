import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/market_reopen_summary.dart';
import '../providers/app_provider.dart';
import '../i18n/translations.dart';
import 'stock_detail_screen.dart';

class MarketReopenDialog extends StatefulWidget {
  final MarketReopenSummary summary;
  final VoidCallback onDismiss;

  const MarketReopenDialog({
    super.key,
    required this.summary,
    required this.onDismiss,
  });

  static Future<void> show(BuildContext context, MarketReopenSummary summary) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MarketReopenDialog(
        summary: summary,
        onDismiss: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  State<MarketReopenDialog> createState() => _MarketReopenDialogState();
}

class _MarketReopenDialogState extends State<MarketReopenDialog> {
  int _tabIndex = 0; // 0: Top Movers, 1: Holdings, 2: Watchlist

  String _formatElapsed(int minutes, String lang) {
    if (minutes < 60) {
      return lang == 'ko' ? '$minutes분' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return lang == 'ko' ? '$hours시간' : '${hours}h';
    }
    return lang == 'ko' ? '$hours시간 $mins분' : '${hours}h ${mins}m';
  }

  String _formatPrice(double price, String currency) {
    if (currency == 'KRW' || currency == 'JPY' || currency == 'VND') {
      return price.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
    }
    return price.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final lang = provider.activeLanguage;
    final summary = widget.summary;

    final elapsedStr = _formatElapsed(summary.sessionElapsedMinutes, lang);
    final isProfit = summary.portfolioChangeUSD >= 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.insights, color: Color(0xFF38BDF8), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTranslations.get('whileYouWereAway', lang),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lang == 'ko'
                                ? '지난 $elapsedStr 동안의 시장 변동 요약'
                                : 'Market activity over the past $elapsedStr',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 22),
                      onPressed: () {
                        widget.onDismiss();
                        provider.acknowledgeMarketSummary();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF1E293B), height: 1),

              // Main Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Error / Unavailable State
                    if (summary.isDataUnavailable) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.wifi_off, color: Color(0xFFF87171), size: 36),
                            const SizedBox(height: 10),
                            Text(
                              summary.unavailableMessage ?? 'Market data currently unavailable',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // 1. Portfolio Changes Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1E293B),
                              isProfit
                                  ? const Color(0xFF064E3B).withOpacity(0.4)
                                  : const Color(0xFF7F1D1D).withOpacity(0.4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isProfit
                                ? const Color(0xFF10B981).withOpacity(0.3)
                                : const Color(0xFFEF4444).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppTranslations.get('portfolioChanges', lang),
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isProfit ? Icons.arrow_upward : Icons.arrow_downward,
                                        color: isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${isProfit ? "+" : ""}${summary.portfolioChangePercent.toStringAsFixed(2)}%',
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
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang == 'ko' ? '이전 총 자산' : 'Previous Value',
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        provider.formatValue(summary.previousPortfolioValueUSD),
                                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward, color: Color(0xFF64748B), size: 16),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lang == 'ko' ? '현재 총 자산' : 'Current Value',
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        provider.formatValue(summary.currentPortfolioValueUSD),
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${lang == 'ko' ? '변동 금액' : 'Difference'}: ${provider.formatValue(summary.portfolioChangeUSD, showSign: true)}',
                              style: TextStyle(
                                color: isProfit ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Market Closure Notice (if any markets are closed)
                      if (summary.closedMarkets.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: Color(0xFFF59E0B), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppTranslations.get('marketClosedNotice', lang),
                                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 2. Tracked Stock Movers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppTranslations.get('trackedMovers', lang),
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${summary.movements.length} tracked',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Filter Chips (Top Movers / Holdings / Watchlist)
                      Row(
                        children: [
                          _buildFilterChip(0, lang == 'ko' ? '주요 변동' : 'Top Movers', summary.movements.length),
                          const SizedBox(width: 8),
                          _buildFilterChip(1, lang == 'ko' ? '보유 종목' : 'Holdings', summary.heldStockMovements.length),
                          const SizedBox(width: 8),
                          _buildFilterChip(2, lang == 'ko' ? '관심 종목' : 'Watchlist', summary.watchlistMovements.length),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Movement List
                      _buildMovementsList(context, provider, lang),
                      const SizedBox(height: 18),

                      // 3. Relevant News Published While Away
                      if (summary.recentNews.isNotEmpty) ...[
                        Text(
                          AppTranslations.get('recentNewsWhileAway', lang),
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: summary.recentNews.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final news = summary.recentNews[index];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.newspaper, color: Color(0xFF38BDF8), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          news.title,
                                          style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          news.channelTitle,
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
              ),

              // Bottom Action Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      widget.onDismiss();
                      provider.acknowledgeMarketSummary();
                    },
                    child: Text(
                      lang == 'ko' ? '확인 및 계속하기' : 'Got It',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(int index, String label, int count) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMovementsList(BuildContext context, AppProvider provider, String lang) {
    final summary = widget.summary;
    List<StockPriceMovement> items;
    if (_tabIndex == 1) {
      items = summary.heldStockMovements;
    } else if (_tabIndex == 2) {
      items = summary.watchlistMovements;
    } else {
      items = summary.movements;
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 32),
              const SizedBox(height: 8),
              Text(
                AppTranslations.get('noSignificantChanges', lang),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length > 8 ? 8 : items.length, // Sensible limit to prevent overwhelming
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = items[index];
        final isUp = m.percentChange >= 0;
        final color = isUp ? const Color(0xFF34D399) : const Color(0xFFF87171);

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            widget.onDismiss();
            provider.acknowledgeMarketSummary();
            final quote = provider.getQuote(m.ticker);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StockDetailScreen(quote: quote)),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            m.ticker,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          if (m.isHolding) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                lang == 'ko' ? '보유' : 'Held',
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.name,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (m.marketClosureNotice != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          m.marketClosureNotice!,
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatPrice(m.previousPrice, m.currency),
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace'),
                        ),
                        const Icon(Icons.arrow_right_alt, color: Color(0xFF64748B), size: 14),
                        Text(
                          _formatPrice(m.currentPrice, m.currency),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isUp ? "+" : ""}${m.percentChange.toStringAsFixed(2)}%',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
