import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'avatar_widget.dart';
import 'unread_badge.dart';

class ChatTile extends ConsumerWidget {
  final Chat chat;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onMute;
  final VoidCallback? onPin;

  const ChatTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.onDelete,
    this.onMute,
    this.onPin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveUser = chat.isGroup
        ? null
        : ref.watch(userByIdProvider(chat.otherUser.id)).valueOrNull;
    final presence = chat.isGroup
        ? null
        : ref.watch(userPresenceProvider(chat.otherUser.id)).valueOrNull;
    final otherUser = (liveUser ?? chat.otherUser).applyPresence(presence);
    final currentUserId = ref.watch(currentUserIdProvider);
    final isTyping = chat.isGroup
        ? false
        : ref
                  .watch(
                    chatTypingProvider((
                      chatId: chat.id,
                      otherUserId: chat.otherUser.id,
                    )),
                  )
                  .valueOrNull ??
              false;
    final canSwipeActions = onDelete != null || onMute != null;
    final previewText = _previewText(
      isTyping: isTyping,
      currentUserId: currentUserId,
    );
    final displayName = chat.isGroup ? chat.displayName : otherUser.name;
    final displayAvatar = chat.isGroup ? chat.groupAvatar : otherUser.avatar;
    final showLastSenderAvatar = _showLastSenderAvatar(currentUserId);
    final lastSenderName = _lastSenderDisplayName();
    final lastSenderAvatar =
        chat.lastMessageSenderAvatar ?? chat.lastMessage?.senderAvatar;

    final tileContent = GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            Stack(
              children: [
                AvatarWidget(
                  imageUrl: displayAvatar,
                  initials: _getInitials(displayName),
                  size: 56,
                  isOnline: !chat.isGroup && otherUser.isOnline,
                ),
                if (chat.isPinned)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary,
                      ),
                      child: const Icon(
                        Icons.push_pin,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        Formatters.formatChatListTime(
                          chat.lastMessage?.timestamp ?? chat.updatedAt,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXs),
                  Row(
                    children: [
                      if (showLastSenderAvatar) ...[
                        AvatarWidget(
                          imageUrl: lastSenderAvatar,
                          initials: _getInitials(lastSenderName),
                          size: 18,
                        ),
                        const SizedBox(width: AppTheme.spacingXs),
                      ],
                      Expanded(
                        child: Text(
                          previewText,
                          style: TextStyle(
                            color: isTyping
                                ? AppTheme.primary
                                : (chat.unreadCount > 0
                                      ? (isDark
                                            ? AppTheme.darkTextPrimary
                                            : AppTheme.lightTextPrimary)
                                      : (isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.lightTextSecondary)),
                            fontSize: 13,
                            fontStyle: isTyping
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.isMuted)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.volume_off,
                            size: 14,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            UnreadBadge(count: chat.unreadCount),
          ],
        ),
      ),
    );

    if (!canSwipeActions) {
      return tileContent;
    }

    return Dismissible(
      key: Key(chat.id),
      background: Container(
        color: AppTheme.warning,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppTheme.spacingLg),
        child: const Icon(Icons.volume_off, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: AppTheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacingLg),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      resizeDuration: const Duration(milliseconds: 300),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (onMute == null) {
            return false;
          }
          onMute?.call();
          return false;
        }
        return direction == DismissDirection.endToStart && onDelete != null;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete?.call();
        }
      },
      child: tileContent,
    );
  }

  String _previewText({
    required bool isTyping,
    required String? currentUserId,
  }) {
    if (isTyping) {
      return 'typing...';
    }

    final lastMessage = chat.lastMessage;
    if (!chat.isGroup || lastMessage == null) {
      return Formatters.formatMessagePreview(
        lastMessage?.content ?? chat.displaySubtitle,
      );
    }

    if (lastMessage.type == MessageType.system) {
      return Formatters.formatMessagePreview(lastMessage.content);
    }

    final senderPrefix = lastMessage.senderId == currentUserId
        ? 'You'
        : _lastSenderDisplayName();
    return Formatters.formatMessagePreview(
      '$senderPrefix: ${lastMessage.content}',
      maxLength: 62,
    );
  }

  bool _showLastSenderAvatar(String? currentUserId) {
    final lastMessage = chat.lastMessage;
    return chat.isGroup &&
        lastMessage != null &&
        lastMessage.type != MessageType.system &&
        lastMessage.senderId != currentUserId;
  }

  String _lastSenderDisplayName() {
    final senderName = chat.lastMessageSenderName?.trim();
    if (senderName != null && senderName.isNotEmpty) {
      return senderName;
    }

    final messageSenderName = chat.lastMessage?.senderName?.trim();
    if (messageSenderName != null && messageSenderName.isNotEmpty) {
      return messageSenderName;
    }

    final senderUsername = chat.lastMessageSenderUsername?.trim();
    if (senderUsername != null && senderUsername.isNotEmpty) {
      return '@$senderUsername';
    }

    final messageSenderUsername = chat.lastMessage?.senderUsername?.trim();
    if (messageSenderUsername != null && messageSenderUsername.isNotEmpty) {
      return '@$messageSenderUsername';
    }

    return 'Member';
  }

  String _getInitials(String name) {
    final normalizedName = name.trim().replaceFirst(RegExp(r'^@+'), '');
    final parts = normalizedName.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.substring(0, 1).toUpperCase();
  }
}
