import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../repositories/chat_repository.dart';
import '../repositories/storage_repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_field.dart';
import '../widgets/state_widgets.dart';
import '../widgets/typing_indicator.dart';
import 'profile_screen.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chat,
    this.isDraft = false,
    this.showBackButton = true,
    this.onClose,
  });

  final Chat chat;
  final bool isDraft;
  final bool showBackButton;
  final VoidCallback? onClose;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  late final TextEditingController _messageController;
  late final ChatRepository _chatRepository;
  late final StorageRepository _storageRepository;
  late Chat _chat;
  late bool _isDraft;
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isUploadingMedia = false;
  int _lastMessageCount = 0;
  String _lastMarkedUnreadSignature = '';
  bool _didResetInitialUnreadCount = false;
  Timer? _typingDebounce;
  Timer? _highlightTimer;
  bool _isTyping = false;
  bool _isDisposed = false;
  String? _currentUserId;
  Message? _replyingToMessage;
  String? _highlightedMessageId;
  List<Message> _latestMessages = const <Message>[];
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  final FocusNode _messageInputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;
    _isDraft = widget.isDraft;
    _chatRepository = ref.read(chatRepositoryProvider);
    _storageRepository = ref.read(storageRepositoryProvider);
    _messageController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant ChatDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id == widget.chat.id &&
        oldWidget.isDraft == widget.isDraft) {
      return;
    }

    _typingDebounce?.cancel();
    _clearTypingOnDispose();
    _chat = widget.chat;
    _isDraft = widget.isDraft;
    _isSending = false;
    _isUploadingMedia = false;
    _lastMessageCount = 0;
    _lastMarkedUnreadSignature = '';
    _didResetInitialUnreadCount = false;
    _isTyping = false;
    _currentUserId = null;
    _replyingToMessage = null;
    _highlightedMessageId = null;
    _highlightTimer?.cancel();
    _messageKeys.clear();
    _latestMessages = const <Message>[];
    _messageController.clear();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _typingDebounce?.cancel();
    _highlightTimer?.cancel();
    _clearTypingOnDispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageInputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final currentUser = ref.read(currentAppUserProvider).value;
    final text = _messageController.text.trim();
    if (currentUser == null || text.isEmpty || _isSending) {
      return;
    }

    final replyTo = _replyingToMessage;
    _currentUserId = currentUser.id;
    setState(() {
      _isSending = true;
      _replyingToMessage = null;
    });

    _messageController.clear();
    unawaited(_setTyping(false));

    try {
      if (_isDraft) {
        final chat = await _chatRepository
            .createOrGetDirectChatAndSendTextMessage(
              currentUser: currentUser,
              otherUser: _chat.otherUser,
              text: text,
              replyTo: replyTo,
            );
        if (!mounted || _isDisposed) {
          return;
        }

        setState(() {
          _chat = chat;
          _isDraft = false;
        });
      } else {
        await _chatRepository.sendTextMessage(
          chatId: _chat.id,
          sender: currentUser,
          text: text,
          replyTo: replyTo,
        );
      }
    } catch (error) {
      if (!mounted || _isDisposed) {
        return;
      }

      _messageController.text = text;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
      setState(() {
        _replyingToMessage = replyTo;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Message failed: $error')));
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (!mounted || _isDisposed || !_scrollController.hasClients) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) {
        return;
      }
      _scrollToBottom();
    });
  }

  void _markMessagesAsReadIfNeeded(
    List<Message> messages,
    String? currentUserId,
  ) {
    if (_isDraft || currentUserId == null) {
      return;
    }

    if (!_didResetInitialUnreadCount && _chat.unreadCount > 0) {
      _didResetInitialUnreadCount = true;
      final chatId = _chat.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) {
          return;
        }

        unawaited(
          _chatRepository
              .markChatAsRead(chatId: chatId, currentUserId: currentUserId)
              .catchError((_) {}),
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
    final chatId = _chat.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) {
        return;
      }

      unawaited(
        _chatRepository
            .markChatAsRead(chatId: chatId, currentUserId: currentUserId)
            .catchError((_) {}),
      );
    });
  }

  Future<void> _pickAndSendMedia() async {
    final currentUser = ref.read(currentAppUserProvider).value;
    if (currentUser == null || _isUploadingMedia || _isSending) {
      return;
    }

    _currentUserId = currentUser.id;
    final chatId = _chat.id;
    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    if (!mounted || _isDisposed || picked == null || picked.files.isEmpty) {
      return;
    }

    final replyTo = _replyingToMessage;
    setState(() {
      _isUploadingMedia = true;
      _replyingToMessage = null;
    });

    unawaited(_setTyping(false));

    try {
      final upload = await _storageRepository.uploadChatMedia(
        file: picked.files.single,
        chatId: chatId,
        senderId: currentUser.id,
      );
      if (!mounted || _isDisposed) {
        return;
      }

      final displayText = switch (upload.messageType) {
        MessageType.image => 'Photo',
        MessageType.video => 'Video',
        MessageType.voice => 'Voice message',
        MessageType.file => upload.fileName,
        MessageType.system => upload.fileName,
        MessageType.text => upload.fileName,
      };

      if (_isDraft) {
        final chat = await _chatRepository
            .createOrGetDirectChatAndSendMediaMessage(
              currentUser: currentUser,
              otherUser: _chat.otherUser,
              displayText: displayText,
              type: upload.messageType,
              mediaUrl: upload.url,
              mediaStoragePath: upload.storagePath,
              fileName: upload.fileName,
              mimeType: upload.mimeType,
              fileSize: upload.fileSize,
              replyTo: replyTo,
            );
        if (!mounted || _isDisposed) {
          return;
        }

        setState(() {
          _chat = chat;
          _isDraft = false;
        });
      } else {
        await _chatRepository.sendMediaMessage(
          chatId: chatId,
          sender: currentUser,
          displayText: displayText,
          type: upload.messageType,
          mediaUrl: upload.url,
          mediaStoragePath: upload.storagePath,
          fileName: upload.fileName,
          mimeType: upload.mimeType,
          fileSize: upload.fileSize,
          replyTo: replyTo,
        );
      }
    } catch (error) {
      if (!mounted || _isDisposed) {
        return;
      }
      setState(() {
        _replyingToMessage = replyTo;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Media upload failed: $error')));
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isUploadingMedia = false;
        });
      }
    }
  }

  void _startReply(Message message) {
    if (message.type == MessageType.system) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _replyingToMessage = message;
    });
    _messageInputFocusNode.requestFocus();
  }

  void _cancelReply() {
    if (_replyingToMessage == null) {
      return;
    }

    setState(() {
      _replyingToMessage = null;
    });
  }

  void _scrollToReply(MessageReply reply) {
    final messageId = reply.messageId;
    if (messageId.isEmpty) {
      return;
    }

    final keyContext = _messageKeys[messageId]?.currentContext;
    if (keyContext != null) {
      _pulseMessage(messageId);
      Scrollable.ensureVisible(
        keyContext,
        alignment: 0.28,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
      return;
    }

    final index = _latestMessages.indexWhere(
      (message) => message.id == messageId,
    );
    if (index < 0 || !_scrollController.hasClients) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original message is not available.')),
      );
      return;
    }

    final targetOffset = (index * 92.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController
        .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        .then((_) {
          if (!mounted || _isDisposed) {
            return;
          }
          _pulseMessage(messageId);
          _ensureMessageVisible(
            messageId,
            duration: const Duration(milliseconds: 180),
          );
        });
  }

  void _ensureMessageVisible(String messageId, {required Duration duration}) {
    final context = _messageKeys[messageId]?.currentContext;
    if (context == null) {
      return;
    }

    Scrollable.ensureVisible(
      context,
      alignment: 0.28,
      duration: duration,
      curve: Curves.easeOut,
    );
  }

  void _pulseMessage(String messageId) {
    if (!mounted || _isDisposed) {
      return;
    }

    _highlightTimer?.cancel();
    setState(() {
      _highlightedMessageId = messageId;
    });
    _highlightTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted || _isDisposed) {
        return;
      }
      setState(() {
        _highlightedMessageId = null;
      });
    });
  }

  void _handleComposerChanged(String value) {
    if (!mounted || _isDisposed || _isDraft || _chat.isGroup) {
      return;
    }

    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      return;
    }

    _currentUserId = currentUserId;
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
    if (!mounted || _isDisposed || _isDraft || _chat.isGroup) {
      return;
    }

    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null || _isTyping == isTyping) {
      return;
    }

    final previousValue = _isTyping;
    _currentUserId = currentUserId;
    _isTyping = isTyping;
    try {
      await _chatRepository.setTypingState(
        chatId: _chat.id,
        userId: currentUserId,
        isTyping: isTyping,
      );
    } catch (_) {
      _isTyping = previousValue;
    }
  }

  void _clearTypingOnDispose() {
    if (_isDraft || _chat.isGroup || !_isTyping) {
      return;
    }

    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return;
    }

    _isTyping = false;
    unawaited(
      _chatRepository
          .setTypingState(
            chatId: _chat.id,
            userId: currentUserId,
            isTyping: false,
          )
          .catchError((_) {}),
    );
  }

  String _formatGroupStatus(int memberCount) {
    if (memberCount == 1) {
      return '1 member';
    }
    return '$memberCount members';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.substring(0, 1).toUpperCase();
  }

  void _showClearChatAndDeleteChatDialog(String username, String actionType) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            actionType == 'clear' ? 'Clear history?' : 'Delete chat?',
          ),
          content: RichText(
            text: TextSpan(
              text:
                  'Are you sure you want to ${actionType == 'clear' ? 'clear' : 'delete'} the chat with ',
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: username,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (actionType == 'delete') {
                  unawaited(_chatRepository.deleteChat(_chat.id));
                  _closeScreen();
                } else {
                  unawaited(_chatRepository.clearChatHistory(_chat.id));
                }
              },
              child: Text(actionType == 'clear' ? 'Clear' : 'Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> clearChatHistory() async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      return;
    }

    try {
      await _chatRepository.clearChatHistory(_chat.id);
    } catch (error) {
      if (!mounted || _isDisposed) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear history: $error')),
      );
    }
  }

  void _closeScreen() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }

    Navigator.pop(context);
  }

  Future<void> deleteMedia(String storagePath) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) {
      return;
    }

    try {
      await _storageRepository.deleteMedia(storagePath);
    } catch (error) {
      if (!mounted || _isDisposed) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete media: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentAppUserProvider).value;
    _currentUserId = currentUser?.id ?? _currentUserId;
    final liveUser = _chat.isGroup
        ? null
        : ref.watch(userByIdProvider(_chat.otherUser.id)).value;
    final presence = _chat.isGroup
        ? null
        : ref.watch(userPresenceProvider(_chat.otherUser.id)).value;
    final otherUser = (liveUser ?? _chat.otherUser).applyPresence(presence);
    final messagesAsync = _isDraft
        ? null
        : ref.watch(messagesProvider(_chat.id));
    final isOtherUserTyping = _isDraft || _chat.isGroup
        ? false
        : ref
                  .watch(
                    chatTypingProvider((
                      chatId: _chat.id,
                      otherUserId: _chat.otherUser.id,
                    )),
                  )
                  .value ??
              false;
    final statusText = _chat.isGroup
        ? _formatGroupStatus(_chat.members.length)
        : isOtherUserTyping
        ? 'typing...'
        : Formatters.formatPresenceStatus(
            isOnline: otherUser.isOnline,
            lastSeen: otherUser.lastSeen,
          );
    final titleText = _chat.isGroup ? _chat.displayName : otherUser.name;
    final avatarUrl = _chat.isGroup ? _chat.groupAvatar : otherUser.avatar;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeScreen,
              )
            : null,
        title: GestureDetector(
          onTap: _chat.isGroup
              ? null
              : () {
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
                        isMuted: _chat.isMuted,
                      ),
                    ),
                  );
                },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primary,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        _getInitials(titleText),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_chat_history') {
                _showClearChatAndDeleteChatDialog(otherUser.name, 'clear');
              } else if (value == 'delete_chat') {
                _showClearChatAndDeleteChatDialog(otherUser.name, 'delete');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'clear_chat_history',
                child: Text('Clear chat history'),
              ),
              PopupMenuItem<String>(
                value: 'delete_chat',
                child: Text('Delete chat'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isDraft
                ? _DraftGreetingView(otherUser: otherUser)
                : messagesAsync!.when(
                    data: (messages) {
                      _latestMessages = messages;
                      _messageKeys.removeWhere(
                        (messageId, _) =>
                            !messages.any((message) => message.id == messageId),
                      );
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
                          final isOwn = message.senderId == currentUser?.id;
                          final messageKey = _messageKeys.putIfAbsent(
                            message.id,
                            () => GlobalKey(),
                          );
                          final bubble = MessageBubble(
                            onDeleteMedia: message.mediaStoragePath != null
                                ? () => deleteMedia(message.mediaStoragePath!)
                                : null,
                            message: message,
                            isOwn: isOwn,
                            showSenderInfo: _chat.isGroup && !isOwn,
                            onReplyTap: message.replyTo == null
                                ? null
                                : () => _scrollToReply(message.replyTo!),
                          );
                          final highlighted =
                              _highlightedMessageId == message.id;
                          final content = KeyedSubtree(
                            key: messageKey,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              color: highlighted
                                  ? AppTheme.primary.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              child: message.type == MessageType.system
                                  ? bubble
                                  : Dismissible(
                                      key: ValueKey('reply-${message.id}'),
                                      direction: DismissDirection.horizontal,
                                      dismissThresholds: const {
                                        DismissDirection.startToEnd: 0.18,
                                        DismissDirection.endToStart: 0.18,
                                      },
                                      background: _ReplySwipeBackground(
                                        alignment: Alignment.centerLeft,
                                      ),
                                      secondaryBackground:
                                          _ReplySwipeBackground(
                                            alignment: Alignment.centerRight,
                                          ),
                                      confirmDismiss: (direction) async {
                                        _startReply(message);
                                        return false;
                                      },
                                      child: bubble,
                                    ),
                            ),
                          );

                          return content;
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => ErrorStateWidget(
                      title: 'Unable to load messages',
                      subtitle: error.toString(),
                      onRetry: () => ref.invalidate(messagesProvider(_chat.id)),
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
              messageFocusNode: _messageInputFocusNode,
              controller: _messageController,
              onSend: _sendMessage,
              onAttach: _pickAndSendMedia,
              onChanged: _handleComposerChanged,
              replyTo: _replyingToMessage,
              onCancelReply: _cancelReply,
              isLoading: _isSending || _isUploadingMedia,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplySwipeBackground extends StatelessWidget {
  const _ReplySwipeBackground({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: EdgeInsets.only(
        left: isLeft ? AppTheme.spacingXl : 0,
        right: isLeft ? 0 : AppTheme.spacingXl,
      ),
      color: AppTheme.primary.withValues(alpha: 0.08),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.reply, color: AppTheme.primary, size: 20),
      ),
    );
  }
}

class _DraftGreetingView extends StatelessWidget {
  const _DraftGreetingView({required this.otherUser});

  final User otherUser;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 220,
              child: Lottie.asset(
                'assets/animations/greeting_animation.json',
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'Say hello to ${otherUser.name}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              otherUser.handle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: secondaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
