import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/mock_data.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_field.dart';
import '../widgets/typing_indicator.dart';
import 'call_screen.dart';
import 'profile_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late TextEditingController _messageController;
  List<Message> _messages = [];
  bool _isTyping = false;
  bool _isSending = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _loadMessages();
  }

  void _loadMessages() {
    _messages = MockData.mockMessages;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final newMessage = Message(
      id: DateTime.now().toString(),
      chatId: widget.chat.id,
      senderId: 'me',
      content: _messageController.text,
      timestamp: DateTime.now(),
      isRead: false,
      type: MessageType.text,
    );

    setState(() {
      _messages.add(newMessage);
      _isSending = true;
    });

    _messageController.clear();
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isTyping = true;
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      setState(() {
        _isTyping = false;
        _isSending = false;
        _messages.add(
          Message(
            id: DateTime.now().toString(),
            chatId: widget.chat.id,
            senderId: widget.chat.otherUser.id,
            content: 'That sounds great! 😊',
            timestamp: DateTime.now(),
            isRead: true,
            type: MessageType.text,
          ),
        );
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallScreen(
                    userName: widget.chat.otherUser.name,
                    userAvatar: widget.chat.otherUser.avatar ?? '',
                  ),
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
                  builder: (context) => CallScreen(
                    userName: widget.chat.otherUser.name,
                    userAvatar: widget.chat.otherUser.avatar ?? '',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('More options')));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: AppTheme.spacingLg,
                      top: AppTheme.spacingSm,
                      bottom: AppTheme.spacingSm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.receivedBubbleBgDark
                                : AppTheme.receivedBubbleBg,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMd,
                            vertical: AppTheme.spacingMd,
                          ),
                          child: const TypingIndicator(),
                        ),
                      ],
                    ),
                  );
                }

                final message = _messages[index];
                return MessageBubble(
                  message: message,
                  isOwn: message.senderId == 'me',
                  showTimestamp: true,
                );
              },
            ),
          ),
          // Message Input
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
                  const SnackBar(content: Text('Attachment feature')),
                );
              },
              onEmoji: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Emoji picker feature')),
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
