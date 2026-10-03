import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../i18n/translations.dart';
import '../services/notification_service.dart';
import 'home_tab.dart';
import 'markets_tab.dart';
import 'news_tab.dart';
import 'portfolio_tab.dart';
import 'ai_agent_tab.dart';
import 'profile_tab.dart';

class MainBottomNavScreen extends StatefulWidget {
  const MainBottomNavScreen({super.key});

  @override
  State<MainBottomNavScreen> createState() => _MainBottomNavScreenState();
}

class _MainBottomNavScreenState extends State<MainBottomNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    HomeTab(),
    MarketsTab(),
    NewsTab(),
    PortfolioTab(),
    AIAgentTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermissionPrompt();
    });
  }

  Future<void> _checkNotificationPermissionPrompt() async {
    final notif = NotificationService.instance;
    if (notif.hasPromptedPermission) return;

    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final lang = provider.activeLanguage;

    final title = lang == 'ko' ? 'Trade X — 시간별 포트폴리오 알림' : 'Trade X — Hourly Portfolio Updates';
    final desc = lang == 'ko'
        ? '보유 주식의 실제 1시간 변동 내역 및 중요한 가격 알림을 휴대폰 시스템 알림으로 받아보시겠습니까?'
        : 'Would you like to receive real hourly summaries of your stock movements and portfolio changes as Android system notifications?';
    final allowText = lang == 'ko' ? '알림 켜기' : 'Enable';
    final laterText = lang == 'ko' ? '나중에' : 'Not Now';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Color(0xFF38BDF8), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          desc,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Respect user choice: remember that user declined and do not ask again repeatedly
              await notif.declineNotificationPermission();
              await provider.toggleHourlyAlerts(false);
            },
            child: Text(laterText, style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final granted = await notif.requestNotificationPermission();
              await provider.toggleHourlyAlerts(granted);
              if (granted) {
                await provider.triggerHourlyAlert(forceTest: false);
              }
            },
            child: Text(allowText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final lang = provider.activeLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        top: true,
        bottom: false,
        child: _tabs[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 0.8)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF38BDF8),
            unselectedItemColor: const Color(0xFF64748B),
            selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 10),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.dashboard_outlined),
                activeIcon: const Icon(Icons.dashboard),
                label: AppTranslations.get('home', lang),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.show_chart_outlined),
                activeIcon: const Icon(Icons.show_chart),
                label: AppTranslations.get('markets', lang),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.newspaper_outlined),
                activeIcon: const Icon(Icons.newspaper),
                label: AppTranslations.get('news', lang),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.pie_chart_outline),
                activeIcon: const Icon(Icons.pie_chart),
                label: AppTranslations.get('portfolio', lang),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.auto_awesome_outlined),
                activeIcon: const Icon(Icons.auto_awesome),
                label: AppTranslations.get('aiAgent', lang),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person),
                label: AppTranslations.get('profile', lang),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
