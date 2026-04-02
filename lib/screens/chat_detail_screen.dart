import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../utils/call_invitation_service.dart';
import '../utils/formatters.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_field.dart';
import '../widgets/state_widgets.dart';
import '../widgets/typing_indicator.dart';
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
  bool _isUploadingMedia = false;
  bool _isStartingCall = false;
  int _lastMessageCount = 0;
  String _lastMarkedUnreadSignature = '';
  bool _didResetInitialUnreadCount = false;
  Timer? _typingDebounce;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    unawaited(_setTyping(false));
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
    unawaited(_setTyping(false));

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

  Future<void> _startCall({required bool isVideoCall}) async {
    if (_isStartingCall) {
      return;
    }

    final currentUser = ref.read(currentAppUserProvider).valueOrNull;
    final otherUser =
        ref.read(userByIdProvider(widget.chat.otherUser.id)).valueOrNull ??
        widget.chat.otherUser;
    if (currentUser == null) {
      return;
    }

    setState(() {
      _isStartingCall = true;
    });

    try {
      final didSend = await CallInvitationService.startCall(
        currentUser: currentUser,
        targetUser: otherUser,
        chatId: widget.chat.id,
        isVideoCall: isVideoCall,
        callID: '${widget.chat.id}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted || didSend) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVideoCall
                ? 'Video call invitation was not sent.'
                : 'Voice call invitation was not sent.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start call: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isStartingCall = false;
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

  void _markMessagesAsReadIfNeeded(
    List<Message> messages,
    String? currentUserId,
  ) {
    if (currentUserId == null) {
      return;
    }

    if (!_didResetInitialUnreadCount && widget.chat.unreadCount > 0) {
      _didResetInitialUnreadCount = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(chatRepositoryProvider)
            .markChatAsRead(
              chatId: widget.chat.id,
              currentUserId: currentUserId,
            );
      });
    }

    final unreadIncomingMessages = messages
        .where(
          (message) => message.senderId != currentUserId && !message.isRead,
        )
        .toList();
    final signature = unreadIncomingMessages
        .map((message) => message.id)
        .join('|');

    if (signature.isEmpty) {
      _lastMarkedUnreadSignature = '';
      return;
    }

    if (_lastMarkedUnreadSignature == signature) {
      return;
    }

    _lastMarkedUnreadSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatRepositoryProvider)
          .markChatAsRead(chatId: widget.chat.id, currentUserId: currentUserId);
    });
  }

  Future<void> _pickAndSendMedia() async {
    final currentUser = ref.read(currentAppUserProvider).valueOrNull;
    if (currentUser == null || _isUploadingMedia || _isSending) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    setState(() {
      _isUploadingMedia = true;
    });

    unawaited(_setTyping(false));

    try {
      final upload = await ref
          .read(storageRepositoryProvider)
          .uploadChatMedia(
            file: picked.files.single,
            chatId: widget.chat.id,
            senderId: currentUser.id,
          );

      await ref
          .read(chatRepositoryProvider)
          .sendMediaMessage(
            chatId: widget.chat.id,
            senderId: currentUser.id,
            displayText: switch (upload.messageType) {
              MessageType.image => 'Photo',
              MessageType.video => 'Video',
              MessageType.voice => 'Voice message',
              MessageType.file => upload.fileName,
              MessageType.system => upload.fileName,
              MessageType.text => upload.fileName,
            },
            type: upload.messageType,
            mediaUrl: upload.url,
            fileName: upload.fileName,
            mimeType: upload.mimeType,
            fileSize: upload.fileSize,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Media upload failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
        });
      }
    }
  }

  void _handleComposerChanged(String value) {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      return;
    }

    _typingDebounce?.cancel();
    final hasText = value.trim().isNotEmpty;
    if (!hasText) {
      unawaited(_setTyping(false));
      return;
    }

    unawaited(_setTyping(true));
    _typingDebounce = Timer(
      const Duration(milliseconds: 1400),
      () => unawaited(_setTyping(false)),
    );
  }

  Future<void> _setTyping(bool isTyping) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null || _isTyping == isTyping) {
      return;
    }

    _isTyping = isTyping;
    await ref
        .read(chatRepositoryProvider)
        .setTypingState(
          chatId: widget.chat.id,
          userId: currentUserId,
          isTyping: isTyping,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    final liveUser = ref
        .watch(userByIdProvider(widget.chat.otherUser.id))
        .valueOrNull;
    final presence = ref
        .watch(userPresenceProvider(widget.chat.otherUser.id))
        .valueOrNull;
    final otherUser = (liveUser ?? widget.chat.otherUser).applyPresence(
      presence,
    );
    final messagesAsync = ref.watch(messagesProvider(widget.chat.id));
    final isOtherUserTyping =
        ref
            .watch(
              chatTypingProvider((
                chatId: widget.chat.id,
                otherUserId: widget.chat.otherUser.id,
              )),
            )
            .valueOrNull ??
        false;
    final statusText = isOtherUserTyping
        ? 'typing...'
        : Formatters.formatPresenceStatus(
            isOnline: otherUser.isOnline,
            lastSeen: otherUser.lastSeen,
          );

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
                  userId: otherUser.id,
                  userName: otherUser.name,
                  userAvatar: otherUser.avatar ?? '',
                  userHandle: otherUser.handle,
                  isOnline: otherUser.isOnline,
                  lastSeen: otherUser.lastSeen,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(otherUser.name),
              Text(statusText, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: _isStartingCall
                ? null
                : () => _startCall(isVideoCall: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _isStartingCall
                ? null
                : () => _startCall(isVideoCall: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                _scheduleScrollIfNeeded(messages.length);
                _markMessagesAsReadIfNeeded(messages, currentUser?.id);

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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isOtherUserTyping
                ? Container(
                    key: const ValueKey('typing-indicator'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingLg,
                      vertical: AppTheme.spacingSm,
                    ),
                    color: isDark
                        ? AppTheme.darkSurface
                        : AppTheme.lightSurface,
                    child: Row(
                      children: [
                        const TypingIndicator(),
                        const SizedBox(width: AppTheme.spacingSm),
                        Text(
                          '${otherUser.name} is typing...',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.primary),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('typing-indicator-empty'),
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
              onAttach: _pickAndSendMedia,
              onChanged: _handleComposerChanged,
              isLoading: _isSending || _isUploadingMedia,
            ),
          ),
        ],
      ),
    );
  }
}
