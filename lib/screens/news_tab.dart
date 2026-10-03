import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/news_video.dart';
import '../providers/app_provider.dart';
import '../services/news_service.dart';
import 'news_card.dart';

class NewsTab extends StatefulWidget {
  const NewsTab({super.key});

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  String _selectedCategory = 'market'; // 'market', 'company', 'event'
  String? _selectedCountryOverride;
  bool _isLoading = false;
  List<NewsVideo> _videos = [];

  final List<Map<String, String>> _availableCountries = const [
    {'code': 'KR', 'flag': '🇰🇷', 'name': 'South Korea', 'localName': '대한민국'},
    {'code': 'US', 'flag': '🇺🇸', 'name': 'United States', 'localName': '미국'},
    {'code': 'JP', 'flag': '🇯🇵', 'name': 'Japan', 'localName': '일본'},
    {'code': 'DE', 'flag': '🇩🇪', 'name': 'Germany', 'localName': '독일'},
    {'code': 'GB', 'flag': '🇬🇧', 'name': 'United Kingdom', 'localName': '영국'},
    {'code': 'FR', 'flag': '🇫🇷', 'name': 'France', 'localName': '프랑스'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNews();
    });
  }

  Future<void> _loadNews({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final provider = Provider.of<AppProvider>(context, listen: false);
    final country = _selectedCountryOverride ?? provider.user?.country ?? 'KR';
    final lang = provider.activeLanguage;

    try {
      final results = await NewsService.instance.fetchMarketNews(
        country: country,
        category: _selectedCategory,
        language: lang,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _videos = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videos = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onCategoryChanged(String category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
    });
    _loadNews();
  }

  void _onCountryChanged(String countryCode) {
    if (_selectedCountryOverride == countryCode) return;
    setState(() {
      _selectedCountryOverride = countryCode;
    });
    _loadNews(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final lang = provider.activeLanguage;
    final activeCountry = _selectedCountryOverride ?? provider.user?.country ?? 'KR';

    final countryObj = _availableCountries.firstWhere(
      (c) => c['code'] == activeCountry,
      orElse: () => _availableCountries.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.newspaper, color: Color(0xFF38BDF8), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              lang == 'ko' ? '금융 및 증시 뉴스' : 'Financial News',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh, color: Colors.white, size: 20),
            onPressed: _isLoading ? null : () => _loadNews(forceRefresh: true),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Country Selector Strip
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: const Color(0xFF0F172A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang == 'ko' ? '선택 국가 / 지역 시장' : 'Selected Market',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.verified, size: 12, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 4),
                        Text(
                          lang == 'ko' ? '공식 검증 언론사 전용' : 'Verified Sources Only',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _availableCountries.map((c) {
                      final isSelected = c['code'] == activeCountry;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => _onCountryChanged(c['code']!),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(c['flag']!, style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 6),
                                Text(
                                  lang == 'ko' ? c['localName']! : c['name']!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF090D16) : Colors.white,
                                  ),
                                ),
                              ],
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

          // 2. Three Main Category Tabs: Latest Market News, Company News, Major Market Events
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 0.8)),
            ),
            child: Row(
              children: [
                _buildCategoryButton(
                  category: 'market',
                  label: lang == 'ko' ? '최신 시장 뉴스' : 'Latest Market',
                  icon: Icons.trending_up,
                ),
                const SizedBox(width: 8),
                _buildCategoryButton(
                  category: 'company',
                  label: lang == 'ko' ? '기업 뉴스' : 'Company News',
                  icon: Icons.business,
                ),
                const SizedBox(width: 8),
                _buildCategoryButton(
                  category: 'event',
                  label: lang == 'ko' ? '주요 시장 이슈' : 'Market Events',
                  icon: Icons.event_note,
                ),
              ],
            ),
          ),

          // 3. News Feed Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF38BDF8)),
                        SizedBox(height: 12),
                        Text(
                          'Loading verified financial news...',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : _videos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.newspaper, size: 48, color: Color(0xFF475569)),
                              const SizedBox(height: 12),
                              Text(
                                lang == 'ko'
                                    ? '${countryObj['localName']} 시장 관련 뉴스를 불러오지 못했습니다.'
                                    : 'No recent financial news found for this market.',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _loadNews(forceRefresh: true),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: Text(lang == 'ko' ? '다시 시도' : 'Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF38BDF8),
                        backgroundColor: const Color(0xFF0F172A),
                        onRefresh: () => _loadNews(forceRefresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _videos.length,
                          itemBuilder: (context, index) {
                            return NewsCard(video: _videos[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton({
    required String category,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: InkWell(
        onTap: () => _onCategoryChanged(category),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8).withOpacity(0.5) : const Color(0xFF1E293B),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
