import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../i18n/translations.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final txs = provider.transactions;
    final lang = provider.activeLanguage;

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
          AppTranslations.get('transactions', lang),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: txs.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: Color(0xFF64748B), size: 64),
                      const SizedBox(height: 16),
                      Text(
                        AppTranslations.get('noTransactionsYet', lang),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppTranslations.get('transactionsEmptyHint', lang),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: txs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tx = txs[index];
                  final isBuy = tx.type == 'BUY';
                  final badgeLabel = isBuy ? AppTranslations.get('bought', lang) : AppTranslations.get('sold', lang);
                  final sharesLabel = AppTranslations.get('shares', lang);

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isBuy
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isBuy
                                  ? const Color(0xFF10B981).withOpacity(0.3)
                                  : const Color(0xFFEF4444).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              color: isBuy ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.stockName,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${tx.ticker} • ${tx.shares.toInt()} $sharesLabel @ ${tx.price.toStringAsFixed(2)} ${tx.currency}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                tx.timestamp,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Total
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${tx.totalAmountNative.toStringAsFixed(0)} ${tx.currency}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Text(
                              provider.formatValue(tx.totalAmountUSD),
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
