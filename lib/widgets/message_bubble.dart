import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingSm,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingSm,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: Text(
                message.content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (showTimestamp)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingXs),
                child: Text(
                  Formatters.formatMessageTime(message.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      );
    }

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
              child: _MessageBubbleContent(
                message: message,
                bubbleText: bubbleText,
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

class _MessageBubbleContent extends StatelessWidget {
  const _MessageBubbleContent({
    required this.message,
    required this.bubbleText,
  });

  final Message message;
  final Color bubbleText;

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return _AttachmentPreview(
          message: message,
          bubbleText: bubbleText,
          icon: Icons.photo_outlined,
          showImage: true,
        );
      case MessageType.video:
        return _AttachmentPreview(
          message: message,
          bubbleText: bubbleText,
          icon: Icons.videocam_outlined,
        );
      case MessageType.file:
      case MessageType.voice:
        return _AttachmentPreview(
          message: message,
          bubbleText: bubbleText,
          icon: message.type == MessageType.voice
              ? Icons.mic_outlined
              : Icons.attach_file_outlined,
        );
      case MessageType.system:
        return const SizedBox.shrink();
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(
            color: bubbleText,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        );
    }
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.message,
    required this.bubbleText,
    required this.icon,
    this.showImage = false,
  });

  final Message message;
  final Color bubbleText;
  final IconData icon;
  final bool showImage;

  @override
  Widget build(BuildContext context) {
    final hasUrl = message.mediaUrl != null && message.mediaUrl!.isNotEmpty;

    return InkWell(
      onTap: hasUrl ? () => _openAttachment(message.mediaUrl!) : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showImage && hasUrl)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Image.network(
                message.mediaUrl!,
                width: 220,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _AttachmentFallback(
                    icon: icon,
                    title: message.fileName ?? message.content,
                    subtitle: 'Unable to load image',
                    color: bubbleText,
                  );
                },
              ),
            )
          else
            _AttachmentFallback(
              icon: icon,
              title: message.fileName ?? message.content,
              subtitle: [
                if (message.mimeType?.isNotEmpty == true) message.mimeType!,
                if ((message.fileSize ?? 0) > 0)
                  Formatters.formatAttachmentSize(message.fileSize),
              ].join(' • '),
              color: bubbleText,
            ),
          if (!_isAutoGeneratedLabel(message))
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSm),
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
        ],
      ),
    );
  }

  bool _isAutoGeneratedLabel(Message message) {
    final content = message.content.trim().toLowerCase();
    return content == 'photo' || content == 'video';
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _AttachmentFallback extends StatelessWidget {
  const _AttachmentFallback({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacingXs),
                    child: Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.86),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
