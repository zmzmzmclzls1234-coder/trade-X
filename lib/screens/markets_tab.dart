import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/stock.dart';
import '../services/company_repository.dart';
import '../i18n/translations.dart';
import 'stock_detail_screen.dart';

class MarketsTab extends StatefulWidget {
  const MarketsTab({super.key});

  @override
  State<MarketsTab> createState() => _MarketsTabState();
}

class _MarketsTabState extends State<MarketsTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  String _selectedCountry = 'ALL'; // ALL, KR, US, JP
  String _selectedExchange = 'ALL'; // ALL, NASDAQ, NYSE, AMEX, KOSPI, KOSDAQ, KONEX, Prime, Standard, Growth, TOKYO PRO Market
  String _selectedCurrency = 'ALL'; // ALL, JPY, KRW, USD
  String _selectedSector = 'ALL';
  String _selectedMarketCapCategory = 'ALL';
  String _selectedSort = 'MARKET_CAP_DESC';
  String _searchQuery = '';

  int _currentPage = 1;
  static const int _pageSize = 40;
  List<StockSecurity> _displayedSecurities = [];
  List<StockSecurity> _allFilteredSecurities = [];
  bool _isLoadingMore = false;

  final List<Map<String, String>> _sectorsList = const [
    {'code': 'ALL', 'name': '전체 업종', 'en': 'All Sectors'},
    {'code': 'Technology', 'name': '기술 / 전기전자', 'en': 'Technology'},
    {'code': 'Healthcare', 'name': '의약품 / 헬스케어', 'en': 'Healthcare'},
    {'code': 'Financials', 'name': '금융업', 'en': 'Financials'},
    {'code': 'Consumer Discretionary', 'name': '임의소비재', 'en': 'Consumer Discretionary'},
    {'code': 'Communication Services', 'name': '통신 / 미디어', 'en': 'Communication'},
    {'code': 'Industrials', 'name': '산업재 / 기계', 'en': 'Industrials'},
    {'code': 'Energy', 'name': '에너지 / 석유화학', 'en': 'Energy'},
    {'code': 'Consumer Staples', 'name': '필수소비재', 'en': 'Consumer Staples'},
    {'code': 'Materials', 'name': '소재 / 원자재', 'en': 'Materials'},
    {'code': 'Utilities', 'name': '유틸리티', 'en': 'Utilities'},
    {'code': 'Real Estate', 'name': '부동산 / 리츠', 'en': 'Real Estate'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _applyFilters(resetPage: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _displayedSecurities.length < _allFilteredSecurities.length) {
        _loadNextPage();
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (_searchQuery != query) {
        setState(() {
          _searchQuery = query;
        });
        _applyFilters(resetPage: true);
      }
    });
  }

  void _applyFilters({bool resetPage = false}) {
    if (resetPage) {
      _currentPage = 1;
    }

    final filtered = CompanyRepository.instance.searchAndFilter(
      query: _searchQuery,
      country: _selectedCountry,
      exchange: _selectedExchange,
      sector: _selectedSector,
      marketCapCategory: _selectedMarketCapCategory,
      currency: _selectedCurrency,
      sort: _selectedSort,
    );

    _allFilteredSecurities = filtered;
    final countToTake = _currentPage * _pageSize;
    final paged = filtered.take(countToTake).toList();

    setState(() {
      _displayedSecurities = paged;
    });

    _fetchQuotesForVisible(paged);
  }

  void _loadNextPage() {
    if (_displayedSecurities.length >= _allFilteredSecurities.length) return;
    setState(() => _isLoadingMore = true);

    _currentPage++;
    final countToTake = _currentPage * _pageSize;
    final nextPaged = _allFilteredSecurities.take(countToTake).toList();

    setState(() {
      _displayedSecurities = nextPaged;
      _isLoadingMore = false;
    });

    final newItems = nextPaged.skip((_currentPage - 1) * _pageSize).toList();
    _fetchQuotesForVisible(newItems);
  }

  void _fetchQuotesForVisible(List<StockSecurity> items) {
    if (items.isEmpty || !mounted) return;
    final tickers = items.map((s) => s.ticker).toList();
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.fetchQuotesForSecurities(tickers);
  }

  String _formatMarketCap(double? cap, String currency, String lang) {
    if (cap == null || cap <= 0) return '—';
    if (currency == 'USD') {
      if (cap >= 1000000000000) {
        return '\$${(cap / 1000000000000).toStringAsFixed(2)}T';
      } else if (cap >= 100000000) {
        return '\$${(cap / 1000000000).toStringAsFixed(1)}B';
      } else if (cap >= 1000000) {
        return '\$${(cap / 1000000).toStringAsFixed(0)}M';
      }
      return '\$${cap.toStringAsFixed(0)}';
    } else if (currency == 'JPY') {
      if (cap >= 1000000000000) {
        final t = cap / 1000000000000;
        return '¥${t.toStringAsFixed(1)}${lang == "ko" ? "조" : "T"}';
      } else if (cap >= 100000000) {
        final b = cap / 100000000;
        return '¥${b.toStringAsFixed(0)}${lang == "ko" ? "억" : "00M"}';
      }
      return '¥${cap.toStringAsFixed(0)}';
    } else {
      if (cap >= 1000000000000) {
        final t = cap / 1000000000000;
        return '${t.toStringAsFixed(1)}${lang == "ko" ? "조" : "T"}';
      } else if (cap >= 100000000) {
        final b = cap / 100000000;
        return '${b.toStringAsFixed(0)}${lang == "ko" ? "억" : "00M"}';
      }
      return cap.toStringAsFixed(0);
    }
  }

  Color _getExchangeBadgeColor(String ex) {
    switch (ex.toUpperCase()) {
      case 'KOSPI':
        return const Color(0xFF38BDF8); // Sky blue
      case 'KOSDAQ':
        return const Color(0xFF10B981); // Emerald
      case 'KONEX':
        return const Color(0xFFF59E0B); // Amber
      case 'NASDAQ':
        return const Color(0xFF6366F1); // Indigo
      case 'NYSE':
        return const Color(0xFF8B5CF6); // Purple
      case 'AMEX':
        return const Color(0xFF06B6D4); // Cyan
      case 'PRIME':
        return const Color(0xFFE11D48); // Rose red
      case 'STANDARD':
        return const Color(0xFF2563EB); // Royal Blue
      case 'GROWTH':
        return const Color(0xFF059669); // Forest Green
      case 'TOKYO PRO MARKET':
      case 'PRO MARKET':
        return const Color(0xFFD97706); // Amber Orange
      case 'XETRA':
        return const Color(0xFF10B981); // Emerald
      case 'FRANKFURT':
      case 'FRANKFURT STOCK EXCHANGE':
        return const Color(0xFF6366F1); // Indigo
      case 'MAIN MARKET':
      case 'LONDON STOCK EXCHANGE':
      case 'LSE':
        return const Color(0xFF2563EB); // Royal Blue
      case 'AIM':
      case 'AIM MARKET':
        return const Color(0xFFD97706); // Amber Orange
      case 'ARCA':
      case 'BATS':
        return const Color(0xFFEC4899); // Pink
      default:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.user;
    final lang = provider.activeLanguage;
    final repo = CompanyRepository.instance;

    return Column(
      children: [
        // 1. Search Bar & Market Count Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: lang == 'ko'
                        ? '기업명, 티커 검색 (Apple, AAPL, 삼성전자, 005930...)'
                        : 'Search stocks (Apple, AAPL, Samsung, 005930...)',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    icon: const Icon(Icons.search, color: Color(0xFF38BDF8), size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF64748B), size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 2. Country / Market Tabs (All, South Korea, United States)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildCountryTab('ALL', lang == 'ko' ? '전체 시장 (${repo.totalCount})' : 'All Markets (${repo.totalCount})'),
                    _buildCountryTab('KR', lang == 'ko' ? '🇰🇷 한국 (${repo.koreanCount})' : '🇰🇷 Korea (${repo.koreanCount})'),
                    _buildCountryTab('US', lang == 'ko' ? '🇺🇸 미국 (${repo.usCount})' : '🇺🇸 USA (${repo.usCount})'),
                    _buildCountryTab('JP', lang == 'ko' ? '🇯🇵 일본 (${repo.japaneseCount})' : '🇯🇵 Japan (${repo.japaneseCount})'),
                    _buildCountryTab('DE', lang == 'ko' ? '🇩🇪 독일 (${repo.germanCount})' : '🇩🇪 Germany (${repo.germanCount})'),
                    _buildCountryTab('GB', lang == 'ko' ? '🇬🇧 영국 (${repo.ukCount})' : '🇬🇧 UK (${repo.ukCount})'),
                    _buildCountryTab('FR', lang == 'ko' ? '🇫🇷 프랑스 (${repo.frenchCount})' : '🇫🇷 France (${repo.frenchCount})'),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // 3. Exchange Filter Chips dynamically matching selected country
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _buildExchangeChipsList(lang),
                ),
              ),
              const SizedBox(height: 6),

              // 4. Currency Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildCurrencyChip('ALL', lang == 'ko' ? '전체 통화' : 'All Currencies'),
                    _buildCurrencyChip('GBP', '£ GBP (파운드)'),
                    _buildCurrencyChip('EUR', '€ EUR (유로)'),
                    _buildCurrencyChip('JPY', '¥ JPY (엔화)'),
                    _buildCurrencyChip('KRW', '₩ KRW (원화)'),
                    _buildCurrencyChip('USD', '\$ USD (달러)'),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // 5. Sector Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _sectorsList.map((s) {
                    final isSelected = _selectedSector == s['code'];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedSector = s['code']!);
                        _applyFilters(resetPage: true);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
                          ),
                        ),
                        child: Text(
                          lang == 'ko' ? s['name']! : s['en']!,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // 5. Result Count & Sort Dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang == 'ko'
                    ? '${_allFilteredSecurities.length}개 상장사 조회됨'
                    : '${_allFilteredSecurities.length} stocks found',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSort,
                  dropdownColor: const Color(0xFF0F172A),
                  isDense: true,
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                  icon: const Icon(Icons.sort, color: Color(0xFF10B981), size: 15),
                  items: [
                    DropdownMenuItem(value: 'MARKET_CAP_DESC', child: Text(lang == 'ko' ? '시가총액순' : 'Market Cap')),
                    DropdownMenuItem(value: 'NAME_ASC', child: Text(lang == 'ko' ? '기업명 가나다순' : 'Name (A-Z)')),
                    DropdownMenuItem(value: 'NAME_DESC', child: Text(lang == 'ko' ? '기업명 역순' : 'Name (Z-A)')),
                    DropdownMenuItem(value: 'TICKER_ASC', child: Text(lang == 'ko' ? '티커코드순' : 'Ticker Code')),
                    DropdownMenuItem(value: 'PRICE_DESC', child: Text(lang == 'ko' ? '최고가순' : 'Highest Price')),
                    DropdownMenuItem(value: 'PRICE_ASC', child: Text(lang == 'ko' ? '최저가순' : 'Lowest Price')),
                    DropdownMenuItem(value: 'GAINERS', child: Text(lang == 'ko' ? '상승률순' : 'Top Gainers')),
                    DropdownMenuItem(value: 'LOSERS', child: Text(lang == 'ko' ? '하락률순' : 'Top Losers')),
                    DropdownMenuItem(value: 'VOLUME_DESC', child: Text(lang == 'ko' ? '거래량순' : 'Trading Volume')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSort = val);
                      _applyFilters(resetPage: true);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // 6. Stock List with Lazy Loading & Infinite Scrolling
        Expanded(
          child: _displayedSecurities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, color: Color(0xFF64748B), size: 44),
                      const SizedBox(height: 10),
                      Text(
                        lang == 'ko' ? '일치하는 상장사가 없습니다.' : 'No matching stocks found.',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _displayedSecurities.length + (_displayedSecurities.length < _allFilteredSecurities.length ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == _displayedSecurities.length) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                        ),
                      );
                    }

                    final sec = _displayedSecurities[index];
                    final quote = provider.getQuote(sec.ticker);
                    final hasPrice = quote.price != null && quote.price! > 0 && quote.dataStatus != 'unavailable';
                    final formattedPrice = provider.formatStockPrice(quote.price, sec.currency);
                    final changePercent = quote.changePercent ?? 0.0;
                    final isPos = changePercent >= 0;

                    final badgeColor = _getExchangeBadgeColor(sec.exchange);
                    final isUS = sec.country == 'US';
                    final isJP = sec.country == 'JP';
                    final currSym = (sec.currency == 'GBP' || sec.country == 'GB')
                        ? '£'
                        : ((sec.currency == 'EUR' || sec.country == 'DE' || sec.country == 'FR')
                            ? '€'
                            : ((sec.currency == 'JPY' || isJP)
                                ? '¥'
                                : ((sec.currency == 'USD' || isUS) ? '\$' : '₩')));

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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          sec.localName ?? sec.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: badgeColor.withOpacity(0.3), width: 0.6),
                                        ),
                                        child: Text(
                                          sec.exchange,
                                          style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${sec.ticker} • ${sec.sector} ${sec.marketCap != null ? "• " + _formatMarketCap(sec.marketCap, sec.currency, lang) : ""}',
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
                                  hasPrice ? '$currSym$formattedPrice' : '—',
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

  Widget _buildCountryTab(String code, String label) {
    final isSelected = _selectedCountry == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCountry = code;
          _selectedExchange = 'ALL';
        });
        _applyFilters(resetPage: true);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1E293B)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExchangeChipsList(String lang) {
    if (_selectedCountry == 'GB' || _selectedCountry == 'UK') {
      return [
        _buildExchangeChip('ALL', lang == 'ko' ? '영국 전체' : 'All UK'),
        _buildExchangeChip('Main Market', lang == 'ko' ? '메인 마켓 (Main Market)' : 'Main Market'),
        _buildExchangeChip('AIM', 'AIM Market'),
      ];
    } else if (_selectedCountry == 'FR') {
      return [
        _buildExchangeChip('ALL', lang == 'ko' ? '프랑스 전체' : 'All France'),
        _buildExchangeChip('Euronext Paris', lang == 'ko' ? '유로넥스트 파리 (Euronext Paris)' : 'Euronext Paris'),
        _buildExchangeChip('Euronext Growth', 'Euronext Growth'),
      ];
    } else if (_selectedCountry == 'DE') {
      return [
        _buildExchangeChip('ALL', lang == 'ko' ? '독일 전체' : 'All Germany'),
        _buildExchangeChip('Xetra', 'Xetra (제트라)'),
        _buildExchangeChip('Frankfurt Stock Exchange', lang == 'ko' ? '프랑크푸르트 (Frankfurt)' : 'Frankfurt Stock Exchange'),
      ];
    } else if (_selectedCountry == 'JP') {
      return [
        _buildExchangeChip('ALL', lang == 'ko' ? '일본 전체' : 'All JPX'),
        _buildExchangeChip('Prime', lang == 'ko' ? '프라임 (Prime)' : 'Prime Market'),
        _buildExchangeChip('Standard', lang == 'ko' ? '스탠다드 (Standard)' : 'Standard Market'),
        _buildExchangeChip('Growth', lang == 'ko' ? '그로스 (Growth)' : 'Growth Market'),
        _buildExchangeChip('TOKYO PRO Market', 'TOKYO PRO Market'),
      ];
    } else if (_selectedCountry == 'US') {
      return [
        _buildExchangeChip('ALL', lang == 'ko' ? '미국 전체' : 'All US'),
        _buildExchangeChip('NASDAQ', 'NASDAQ'),
        _buildExchangeChip('NYSE', 'NYSE'),
        _buildExchangeChip('AMEX', 'AMEX'),
        _buildExchangeChip('ARCA', 'ARCA'),
      ];
    } else if (_selectedCountry == 'KR') {
      return [
        _buildExchangeChip('ALL', lang == 'ko' ? '한국 전체' : 'All KRX'),
        _buildExchangeChip('KOSPI', 'KOSPI (유가증권)'),
        _buildExchangeChip('KOSDAQ', 'KOSDAQ (코스닥)'),
        _buildExchangeChip('KONEX', 'KONEX (코넥스)'),
      ];
    } else {
      return [
        _buildExchangeChip('ALL', lang == 'ko' ? '전체 거래소' : 'All Exchanges'),
        _buildExchangeChip('Prime', 'Prime (東証)'),
        _buildExchangeChip('Standard', 'Standard (東証)'),
        _buildExchangeChip('Growth', 'Growth (東証)'),
        _buildExchangeChip('NASDAQ', 'NASDAQ'),
        _buildExchangeChip('NYSE', 'NYSE'),
        _buildExchangeChip('KOSPI', 'KOSPI'),
        _buildExchangeChip('KOSDAQ', 'KOSDAQ'),
        _buildExchangeChip('AMEX', 'AMEX'),
        _buildExchangeChip('TOKYO PRO Market', 'PRO Market'),
        _buildExchangeChip('KONEX', 'KONEX'),
      ];
    }
  }

  Widget _buildCurrencyChip(String code, String label) {
    final isSelected = _selectedCurrency == code;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCurrency = code);
        _applyFilters(resetPage: true);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8).withOpacity(0.15) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeChip(String code, String label) {
    final isSelected = _selectedExchange == code;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedExchange = code);
        _applyFilters(resetPage: true);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
}
