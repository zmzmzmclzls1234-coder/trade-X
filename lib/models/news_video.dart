class NewsVideo {
  final String id;
  final String title;
  final String channelTitle;
  final String publishedAt;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final String country;
  final String? ticker;
  final String? companyName;
  final bool isVerifiedSource;
  final String category; // 'market', 'company', 'event'
  String? aiSummary;
  bool isSummaryLoading;
  String? summaryUnavailableReason;
  String? transcriptSnippet;

  NewsVideo({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.publishedAt,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.country,
    this.ticker,
    this.companyName,
    this.isVerifiedSource = false,
    this.category = 'market',
    this.aiSummary,
    this.isSummaryLoading = false,
    this.summaryUnavailableReason,
    this.transcriptSnippet,
  });

  factory NewsVideo.fromJson(Map<String, dynamic> json) {
    return NewsVideo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      channelTitle: json['channelTitle'] as String? ?? '',
      publishedAt: json['publishedAt'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? 'https://www.youtube.com/watch?v=${json['id']}',
      country: json['country'] as String? ?? 'KR',
      ticker: json['ticker'] as String?,
      companyName: json['companyName'] as String?,
      isVerifiedSource: json['isVerifiedSource'] as bool? ?? false,
      category: json['category'] as String? ?? 'market',
      aiSummary: json['aiSummary'] as String?,
      isSummaryLoading: json['isSummaryLoading'] as bool? ?? false,
      summaryUnavailableReason: json['summaryUnavailableReason'] as String?,
      transcriptSnippet: json['transcriptSnippet'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'channelTitle': channelTitle,
      'publishedAt': publishedAt,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'country': country,
      'ticker': ticker,
      'companyName': companyName,
      'isVerifiedSource': isVerifiedSource,
      'category': category,
      'aiSummary': aiSummary,
      'summaryUnavailableReason': summaryUnavailableReason,
      'transcriptSnippet': transcriptSnippet,
    };
  }

  NewsVideo copyWith({
    String? id,
    String? title,
    String? channelTitle,
    String? publishedAt,
    String? description,
    String? thumbnailUrl,
    String? videoUrl,
    String? country,
    String? ticker,
    String? companyName,
    bool? isVerifiedSource,
    String? category,
    String? aiSummary,
    bool? isSummaryLoading,
    String? summaryUnavailableReason,
    String? transcriptSnippet,
  }) {
    return NewsVideo(
      id: id ?? this.id,
      title: title ?? this.title,
      channelTitle: channelTitle ?? this.channelTitle,
      publishedAt: publishedAt ?? this.publishedAt,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      country: country ?? this.country,
      ticker: ticker ?? this.ticker,
      companyName: companyName ?? this.companyName,
      isVerifiedSource: isVerifiedSource ?? this.isVerifiedSource,
      category: category ?? this.category,
      aiSummary: aiSummary ?? this.aiSummary,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      summaryUnavailableReason: summaryUnavailableReason ?? this.summaryUnavailableReason,
      transcriptSnippet: transcriptSnippet ?? this.transcriptSnippet,
    );
  }
}
