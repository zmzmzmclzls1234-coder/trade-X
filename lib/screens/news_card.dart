import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/news_video.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../services/news_service.dart';

class NewsCard extends StatefulWidget {
  final NewsVideo video;
  final bool compact;

  const NewsCard({
    super.key,
    required this.video,
    this.compact = false,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  bool _isExpanded = false;
  bool _isLoadingSummary = false;
  String? _aiSummary;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _aiSummary = widget.video.aiSummary;
    _summaryError = widget.video.summaryUnavailableReason;
  }

  Future<void> _fetchAISummary() async {
    if (_aiSummary != null || _summaryError != null) {
      setState(() => _isExpanded = !_isExpanded);
      return;
    }

    setState(() {
      _isLoadingSummary = true;
      _isExpanded = true;
    });

    final provider = Provider.of<AppProvider>(context, listen: false);
    final lang = provider.activeLanguage;

    try {
      final res = await AIService.instance.generateNewsSummary(
        video: widget.video,
        language: lang,
      );

      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
          if (res['status'] == 'success') {
            _aiSummary = res['summary'] as String?;
            widget.video.aiSummary = _aiSummary;
          } else {
            _summaryError = res['reason'] as String?;
            widget.video.summaryUnavailableReason = _summaryError;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
          _summaryError = lang == 'ko'
              ? '요약 생성 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'
              : 'Failed to generate summary. Please try again later.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final lang = provider.activeLanguage;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.video.isVerifiedSource
              ? const Color(0xFF1E293B)
              : Colors.white.withOpacity(0.05),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Bar: Channel & Published time
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // News Channel badge (safely flexible)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.video.isVerifiedSource
                          ? const Color(0xFF0284C7).withOpacity(0.15)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.video.isVerifiedSource
                            ? const Color(0xFF38BDF8).withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.video.isVerifiedSource) ...[
                          const Icon(Icons.verified, size: 13, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            widget.video.channelTitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.video.isVerifiedSource
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF94A3B8),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Relative published time
                Text(
                  widget.video.publishedAt,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // 2. Middle Row: Thumbnail + Title & Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail with Play overlay
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      widget.video.thumbnailUrl.trim().isNotEmpty
                          ? Image.network(
                              widget.video.thumbnailUrl.trim(),
                              width: 100,
                              height: 65,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildThumbPlaceholder(),
                            )
                          : _buildThumbPlaceholder(),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Video Title and Short Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (widget.video.description.isNotEmpty)
                        Text(
                          widget.video.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Actions Row: AI Summary & Watch on YouTube
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                // AI Summary button
                InkWell(
                  onTap: _fetchAISummary,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withOpacity(0.2),
                          const Color(0xFF38BDF8).withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withOpacity(0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 13, color: Color(0xFFA78BFA)),
                        const SizedBox(width: 5),
                        Text(
                          _isLoadingSummary
                              ? (lang == 'ko' ? '요약 생성 중...' : 'Generating...')
                              : (lang == 'ko' ? 'AI 요약' : 'AI Summary'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA78BFA),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 14,
                          color: const Color(0xFFA78BFA),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Watch on YouTube button
                TextButton.icon(
                  onPressed: () => NewsService.instance.openVideo(widget.video.videoUrl),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 12, color: Color(0xFF38BDF8)),
                  label: Text(
                    lang == 'ko' ? '영상 보기' : 'Watch',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. AI Summary / Reason Expandable Panel
          if (_isExpanded)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF131C31),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _aiSummary != null
                      ? const Color(0xFF8B5CF6).withOpacity(0.3)
                      : const Color(0xFF334155),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _aiSummary != null ? Icons.auto_awesome : Icons.info_outline,
                        size: 14,
                        color: _aiSummary != null
                            ? const Color(0xFFA78BFA)
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _aiSummary != null
                            ? (lang == 'ko' ? 'AI 뉴스 요약 (Gemini)' : 'AI News Summary (Gemini)')
                            : (lang == 'ko' ? '요약 안내' : 'Notice'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _aiSummary != null
                              ? const Color(0xFFA78BFA)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_isLoadingSummary) ...[
                    const Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA78BFA)),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Analyzing video transcript factually...',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ] else if (_aiSummary != null) ...[
                    Text(
                      _aiSummary!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE2E8F0),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lang == 'ko'
                          ? '※ 원문 방송의 텍스트 자막에 기반하여 사실만을 요약했습니다.'
                          : '※ Factually summarized from the official video closed captions.',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                    ),
                  ] else if (_summaryError != null) ...[
                    Text(
                      _summaryError!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbPlaceholder() {
    return Container(
      width: 100,
      height: 65,
      color: const Color(0xFF1E293B),
      child: const Icon(Icons.video_library, color: Color(0xFF64748B), size: 24),
    );
  }
}
