import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/news_video.dart';
import '../providers/app_provider.dart';
import '../data/api_config.dart';

class AIService {
  static final AIService instance = AIService._internal();
  AIService._internal();

  // Primary Gemini models in priority order
  static const List<String> _geminiModels = [
    'gemini-3.1-flash-lite',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];

  Future<String> askAI({
    required String query,
    required List<Map<String, String>> conversationHistory,
    required AppProvider provider,
  }) async {
    final lang = provider.activeLanguage;
    final user = provider.user;
    final portfolio = user?.portfolio ?? [];

    final portfolioContext = {
      'username': user?.username ?? 'Investor',
      'country': user?.country ?? 'KR',
      'displayCurrency': user?.displayCurrency ?? 'KRW',
      'cashUSD': user?.cashUSD ?? 0.0,
      'totalPortfolioUSD': provider.totalPortfolioValueUSD,
      'totalStockValueUSD': provider.totalStockValueUSD,
      'totalProfitLossUSD': provider.totalProfitLossUSD,
      'totalReturnPercent': provider.totalReturnPercent,
      'holdingsCount': portfolio.length,
      'holdings': portfolio.map((p) {
        final q = provider.getQuote(p.ticker);
        final curPrice = (q.price != null && q.price! > 0) ? q.price! : p.averagePrice;
        return {
          'ticker': p.ticker,
          'name': p.stockName,
          'shares': p.shares,
          'averagePrice': p.averagePrice,
          'currentPrice': curPrice,
          'currency': p.nativeCurrency,
          'totalCostUSD': p.totalCostUSD,
          'returnPercent': p.averagePrice > 0 ? ((curPrice - p.averagePrice) / p.averagePrice) * 100 : 0.0,
        };
      }).toList(),
      'watchlist': user?.watchlist ?? [],
      'recentTransactions': provider.transactions.take(8).map((t) => {
        'type': t.type,
        'ticker': t.ticker,
        'name': t.stockName,
        'shares': t.shares,
        'price': t.price,
        'currency': t.currency,
        'timestamp': t.timestamp,
      }).toList(),
    };

    final errorLog = <String>[];
    debugPrint('[AIService] === Starting AI Query ===');
    debugPrint('[AIService] Query: "$query" | Lang: $lang | Platform: ${kIsWeb ? "Web" : defaultTargetPlatform.name}');

    // 1. If running on Web, query the same-origin backend proxy
    if (kIsWeb) {
      try {
        final webResult = await _callServerProxy(
          endpoint: '/api/ai-chat',
          query: query,
          conversationHistory: conversationHistory,
          portfolioContext: portfolioContext,
          language: lang,
          timeout: const Duration(seconds: 12),
        );
        if (webResult != null && webResult.isNotEmpty) {
          debugPrint('[AIService] Web proxy succeeded.');
          return webResult;
        }
      } catch (e) {
        errorLog.add('Web proxy: $e');
        debugPrint('[AIService] Web proxy error: $e');
      }
    }

    // 2. If a custom backend URL is configured by the user, try it first
    final customUrl = await ApiConfig.getCustomBackendUrl();
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      final clean = customUrl.trim().endsWith('/') ? customUrl.trim().substring(0, customUrl.trim().length - 1) : customUrl.trim();
      final target = '$clean/api/ai-chat';
      try {
        debugPrint('[AIService] Trying custom backend: $target');
        final customResult = await _callServerProxy(
          endpoint: target,
          query: query,
          conversationHistory: conversationHistory,
          portfolioContext: portfolioContext,
          language: lang,
          timeout: const Duration(seconds: 5),
        );
        if (customResult != null && customResult.isNotEmpty) {
          debugPrint('[AIService] Custom backend succeeded.');
          return customResult;
        }
      } catch (e) {
        errorLog.add('Custom backend ($target): $e');
        debugPrint('[AIService] Custom backend error: $e');
      }
    }

    // 3. Direct Google Gemini REST API Client
    // Works reliably on any phone over standard HTTPS (Wi-Fi & Mobile 4G/5G data)
    debugPrint('[AIService] Calling direct Google Gemini Generative Language API...');
    try {
      final directResponse = await _callGeminiDirect(
        query: query,
        conversationHistory: conversationHistory,
        portfolioContext: portfolioContext,
        language: lang,
      );
      if (directResponse.isNotEmpty) {
        debugPrint('[AIService] Direct Gemini API call succeeded with length ${directResponse.length}');
        return directResponse;
      }
    } catch (e) {
      errorLog.add('Gemini Direct API: ${e.toString()}');
      debugPrint('[AIService] Direct Gemini API exception: $e');
    }

    // 4. Fallback check: If local emulator dev server is reachable
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        debugPrint('[AIService] Checking local Android emulator bridge (10.0.2.2:3000)...');
        final emuResult = await _callServerProxy(
          endpoint: 'http://10.0.2.2:3000/api/ai-chat',
          query: query,
          conversationHistory: conversationHistory,
          portfolioContext: portfolioContext,
          language: lang,
          timeout: const Duration(milliseconds: 1500),
        );
        if (emuResult != null && emuResult.isNotEmpty) {
          return emuResult;
        }
      } catch (e) {
        errorLog.add('Emulator bridge: $e');
      }
    }

    // If all connection channels failed, provide detailed diagnostic failure details
    final failureDetails = errorLog.join(' \n• ');
    debugPrint('[AIService] All AI connection channels failed:\n• $failureDetails');

    if (lang == 'ko') {
      return "⚠️ AI 어시스턴트 통신 오류\n\n서버 및 AI API 응답을 완료하지 못했습니다.\n\n[상세 진단 정보]\n• $failureDetails\n\n잠시 후 다시 질문해 주세요.";
    } else if (lang == 'ja') {
      return "⚠️ AIアシスタント通信エラー\n\nサーバーおよびAI APIから応答を受信できませんでした。\n\n[詳細診断情報]\n• $failureDetails\n\nしばらくしてから再度お試しください。";
    } else if (lang == 'de') {
      return "⚠️ KI-Assistent Kommunikationsfehler\n\nKeine Antwort vom Server oder der KI-API erhalten.\n\n[Diagnosedetails]\n• $failureDetails\n\nBitte versuchen Sie es in Kürze erneut.";
    } else if (lang == 'fr') {
      return "⚠️ Erreur de communication avec l'assistant IA\n\nImpossible de recevoir une réponse du serveur ou de l'API IA.\n\n[Détails du diagnostic]\n• $failureDetails\n\nVeuillez réessayer dans un instant.";
    } else {
      return "⚠️ AI Assistant Communication Error\n\nCould not receive a response from the AI service.\n\n[Diagnostic Details]\n• $failureDetails\n\nPlease try asking again in a moment.";
    }
  }

  // Server proxy call helper
  Future<String?> _callServerProxy({
    required String endpoint,
    required String query,
    required List<Map<String, String>> conversationHistory,
    required Map<String, dynamic> portfolioContext,
    required String language,
    required Duration timeout,
  }) async {
    final uri = Uri.parse(endpoint);
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'query': query,
        'history': conversationHistory,
        'portfolioContext': portfolioContext,
        'language': language,
      }),
    ).timeout(timeout);

    if (response.statusCode == 200) {
      final bodyStr = utf8.decode(response.bodyBytes).trim();
      if (bodyStr.startsWith('{') && bodyStr.endsWith('}')) {
        final data = json.decode(bodyStr);
        if (data['success'] == true && data['text'] != null) {
          final t = data['text'].toString().trim();
          if (t.isNotEmpty) return t;
        }
      }
      throw Exception('Server returned 200 with non-JSON or invalid body');
    } else if (response.statusCode == 302 || response.statusCode == 301) {
      throw Exception('HTTP ${response.statusCode} Redirect (Authentication cookie barrier)');
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body.take(100)}');
    }
  }

  // Direct Google Gemini REST API Client
  Future<String> _callGeminiDirect({
    required String query,
    required List<Map<String, String>> conversationHistory,
    required Map<String, dynamic> portfolioContext,
    required String language,
  }) async {
    final langName = language == 'ko'
        ? 'Korean (한국어)'
        : (language == 'ja'
            ? 'Japanese (日本語)'
            : (language == 'de'
                ? 'German (Deutsch)'
                : (language == 'fr' ? 'French (Français)' : 'English')));

    final systemInstructionText = """
You are Trade X AI (TradePulse), a professional, highly knowledgeable, factual, text-only stock market and portfolio advisor inside the Trade X mobile investment simulator.
CRITICAL OPERATIONAL RULES:
1. TEXT-ONLY: You must NEVER output image URLs, HTML image tags, Markdown image embeds, or offer to generate files/images.
2. CONTEXT-AWARE: If the user asks about their portfolio, holdings, cash, profits, or specific owned stocks, ALWAYS analyze and incorporate their actual live account data provided in the [PORTFOLIO CONTEXT].
3. DYNAMIC & INTELLIGENT: NEVER output static canned responses. Analyze the user's exact specific question, company names, tickers, financial concepts, or market situations.
4. FINANCIAL EDUCATION: Clearly explain technical metrics (P/E, Market Cap, EPS, Dividend Yield, Beta, Volume, RSI, DCA, Stop-Loss, Diversification Index).
5. LANGUAGE: Respond strictly in $langName with clear formatting, bullet points, and actionable educational insights.
6. DISCLAIMER: Always maintain an educational perspective without guaranteeing future profits or encouraging reckless trading.
""";

    final contents = <Map<String, dynamic>>[];

    // 1. Inject active portfolio context as first user turn
    contents.add({
      'role': 'user',
      'parts': [
        {'text': '[ACTIVE LIVE PORTFOLIO & ACCOUNT CONTEXT]:\n${json.encode(portfolioContext)}'}
      ],
    });
    contents.add({
      'role': 'model',
      'parts': [
        {'text': 'Understood. I have securely loaded your active portfolio, balance, holdings, and transaction context.'}
      ],
    });

    // 2. Add recent conversation history (last 6 turns, avoiding duplicates)
    final recentHistory = conversationHistory.length > 6
        ? conversationHistory.sublist(conversationHistory.length - 6)
        : conversationHistory;

    for (final item in recentHistory) {
      final role = item['role'] == 'model' ? 'model' : 'user';
      final text = (item['text'] ?? '').trim();
      // Skip if this history turn matches the query to prevent immediate repetition
      if (text.isNotEmpty && text != query.trim()) {
        contents.add({
          'role': role,
          'parts': [{'text': text}],
        });
      }
    }

    // 3. Add current query as final user turn
    contents.add({
      'role': 'user',
      'parts': [{'text': query.trim()}],
    });

    // Turn sanitization: Ensure strict role alternation (user <-> model)
    final sanitizedContents = <Map<String, dynamic>>[];
    for (final turn in contents) {
      if (sanitizedContents.isNotEmpty && sanitizedContents.last['role'] == turn['role']) {
        final existingText = (sanitizedContents.last['parts'] as List)[0]['text'] as String;
        final newText = (turn['parts'] as List)[0]['text'] as String;
        sanitizedContents.last['parts'] = [{'text': '$existingText\n\n$newText'}];
      } else {
        sanitizedContents.add(turn);
      }
    }

    // Must start with user role
    if (sanitizedContents.isNotEmpty && sanitizedContents.first['role'] == 'model') {
      sanitizedContents.removeAt(0);
    }

    final errors = <String>[];

    // Multi-model fallback
    for (final model in _geminiModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
        );

        debugPrint('[AIService] Calling Gemini API ($model)...');

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': ApiConfig.geminiApiKey,
          },
          body: json.encode({
            'systemInstruction': {
              'parts': [{'text': systemInstructionText}],
            },
            'contents': sanitizedContents,
            'generationConfig': {
              'temperature': 0.7,
            },
          }),
        ).timeout(const Duration(seconds: 12));

        debugPrint('[AIService] Gemini ($model) status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final textParts = <String>[];
              for (final p in parts) {
                if (p is Map<String, dynamic>) {
                  // Skip internal reasoning thoughts
                  if (p['thought'] == true) continue;
                  final t = p['text'] as String?;
                  if (t != null && t.trim().isNotEmpty) {
                    textParts.add(t.trim());
                  }
                }
              }
              if (textParts.isNotEmpty) {
                return textParts.join('\n\n');
              }
              // Fallback: Check if any part had text
              for (final p in parts) {
                if (p is Map<String, dynamic>) {
                  final t = p['text'] as String?;
                  if (t != null && t.trim().isNotEmpty) {
                    return t.trim();
                  }
                }
              }
            }
          }
          errors.add('$model: empty candidate parts in response');
        } else {
          final errorBody = utf8.decode(response.bodyBytes);
          errors.add('$model: HTTP ${response.statusCode} (${errorBody.take(80)})');
          debugPrint('[AIService] $model error response: $errorBody');
        }
      } catch (e) {
        errors.add('$model: ${e.toString()}');
        debugPrint('[AIService] $model request exception: $e');
      }
    }

    throw Exception(errors.isNotEmpty ? errors.join(', ') : 'All models failed to return content');
  }

  /// AI News Summary: Summarizes real news video transcripts strictly factually.
  /// If captions/transcripts are unavailable, explicitly states this without fabricating information.
  Future<Map<String, dynamic>> generateNewsSummary({
    required NewsVideo video,
    required String language,
  }) async {
    // 1. Attempt to fetch genuine caption/transcript
    final transcript = await fetchVideoTranscript(video.id);

    if (transcript == null || transcript.trim().isEmpty) {
      final msg = language == 'ko'
          ? '자막 정보 없음: 이 영상은 공식 텍스트 자막(Closed Captions)이 제공되지 않아 허위 정보 생성을 방지하기 위해 AI 요약을 생성하지 않습니다.'
          : (language == 'ja'
              ? '字幕利用不可: この動画には公式字幕が提供されていないため、不正確な推測を防ぐ目的でAI要約を生成しません。'
              : 'Transcript unavailable: Closed captions or an official transcript are not provided for this news video. In compliance with strict news verification standards, Trade X AI does not generate speculative or unverified summaries.');
      return {
        'status': 'unavailable',
        'summary': null,
        'reason': msg,
      };
    }

    // 2. We have a verified transcript — generate concise, factual bullet points using Gemini
    final langName = language == 'ko'
        ? 'Korean (한국어)'
        : (language == 'ja'
            ? 'Japanese (日本語)'
            : (language == 'de'
                ? 'German (Deutsch)'
                : (language == 'fr' ? 'French (Français)' : 'English')));

    final prompt = """
You are Trade X AI, a factual financial news analyst.
Task: Summarize the following news report transcript into 2-3 concise, bullet-pointed key takeaways.
STRICT COMPLIANCE RULES:
1. Summarize ONLY facts explicitly stated in the transcript below.
2. Do NOT extrapolate, speculate, give personal investment advice, or introduce external knowledge.
3. Language: Respond strictly in $langName.
4. Output format: Start each point with '• '. Do not include conversational greetings.

NEWS REPORT TITLE: ${video.title}
NEWS CHANNEL: ${video.channelTitle}
TRANSCRIPT:
${transcript.take(2500)}
""";

    for (final model in _geminiModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
        );

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': ApiConfig.geminiApiKey,
          },
          body: json.encode({
            'contents': [
              {
                'role': 'user',
                'parts': [{'text': prompt}],
              }
            ],
            'generationConfig': {
              'temperature': 0.2,
            },
          }),
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              for (final p in parts) {
                if (p is Map<String, dynamic> && p['thought'] != true) {
                  final t = p['text'] as String?;
                  if (t != null && t.trim().isNotEmpty) {
                    return {
                      'status': 'success',
                      'summary': t.trim(),
                      'reason': null,
                    };
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[AIService] News summary $model error: $e');
      }
    }

    final busyMsg = language == 'ko'
        ? 'AI 요약 생성 서비스에 일시적인 지연이 발생했습니다. 잠시 후 다시 시도해주세요.'
        : 'AI summary service is temporarily busy. Please try again shortly.';
    return {
      'status': 'error',
      'summary': null,
      'reason': busyMsg,
    };
  }

  /// Extracts genuine caption/transcript text from YouTube video
  Future<String?> fetchVideoTranscript(String videoId) async {
    try {
      final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
      final res = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9,ko;q=0.8',
      }).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return null;
      final html = res.body;

      final captionMatch = RegExp(r'"captionTracks":(\[.*?\])').firstMatch(html);
      if (captionMatch != null) {
        final rawJson = captionMatch.group(1);
        if (rawJson != null) {
          final tracks = json.decode(rawJson) as List<dynamic>;
          if (tracks.isNotEmpty) {
            String? trackUrl;
            for (final t in tracks) {
              if (t is Map<String, dynamic> && t['baseUrl'] != null) {
                trackUrl = t['baseUrl'] as String;
                break;
              }
            }
            if (trackUrl != null && trackUrl.isNotEmpty) {
              final capRes = await http.get(Uri.parse(trackUrl)).timeout(const Duration(seconds: 5));
              if (capRes.statusCode == 200 && capRes.body.isNotEmpty) {
                final textMatches = RegExp(r'<text[^>]*>(.*?)</text>', dotAll: true).allMatches(capRes.body);
                if (textMatches.isNotEmpty) {
                  final lines = textMatches.map((m) {
                    var s = m.group(1) ?? '';
                    s = s.replaceAll('&amp;', '&')
                         .replaceAll('&lt;', '<')
                         .replaceAll('&gt;', '>')
                         .replaceAll('&quot;', '"')
                         .replaceAll('&#39;', "'");
                    return s.trim();
                  }).where((s) => s.isNotEmpty).toList();
                  if (lines.isNotEmpty) {
                    return lines.join(' ');
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AIService] fetchVideoTranscript error: $e');
    }
    return null;
  }
}

extension StringTakeExtension on String {
  String take(int n) {
    if (length <= n) return this;
    return substring(0, n);
  }
}
