import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/news_video.dart';
import '../data/trusted_news_sources.dart';
import '../data/api_config.dart';

class NewsService {
  static final NewsService instance = NewsService._internal();
  NewsService._internal();

  static const MethodChannel _channel = MethodChannel('com.tradepulse.stocksimulator/notifications');

  // In-memory cache with timestamp to prevent redundant network calls
  final Map<String, _CachedNews> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  /// Fetch company-specific news videos from YouTube for StockDetailScreen
  Future<List<NewsVideo>> fetchCompanyNews({
    required String ticker,
    required String companyName,
    String? localName,
    required String country,
    required String language,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'company_${ticker}_${country}_$language';
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheDuration) {
        return cached.videos;
      }
    }

    try {
      // Build search query incorporating company identifiers and financial news context
      final searchTerms = <String>[];
      final isKoreanSearch = country.toUpperCase() == 'KR' || language.toLowerCase() == 'ko';
      if (isKoreanSearch && localName != null && localName.trim().isNotEmpty) {
        searchTerms.add(localName.trim());
      } else {
        searchTerms.add(companyName.trim());
      }

      final finKw = language == 'ko'
          ? '주식 실적 뉴스'
          : (language == 'ja'
              ? '株価 決算 ニュース'
              : (language == 'de'
                  ? 'Aktie Quartalszahlen Börse'
                  : (language == 'fr' ? 'bourse résultats actions' : 'stock earnings market news')));
      searchTerms.add(finKw);

      final query = searchTerms.join(' ');

      // Query YouTube API
      final rawVideos = await _queryYouTube(
        query: query,
        country: country,
        language: language,
        category: 'company',
        ticker: ticker,
        companyName: companyName,
      );

      // Filter and prioritize company-specific relevance
      final filtered = <NewsVideo>[];
      final seenIds = <String>{};

      for (final v in rawVideos) {
        if (seenIds.contains(v.id)) continue;

        final isRelevant = TrustedNewsSources.isRelevantToCompany(
          title: v.title,
          description: v.description,
          companyName: companyName,
          localName: localName,
          ticker: ticker,
        );

        if (isRelevant) {
          seenIds.add(v.id);
          filtered.add(v);
        }
      }

      // Sort: verified reputable news organizations first, then recency
      filtered.sort((a, b) {
        if (a.isVerifiedSource != b.isVerifiedSource) {
          return a.isVerifiedSource ? -1 : 1;
        }
        return 0;
      });

      _cache[cacheKey] = _CachedNews(videos: filtered, timestamp: DateTime.now());
      return filtered;
    } catch (e) {
      debugPrint('[NewsService] fetchCompanyNews error: $e');
      return [];
    }
  }

  /// Fetch country-specific financial news videos for the main "News" tab
  Future<List<NewsVideo>> fetchMarketNews({
    required String country,
    required String category, // 'market', 'company', 'event'
    required String language,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'market_${category}_${country}_$language';
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheDuration) {
        return cached.videos;
      }
    }

    try {
      final query = _buildMarketQuery(country: country, category: category, language: language);

      final rawVideos = await _queryYouTube(
        query: query,
        country: country,
        language: language,
        category: category,
      );

      final filtered = <NewsVideo>[];
      final seenIds = <String>{};

      for (final v in rawVideos) {
        if (seenIds.contains(v.id)) continue;

        // Rule 4: ONLY allow videos from approved reputable sources in the main news feed
        if (!v.isVerifiedSource) continue;

        // Rule 5: Verify market & financial relevance
        final isMarketRelevant = TrustedNewsSources.isRelevantToMarket(
          title: v.title,
          description: v.description,
          country: country,
        );

        if (isMarketRelevant) {
          seenIds.add(v.id);
          filtered.add(v);
        }
      }

      _cache[cacheKey] = _CachedNews(videos: filtered, timestamp: DateTime.now());
      return filtered;
    } catch (e) {
      debugPrint('[NewsService] fetchMarketNews error: $e');
      return [];
    }
  }

  /// Launch YouTube video via native Android Intent
  Future<bool> openVideo(String videoUrl) async {
    try {
      final res = await _channel.invokeMethod<bool>('openUrl', {'url': videoUrl});
      return res ?? false;
    } catch (e) {
      debugPrint('[NewsService] openVideo error: $e');
      return false;
    }
  }

  /// Query YouTube via official YouTube Data API v3 (or direct YouTube search client)
  Future<List<NewsVideo>> _queryYouTube({
    required String query,
    required String country,
    required String language,
    required String category,
    String? ticker,
    String? companyName,
  }) async {
    // 1. Check if official YouTube API Key is configured
    final apiKey = await ApiConfig.getYoutubeApiKey();
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final results = await _callYouTubeDataApiV3(
          apiKey: apiKey.trim(),
          query: query,
          country: country,
          language: language,
          category: category,
          ticker: ticker,
          companyName: companyName,
        );
        if (results.isNotEmpty) return results;
      } catch (e) {
        debugPrint('[NewsService] Official YouTube Data API v3 failed, falling back: $e');
      }
    }

    // 2. Direct YouTube Web Client Search API
    return await _callYouTubeSearchClient(
      query: query,
      country: country,
      language: language,
      category: category,
      ticker: ticker,
      companyName: companyName,
    );
  }

  /// Official YouTube Data API v3 (`https://www.googleapis.com/youtube/v3/search`)
  Future<List<NewsVideo>> _callYouTubeDataApiV3({
    required String apiKey,
    required String query,
    required String country,
    required String language,
    required String category,
    String? ticker,
    String? companyName,
  }) async {
    final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90)).toUtc().toIso8601String();

    final uri = Uri.https('www.googleapis.com', '/youtube/v3/search', {
      'part': 'snippet',
      'q': query,
      'type': 'video',
      'maxResults': '20',
      'order': 'relevance',
      'regionCode': country.toUpperCase(),
      'relevanceLanguage': language.toLowerCase(),
      'publishedAfter': ninetyDaysAgo,
      'key': apiKey,
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      final videos = <NewsVideo>[];

      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final idMap = item['id'] as Map<String, dynamic>?;
        final videoId = idMap?['videoId'] as String?;
        if (videoId == null || videoId.isEmpty) continue;

        final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
        final title = snippet['title'] as String? ?? '';
        final channelTitle = snippet['channelTitle'] as String? ?? '';
        final publishedAt = snippet['publishedAt'] as String? ?? '';
        final description = snippet['description'] as String? ?? '';
        final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
        final highThumb = thumbnails['high']?['url'] as String? ??
            thumbnails['medium']?['url'] as String? ??
            'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

        final isVerified = TrustedNewsSources.isTrustedSource(channelTitle, country);

        videos.add(NewsVideo(
          id: videoId,
          title: _cleanHtmlEntities(title),
          channelTitle: channelTitle,
          publishedAt: _formatPublishedDate(publishedAt, language),
          description: _cleanHtmlEntities(description),
          thumbnailUrl: highThumb,
          videoUrl: 'https://www.youtube.com/watch?v=$videoId',
          country: country,
          ticker: ticker,
          companyName: companyName,
          isVerifiedSource: isVerified,
          category: category,
        ));
      }
      return videos;
    } else {
      throw Exception('YouTube Data API v3 error ${res.statusCode}: ${res.body}');
    }
  }

  /// Direct YouTube Client Search API
  Future<List<NewsVideo>> _callYouTubeSearchClient({
    required String query,
    required String country,
    required String language,
    required String category,
    String? ticker,
    String? companyName,
  }) async {
    final uri = Uri.parse('https://www.youtube.com/youtubei/v1/search?prettyPrint=false');

    final body = json.encode({
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20240101.00.00',
          'hl': language,
          'gl': country.toUpperCase(),
        }
      },
      'query': query,
    });

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      body: body,
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return [];

    final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final contents = data['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents'] as List<dynamic>?;
    if (contents == null || contents.isEmpty) return [];

    final videos = <NewsVideo>[];

    for (final section in contents) {
      if (section is! Map<String, dynamic>) continue;
      final itemSection = section['itemSectionRenderer']?['contents'] as List<dynamic>?;
      if (itemSection == null) continue;

      for (final item in itemSection) {
        if (item is! Map<String, dynamic>) continue;
        final v = item['videoRenderer'] as Map<String, dynamic>?;
        if (v == null) continue;

        final videoId = v['videoId'] as String?;
        if (videoId == null || videoId.isEmpty) continue;

        // Title
        var title = '';
        final titleRuns = v['title']?['runs'] as List<dynamic>?;
        if (titleRuns != null && titleRuns.isNotEmpty) {
          title = titleRuns.map((r) => r['text'] ?? '').join('');
        }

        // Channel
        var channelTitle = '';
        final ownerRuns = v['ownerText']?['runs'] as List<dynamic>?;
        if (ownerRuns != null && ownerRuns.isNotEmpty) {
          channelTitle = ownerRuns.map((r) => r['text'] ?? '').join('');
        }

        // Published time
        final published = v['publishedTimeText']?['simpleText'] as String? ?? '';

        // Description
        var description = '';
        final descSnippets = v['detailedMetadataSnippets'] as List<dynamic>?;
        if (descSnippets != null && descSnippets.isNotEmpty) {
          final runs = descSnippets[0]?['snippetText']?['runs'] as List<dynamic>?;
          if (runs != null) {
            description = runs.map((r) => r['text'] ?? '').join('');
          }
        }
        if (description.isEmpty) {
          final runs = v['descriptionSnippet']?['runs'] as List<dynamic>?;
          if (runs != null) {
            description = runs.map((r) => r['text'] ?? '').join('');
          }
        }

        // Thumbnail
        var thumbUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
        final thumbList = v['thumbnail']?['thumbnails'] as List<dynamic>?;
        if (thumbList != null && thumbList.isNotEmpty) {
          final last = thumbList.last as Map<String, dynamic>?;
          if (last?['url'] != null) {
            thumbUrl = last!['url'] as String;
          }
        }

        final isVerified = TrustedNewsSources.isTrustedSource(channelTitle, country);

        videos.add(NewsVideo(
          id: videoId,
          title: _cleanHtmlEntities(title),
          channelTitle: channelTitle,
          publishedAt: published.isNotEmpty ? published : 'Recent',
          description: _cleanHtmlEntities(description),
          thumbnailUrl: thumbUrl,
          videoUrl: 'https://www.youtube.com/watch?v=$videoId',
          country: country,
          ticker: ticker,
          companyName: companyName,
          isVerifiedSource: isVerified,
          category: category,
        ));
      }
    }

    return videos;
  }

  String _buildMarketQuery({
    required String country,
    required String category,
    required String language,
  }) {
    final cUpper = country.toUpperCase();

    if (cUpper == 'KR') {
      switch (category) {
        case 'company':
          return '한국 주요 상장 기업 실적 주가 뉴스 한국경제TV 연합뉴스TV';
        case 'event':
          return '한국은행 금리 환율 코스피 증시 주요 이슈 뉴스 SBS Biz';
        case 'market':
        default:
          return '오늘 코스피 코스닥 마감 시황 증시 주식 뉴스 한국경제TV';
      }
    } else if (cUpper == 'US') {
      switch (category) {
        case 'company':
          return 'Wall Street tech earnings big tech stocks CNBC Bloomberg';
        case 'event':
          return 'Federal Reserve interest rate inflation CPI FOMC market news Reuters';
        case 'market':
        default:
          return 'Stock market today S&P 500 Nasdaq Dow closing bell CNBC Bloomberg';
      }
    } else if (cUpper == 'JP') {
      switch (category) {
        case 'company':
          return '日本 企業 決算 業績 株価 日経 テレ東BIZ';
        case 'event':
          return '日銀 金利 円安 円高 景気 金融政策 ニュース';
        case 'market':
        default:
          return '日経平均 株価 東証 市況 ニュース 日本経済新聞';
      }
    } else if (cUpper == 'DE') {
      switch (category) {
        case 'company':
          return 'DAX Unternehmen Quartalszahlen Aktien Wirtschaft Handelsblatt';
        case 'event':
          return 'EZB Zinsen Inflation Finanzpolitik Börse tagesschau';
        case 'market':
        default:
          return 'DAX Börsenbericht Aktienmarkt Frankfurt ntv Nachrichten';
      }
    } else if (cUpper == 'GB') {
      switch (category) {
        case 'company':
          return 'FTSE 100 corporate earnings business news Financial Times';
        case 'event':
          return 'Bank of England interest rate inflation economy BBC News';
        case 'market':
        default:
          return 'London Stock Exchange FTSE market report Reuters UK';
      }
    } else if (cUpper == 'FR') {
      switch (category) {
        case 'company':
          return 'CAC 40 entreprises résultats boursiers BFM Business';
        case 'event':
          return 'Banque centrale BCE taux inflation économie France Info';
        case 'market':
        default:
          return 'Bourse de Paris CAC 40 actualité marchés Les Echos';
      }
    } else {
      switch (category) {
        case 'company':
          return 'Global stock earnings market news Bloomberg Reuters';
        case 'event':
          return 'Global central bank interest rate inflation economic events CNBC';
        case 'market':
        default:
          return 'Global stock markets rally slump news Bloomberg';
      }
    }
  }

  String _cleanHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  String _formatPublishedDate(String dateStr, String language) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);

      if (language == 'ko') {
        if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
        if (diff.inHours < 24) return '${diff.inHours}시간 전';
        if (diff.inDays < 7) return '${diff.inDays}일 전';
        return '${dt.month}월 ${dt.day}일';
      } else if (language == 'ja') {
        if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
        if (diff.inHours < 24) return '${diff.inHours}時間前';
        if (diff.inDays < 7) return '${diff.inDays}日前';
        return '${dt.month}月${dt.day}日';
      } else {
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        if (diff.inDays < 7) return '${diff.inDays}d ago';
        return '${dt.month}/${dt.day}';
      }
    } catch (_) {
      return dateStr;
    }
  }
}

class _CachedNews {
  final List<NewsVideo> videos;
  final DateTime timestamp;

  _CachedNews({required this.videos, required this.timestamp});
}
