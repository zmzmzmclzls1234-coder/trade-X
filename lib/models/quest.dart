import 'package:flutter/material.dart';

enum QuestCategory {
  profit,
  portfolio,
  consistency,
  daily,
}

enum QuestDifficulty {
  easy,
  medium,
  hard,
}

enum QuestStatus {
  locked,
  inProgress,
  completed,
  claimed,
}

class QuestItem {
  final String id;
  final QuestCategory category;
  final QuestDifficulty difficulty;
  final String title;
  final String titleKo;
  final String description;
  final String descriptionKo;
  final int rewardKRW;
  final double targetValue;
  final double currentValue;
  final String unit;
  final QuestStatus status;
  final DateTime? claimedAt;
  final bool isDaily;
  final IconData icon;

  const QuestItem({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.title,
    required this.titleKo,
    required this.description,
    required this.descriptionKo,
    required this.rewardKRW,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.status,
    this.claimedAt,
    this.isDaily = false,
    required this.icon,
  });

  bool get isClaimed => status == QuestStatus.claimed;
  bool get isCompleted => status == QuestStatus.completed || status == QuestStatus.claimed;
  bool get canClaim => status == QuestStatus.completed;

  double get progressRatio {
    if (targetValue <= 0) return 0.0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  String getLocalizedTitle(String lang) => lang == 'ko' ? titleKo : title;
  String getLocalizedDescription(String lang) => lang == 'ko' ? descriptionKo : description;

  QuestItem copyWith({
    String? id,
    QuestCategory? category,
    QuestDifficulty? difficulty,
    String? title,
    String? titleKo,
    String? description,
    String? descriptionKo,
    int? rewardKRW,
    double? targetValue,
    double? currentValue,
    String? unit,
    QuestStatus? status,
    DateTime? claimedAt,
    bool? isDaily,
    IconData? icon,
  }) {
    return QuestItem(
      id: id ?? this.id,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      title: title ?? this.title,
      titleKo: titleKo ?? this.titleKo,
      description: description ?? this.description,
      descriptionKo: descriptionKo ?? this.descriptionKo,
      rewardKRW: rewardKRW ?? this.rewardKRW,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      claimedAt: claimedAt ?? this.claimedAt,
      isDaily: isDaily ?? this.isDaily,
      icon: icon ?? this.icon,
    );
  }
}

class QuestClaimRecord {
  final String id;
  final String questId;
  final String questTitle;
  final int rewardKRW;
  final String timestamp;

  const QuestClaimRecord({
    required this.id,
    required this.questId,
    required this.questTitle,
    required this.rewardKRW,
    required this.timestamp,
  });

  factory QuestClaimRecord.fromJson(Map<String, dynamic> json) {
    return QuestClaimRecord(
      id: json['id'] ?? '',
      questId: json['questId'] ?? '',
      questTitle: json['questTitle'] ?? '',
      rewardKRW: (json['rewardKRW'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'questId': questId,
    'questTitle': questTitle,
    'rewardKRW': rewardKRW,
    'timestamp': timestamp,
  };
}

class QuestStreakState {
  final int currentStreak;
  final int longestStreak;
  final String? lastCompletionDate;
  final List<String> completedDates;
  final int totalClaimedRewardsKRW;
  final Set<String> claimedQuestIds;
  final List<QuestClaimRecord> claimHistory;

  const QuestStreakState({
    required this.currentStreak,
    required this.longestStreak,
    this.lastCompletionDate,
    required this.completedDates,
    required this.totalClaimedRewardsKRW,
    required this.claimedQuestIds,
    required this.claimHistory,
  });

  factory QuestStreakState.initial() {
    return const QuestStreakState(
      currentStreak: 0,
      longestStreak: 0,
      lastCompletionDate: null,
      completedDates: [],
      totalClaimedRewardsKRW: 0,
      claimedQuestIds: {},
      claimHistory: [],
    );
  }

  factory QuestStreakState.fromJson(Map<String, dynamic> json) {
    final rawDates = json['completedDates'] as List? ?? [];
    final rawClaimed = json['claimedQuestIds'] as List? ?? [];
    final rawHistory = json['claimHistory'] as List? ?? [];

    return QuestStreakState(
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastCompletionDate: json['lastCompletionDate'] as String?,
      completedDates: rawDates.map((e) => e.toString()).toList(),
      totalClaimedRewardsKRW: (json['totalClaimedRewardsKRW'] as num?)?.toInt() ?? 0,
      claimedQuestIds: rawClaimed.map((e) => e.toString()).toSet(),
      claimHistory: rawHistory.map((e) => QuestClaimRecord.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastCompletionDate': lastCompletionDate,
    'completedDates': completedDates,
    'totalClaimedRewardsKRW': totalClaimedRewardsKRW,
    'claimedQuestIds': claimedQuestIds.toList(),
    'claimHistory': claimHistory.map((e) => e.toJson()).toList(),
  };

  QuestStreakState copyWith({
    int? currentStreak,
    int? longestStreak,
    String? lastCompletionDate,
    List<String>? completedDates,
    int? totalClaimedRewardsKRW,
    Set<String>? claimedQuestIds,
    List<QuestClaimRecord>? claimHistory,
  }) {
    return QuestStreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCompletionDate: lastCompletionDate ?? this.lastCompletionDate,
      completedDates: completedDates ?? this.completedDates,
      totalClaimedRewardsKRW: totalClaimedRewardsKRW ?? this.totalClaimedRewardsKRW,
      claimedQuestIds: claimedQuestIds ?? this.claimedQuestIds,
      claimHistory: claimHistory ?? this.claimHistory,
    );
  }
}
