import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quest.dart';
import '../providers/app_provider.dart';
import '../i18n/translations.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  int _selectedCategoryIndex = 0; // 0: All, 1: Profit, 2: Portfolio, 3: Daily & Streak

  void _showClaimHistory(BuildContext context, AppProvider provider) {
    final lang = provider.activeLanguage;
    final streak = provider.questStreak;
    final history = streak.claimHistory;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, color: Color(0xFF38BDF8), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      AppTranslations.get('claimHistory', lang),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${history.length} records',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined, color: Color(0xFF64748B), size: 40),
                      const SizedBox(height: 10),
                      Text(
                        AppTranslations.get('noClaimHistory', lang),
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.monetization_on, color: Color(0xFF10B981), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.questTitle,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.timestamp,
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+₩${_formatNumber(item.rewardKRW)}',
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatNumber(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  String _formatProgressValue(QuestItem quest) {
    if (quest.unit == 'KRW') {
      return '₩${_formatNumber(quest.currentValue)} / ₩${_formatNumber(quest.targetValue)}';
    } else if (quest.unit == 'companies') {
      return '${quest.currentValue.toInt()} / ${quest.targetValue.toInt()} companies';
    } else if (quest.unit == 'markets') {
      return '${quest.currentValue.toInt()} / ${quest.targetValue.toInt()} markets';
    } else if (quest.unit == 'days') {
      return '${quest.currentValue.toInt()} / ${quest.targetValue.toInt()} days';
    }
    return '${quest.currentValue.toInt()} / ${quest.targetValue.toInt()}';
  }

  Color _getDifficultyColor(QuestDifficulty diff) {
    switch (diff) {
      case QuestDifficulty.easy:
        return const Color(0xFF10B981);
      case QuestDifficulty.medium:
        return const Color(0xFFF59E0B);
      case QuestDifficulty.hard:
        return const Color(0xFF8B5CF6);
    }
  }

  String _getDifficultyText(QuestDifficulty diff, String lang) {
    switch (diff) {
      case QuestDifficulty.easy:
        return lang == 'ko' ? '초급' : 'Easy';
      case QuestDifficulty.medium:
        return lang == 'ko' ? '중급' : 'Medium';
      case QuestDifficulty.hard:
        return lang == 'ko' ? '고급' : 'Hard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final lang = provider.activeLanguage;
    final allQuests = provider.quests;
    final streak = provider.questStreak;
    final claimableCount = provider.claimableQuestsCount;

    // Filter quests based on selected category tab
    final filteredQuests = allQuests.where((q) {
      if (_selectedCategoryIndex == 1) return q.category == QuestCategory.profit;
      if (_selectedCategoryIndex == 2) return q.category == QuestCategory.portfolio;
      if (_selectedCategoryIndex == 3) {
        return q.category == QuestCategory.consistency || q.category == QuestCategory.daily;
      }
      return true; // All
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          AppTranslations.get('quests', lang),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: AppTranslations.get('claimHistory', lang),
            icon: const Icon(Icons.history, color: Color(0xFF38BDF8)),
            onPressed: () => _showClaimHistory(context, provider),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Banner: Streak & Cumulative Rewards
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Streak Stat
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF090D16).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Color(0xFFF97316), size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${streak.currentStreak} ${AppTranslations.get('currentStreak', lang)}',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '${AppTranslations.get('longestStreak', lang)}: ${streak.longestStreak}d',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Cumulative Rewards Stat
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF090D16).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stars_rounded, color: Color(0xFF10B981), size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₩${_formatNumber(streak.totalClaimedRewardsKRW)}',
                                        style: const TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                      ),
                                      Text(
                                        AppTranslations.get('totalClaimed', lang),
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Virtual Reward Notice
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              AppTranslations.get('rewardVirtualNotice', lang),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Filter Tabs Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip(
                      index: 0,
                      label: AppTranslations.get('allQuests', lang),
                      badgeCount: claimableCount,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      index: 1,
                      label: AppTranslations.get('profitQuests', lang),
                      badgeCount: allQuests.where((q) => q.category == QuestCategory.profit && q.canClaim).length,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      index: 2,
                      label: AppTranslations.get('portfolioQuests', lang),
                      badgeCount: allQuests.where((q) => q.category == QuestCategory.portfolio && q.canClaim).length,
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryChip(
                      index: 3,
                      label: AppTranslations.get('dailyQuests', lang),
                      badgeCount: allQuests.where((q) => (q.category == QuestCategory.consistency || q.category == QuestCategory.daily) && q.canClaim).length,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Quest List
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: filteredQuests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final quest = filteredQuests[index];
                  return _buildQuestCard(context, provider, quest, lang);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({required int index, required String label, int badgeCount = 0}) {
    final isSelected = _selectedCategoryIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF10B981) : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestCard(BuildContext context, AppProvider provider, QuestItem quest, String lang) {
    final diffColor = _getDifficultyColor(quest.difficulty);
    final diffText = _getDifficultyText(quest.difficulty, lang);
    final ratio = quest.progressRatio;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: quest.canClaim
              ? const Color(0xFF10B981).withOpacity(0.5)
              : (quest.isClaimed ? const Color(0xFF1E293B) : const Color(0xFF1E293B)),
          width: quest.canClaim ? 1.5 : 1.0,
        ),
        boxShadow: quest.canClaim
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Difficulty Badge, Icon, Title, and Reward Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: diffColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(quest.icon, color: diffColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: diffColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            diffText,
                            style: TextStyle(color: diffColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (quest.isDaily) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DAILY',
                              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quest.getLocalizedTitle(lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Reward Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Text(
                  '+₩${_formatNumber(quest.rewardKRW)}',
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            quest.getLocalizedDescription(lang),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 14),

          // Progress Bar and Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatProgressValue(quest),
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                '${(ratio * 100).toInt()}%',
                style: TextStyle(
                  color: quest.isCompleted ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(
                quest.isClaimed
                    ? const Color(0xFF64748B)
                    : (quest.canClaim ? const Color(0xFF10B981) : diffColor),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(context, provider, quest, lang),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, AppProvider provider, QuestItem quest, String lang) {
    if (quest.isClaimed) {
      return OutlinedButton.icon(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF334155)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: const Icon(Icons.check_circle_outline, color: Color(0xFF64748B), size: 16),
        label: Text(
          AppTranslations.get('claimed', lang),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (quest.canClaim) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 11),
          elevation: 2,
        ),
        onPressed: () async {
          final result = await provider.claimQuestReward(quest.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.celebration, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        result.message,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: result.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        icon: const Icon(Icons.card_giftcard, size: 16),
        label: Text(
          '${AppTranslations.get('claimReward', lang)} (+₩${_formatNumber(quest.rewardKRW)})',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      );
    }

    // In Progress
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Center(
        child: Text(
          AppTranslations.get('inProgress', lang),
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
