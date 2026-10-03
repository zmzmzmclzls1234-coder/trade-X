import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../i18n/translations.dart';
import '../services/ai_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String timestamp;
  final bool isSpecialAnalysis;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isSpecialAnalysis = false,
  });
}

class AIAgentTab extends StatefulWidget {
  const AIAgentTab({super.key});

  @override
  State<AIAgentTab> createState() => _AIAgentTabState();
}

class _AIAgentTabState extends State<AIAgentTab> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWelcomeMessage();
    });
  }

  void _initWelcomeMessage() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final lang = provider.activeLanguage;
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    if (_messages.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          text: AppTranslations.get('aiWelcomeMessage', lang),
          isUser: false,
          timestamp: timeStr,
        ));
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty || _isTyping) return;
    _textController.clear();
    final queryText = text.trim();
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    setState(() {
      _messages.add(ChatMessage(
        text: queryText,
        isUser: true,
        timestamp: timeStr,
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    final provider = Provider.of<AppProvider>(context, listen: false);

    // Build conversation history (only messages prior to current query)
    final history = _messages.length > 1
        ? _messages.take(_messages.length - 1).map((m) => {
            'role': m.isUser ? 'user' : 'model',
            'text': m.text,
          }).toList()
        : <Map<String, String>>[];

    try {
      final responseText = await AIService.instance.askAI(
        query: queryText,
        conversationHistory: history,
        provider: provider,
      );

      final replyTime = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            text: responseText,
            isUser: false,
            timestamp: replyTime,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final lang = provider.activeLanguage;
        final errorMsg = lang == 'ko'
            ? "⚠️ 요청 처리 중 오류가 발생했습니다: ${e.toString()}"
            : "⚠️ Error processing your request: ${e.toString()}";
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            text: errorMsg,
            isUser: false,
            timestamp: timeStr,
          ));
        });
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final lang = provider.activeLanguage;

    final promptList = [
      AppTranslations.get('promptAnalyzePortfolio', lang),
      AppTranslations.get('promptDiversification', lang),
      AppTranslations.get('promptExplainBiggestHolding', lang),
      AppTranslations.get('promptWhatIsPE', lang),
      AppTranslations.get('promptHowToManageRisk', lang),
      AppTranslations.get('promptWhyStocksMoved', lang),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 0.8)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.get('aiAgent', lang),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          AppTranslations.get('aiAgentSubtitle', lang),
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: msg.isUser ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: msg.isUser ? const Radius.circular(2) : const Radius.circular(16),
                            bottomLeft: !msg.isUser ? const Radius.circular(2) : const Radius.circular(16),
                          ),
                          border: Border.all(
                            color: msg.isUser ? const Color(0xFF3B82F6) : const Color(0xFF334155),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                msg.timestamp,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI is analyzing your inquiry...',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),

            // Suggested Question Chips
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: promptList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = promptList[index];
                  return ActionChip(
                    backgroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFF334155), width: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    label: Text(
                      prompt,
                      style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11),
                    ),
                    onPressed: () => _handleSubmitted(prompt),
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // Input Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 0.8)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: AppTranslations.get('askAIHint', lang),
                              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              border: InputBorder.none,
                            ),
                            onSubmitted: _handleSubmitted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _handleSubmitted(_textController.text),
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF3B82F6), size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppTranslations.get('aiDisclaimer', lang),
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
