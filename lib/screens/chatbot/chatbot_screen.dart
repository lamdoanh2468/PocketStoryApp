import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/chatbot_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key, required this.user});

  final User user;

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Xin chào, mình là trợ lý phân tích chi tiêu của PocketStory. Bạn có thể hỏi: “Tháng này tôi chi nhiều nhất ở đâu?” hoặc “Ngân sách nào sắp vượt?”.',
      isUser: false,
    ),
  ];

  int _rangeDays = 30;
  bool _isLoading = false;

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion({String? preset}) async {
    final question = (preset ?? _questionController.text).trim();
    final resolvedQuestion = question.isEmpty
        ? 'Hãy phân tích chi tiêu của tôi trong $_rangeDays ngày gần đây.'
        : question;

    if (_isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: resolvedQuestion, isUser: true));
      _isLoading = true;
      _questionController.clear();
    });
    _scrollToBottom();

    try {
      final analysis = await _chatbotService.analyzePersonalSpending(
        question: resolvedQuestion,
        rangeDays: _rangeDays,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text:
                '${analysis.answer}\n\nDữ liệu đã xét: ${analysis.entriesCount} giao dịch, ${analysis.budgetsCount} ngân sách trong ${analysis.rangeDays} ngày.',
            isUser: false,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text:
                'Mình chưa phân tích được lúc này. Bạn kiểm tra lại kết nối mạng, đăng nhập Firebase và Cloud Function analyzePersonalSpending nhé.\n\nChi tiết lỗi: $error',
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chatbot phân tích chi tiêu',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'AI sẽ dựa trên entries và budgets của tài khoản hiện tại để nhận xét theo thu/chi, danh mục, ghi chú, thời gian và ngân sách.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Khoảng thời gian:'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _rangeDays,
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 ngày')),
                        DropdownMenuItem(value: 30, child: Text('30 ngày')),
                        DropdownMenuItem(value: 90, child: Text('90 ngày')),
                        DropdownMenuItem(value: 180, child: Text('180 ngày')),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (value) => setState(() => _rangeDays = value ?? 30),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PromptChip(
                      label: 'Chi nhiều nhất ở đâu?',
                      onTap: _isLoading
                          ? null
                          : () => _sendQuestion(
                                preset:
                                    'Trong $_rangeDays ngày gần đây tôi chi nhiều nhất ở danh mục nào?',
                              ),
                    ),
                    _PromptChip(
                      label: 'Ngân sách nào sắp vượt?',
                      onTap: _isLoading
                          ? null
                          : () => _sendQuestion(
                                preset:
                                    'Ngân sách nào của tôi đang gần vượt hoặc đã vượt?',
                              ),
                    ),
                    _PromptChip(
                      label: 'Gợi ý tiết kiệm',
                      onTap: _isLoading
                          ? null
                          : () => _sendQuestion(
                                preset:
                                    'Hãy gợi ý cách tiết kiệm dựa trên thói quen chi tiêu gần đây của tôi.',
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final message = _messages[index];
                return _ChatBubble(message: message);
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    enabled: !_isLoading,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Hỏi về chi tiêu cá nhân của bạn...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendQuestion(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _sendQuestion,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Gửi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = message.isUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SelectableText(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
    );
  }
}
