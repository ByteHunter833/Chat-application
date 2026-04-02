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
    final liveUser = ref.watch(userByIdProvider(chat.otherUser.id)).valueOrNull;
    final presence = ref
        .watch(userPresenceProvider(chat.otherUser.id))
        .valueOrNull;
    final otherUser = (liveUser ?? chat.otherUser).applyPresence(presence);
    final isTyping =
        ref
            .watch(
              chatTypingProvider((
                chatId: chat.id,
                otherUserId: chat.otherUser.id,
              )),
            )
            .valueOrNull ??
        false;
    final canSwipeActions = onDelete != null || onMute != null;
    final previewText = isTyping
        ? 'typing...'
        : Formatters.formatMessagePreview(
            chat.lastMessage?.content ?? otherUser.handle,
          );

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
                  imageUrl: otherUser.avatar,
                  initials: _getInitials(otherUser.name),
                  size: 56,
                  isOnline: otherUser.isOnline,
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
                          otherUser.name,
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

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }
}
