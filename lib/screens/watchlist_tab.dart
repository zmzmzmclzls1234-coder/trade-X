import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/stock.dart';
import '../services/market_data_service.dart';
import '../i18n/translations.dart';
import 'stock_detail_screen.dart';

class WatchlistTab extends StatefulWidget {
  const WatchlistTab({super.key});

  @override
  State<WatchlistTab> createState() => _WatchlistTabState();
}

class _WatchlistTabState extends State<WatchlistTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWatchlistQuotes();
    });
  }

  void _refreshWatchlistQuotes() {
    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final watchlist = provider.user?.watchlist ?? [];
    if (watchlist.isNotEmpty) {
      provider.fetchQuotesForSecurities(watchlist);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.user;
    final lang = provider.activeLanguage;
    final watchlist = user?.watchlist ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppTranslations.get('watchlist', lang),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (watchlist.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF64748B), size: 20),
                  onPressed: _refreshWatchlistQuotes,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (watchlist.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_outline, color: Color(0xFF64748B), size: 56),
                      const SizedBox(height: 16),
                      Text(
                        AppTranslations.get('watchlistEmpty', lang),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppTranslations.get('watchlistHint', lang),
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
                itemCount: watchlist.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ticker = watchlist[index];
                  final quote = provider.getQuote(ticker);
                  final sec = MarketDataService.securities.firstWhere(
                    (s) => s.ticker == ticker,
                    orElse: () => StockSecurity(
                      ticker: ticker,
                      name: quote.name.isNotEmpty ? quote.name : ticker,
                      country: 'US',
                      countryName: 'US',
                      exchange: 'NYSE',
                      sector: 'General',
                      marketCapCategory: 'Large Cap',
                      currency: quote.currency,
                    ),
                  );

                  final hasPrice = quote.price != null && quote.price! > 0 && quote.dataStatus != 'unavailable';
                  final formattedPrice = provider.formatStockPrice(quote.price, quote.currency);
                  final changePercent = quote.changePercent ?? 0.0;
                  final isPos = changePercent >= 0;

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StockDetailScreen(quote: quote)),
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
                            icon: const Icon(Icons.star, color: Colors.amber, size: 20),
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
                                hasPrice ? '${isPos ? "+" : ""}${changePercent.toStringAsFixed(2)}%' : AppTranslations.get('unavailable', lang),
                                style: TextStyle(
                                  color: hasPrice ? (isPos ? const Color(0xFF34D399) : const Color(0xFFF87171)) : const Color(0xFF64748B),
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
            ),
        ],
      ),
    );
  }
}
