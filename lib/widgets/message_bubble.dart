import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final bool showTimestamp;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.showTimestamp = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBg = isOwn
        ? AppTheme.sentBubbleBg
        : (isDark ? AppTheme.receivedBubbleBgDark : AppTheme.receivedBubbleBg);
    final bubbleText = isOwn
        ? AppTheme.sentBubbleText
        : (isDark
              ? AppTheme.receivedBubbleTextDark
              : AppTheme.receivedBubbleText);

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isOwn ? 60 : AppTheme.spacingLg,
          right: isOwn ? AppTheme.spacingLg : 60,
          top: AppTheme.spacingSm,
          bottom: AppTheme.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: isOwn
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTheme.radiusLg),
                  topRight: const Radius.circular(AppTheme.radiusLg),
                  bottomLeft: Radius.circular(
                    isOwn ? AppTheme.radiusLg : AppTheme.radiusSm,
                  ),
                  bottomRight: Radius.circular(
                    isOwn ? AppTheme.radiusSm : AppTheme.radiusLg,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm,
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: bubbleText,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
            if (showTimestamp)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingXs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Formatters.formatMessageTime(message.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (isOwn && message.isRead)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.done_all,
                          size: 14,
                          color: AppTheme.primary,
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
