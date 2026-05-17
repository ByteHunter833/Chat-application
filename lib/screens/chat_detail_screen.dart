import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
  const ChatDetailScreen({super.key, required this.chat, this.isDraft = false});

  final Chat chat;
  final bool isDraft;

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
  bool _isTyping = false;
  bool _isDisposed = false;
  String? _currentUserId;

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
  void dispose() {
    _isDisposed = true;
    _typingDebounce?.cancel();
    _clearTypingOnDispose();
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

    _currentUserId = currentUser.id;
    setState(() {
      _isSending = true;
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
    final currentUser = ref.read(currentAppUserProvider).valueOrNull;
    if (currentUser == null || _isUploadingMedia || _isSending) {
      return;
    }

    _currentUserId = currentUser.id;
    final chatId = _chat.id;
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    if (!mounted || _isDisposed || picked == null || picked.files.isEmpty) {
      return;
    }

    setState(() {
      _isUploadingMedia = true;
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
              fileName: upload.fileName,
              mimeType: upload.mimeType,
              fileSize: upload.fileSize,
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
          fileName: upload.fileName,
          mimeType: upload.mimeType,
          fileSize: upload.fileSize,
        );
      }
    } catch (error) {
      if (!mounted || _isDisposed) {
        return;
      }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    _currentUserId = currentUser?.id ?? _currentUserId;
    final liveUser = _chat.isGroup
        ? null
        : ref.watch(userByIdProvider(_chat.otherUser.id)).valueOrNull;
    final presence = _chat.isGroup
        ? null
        : ref.watch(userPresenceProvider(_chat.otherUser.id)).valueOrNull;
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
                  .valueOrNull ??
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).iconTheme.color,
            ),
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
                          return MessageBubble(
                            message: message,
                            isOwn: isOwn,
                            showSenderInfo: _chat.isGroup && !isOwn,
                          );
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
