import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../i18n/translations.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _realUsersLeaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealLeaderboard();
  }

  Future<void> _loadRealLeaderboard() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final users = await DatabaseService.instance.loadAllUserProfiles();

    final List<Map<String, dynamic>> list = [];

    for (final u in users) {
      double stockValUSD = 0.0;
      for (final pos in u.portfolio) {
        final q = provider.getQuote(pos.ticker);
        final rate = provider.rates[pos.nativeCurrency.toUpperCase()] ?? 1.0;
        final priceUSD = (q.price ?? pos.averagePrice) / rate;
        stockValUSD += pos.shares * priceUSD;
      }

      final totalValUSD = u.cashUSD + stockValUSD;
      final initialUSD = u.initialCashKRW / (provider.rates['KRW'] ?? 1350.0);
      final returnPct = initialUSD > 0 ? ((totalValUSD - initialUSD) / initialUSD) * 100.0 : 0.0;

      list.add({
        'id': u.id,
        'username': u.username,
        'country': u.country,
        'totalValUSD': totalValUSD,
        'returnPct': returnPct,
        'isCurrent': u.id == provider.user?.id,
      });
    }

    // Strictly sort by actual return percentage descending
    list.sort((a, b) => (b['returnPct'] as double).compareTo(a['returnPct'] as double));

    if (mounted) {
      setState(() {
        _realUsersLeaderboard = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final lang = provider.activeLanguage;
    final youBadge = AppTranslations.get('youBadge', lang);

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppTranslations.get('topPerformers', lang),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8), size: 20),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadRealLeaderboard();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              )
            : _realUsersLeaderboard.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emoji_events_outlined, size: 56, color: Color(0xFF64748B)),
                          const SizedBox(height: 16),
                          Text(
                            AppTranslations.get('noTransactions', lang),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _realUsersLeaderboard.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _realUsersLeaderboard[index];
                      final isUser = item['isCurrent'] as bool;
                      final ret = item['returnPct'] as double;
                      final isPos = ret >= 0;
                      final countryCode = item['country'] as String;

                      String flag = '🌐';
                      if (countryCode == 'KR') flag = '🇰🇷 KR';
                      else if (countryCode == 'US') flag = '🇺🇸 US';
                      else if (countryCode == 'JP') flag = '🇯🇵 JP';
                      else if (countryCode == 'DE') flag = '🇩🇪 DE';
                      else if (countryCode == 'GB') flag = '🇬🇧 GB';
                      else if (countryCode == 'FR') flag = '🇫🇷 FR';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUser ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFF1E293B),
                            width: isUser ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Rank
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? Colors.amber.withOpacity(0.2)
                                    : (index == 1 ? Colors.grey.withOpacity(0.2) : (index == 2 ? Colors.brown.withOpacity(0.2) : Colors.transparent)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  color: index < 3 ? Colors.amber : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Name & Country
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item['username'] as String,
                                          style: TextStyle(
                                            color: isUser ? const Color(0xFF10B981) : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      if (isUser) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            youBadge,
                                            style: const TextStyle(color: Color(0xFF090D16), fontSize: 8, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    flag,
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Return % & Value
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isPos ? "+" : ""}${ret.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: isPos ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  provider.formatValue(item['totalValUSD'] as double),
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
