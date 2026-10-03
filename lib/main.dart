import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/main_bottom_nav.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const TradePulseApp(),
    ),
  );
}

class TradePulseApp extends StatelessWidget {
  const TradePulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TradePulse Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        primaryColor: const Color(0xFF10B981),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.isCheckingOnboarding) {
            return const Scaffold(
              backgroundColor: Color(0xFF090D16),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2),
              ),
            );
          }
          if (!provider.hasCompletedOnboarding) {
            return const OnboardingScreen();
          }
          return const MainBottomNavScreen();
        },
      ),
    );
  }
}
