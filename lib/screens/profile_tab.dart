import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../i18n/translations.dart';
import 'transactions_screen.dart';
import 'leaderboard_screen.dart';
import 'watchlist_tab.dart';
import 'currency_exchange_screen.dart';
import '../services/notification_service.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  void _showAlertHistorySheet(BuildContext context, AppProvider provider) {
    final lang = provider.activeLanguage;
    final alerts = provider.alerts;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Color(0xFF38BDF8), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppTranslations.get('alertHistory', lang),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (alerts.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          await provider.clearAlerts();
                          setModalState(() {});
                        },
                        child: Text(
                          AppTranslations.get('clearAlerts', lang),
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (alerts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.notifications_none, color: Color(0xFF64748B), size: 40),
                          const SizedBox(height: 8),
                          Text(
                            AppTranslations.get('noAlertsYet', lang),
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
                      itemCount: alerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: alert.isUp ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                alert.isUp ? Icons.arrow_upward : Icons.arrow_downward,
                                color: alert.isUp ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alert.message,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${alert.timestamp} • ${alert.timePeriod}',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontFamily: 'monospace'),
                                    ),
                                  ],
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
          );
        },
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context, AppProvider provider) {
    final lang = provider.activeLanguage;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppTranslations.get('selectCurrency', lang),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              {'code': 'KRW', 'nameKey': 'currKRW'},
              {'code': 'USD', 'nameKey': 'currUSD'},
              {'code': 'JPY', 'nameKey': 'currJPY'},
              {'code': 'EUR', 'nameKey': 'currEUR'},
              {'code': 'GBP', 'nameKey': 'currGBP'},
            ].map((c) {
              final isSel = provider.user?.displayCurrency == c['code'];
              final currLabel = AppTranslations.get(c['nameKey']!, lang);
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(
                  currLabel,
                  style: TextStyle(
                    color: isSel ? const Color(0xFF10B981) : Colors.white,
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSel ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20) : null,
                onTap: () {
                  provider.updateCurrency(c['code']!);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, AppProvider provider) {
    final lang = provider.activeLanguage;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppTranslations.get('selectLanguage', lang),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              {'code': 'ko', 'name': '한국어 (Korean)'},
              {'code': 'en', 'name': 'English (United States)'},
              {'code': 'ja', 'name': '日本語 (Japanese)'},
              {'code': 'de', 'name': 'Deutsch (German)'},
              {'code': 'fr', 'name': 'Français (French)'},
            ].map((l) {
              final isSel = provider.activeLanguage == l['code'];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(
                  l['name']!,
                  style: TextStyle(
                    color: isSel ? const Color(0xFF10B981) : Colors.white,
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSel ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20) : null,
                onTap: () {
                  provider.updateLanguage(l['code']!);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showResetConfirmDialog(BuildContext context, AppProvider provider) {
    final lang = provider.activeLanguage;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppTranslations.get('resetAccountTitle', lang),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppTranslations.get('resetAccountDesc', lang),
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppTranslations.get('cancel', lang), style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.resetAccount();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppTranslations.get('accountResetSuccess', provider.activeLanguage)),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: Text(AppTranslations.get('resetAccount', lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.user;
    final lang = provider.activeLanguage;

    final currKey = user?.displayCurrency == 'KRW'
        ? 'currKRW'
        : (user?.displayCurrency == 'USD'
            ? 'currUSD'
            : (user?.displayCurrency == 'JPY'
                ? 'currJPY'
                : (user?.displayCurrency == 'EUR' ? 'currEUR' : 'currGBP')));

    final langName = lang == 'ko'
        ? '한국어 (Korean)'
        : (lang == 'ja'
            ? '日本語 (Japanese)'
            : (lang == 'de'
                ? 'Deutsch (German)'
                : (lang == 'fr' ? 'Français (French)' : 'English (US)')));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.get('profile', lang),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // User Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    (user?.username.isNotEmpty ?? false) ? user!.username[0].toUpperCase() : 'I',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.username ?? AppTranslations.get('defaultInvestor', lang),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${user?.id ?? "investor_001"} • ${user?.country ?? "KR"}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Hourly Portfolio Alerts Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: Color(0xFF38BDF8), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppTranslations.get('hourlyAlerts', lang),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Switch(
                      value: provider.hourlyAlertsEnabled,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) async {
                        if (val) {
                          final granted = await NotificationService.instance.requestNotificationPermission();
                          if (!granted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(lang == 'ko'
                                    ? '실제 휴대폰 알림을 받으시려면 알림 권한을 허용해 주세요.'
                                    : 'Please allow notification permission to receive hourly updates.'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                        await provider.toggleHourlyAlerts(val);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val
                                  ? AppTranslations.get('alertsEnabled', lang)
                                  : AppTranslations.get('alertsDisabled', lang)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppTranslations.get('hourlyAlertsDesc', lang),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () async {
                          final enabled = await NotificationService.instance.areNotificationsEnabled();
                          if (!enabled) {
                            await NotificationService.instance.requestNotificationPermission();
                          }
                          final newAlerts = await provider.triggerHourlyAlert(forceTest: true);
                          if (context.mounted) {
                            if (newAlerts.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.notifications_active, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          lang == 'ko'
                                              ? '휴대폰 상단바에 실제 시스템 알림을 전송했습니다!'
                                              : 'Real system notification sent to your phone!',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppTranslations.get('noHoldings', lang)),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.send_outlined, size: 14, color: Color(0xFF38BDF8)),
                        label: Text(
                          AppTranslations.get('testAlert', lang),
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => _showAlertHistorySheet(context, provider),
                        icon: const Icon(Icons.history, size: 14, color: Colors.white70),
                        label: Text(
                          '${AppTranslations.get('alertHistory', lang)} (${provider.alerts.length})',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Navigation Card (Watchlist, Transactions, Leaderboard)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.star_outline,
                  iconColor: const Color(0xFFF59E0B),
                  title: AppTranslations.get('watchlist', lang),
                  subtitle: '${user?.watchlist.length ?? 0} tracked',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => Scaffold(
                        backgroundColor: const Color(0xFF090D16),
                        appBar: AppBar(
                          backgroundColor: const Color(0xFF0F172A),
                          title: Text(AppTranslations.get('watchlist', lang), style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                        body: const SafeArea(child: WatchlistTab()),
                      )),
                    );
                  },
                ),
                const Divider(height: 1, color: Color(0xFF1E293B)),
                _buildActionTile(
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  title: AppTranslations.get('transactions', lang),
                  subtitle: '${provider.transactions.length} orders',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                    );
                  },
                ),
                const Divider(height: 1, color: Color(0xFF1E293B)),
                _buildActionTile(
                  icon: Icons.emoji_events_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: AppTranslations.get('leaderboard', lang),
                  subtitle: 'Top Traders',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                    );
                  },
                ),
                const Divider(height: 1, color: Color(0xFF1E293B)),
                _buildActionTile(
                  icon: Icons.currency_exchange,
                  iconColor: const Color(0xFF38BDF8),
                  title: AppTranslations.get('currencyExchangeTitle', lang),
                  subtitle: AppTranslations.get('currencyExchangeSubtitle', lang),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CurrencyExchangeScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Preferences & Account Settings Card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.attach_money,
                  iconColor: const Color(0xFF10B981),
                  title: AppTranslations.get('displayCurrency', lang),
                  subtitle: AppTranslations.get(currKey, lang),
                  onTap: () => _showCurrencyDialog(context, provider),
                ),
                const Divider(height: 1, color: Color(0xFF1E293B)),
                _buildActionTile(
                  icon: Icons.language,
                  iconColor: const Color(0xFF8B5CF6),
                  title: AppTranslations.get('language', lang),
                  subtitle: langName,
                  onTap: () => _showLanguageDialog(context, provider),
                ),
                const Divider(height: 1, color: Color(0xFF1E293B)),
                _buildActionTile(
                  icon: Icons.refresh,
                  iconColor: const Color(0xFFEF4444),
                  title: AppTranslations.get('resetAccount', lang),
                  subtitle: 'Reset balance to ₩1,000,000',
                  onTap: () => _showResetConfirmDialog(context, provider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Version Footer
          Center(
            child: Text(
              AppTranslations.get('version', lang),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 18),
    );
  }
}
