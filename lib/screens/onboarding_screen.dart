import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../i18n/translations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _usernameController = TextEditingController(text: 'Investor');
  String _selectedCountry = 'KR';
  String _selectedCurrency = 'KRW';
  String _selectedLanguage = 'ko';
  bool _isLoading = false;

  final List<Map<String, String>> _countries = [
    {'code': 'KR', 'nameKey': 'countryNameKR', 'flag': '🇰🇷', 'currency': 'KRW', 'lang': 'ko'},
    {'code': 'US', 'nameKey': 'countryNameUS', 'flag': '🇺🇸', 'currency': 'USD', 'lang': 'en'},
    {'code': 'JP', 'nameKey': 'countryNameJP', 'flag': '🇯🇵', 'currency': 'JPY', 'lang': 'ja'},
    {'code': 'GB', 'nameKey': 'countryNameGB', 'flag': '🇬🇧', 'currency': 'GBP', 'lang': 'en'},
    {'code': 'DE', 'nameKey': 'countryNameDE', 'flag': '🇩🇪', 'currency': 'EUR', 'lang': 'de'},
    {'code': 'FR', 'nameKey': 'countryNameFR', 'flag': '🇫🇷', 'currency': 'EUR', 'lang': 'fr'},
  ];

  final List<Map<String, String>> _currencies = [
    {'code': 'KRW', 'symbol': '₩', 'label': 'KRW (₩ 1,000,000)'},
    {'code': 'USD', 'symbol': '\$', 'label': 'USD (\$ 740.74)'},
    {'code': 'JPY', 'symbol': '¥', 'label': 'JPY (¥ 108,000)'},
    {'code': 'EUR', 'symbol': '€', 'label': 'EUR (€ 680.00)'},
    {'code': 'GBP', 'symbol': '£', 'label': 'GBP (£ 580.00)'},
  ];

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _onCountrySelected(String code, String defaultCurr, String defaultLang) {
    setState(() {
      _selectedCountry = code;
      _selectedCurrency = defaultCurr;
      _selectedLanguage = defaultLang;
    });
  }

  Future<void> _handleStartTrading() async {
    final name = _usernameController.text.trim().isEmpty ? 'Investor' : _usernameController.text.trim();
    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.createAccount(
        username: name,
        country: _selectedCountry,
        currency: _selectedCurrency,
        language: _selectedLanguage,
      );
    } catch (e) {
      if (mounted) {
        final errPrefix = AppTranslations.get('accountCreationError', _selectedLanguage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$errPrefix $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getStartingCapitalDisplay() {
    switch (_selectedCurrency) {
      case 'USD':
        return '\$ 740.74';
      case 'JPY':
        return '¥ 108,000';
      case 'EUR':
        return '€ 680.00';
      case 'GBP':
        return '£ 580.00';
      case 'KRW':
      default:
        return '₩ 1,000,000';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = _selectedLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Language Selector Bar on Top Right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLanguage,
                            dropdownColor: const Color(0xFF0F172A),
                            icon: const Icon(Icons.language, color: Color(0xFF10B981), size: 16),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            items: const [
                              DropdownMenuItem(value: 'ko', child: Text('한국어')),
                              DropdownMenuItem(value: 'en', child: Text('English')),
                              DropdownMenuItem(value: 'ja', child: Text('日本語')),
                              DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                              DropdownMenuItem(value: 'fr', child: Text('Français')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedLanguage = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Branding Badge
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '⚡',
                          style: TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Titles
                  Text(
                    AppTranslations.get('onboardingTitle', lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppTranslations.get('onboardingSubtitle', lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 1. Trader Username
                  Text(
                    AppTranslations.get('traderNickname', lang),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        icon: const Icon(Icons.person, color: Color(0xFF10B981), size: 18),
                        hintText: AppTranslations.get('traderNicknameHint', lang),
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Country Selection
                  Text(
                    AppTranslations.get('primaryMarket', lang),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _countries.map((c) {
                      final isSelected = _selectedCountry == c['code'];
                      final countryLabel = AppTranslations.get(c['nameKey']!, lang);
                      return ChoiceChip(
                        label: Text('${c['flag']} $countryLabel'),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) _onCountrySelected(c['code']!, c['currency']!, c['lang']!);
                        },
                        selectedColor: const Color(0xFF10B981),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF090D16) : const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 3. Preferred Currency
                  Text(
                    AppTranslations.get('displayCurrency', lang),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        items: _currencies.map((curr) {
                          return DropdownMenuItem<String>(
                            value: curr['code'],
                            child: Row(
                              children: [
                                Text(
                                  curr['symbol']!,
                                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(width: 10),
                                Text(curr['label']!),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCurrency = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Starting Virtual Capital Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              AppTranslations.get('startingCapital', lang),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getStartingCapitalDisplay(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppTranslations.get('riskFreeNote', lang),
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF090D16),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    onPressed: _isLoading ? null : _handleStartTrading,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF090D16)),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppTranslations.get('startTrading', lang),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
