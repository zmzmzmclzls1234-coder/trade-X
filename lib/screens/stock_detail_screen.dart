import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/stock.dart';
import '../models/news_video.dart';
import '../providers/app_provider.dart';
import '../services/market_data_service.dart';
import '../services/news_service.dart';
import '../services/company_repository.dart';
import '../data/securities_data.dart';
import '../i18n/translations.dart';
import 'news_card.dart';

class StockDetailScreen extends StatefulWidget {
  final StockQuote quote;

  const StockDetailScreen({super.key, required this.quote});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final TextEditingController _sharesInputController = TextEditingController(text: '1');
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _tradeCardKey = GlobalKey();

  double _shares = 1.0;
  String _tradeMode = 'BUY'; // 'BUY' or 'SELL'
  bool _isTrading = false;
  bool _isRefreshing = false;
  String _selectedRange = '1M';
  StockChartData? _chartData;
  bool _isChartLoading = false;

  List<NewsVideo> _companyNews = [];
  bool _isNewsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDataPrioritized();
  }

  void _loadDataPrioritized() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    // 1. Immediately request fresh quote in background (cached is already displayed at 0ms)
    provider.fetchQuoteForTicker(widget.quote.ticker);
    // 2. Load chart data for selected timeframe
    _loadChartData();
    // 3. Load company news independently in background
    _loadCompanyNews();
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Refresh price first, then trigger chart and news in parallel without blocking price
    provider.fetchQuoteForTicker(widget.quote.ticker).then((_) {
      if (mounted) setState(() => _isRefreshing = false);
    });
    _loadChartData();
    _loadCompanyNews(forceRefresh: true);
  }

  Future<void> _loadCompanyNews({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isNewsLoading = true);
    final provider = Provider.of<AppProvider>(context, listen: false);
    final lang = provider.activeLanguage;
    final selectedCountry = provider.user?.country ?? 'KR';

    // Look up localName from CompanyRepository or securities directory
    final repoSec = CompanyRepository.instance.findCompany(widget.quote.ticker);
    String? localName = repoSec?.localName;

    if (localName == null || localName.isEmpty) {
      for (final sec in allSecuritiesDirectory) {
        if (sec.ticker == widget.quote.ticker) {
          localName = sec.localName;
          break;
        }
      }
    }

    try {
      final results = await NewsService.instance.fetchCompanyNews(
        ticker: widget.quote.ticker,
        companyName: widget.quote.name.isNotEmpty ? widget.quote.name : widget.quote.ticker,
        localName: localName,
        country: selectedCountry,
        language: lang,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _companyNews = results;
          _isNewsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isNewsLoading = false);
    }
  }

  @override
  void dispose() {
    _sharesInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChartData() async {
    setState(() => _isChartLoading = true);
    try {
      final data = await MarketDataService.fetchStockChart(widget.quote.ticker, _selectedRange);
      if (mounted) {
        setState(() {
          _chartData = data;
          _isChartLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isChartLoading = false);
    }
  }

  void _updateShares(double newShares, {bool updateText = true}) {
    final clamped = newShares.clamp(0.0, 1000000.0);
    setState(() {
      _shares = clamped;
      if (updateText) {
        _sharesInputController.text = clamped == clamped.roundToDouble() 
            ? clamped.toInt().toString() 
            : clamped.toStringAsFixed(2);
      }
    });
  }

  void _onTextChanged(String val) {
    final parsed = double.tryParse(val.trim());
    if (parsed != null && parsed >= 0) {
      setState(() => _shares = parsed);
    }
  }

  Future<void> _executeTrade(String type) async {
    if (_shares <= 0) {
      final lang = Provider.of<AppProvider>(context, listen: false).activeLanguage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.get('enterValidShares', lang)),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final lang = provider.activeLanguage;
    setState(() => _isTrading = true);

    try {
      await provider.executeTrade(
        ticker: widget.quote.ticker,
        type: type,
        shares: _shares,
      );

      if (mounted) {
        final actionWord = type == 'BUY' ? AppTranslations.get('boughtSuccess', lang) : AppTranslations.get('soldSuccess', lang);
        final sharesStr = AppTranslations.get('shares', lang);
        final successMsg = '$actionWord: ${_shares.toInt()} $sharesStr (${widget.quote.ticker})';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMsg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        var errText = e.toString().replaceAll('Exception: ', '');
        if (errText.contains('Insufficient virtual cash balance') || errText.contains('잔액이 부족') || errText.contains('Needs')) {
          errText = AppTranslations.get('insufficientFunds', lang);
        } else if (errText.contains('Insufficient shares') || errText.contains('수량이 부족') || errText.contains('own')) {
          errText = AppTranslations.get('insufficientShares', lang);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(errText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.user;
    final lang = provider.activeLanguage;
    final liveQuote = provider.getQuote(widget.quote.ticker);
    final hasPrice = liveQuote.price != null && liveQuote.price! > 0 && liveQuote.dataStatus != 'unavailable';
    final isPos = (liveQuote.changePercent ?? 0) >= 0;
    final price = liveQuote.price ?? 0.0;
    final formattedPrice = provider.formatStockPrice(liveQuote.price, liveQuote.currency);

    // Current position
    final posIndex = user?.portfolio.indexWhere((p) => p.ticker == liveQuote.ticker) ?? -1;
    final ownedPosition = posIndex >= 0 ? user!.portfolio[posIndex] : null;
    final ownedShares = ownedPosition?.shares ?? 0.0;

    // Conversion and Calculations
    final rateToUSD = provider.rates[liveQuote.currency.toUpperCase()] ?? 1.0;

    // Cost calculations for BUY
    final totalCostNative = price * _shares;
    final totalCostUSD = price > 0 ? (totalCostNative / rateToUSD) : 0.0;
    final displayTotalCost = provider.formatValue(totalCostUSD);
    final availableCashUSD = user?.cashUSD ?? 0.0;
    final canAffordBuy = price > 0 && totalCostUSD <= availableCashUSD && _shares > 0;
    final remainingCashUSD = availableCashUSD - totalCostUSD;

    // Max affordable shares for BUY
    final pricePerShareUSD = price > 0 ? (price / rateToUSD) : 1.0;
    final maxBuyShares = pricePerShareUSD > 0 ? (availableCashUSD / pricePerShareUSD).floor().toDouble() : 0.0;

    // Calculations for SELL
    final totalProceedsNative = price * _shares;
    final totalProceedsUSD = price > 0 ? (totalProceedsNative / rateToUSD) : 0.0;
    final displayProceeds = provider.formatValue(totalProceedsUSD);
    final canSell = ownedShares > 0 && _shares > 0 && _shares <= ownedShares;
    final cashAfterSellUSD = availableCashUSD + totalProceedsUSD;

    final sec = CompanyRepository.instance.findCompany(widget.quote.ticker);
    final displayName = sec?.localName ?? (liveQuote.name.isNotEmpty ? liveQuote.name : liveQuote.ticker);

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Row(
              children: [
                Text(
                  liveQuote.ticker,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
                if (sec != null && sec.exchange.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sec.exchange,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  '• ${liveQuote.currency}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh, color: Colors.white, size: 22),
            onPressed: _isRefreshing ? null : _refreshAll,
          ),
          IconButton(
            icon: Icon(
              user?.watchlist.contains(liveQuote.ticker) == true ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 24,
            ),
            onPressed: () => provider.toggleWatchlist(liveQuote.ticker),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Price & Change Banner (Mobile Responsive)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              hasPrice ? '${liveQuote.currency} $formattedPrice' : AppTranslations.get('unavailable', lang),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (hasPrice)
                            Row(
                              children: [
                                Icon(
                                  isPos ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: isPos ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${isPos ? "+" : ""}${liveQuote.change?.toStringAsFixed(2) ?? "0.00"} (${isPos ? "+" : ""}${liveQuote.changePercent?.toStringAsFixed(2) ?? "0.00"}%)',
                                    style: TextStyle(
                                      color: isPos ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              AppTranslations.get('marketDataUnavailable', lang),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (liveQuote.dataStatus == 'realtime'
                                ? const Color(0xFF10B981)
                                : (liveQuote.dataStatus == 'delayed'
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF64748B)))
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (liveQuote.dataStatus == 'realtime'
                                  ? const Color(0xFF10B981)
                                  : (liveQuote.dataStatus == 'delayed'
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF64748B)))
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            liveQuote.dataStatus == 'realtime'
                                ? Icons.bolt
                                : (liveQuote.dataStatus == 'delayed' ? Icons.access_time : Icons.cloud_off),
                            color: liveQuote.dataStatus == 'realtime'
                                ? const Color(0xFF10B981)
                                : (liveQuote.dataStatus == 'delayed' ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8)),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            liveQuote.dataStatus == 'realtime'
                                ? 'Real-time'
                                : (liveQuote.dataStatus == 'delayed' ? 'Delayed' : 'Unavailable'),
                            style: TextStyle(
                              color: liveQuote.dataStatus == 'realtime'
                                  ? const Color(0xFF10B981)
                                  : (liveQuote.dataStatus == 'delayed' ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8)),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Provider: Yahoo Finance v8 API',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                    Text(
                      'Updated: ${liveQuote.lastUpdated}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Interactive Chart & Range Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['1D', '1W', '1M', '1Y', '5Y'].map((range) {
                  final isSelected = _selectedRange == range;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () {
                          if (_selectedRange != range) {
                            setState(() => _selectedRange = range);
                            _loadChartData();
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                            ),
                          ),
                          child: Text(
                            range,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF090D16) : const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              Container(
                height: 200,
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(4, 12, 12, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: _isChartLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2))
                    : (_chartData == null || _chartData!.points.isEmpty)
                        ? Center(child: Text(AppTranslations.get('chartLoading', lang), style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)))
                        : _buildLineChart(isPos),
              ),
              const SizedBox(height: 16),

              // 3. Current User Holding Status Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pie_chart, color: Color(0xFF10B981), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppTranslations.get('yourHoldings', lang), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            Text(
                              ownedShares > 0
                                  ? '${ownedShares.toInt()} ${AppTranslations.get('sharesOwned', lang)}'
                                  : AppTranslations.get('noSharesOwned', lang),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (ownedShares > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(AppTranslations.get('marketValue', lang), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          Text(
                            '${(price * ownedShares).toStringAsFixed(0)} ${liveQuote.currency}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Smartphone-Optimized Trading Station
              Container(
                key: _tradeCardKey,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _tradeMode == 'BUY' ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFEF4444).withOpacity(0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_tradeMode == 'BUY' ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segmented Tab Toggle (BUY vs SELL)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _tradeMode = 'BUY';
                                  if (_shares <= 0) _updateShares(1);
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _tradeMode == 'BUY' ? const Color(0xFF10B981) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  AppTranslations.get('buy', lang).toUpperCase(),
                                  style: TextStyle(
                                    color: _tradeMode == 'BUY' ? const Color(0xFF090D16) : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _tradeMode = 'SELL';
                                  if (ownedShares > 0 && _shares > ownedShares) {
                                    _updateShares(ownedShares);
                                  } else if (ownedShares > 0 && _shares <= 0) {
                                    _updateShares(1);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _tradeMode == 'SELL' ? const Color(0xFFEF4444) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  AppTranslations.get('sell', lang).toUpperCase(),
                                  style: TextStyle(
                                    color: _tradeMode == 'SELL' ? Colors.white : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Available Balance / Share Balance Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _tradeMode == 'BUY' 
                                ? AppTranslations.get('availableCash', lang) 
                                : AppTranslations.get('sharesAvailable', lang),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _tradeMode == 'BUY'
                                ? provider.formatValue(availableCashUSD)
                                : '${ownedShares.toInt()} ${AppTranslations.get('shares', lang)}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quantity Input with Stepper Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _tradeMode == 'BUY' ? AppTranslations.get('sharesToBuy', lang) : AppTranslations.get('sharesToSell', lang),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(36, 36),
                              ),
                              icon: const Icon(Icons.remove, color: Colors.white, size: 16),
                              onPressed: () {
                                if (_shares > 1) _updateShares(_shares - 1);
                              },
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 76,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF090D16),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: TextField(
                                controller: _sharesInputController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: _onTextChanged,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(36, 36),
                              ),
                              icon: const Icon(Icons.add, color: Color(0xFF10B981), size: 16),
                              onPressed: () {
                                _updateShares(_shares + 1);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Quick Quantity Selector Chips
                    if (_tradeMode == 'BUY')
                      Row(
                        children: [
                          ...[1, 5, 10, 50, 100].map((amt) {
                            final isCur = _shares == amt.toDouble();
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: InkWell(
                                  onTap: () => _updateShares(amt.toDouble()),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isCur ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '+$amt',
                                      style: TextStyle(
                                        color: isCur ? const Color(0xFF090D16) : const Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (maxBuyShares > 0)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: InkWell(
                                  onTap: () => _updateShares(maxBuyShares),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.2),
                                      border: Border.all(color: const Color(0xFF10B981)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      AppTranslations.get('maxBuy', lang),
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      // SELL percentage chips
                      Row(
                        children: [
                          for (final pct in [0.25, 0.50, 0.75, 1.0])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: InkWell(
                                  onTap: ownedShares > 0 
                                      ? () => _updateShares((ownedShares * pct).floor().toDouble().clamp(1.0, ownedShares))
                                      : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      pct == 1.0 ? AppTranslations.get('maxSell', lang) : '${(pct * 100).toInt()}%',
                                      style: TextStyle(
                                        color: ownedShares > 0 ? const Color(0xFFF87171) : const Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Order Summary Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _tradeMode == 'BUY' ? AppTranslations.get('estimatedCost', lang) : AppTranslations.get('estProceeds', lang),
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(_tradeMode == 'BUY' ? totalCostNative : totalProceedsNative).toStringAsFixed(2)} ${liveQuote.currency}',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                  ),
                                  Text(
                                    '≈ ${_tradeMode == 'BUY' ? displayTotalCost : displayProceeds}',
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFF334155), height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _tradeMode == 'BUY' ? AppTranslations.get('remainingCash', lang) : AppTranslations.get('cashAfterSale', lang),
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                              Text(
                                provider.formatValue(_tradeMode == 'BUY' ? remainingCashUSD : cashAfterSellUSD),
                                style: TextStyle(
                                  color: (_tradeMode == 'BUY' && remainingCashUSD < 0) ? const Color(0xFFEF4444) : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Execution Button (Touch Target >= 48px)
                    if (_tradeMode == 'BUY')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (hasPrice && canAffordBuy) ? const Color(0xFF10B981) : const Color(0xFF334155),
                            foregroundColor: (hasPrice && canAffordBuy) ? const Color(0xFF090D16) : const Color(0xFF94A3B8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: (hasPrice && canAffordBuy) ? 4 : 0,
                          ),
                          onPressed: (_isTrading || !hasPrice || !canAffordBuy) ? null : () => _executeTrade('BUY'),
                          child: _isTrading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(hasPrice ? Icons.shopping_bag_outlined : Icons.lock_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      !hasPrice
                                          ? AppTranslations.get('marketDataUnavailable', lang)
                                          : (!canAffordBuy && _shares > 0
                                              ? AppTranslations.get('cantAfford', lang)
                                              : '${AppTranslations.get('buy', lang)} ${_shares.toInt()} ${AppTranslations.get('shares', lang)} ($displayTotalCost)'),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (hasPrice && canSell) ? const Color(0xFFEF4444) : const Color(0xFF334155),
                            foregroundColor: (hasPrice && canSell) ? Colors.white : const Color(0xFF94A3B8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: (hasPrice && canSell) ? 4 : 0,
                          ),
                          onPressed: (_isTrading || !hasPrice || !canSell) ? null : () => _executeTrade('SELL'),
                          child: _isTrading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(hasPrice ? Icons.sell_outlined : Icons.lock_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      !hasPrice
                                          ? AppTranslations.get('marketDataUnavailable', lang)
                                          : (ownedShares <= 0
                                              ? AppTranslations.get('noSharesToSell', lang)
                                              : (!canSell
                                                  ? AppTranslations.get('insufficientShares', lang)
                                                  : '${AppTranslations.get('sell', lang)} ${_shares.toInt()} ${AppTranslations.get('shares', lang)} (+$displayProceeds)')),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 5. Company Information & Key Statistics
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lang == 'ko' ? '기업 정보 및 주요 지표' : AppTranslations.get('keyStats', lang),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sec?.listingStatus ?? 'LISTED',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (sec?.localName != null && sec!.localName != sec.name)
                      _buildStatRow(
                        sec.country == 'GB'
                            ? (lang == 'ko' ? '영국 현지 기업명' : 'UK Local Name')
                            : (sec.country == 'DE'
                                ? (lang == 'ko' ? '독일 현지 기업명' : 'German Name')
                                : (sec.country == 'JP'
                                    ? (lang == 'ko' ? '일본 현지 기업명' : 'Japanese Name')
                                    : (lang == 'ko' ? '한글 기업명' : 'Local Name'))),
                        sec.localName!,
                      ),
                    if (sec?.name != null && sec!.name.isNotEmpty)
                      _buildStatRow(lang == 'ko' ? '영문 기업명' : 'English Name', sec.name),
                    _buildStatRow(
                      lang == 'ko' ? '종목코드 / 티커' : 'Symbol / Ticker',
                      sec?.code != null ? '${sec!.code} (${liveQuote.ticker})' : liveQuote.ticker,
                    ),
                    if (sec?.isin != null && sec!.isin!.isNotEmpty)
                      _buildStatRow(lang == 'ko' ? '국제표준코드 (ISIN)' : 'ISIN Code', sec.isin!),
                    _buildStatRow(
                      lang == 'ko' ? '상장 거래소' : AppTranslations.get('exchange', lang),
                      sec?.exchange ?? (liveQuote.ticker.contains('.KS') ? 'KOSPI' : (liveQuote.ticker.contains('.KQ') ? 'KOSDAQ' : 'KRX')),
                    ),
                    if (sec?.sector != null && sec!.sector.isNotEmpty)
                      _buildStatRow(lang == 'ko' ? '업종 분류' : 'Sector', sec.sector),
                    if (sec?.industry != null && sec!.industry!.isNotEmpty)
                      _buildStatRow(lang == 'ko' ? '주요 사업' : 'Industry', sec.industry!),
                    if (sec?.marketCap != null && sec!.marketCap! > 0)
                      _buildStatRow(lang == 'ko' ? '시가총액' : 'Market Cap', _formatMarketCap(sec.marketCap, sec.currency, lang)),
                    _buildStatRow(
                      AppTranslations.get('previousClose', lang),
                      liveQuote.previousClose != null ? '${provider.formatStockPrice(liveQuote.previousClose, liveQuote.currency)} ${liveQuote.currency}' : '—',
                    ),
                    _buildStatRow(AppTranslations.get('currency', lang), liveQuote.currency),
                    _buildStatRow(
                      AppTranslations.get('volume', lang),
                      liveQuote.volume != null ? '${liveQuote.volume} ${lang == "ko" ? "주" : "shares"}' : '—',
                    ),
                    if (sec?.representative != null && sec!.representative!.isNotEmpty)
                      _buildStatRow(lang == 'ko' ? '대표자' : 'CEO', sec.representative!),
                    if (sec?.listingDate != null && sec!.listingDate!.isNotEmpty)
                      _buildStatRow(lang == 'ko' ? '상장일' : 'Listing Date', sec.listingDate!),
                    _buildStatRow(
                      AppTranslations.get('marketState', lang),
                      liveQuote.marketState == 'REGULAR'
                          ? AppTranslations.get('regularMarket', lang)
                          : AppTranslations.get('closedMarket', lang),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 6. Related News Section (Company-specific YouTube News & AI Summary)
              _buildRelatedNewsSection(lang),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelatedNewsSection(String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.newspaper, color: Color(0xFF38BDF8), size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              lang == 'ko' ? '관련 뉴스' : 'Related News',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3), width: 0.6),
              ),
              child: Text(
                lang == 'ko' ? '공식 보도' : 'Verified Coverage',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: _isNewsLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh, color: Color(0xFF94A3B8), size: 18),
              onPressed: _isNewsLoading ? null : () => _loadCompanyNews(forceRefresh: true),
              tooltip: lang == 'ko' ? '뉴스 새로고침' : 'Refresh News',
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_isNewsLoading)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 10),
                Text(
                  lang == 'ko' ? '기업 관련 뉴스를 검색하는 중...' : 'Searching related news...',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          )
        else if (_companyNews.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getNoRelatedVideosMessage(lang),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _companyNews.map((v) => NewsCard(video: v, compact: true)).toList(),
          ),
      ],
    );
  }

  String _getNoRelatedVideosMessage(String lang) {
    switch (lang.toLowerCase()) {
      case 'ko':
        return '관련 동영상 없음';
      case 'ja':
        return '関連動画がありません';
      case 'de':
        return 'Keine zugehörigen Videos verfügbar';
      case 'fr':
        return 'Aucune vidéo associée disponible';
      case 'en':
      default:
        return 'No related videos available';
    }
  }

  String _formatMarketCap(double? cap, String currency, String lang) {
    if (cap == null || cap <= 0) return '—';
    if (currency.toUpperCase() == 'USD') {
      if (cap >= 1000000000000) {
        return '\$${(cap / 1000000000000).toStringAsFixed(2)}T';
      } else if (cap >= 1000000000) {
        return '\$${(cap / 1000000000).toStringAsFixed(1)}B';
      } else if (cap >= 1000000) {
        return '\$${(cap / 1000000).toStringAsFixed(0)}M';
      }
      return '\$${cap.toStringAsFixed(0)}';
    } else if (currency.toUpperCase() == 'JPY') {
      if (cap >= 1000000000000) {
        final trillions = cap / 1000000000000;
        return lang == 'ko'
            ? '${trillions.toStringAsFixed(1)}조엔'
            : '¥${trillions.toStringAsFixed(1)}T';
      } else if (cap >= 100000000) {
        final billions = cap / 100000000;
        return lang == 'ko'
            ? '${billions.toStringAsFixed(0)}억엔'
            : '¥${billions.toStringAsFixed(0)}00M';
      }
      return '¥${cap.toStringAsFixed(0)}';
    } else {
      if (cap >= 1000000000000) {
        final trillions = cap / 1000000000000;
        return lang == 'ko'
            ? '${trillions.toStringAsFixed(1)}조원'
            : '${trillions.toStringAsFixed(1)}T KRW';
      } else if (cap >= 100000000) {
        final billions = cap / 100000000;
        return lang == 'ko'
            ? '${billions.toStringAsFixed(0)}억원'
            : '${billions.toStringAsFixed(0)}00M KRW';
      }
      return cap.toStringAsFixed(0);
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(bool isPos) {
    final points = _chartData!.points;
    if (points.isEmpty) return const SizedBox();

    double minY = points.first.price;
    double maxY = points.first.price;
    for (final pt in points) {
      if (pt.price < minY) minY = pt.price;
      if (pt.price > maxY) maxY = pt.price;
    }
    final rangeY = maxY - minY;
    final padding = rangeY > 0 ? rangeY * 0.1 : 1.0;
    minY = (minY - padding).clamp(0.0, double.infinity);
    maxY = maxY + padding;

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].price));
    }

    final lineColor = isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: rangeY > 0 ? rangeY / 3 : 1.0,
          getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFF1E293B), strokeWidth: 0.8),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (val, meta) {
                return Text(
                  val.toStringAsFixed(0),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontFamily: 'monospace'),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              interval: (points.length / 4).clamp(1.0, 100.0),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < points.length) {
                  return Text(
                    points[idx].dateStr,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 8),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: const Color(0xFF1E293B),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final date = idx >= 0 && idx < points.length ? points[idx].dateStr : '';
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(2)}\n$date',
                  const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: lineColor,
            barWidth: 2.2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  lineColor.withOpacity(0.25),
                  lineColor.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
