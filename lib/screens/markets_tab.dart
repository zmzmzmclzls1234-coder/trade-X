import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/stock.dart';
import '../services/market_data_service.dart';
import '../i18n/translations.dart';
import 'stock_detail_screen.dart';

class MarketsTab extends StatefulWidget {
  const MarketsTab({super.key});

  @override
  State<MarketsTab> createState() => _MarketsTabState();
}

class _MarketsTabState extends State<MarketsTab> {
  String _selectedCountry = 'GLOBAL';
  String _selectedSector = 'ALL';
  String _selectedSort = 'NAME_ASC';
  String _searchQuery = '';
  List<StockSecurity> _securities = [];
  bool _initializedUserCountry = false;

  @override
  void initState() {
    super.initState();
    _filterSecurities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedUserCountry) {
      final user = Provider.of<AppProvider>(context, listen: false).user;
      if (user != null && user.country.isNotEmpty) {
        _selectedCountry = user.country;
        _filterSecurities();
      }
      _initializedUserCountry = true;
    }
  }

  void _filterSecurities() {
    final list = MarketDataService.searchSecurities(
      query: _searchQuery,
      country: _selectedCountry,
      sector: _selectedSector,
      sort: _selectedSort,
    );
    setState(() {
      _securities = list;
    });

    // Fetch verified real market quotes for the visible items of this category/query
    final visibleTickers = list.take(30).map((s) => s.ticker).toList();
    if (visibleTickers.isNotEmpty && mounted) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      provider.fetchQuotesForSecurities(visibleTickers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.user;
    final lang = provider.activeLanguage;

    return Column(
      children: [
        // Search & Filter Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Field
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (val) {
                    _searchQuery = val;
                    _filterSecurities();
                  },
                  decoration: InputDecoration(
                    hintText: AppTranslations.get('searchPlaceholder', lang),
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    icon: const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Country Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildCountryChip('GLOBAL', AppTranslations.get('globalTop100', lang)),
                    _buildCountryChip('ALL', AppTranslations.get('allGlobalSecurities', lang)),
                    _buildCountryChip('KR', AppTranslations.get('countryKR', lang)),
                    _buildCountryChip('US', AppTranslations.get('countryUS', lang)),
                    _buildCountryChip('JP', AppTranslations.get('countryJP', lang)),
                    _buildCountryChip('DE', AppTranslations.get('countryDE', lang)),
                    _buildCountryChip('GB', AppTranslations.get('countryGB', lang)),
                    _buildCountryChip('FR', AppTranslations.get('countryFR', lang)),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Sector Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildSectorChip('ALL', AppTranslations.get('allSectors', lang)),
                    _buildSectorChip('Technology', AppTranslations.get('technology', lang)),
                    _buildSectorChip('Financials', AppTranslations.get('financials', lang)),
                    _buildSectorChip('Consumer Discretionary', AppTranslations.get('consumer', lang)),
                    _buildSectorChip('Healthcare', AppTranslations.get('healthcare', lang)),
                    _buildSectorChip('Industrials', AppTranslations.get('industrials', lang)),
                    _buildSectorChip('Communication Services', AppTranslations.get('communication', lang)),
                    _buildSectorChip('Materials', AppTranslations.get('materials', lang)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Result count & sort selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_securities.length} ${AppTranslations.get('securitiesFound', lang)}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSort,
                  dropdownColor: const Color(0xFF0F172A),
                  isDense: true,
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                  icon: const Icon(Icons.sort, color: Color(0xFF10B981), size: 16),
                  items: [
                    DropdownMenuItem(value: 'NAME_ASC', child: Text(AppTranslations.get('sortNameAsc', lang))),
                    DropdownMenuItem(value: 'NAME_DESC', child: Text(AppTranslations.get('sortNameDesc', lang))),
                    DropdownMenuItem(value: 'PRICE_DESC', child: Text(AppTranslations.get('sortPriceDesc', lang))),
                    DropdownMenuItem(value: 'PRICE_ASC', child: Text(AppTranslations.get('sortPriceAsc', lang))),
                    DropdownMenuItem(value: 'GAINERS', child: Text(AppTranslations.get('sortGainers', lang))),
                    DropdownMenuItem(value: 'LOSERS', child: Text(AppTranslations.get('sortLosers', lang))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSort = val);
                      _filterSecurities();
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // Securities List
        Expanded(
          child: _securities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, color: Color(0xFF64748B), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        AppTranslations.get('noResults', lang),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _securities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final sec = _securities[index];
                    final quote = provider.getQuote(sec.ticker);
                    final hasPrice = quote.price != null && quote.price! > 0 && quote.dataStatus != 'unavailable';
                    final formattedPrice = provider.formatStockPrice(quote.price, sec.currency);
                    final changePercent = quote.changePercent ?? 0.0;
                    final isPos = changePercent >= 0;

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
                                user?.watchlist.contains(sec.ticker) == true ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              ),
                              onPressed: () => provider.toggleWatchlist(sec.ticker),
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
                                    '${sec.ticker} • ${sec.exchange} • ${sec.sector}',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  hasPrice ? '$formattedPrice ${sec.currency}' : '—',
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
    );
  }

  Widget _buildCountryChip(String code, String label) {
    final isSelected = _selectedCountry == code;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCountry = code);
        _filterSecurities();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1E293B)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF090D16) : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectorChip(String sector, String label) {
    final isSelected = _selectedSector == sector;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSector = sector);
        _filterSecurities();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
