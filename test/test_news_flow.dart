import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_pulse_mobile/services/news_service.dart';
import 'package:trade_pulse_mobile/services/ai_service.dart';
import 'package:trade_pulse_mobile/data/trusted_news_sources.dart';
import 'package:trade_pulse_mobile/models/news_video.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  test('Test 1: Trusted News Sources Allowlist Validation', () {
    final krAllowed = TrustedNewsSources.isTrustedSource('한국경제TV', 'KR');
    final sbsBizAllowed = TrustedNewsSources.isTrustedSource('SBS Biz', 'KR');
    final cnbcAllowed = TrustedNewsSources.isTrustedSource('CNBC Television', 'US');
    final bloombergAllowed = TrustedNewsSources.isTrustedSource('Bloomberg Markets and Finance', 'US');
    final fakeChannel = TrustedNewsSources.isTrustedSource('Random Stock Moon Boy 1000x', 'KR');

    expect(krAllowed, isTrue);
    expect(sbsBizAllowed, isTrue);
    expect(cnbcAllowed, isTrue);
    expect(bloombergAllowed, isTrue);
    expect(fakeChannel, isFalse);
  });

  test('Test 2: Relevance Filter & Negative Keywords', () {
    final clickbaitNegative = TrustedNewsSources.hasNegativeKeywords(
      '이 주식 내일 1000배 폭등합니다 무조건 사세요',
      '설명',
    );
    expect(clickbaitNegative, isTrue);

    final isRelevantSamsung = TrustedNewsSources.isRelevantToCompany(
      title: '[속보] 삼성전자 실적 발표, 반도체 영업이익 5조원 돌파',
      description: '한국경제TV 속보 뉴스',
      companyName: 'Samsung Electronics',
      localName: '삼성전자',
      ticker: '005930.KS',
    );
    expect(isRelevantSamsung, isTrue);

    final isIrrelevantVideo = TrustedNewsSources.isRelevantToCompany(
      title: '제주도 브이로그 맛집 먹방 여행',
      description: 'vlog',
      companyName: 'Samsung Electronics',
      localName: '삼성전자',
      ticker: '005930.KS',
    );
    expect(isIrrelevantVideo, isFalse);
  });

  test('Test 3: Real Company News Fetch for Korean Company (Samsung Electronics)', () async {
    final samsungNews = await NewsService.instance.fetchCompanyNews(
      ticker: '005930.KS',
      companyName: 'Samsung Electronics',
      localName: '삼성전자',
      country: 'KR',
      language: 'ko',
    );

    expect(samsungNews, isNotEmpty);
    final first = samsungNews.first;
    expect(first.id, isNotEmpty);
    expect(first.title, isNotEmpty);
    expect(first.thumbnailUrl, isNotEmpty);
    expect(first.videoUrl, contains(first.id));
  });

  test('Test 4: Real Company News Fetch for US Company (NVIDIA / NVDA)', () async {
    final nvdaNews = await NewsService.instance.fetchCompanyNews(
      ticker: 'NVDA',
      companyName: 'NVIDIA Corporation',
      localName: '엔비디아',
      country: 'US',
      language: 'en',
    );

    expect(nvdaNews, isNotEmpty);
    final first = nvdaNews.first;
    expect(first.id, isNotEmpty);
    expect(first.title, isNotEmpty);
  });

  test('Test 5: Real Main News Feed (South Korea - Market News)', () async {
    final krMarketNews = await NewsService.instance.fetchMarketNews(
      country: 'KR',
      category: 'market',
      language: 'ko',
    );

    expect(krMarketNews, isNotEmpty);
    for (final v in krMarketNews) {
      expect(v.isVerifiedSource, isTrue, reason: 'Main news feed must strictly only include verified reputable sources');
    }
  });

  test('Test 6: Real Main News Feed (United States - Company News)', () async {
    final usCompanyNews = await NewsService.instance.fetchMarketNews(
      country: 'US',
      category: 'company',
      language: 'en',
    );

    expect(usCompanyNews, isNotEmpty);
    for (final v in usCompanyNews) {
      expect(v.isVerifiedSource, isTrue);
    }
  });

  test('Test 7: AI News Summary Behavior when transcript is unavailable', () async {
    final sampleVideoNoTranscript = NewsVideo(
      id: 'non_existent_or_no_sub_123',
      title: 'Test Live Broadcast Without Subtitles',
      channelTitle: '한국경제TV',
      publishedAt: '1시간 전',
      description: 'Live broadcast test',
      thumbnailUrl: '',
      videoUrl: 'https://www.youtube.com/watch?v=non_existent_or_no_sub_123',
      country: 'KR',
      isVerifiedSource: true,
    );

    final summaryResult = await AIService.instance.generateNewsSummary(
      video: sampleVideoNoTranscript,
      language: 'ko',
    );

    expect(summaryResult['status'], 'unavailable');
    expect(summaryResult['summary'], isNull);
    expect(summaryResult['reason'], isNotNull);
  });

  test('Test 8: Empty / Graceful Handling for non-existent company', () async {
    final emptyNews = await NewsService.instance.fetchCompanyNews(
      ticker: 'XYZ999NONEXISTENT',
      companyName: 'ZZZZZZNonExistentCompany99999999',
      country: 'US',
      language: 'en',
    );

    expect(emptyNews, isEmpty);
  });
}
