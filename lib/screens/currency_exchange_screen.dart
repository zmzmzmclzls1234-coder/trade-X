import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/currency_service.dart';
import '../i18n/translations.dart';

class CurrencyExchangeScreen extends StatefulWidget {
  const CurrencyExchangeScreen({super.key});

  @override
  State<CurrencyExchangeScreen> createState() => _CurrencyExchangeScreenState();
}

class _CurrencyExchangeScreenState extends State<CurrencyExchangeScreen> {
  String _selectedBase = 'USD';
  String _searchQuery = '';
  CurrencyRateResult? _rateResult;
  bool _isLoading = true;
  Timer? _uiClockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadRates();
    // 1-second UI clock update to show accurate elapsed observation time
    _uiClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _uiClockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRates({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final res = await CurrencyService.instance.fetchExchangeRates(
      baseCurrency: _selectedBase,
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _rateResult = res;
        _isLoading = false;
      });
    }
  }

  void _showBaseCurrencySelector() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final lang = provider.activeLanguage;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get('selectBaseCurrency', lang),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: CurrencyService.supportedBaseCurrencies.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1E293B)),
                  itemBuilder: (context, index) {
                    final code = CurrencyService.supportedBaseCurrencies[index];
                    final meta = CurrencyService.knownCurrencyMeta[code];
                    final isSel = code == _selectedBase;

                    return ListTile(
                      dense: true,
                      leading: Text(meta?['flag'] ?? '🌐', style: const TextStyle(fontSize: 22)),
                      title: Text(
                        '$code • ${meta?['name'] ?? code}',
                        style: TextStyle(
                          color: isSel ? const Color(0xFF38BDF8) : Colors.white,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      trailing: isSel ? const Icon(Icons.check_circle, color: Color(0xFF38BDF8), size: 18) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedBase = code;
                        });
                        _loadRates(forceRefresh: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyConverterDialog(CurrencyRateItem item) {
    final amountController = TextEditingController(text: '100');
    final provider = Provider.of<AppProvider>(context, listen: false);
    final lang = provider.activeLanguage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double amount = double.tryParse(amountController.text) ?? 0.0;
          final double converted = amount * item.rate;

          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Text(item.flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  '$_selectedBase ➔ ${item.code}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 $_selectedBase = ${item.rate.toStringAsFixed(item.rate < 1 ? 4 : 2)} ${item.code}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Amount in $_selectedBase',
                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Converted Amount (${item.code})',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.code == 'KRW' || item.code == 'JPY' || item.code == 'VND' ? converted.toStringAsFixed(0) : converted.toStringAsFixed(2)} ${item.code}',
                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppTranslations.get('cancel', lang), style: const TextStyle(color: Color(0xFF64748B))),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final lang = provider.activeLanguage;

    final filteredItems = (_rateResult?.items ?? []).where((item) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return item.code.toLowerCase().contains(q) || item.name.toLowerCase().contains(q);
    }).toList();

    // Compute elapsed time from actual market observation
    String elapsedStr = 'Just now';
    if (_rateResult != null) {
      final diff = _now.difference(_rateResult!.marketObservationTime);
      if (diff.inSeconds < 60) {
        elapsedStr = '${diff.inSeconds}s ago';
      } else if (diff.inMinutes < 60) {
        elapsedStr = '${diff.inMinutes}m ${diff.inSeconds % 60}s ago';
      } else {
        elapsedStr = '${diff.inHours}h ${diff.inMinutes % 60}m ago';
      }
    }

    final isError = _rateResult?.error != null;
    final isCached = _rateResult?.isCached ?? false;

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
        title: Row(
          children: [
            const Icon(Icons.currency_exchange, color: Color(0xFF38BDF8), size: 20),
            const SizedBox(width: 8),
            Text(
              AppTranslations.get('currencyExchangeTitle', lang),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8), size: 20),
            onPressed: () => _loadRates(forceRefresh: true),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status and Metadata Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 0.8)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Base Currency Selector Button
                      InkWell(
                        onTap: _showBaseCurrencySelector,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${CurrencyService.knownCurrencyMeta[_selectedBase]?['flag'] ?? '🌐'} $_selectedBase',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8), size: 18),
                            ],
                          ),
                        ),
                      ),
                      // Provider Status Indicator
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isError
                                  ? const Color(0xFFEF4444)
                                  : (isCached ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isError ? 'Service Error' : (isCached ? 'Cached / Stale' : 'Live Official Feed'),
                            style: TextStyle(
                              color: isError
                                  ? const Color(0xFFF87171)
                                  : (isCached ? const Color(0xFFFBBF24) : const Color(0xFF34D399)),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Timing Disclosures
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Provider: ${_rateResult?.providerName ?? "Open Exchange Rates"}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                      ),
                      Text(
                        'Observed: $elapsedStr',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: AppTranslations.get('searchCurrencyPlaceholder', lang),
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    icon: const Icon(Icons.search, color: Color(0xFF64748B), size: 16),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),

            // Main Rates List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                  : isError && filteredItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  _rateResult?.error ?? 'Error loading exchange rates',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                                  onPressed: () => _loadRates(forceRefresh: true),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry Connection'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isSameBase = item.code == _selectedBase;

                            final formattedRate = (item.code == 'KRW' || item.code == 'JPY' || item.code == 'VND' || item.code == 'IDR')
                                ? item.rate.toStringAsFixed(item.rate >= 100 ? 0 : 2)
                                : (item.rate < 0.01 ? item.rate.toStringAsFixed(5) : (item.rate < 1 ? item.rate.toStringAsFixed(4) : item.rate.toStringAsFixed(2)));

                            final formattedInverse = item.inverseRate < 0.001
                                ? item.inverseRate.toStringAsExponential(2)
                                : (item.inverseRate < 1 ? item.inverseRate.toStringAsFixed(4) : item.inverseRate.toStringAsFixed(2));

                            return InkWell(
                              onTap: () => _showCurrencyConverterDialog(item),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSameBase ? const Color(0xFF0284C7).withOpacity(0.12) : const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSameBase ? const Color(0xFF0284C7).withOpacity(0.4) : const Color(0xFF1E293B),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(item.flag, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                item.code,
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              if (isSameBase) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0284C7),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('BASE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.name,
                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$formattedRate ${item.code}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '1 ${item.code} = $formattedInverse $_selectedBase',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontFamily: 'monospace'),
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
      ),
    );
  }
}
