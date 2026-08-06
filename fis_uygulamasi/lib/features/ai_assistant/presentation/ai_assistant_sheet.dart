import 'dart:async';

import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/ai_assistant_message_stream.dart';

class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({
    required this.transactions,
    this.messageStream,
    super.key,
  });

  final List<TransactionEntity> transactions;
  final AiAssistantMessageStream? messageStream;

  static const suggestedQuestions = <String>[
    'Bu ay en çok neye harcadım?',
    'Tasarruf için 3 öneri ver',
    'Bütçemi nasıl iyileştirebilirim?',
  ];

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  StreamSubscription<String>? _responseSubscription;
  bool _isStreaming = false;

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedPrompt]) async {
    final prompt = (suggestedPrompt ?? _inputController.text).trim();
    if (prompt.isEmpty || _isStreaming) return;

    _inputController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _messages
        ..add(_ChatMessage.user(prompt))
        ..add(_ChatMessage.assistant());
      _isStreaming = true;
    });
    _scrollToLatest();

    final stream = widget.messageStream?.call(prompt) ?? _demoResponse(prompt);
    _responseSubscription = stream.listen(
      (chunk) {
        if (!mounted) return;
        setState(() => _messages.last.text += chunk);
        _scrollToLatest();
      },
      onError: (Object error) {
        if (!mounted) return;
        final message = error.toString().trim();
        setState(() {
          _messages.last.text = message.isEmpty
              ? 'Şu anda yanıt oluşturamıyorum. Lütfen tekrar dene.'
              : message;
          _isStreaming = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _isStreaming = false);
        _scrollToLatest();
      },
    );
  }

  Future<void> _stopStreaming() async {
    final subscription = _responseSubscription;
    _responseSubscription = null;
    if (mounted) {
      setState(() {
        _isStreaming = false;
        if (_messages.isNotEmpty && _messages.last.text.isEmpty) {
          _messages.last.text = 'Yanıt durduruldu.';
        }
      });
    }
    await subscription?.cancel();
  }

  Stream<String> _demoResponse(String prompt) async* {
    final response = _buildDemoAnswer(prompt);
    for (final word in response.split(' ')) {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      yield '$word ';
    }
  }

  String _buildDemoAnswer(String prompt) {
    final expenses = widget.transactions
        .where((item) => item.transactionType == TransactionType.expense)
        .toList();
    final total = expenses.fold<int>(
      0,
      (sum, transaction) => sum + transaction.amountInMinor,
    );
    final amount = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    ).format(total / 100);

    if (expenses.isEmpty) {
      return 'Henüz analiz edebileceğim bir harcama yok. İşlemlerini ekledikçe sana kişisel öneriler sunabilirim.';
    }
    if (prompt.toLowerCase().contains('tasarruf')) {
      return 'Toplam $amount harcaman görünüyor. Önce düzenli giderlerini ayır, haftalık bir harcama sınırı belirle ve küçük alışverişleri birlikte değerlendir.';
    }
    return 'Kayıtlı ${expenses.length} harcamanda toplam $amount gider görüyorum. Daha ayrıntılı analiz için kategori veya tarih aralığı sorabilirsin.';
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: const Icon(Icons.auto_awesome_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finans Asistanı',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          _isStreaming
                              ? 'Yanıt hazırlanıyor…'
                              : 'Sana nasıl yardımcı olabilirim?',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('ai_close_button'),
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              key: const Key('ai_investment_disclaimer'),
              width: double.infinity,
              color: scheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu bir yatırım tavsiyesi değildir.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyConversation(onQuestionPressed: _send)
                  : ListView.separated(
                      key: const Key('ai_message_list'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      itemCount: _messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _MessageBubble(
                        message: _messages[index],
                        isStreaming:
                            _isStreaming && index == _messages.length - 1,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('ai_message_field'),
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      enabled: !_isStreaming,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Harcamaların hakkında sor…',
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    key: Key(
                      _isStreaming ? 'ai_stop_button' : 'ai_send_button',
                    ),
                    tooltip: _isStreaming ? 'Yanıtı durdur' : 'Gönder',
                    onPressed: _isStreaming ? _stopStreaming : _send,
                    icon: Icon(
                      _isStreaming
                          ? Icons.stop_rounded
                          : Icons.arrow_upward_rounded,
                    ),
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

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.onQuestionPressed});

  final ValueChanged<String> onQuestionPressed;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
    children: [
      Icon(
        Icons.forum_outlined,
        size: 46,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 14),
      Text(
        'Finansını birlikte sadeleştirelim',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        'Harcama alışkanlıkların, bütçen veya tasarruf hedeflerin hakkında sorabilirsin.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      Text('Hazır sorular', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: AiAssistantSheet.suggestedQuestions
            .map(
              (question) => ActionChip(
                avatar: const Icon(Icons.auto_awesome_rounded, size: 17),
                label: Text(question),
                onPressed: () => onQuestionPressed(question),
              ),
            )
            .toList(),
      ),
    ],
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isStreaming});

  final _ChatMessage message;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 20),
          ),
        ),
        child: isStreaming && message.text.isEmpty
            ? const SizedBox(
                key: Key('ai_typing_indicator'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                message.text,
                key: ValueKey(
                  isUser ? 'ai_user_message' : 'ai_assistant_message',
                ),
                style: TextStyle(
                  color: isUser ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage.user(this.text) : isUser = true;
  _ChatMessage.assistant() : text = '', isUser = false;

  String text;
  final bool isUser;
}
