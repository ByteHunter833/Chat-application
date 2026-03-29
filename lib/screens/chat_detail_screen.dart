import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_field.dart';
import '../widgets/state_widgets.dart';
import 'call_screen.dart';
import 'profile_screen.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.chat});

  final Chat chat;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  late final TextEditingController _messageController;
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final currentUser = ref.read(currentAppUserProvider).valueOrNull;
    final text = _messageController.text.trim();
    if (currentUser == null || text.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendTextMessage(
            chatId: widget.chat.id,
            senderId: currentUser.id,
            text: text,
          );
    } catch (error) {
      _messageController.text = text;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Message failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _scheduleScrollIfNeeded(int messageCount) {
    if (_lastMessageCount == messageCount) {
      return;
    }

    _lastMessageCount = messageCount;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    final messagesAsync = ref.watch(messagesProvider(widget.chat.id));
    final statusText = widget.chat.otherUser.isOnline
        ? 'Active now'
        : Formatters.formatLastSeen(widget.chat.otherUser.lastSeen);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  userId: widget.chat.otherUser.id,
                  userName: widget.chat.otherUser.name,
                  userAvatar: widget.chat.otherUser.avatar ?? '',
                  userHandle: widget.chat.otherUser.handle,
                  isOnline: widget.chat.otherUser.isOnline,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.chat.otherUser.name),
              Text(statusText, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallPage(callID: widget.chat.id),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallPage(callID: widget.chat.id),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                _scheduleScrollIfNeeded(messages.length);

                if (messages.isEmpty) {
                  return const EmptyStateWidget(
                    title: 'No messages yet',
                    subtitle:
                        'This chat is ready. Send the first message to start the conversation.',
                    icon: Icons.forum_outlined,
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingMd,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return MessageBubble(
                      message: message,
                      isOwn: message.senderId == currentUser?.id,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => ErrorStateWidget(
                title: 'Unable to load messages',
                subtitle: error.toString(),
                onRetry: () => ref.invalidate(messagesProvider(widget.chat.id)),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
            ),
            child: MessageInputField(
              controller: _messageController,
              onSend: _sendMessage,
              onAttach: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Media upload can be added next.'),
                  ),
                );
              },
              isLoading: _isSending,
            ),
          ),
        ],
      ),
    );
  }
}
