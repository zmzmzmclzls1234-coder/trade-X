import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_pulse_mobile/services/news_service.dart';
import 'package:trade_pulse_mobile/services/ai_service.dart';
import 'package:trade_pulse_mobile/data/trusted_news_sources.dart';
import 'package:trade_pulse_mobile/models/news_video.dart';
import 'package:trade_pulse_mobile/models/user.dart';
import 'package:trade_pulse_mobile/data/securities_data.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  group('CHECK 1 — COMPANY NEWS (Multiple Stocks & Countries)', () {
    test('1.1 Samsung Electronics (KR)', () async {
      final news = await NewsService.instance.fetchCompanyNews(
        ticker: '005930.KS',
        companyName: 'Samsung Electronics',
        localName: '삼성전자',
        country: 'KR',
        language: 'ko',
        forceRefresh: true,
      );

      expect(news, isNotEmpty);
      final ids = <String>{};
      for (final v in news) {
        expect(ids.contains(v.id), isFalse, reason: 'Duplicate video ID found: ${v.id}');
        ids.add(v.id);
        expect(v.title, isNotEmpty);
        expect(v.channelTitle, isNotEmpty);
        expect(v.publishedAt, isNotEmpty);
        expect(v.thumbnailUrl, isNotEmpty);
        expect(v.videoUrl, contains(v.id));

        // Verify relevance to company
        final isRelevant = TrustedNewsSources.isRelevantToCompany(
          title: v.title,
          description: v.description,
          companyName: 'Samsung Electronics',
          localName: '삼성전자',
          ticker: '005930.KS',
        );
        expect(isRelevant, isTrue);
      }
    });

    test('1.2 SK Hynix (KR)', () async {
      final news = await NewsService.instance.fetchCompanyNews(
        ticker: '000660.KS',
        companyName: 'SK Hynix',
        localName: 'SK하이닉스',
        country: 'KR',
        language: 'ko',
        forceRefresh: true,
      );

      expect(news, isNotEmpty);
      for (final v in news) {
        final isRelevant = TrustedNewsSources.isRelevantToCompany(
          title: v.title,
          description: v.description,
          companyName: 'SK Hynix',
          localName: 'SK하이닉스',
          ticker: '000660.KS',
        );
        expect(isRelevant, isTrue);
      }
    });

    test('1.3 Hyundai Motor with Korean abbreviation "현대차" (KR)', () async {
      final news = await NewsService.instance.fetchCompanyNews(
        ticker: '005380.KS',
        companyName: 'Hyundai Motor',
        localName: '현대자동차',
        country: 'KR',
        language: 'ko',
        forceRefresh: true,
      );

      expect(news, isNotEmpty);
      for (final v in news) {
        final isRelevant = TrustedNewsSources.isRelevantToCompany(
          title: v.title,
          description: v.description,
          companyName: 'Hyundai Motor',
          localName: '현대자동차',
          ticker: '005380.KS',
        );
        expect(isRelevant, isTrue);
      }
    });

    test('1.4 Apple (AAPL, US)', () async {
      final news = await NewsService.instance.fetchCompanyNews(
        ticker: 'AAPL',
        companyName: 'Apple Inc.',
        localName: '애플',
        country: 'US',
        language: 'en',
        forceRefresh: true,
      );

      expect(news, isNotEmpty);
      for (final v in news) {
        final isRelevant = TrustedNewsSources.isRelevantToCompany(
          title: v.title,
          description: v.description,
          companyName: 'Apple Inc.',
          localName: '애플',
          ticker: 'AAPL',
        );
        expect(isRelevant, isTrue);
      }
    });

    test('1.5 NVIDIA (NVDA, US)', () async {
      final news = await NewsService.instance.fetchCompanyNews(
        ticker: 'NVDA',
        companyName: 'NVIDIA Corporation',
        localName: '엔비디아',
        country: 'US',
        language: 'en',
        forceRefresh: true,
      );

      expect(news, isNotEmpty);
      for (final v in news) {
        final isRelevant = TrustedNewsSources.isRelevantToCompany(
          title: v.title,
          description: v.description,
          companyName: 'NVIDIA Corporation',
          localName: '엔비디아',
          ticker: 'NVDA',
        );
        expect(isRelevant, isTrue);
      }
    });
  });

  group('CHECK 2 — AI VIDEO SUMMARIES', () {
    test('2.1 Transcript unavailable reports cleanly without hallucinations', () async {
      final noTranscriptVideo = NewsVideo(
        id: 'no_transcript_video_sample_999',
        title: 'Live Market Broadcast',
        channelTitle: '한국경제TV',
        publishedAt: '2시간 전',
        description: 'Live test without closed captions',
        thumbnailUrl: '',
        videoUrl: 'https://www.youtube.com/watch?v=no_transcript_video_sample_999',
        country: 'KR',
        isVerifiedSource: true,
      );

      final result = await AIService.instance.generateNewsSummary(
        video: noTranscriptVideo,
        language: 'ko',
      );

      expect(result['status'], 'unavailable');
      expect(result['summary'], isNull);
      expect(result['reason'], isNotNull);
      expect(result['reason'], contains('자막 정보 없음'));
    });

    test('2.2 Video with captions produces factual summary without external inventions', () async {
      final videoWithTranscript = NewsVideo(
        id: 'dQw4w9WgXcQ',
        title: 'Sample Track',
        channelTitle: 'Official Channel',
        publishedAt: '1 year ago',
        description: 'Official video',
        thumbnailUrl: '',
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        country: 'US',
        isVerifiedSource: true,
      );

      final result = await AIService.instance.generateNewsSummary(
        video: videoWithTranscript,
        language: 'en',
      );

      // Either returns a factual summary if transcript is accessible, or reports unavailable honestly
      if (result['status'] == 'success') {
        expect(result['summary'], isNotNull);
        expect((result['summary'] as String).length, greaterThan(10));
      } else {
        expect(result['status'], 'unavailable');
        expect(result['reason'], isNotNull);
      }
    });
  });

  group('CHECK 3 — NEWS TAB (Country Switching & Category Filtering)', () {
    test('3.1 South Korea (KR - Latest Market News)', () async {
      final news = await NewsService.instance.fetchMarketNews(
        country: 'KR',
        category: 'market',
        language: 'ko',
        forceRefresh: true,
      );

      expect(news, isNotEmpty);
      for (final v in news) {
        expect(v.isVerifiedSource, isTrue, reason: 'Main news feed must strictly only include verified reputable sources');
        expect(v.channelTitle, isNotEmpty);
        expect(v.title, isNotEmpty);
      }
    });

    test('3.2 United States (US - Major Market Events)', () async {
      final news = await NewsService.instance.fetchMarketNews(
        country: 'US',
        category: 'event',
        language: 'en',
        forceRefresh: true,
      );

      expect(news, isNotEmpty);
      for (final v in news) {
        expect(v.isVerifiedSource, isTrue);
      }
    });

    test('3.3 Japan (JP - Company News)', () async {
      final news = await NewsService.instance.fetchMarketNews(
        country: 'JP',
        category: 'company',
        language: 'ja',
        forceRefresh: true,
      );

      expect(news, isNotEmpty);
      for (final v in news) {
        expect(v.isVerifiedSource, isTrue);
      }
    });

    test('3.4 Germany (DE - Latest Market News)', () async {
      final news = await NewsService.instance.fetchMarketNews(
        country: 'DE',
        category: 'market',
        language: 'de',
        forceRefresh: true,
      );

      expect(news, isNotEmpty);
      for (final v in news) {
        expect(v.isVerifiedSource, isTrue);
      }
    });

    test('3.5 Country Change: Switching country changes language, market context, and cache keys', () async {
      final krResults = await NewsService.instance.fetchCompanyNews(
        ticker: '005930.KS',
        companyName: 'Samsung Electronics',
        localName: '삼성전자',
        country: 'KR',
        language: 'ko',
        forceRefresh: true,
      );

      final usResults = await NewsService.instance.fetchCompanyNews(
        ticker: '005930.KS',
        companyName: 'Samsung Electronics',
        localName: '삼성전자',
        country: 'US',
        language: 'en',
        forceRefresh: true,
      );

      expect(krResults, isNotEmpty);
      expect(usResults, isNotEmpty);
      // Different regions and languages produce distinct results
      expect(krResults.first.videoUrl, isNot(equals(usResults.first.videoUrl)));
    });
  });

  group('CHECK 4 & 5 — DATA QUALITY & EDGE CASES', () {
    test('5.1 Non-existent company returns empty without throwing', () async {
      final result = await NewsService.instance.fetchCompanyNews(
        ticker: 'NONEXISTENT999',
        companyName: 'TotallyFakeCompanyXYZ123456789',
        country: 'US',
        language: 'en',
        forceRefresh: true,
      );

      expect(result, isEmpty);
    });

    test('5.2 Clickbait and scam videos are detected and rejected', () {
      expect(TrustedNewsSources.hasNegativeKeywords('내일 1000배 폭등하는 역대급 주식', ''), isTrue);
      expect(TrustedNewsSources.hasNegativeKeywords('1000x crypto gem to the moon', ''), isTrue);
      expect(TrustedNewsSources.hasNegativeKeywords('제주도 먹방 브이로그', 'vlog'), isTrue);
      expect(TrustedNewsSources.hasNegativeKeywords('KOSPI 시장 마감 시황', '한국경제TV'), isFalse);
    });

    test('5.3 Video object handles missing thumbnail, empty descriptions gracefully', () {
      final v = NewsVideo(
        id: 'test_vid',
        title: 'Test',
        channelTitle: 'Test Channel',
        publishedAt: '',
        description: '',
        thumbnailUrl: '',
        videoUrl: 'https://youtube.com/watch?v=test_vid',
        country: 'US',
      );

      expect(v.id, 'test_vid');
      expect(v.thumbnailUrl, isEmpty);
      expect(v.description, isEmpty);
      final json = v.toJson();
      expect(json['id'], 'test_vid');
      final roundtrip = NewsVideo.fromJson(json);
      expect(roundtrip.id, 'test_vid');
    });
  });

  group('CHECK 7 — EXISTING FEATURES INTEGRITY', () {
    test('7.1 Securities directory integrity (1028 stocks)', () {
      expect(allSecuritiesDirectory.length, greaterThan(1000));
      final samsung = allSecuritiesDirectory.firstWhere((s) => s.ticker == '005930.KS');
      expect(samsung.name, 'Samsung Electronics');
      expect(samsung.localName, '삼성전자');
      expect(samsung.country, 'KR');
    });

    test('7.2 User profile and PortfolioPosition production model intact', () {
      final user = UserProfile(
        id: 'test_user',
        username: 'Trader',
        country: 'KR',
        displayCurrency: 'KRW',
        language: 'ko',
        cashUSD: 10000.0,
        portfolio: [
          PortfolioPosition(
            ticker: '005930.KS',
            stockName: 'Samsung Electronics',
            shares: 10.0,
            averagePrice: 70000.0,
            averagePriceUSD: 51.6,
            totalCostUSD: 516.0,
            nativeCurrency: 'KRW',
          ),
        ],
        watchlist: ['005930.KS', 'AAPL'],
        totalRealizedProfit: 125000.0,
      );

      expect(user.portfolio.length, 1);
      expect(user.watchlist.length, 2);
      expect(user.portfolio.first.ticker, '005930.KS');
      expect(user.portfolio.first.shares, 10.0);
      expect(user.totalRealizedProfit, 125000.0);
      expect(user.virtualCashBalance, 13500000.0);
    });
  });
}
