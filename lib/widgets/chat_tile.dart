import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'avatar_widget.dart';
import 'unread_badge.dart';

class ChatTile extends StatefulWidget {
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
  State<ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<ChatTile> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSwipeActions = widget.onDelete != null || widget.onMute != null;

    final tileContent = GestureDetector(
      onTap: widget.onTap,
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
                  imageUrl: widget.chat.otherUser.avatar,
                  initials: _getInitials(widget.chat.otherUser.name),
                  size: 56,
                  isOnline: widget.chat.otherUser.isOnline,
                ),
                if (widget.chat.isPinned)
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
                          widget.chat.otherUser.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        Formatters.formatChatListTime(
                          widget.chat.lastMessage?.timestamp ??
                              widget.chat.updatedAt,
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
                          widget.chat.lastMessage?.content ??
                              widget.chat.otherUser.handle,
                          style: TextStyle(
                            color: widget.chat.unreadCount > 0
                                ? (isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary)
                                : (isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary),
                            fontSize: 13,
                            fontWeight: widget.chat.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.chat.isMuted)
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
            UnreadBadge(count: widget.chat.unreadCount),
          ],
        ),
      ),
    );

    if (!canSwipeActions) {
      return tileContent;
    }

    return Dismissible(
      key: Key(widget.chat.id),
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
          if (widget.onMute == null) {
            return false;
          }
          widget.onMute?.call();
          return false;
        }
        return direction == DismissDirection.endToStart &&
            widget.onDelete != null;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          widget.onDelete?.call();
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
