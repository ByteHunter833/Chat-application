import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'avatar_widget.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final bool showTimestamp;
  final bool showSenderInfo;
  final VoidCallback? onReplyTap;
  final VoidCallback? onDeleteMedia;
  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.showTimestamp = true,
    this.showSenderInfo = false,
    this.onReplyTap,
    this.onDeleteMedia,
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

    final shouldShowSender = showSenderInfo && !isOwn;
    final senderName = _senderDisplayName(message);
    final bubbleColumn = Column(
      crossAxisAlignment: isOwn
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (shouldShowSender)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingSm,
              bottom: AppTheme.spacingXs,
            ),
            child: Text(
              senderName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
            isOwn: isOwn,
            onReplyTap: onReplyTap,
            onDeleteMedia: onDeleteMedia,
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
    );

    if (shouldShowSender) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppTheme.spacingLg,
          right: 60,
          top: AppTheme.spacingSm,
          bottom: AppTheme.spacingSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AvatarWidget(
              imageUrl: message.senderAvatar,
              initials: _getInitials(senderName),
              size: 32,
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Flexible(child: bubbleColumn),
          ],
        ),
      );
    }

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isOwn ? 60 : AppTheme.spacingLg,
          right: isOwn ? AppTheme.spacingLg : 60,
          top: AppTheme.spacingSm,
          bottom: AppTheme.spacingSm,
        ),
        child: bubbleColumn,
      ),
    );
  }

  String _senderDisplayName(Message message) {
    final name = message.senderName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final username = message.senderUsername?.trim();
    if (username != null && username.isNotEmpty) {
      return '@$username';
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

class _MessageBubbleContent extends StatelessWidget {
  const _MessageBubbleContent({
    required this.message,
    required this.bubbleText,
    required this.isOwn,
    this.onReplyTap,
    this.onDeleteMedia,
  });

  final Message message;
  final Color bubbleText;
  final bool isOwn;
  final VoidCallback? onReplyTap;
  final VoidCallback? onDeleteMedia;

  @override
  Widget build(BuildContext context) {
    final content = switch (message.type) {
      MessageType.image => _AttachmentPreview(
        message: message,
        bubbleText: bubbleText,
        icon: Icons.photo_outlined,
        showImage: true,
      ),
      MessageType.video => _AttachmentPreview(
        message: message,
        bubbleText: bubbleText,
        icon: Icons.videocam_outlined,
      ),
      MessageType.file || MessageType.voice => _AttachmentPreview(
        message: message,
        bubbleText: bubbleText,
        icon: message.type == MessageType.voice
            ? Icons.mic_outlined
            : Icons.attach_file_outlined,
      ),
      MessageType.system => const SizedBox.shrink(),
      MessageType.text => Text(
        message.content,
        style: TextStyle(
          color: bubbleText,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
      ),
    };

    final reply = message.replyTo;
    if (reply == null) {
      return content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReplyQuote(
          reply: reply,
          isOwn: isOwn,
          textColor: bubbleText,
          onTap: onReplyTap,
        ),
        const SizedBox(height: AppTheme.spacingSm),
        content,
      ],
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.reply,
    required this.isOwn,
    required this.textColor,
    this.onTap,
  });

  final MessageReply reply;
  final bool isOwn;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isOwn
        ? Colors.white.withValues(alpha: 0.16)
        : AppTheme.primary.withValues(alpha: 0.08);
    final titleColor = isOwn ? Colors.white : AppTheme.primary;
    final previewColor = isOwn
        ? Colors.white.withValues(alpha: 0.88)
        : textColor.withValues(alpha: 0.78);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
        padding: const EdgeInsets.all(AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: titleColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reply.senderDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (reply.type != MessageType.text) ...[
                        Icon(
                          _replyIcon(reply.type),
                          size: 14,
                          color: previewColor,
                        ),
                        const SizedBox(width: AppTheme.spacingXs),
                      ],
                      Flexible(
                        child: Text(
                          reply.previewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: previewColor,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _replyIcon(MessageType type) {
    return switch (type) {
      MessageType.image => Icons.photo_outlined,
      MessageType.video => Icons.videocam_outlined,
      MessageType.voice => Icons.mic_outlined,
      MessageType.file => Icons.attach_file_outlined,
      MessageType.system => Icons.info_outline,
      MessageType.text => Icons.notes_outlined,
    };
  }
}

class _AttachmentPreview extends ConsumerStatefulWidget {
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
  ConsumerState<_AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends ConsumerState<_AttachmentPreview> {
  late Future<String?> _mediaUrlFuture;

  @override
  void initState() {
    super.initState();
    _mediaUrlFuture = _resolveMediaUrl();
  }

  @override
  void didUpdateWidget(covariant _AttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.mediaUrl == widget.message.mediaUrl &&
        oldWidget.message.mediaStoragePath == widget.message.mediaStoragePath) {
      return;
    }

    _mediaUrlFuture = _resolveMediaUrl();
  }

  Future<String?> _resolveMediaUrl() async {
    final mediaUrl = widget.message.mediaUrl?.trim();
    final mediaStoragePath = widget.message.mediaStoragePath?.trim();
    if ((mediaUrl == null || mediaUrl.isEmpty) &&
        (mediaStoragePath == null || mediaStoragePath.isEmpty)) {
      return null;
    }

    try {
      return await ref
          .read(storageRepositoryProvider)
          .resolveMediaUrl(url: mediaUrl, storagePath: mediaStoragePath);
    } catch (_) {
      return mediaUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _mediaUrlFuture,
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data?.trim();
        final hasUrl = resolvedUrl != null && resolvedUrl.isNotEmpty;
        final cacheKey =
            widget.message.mediaStoragePath ??
            widget.message.mediaUrl ??
            resolvedUrl;
        final isResolvingUrl =
            snapshot.connectionState != ConnectionState.done &&
            ((widget.message.mediaUrl?.trim().isNotEmpty ?? false) ||
                (widget.message.mediaStoragePath?.trim().isNotEmpty ?? false));

        return InkWell(
          onTap: hasUrl ? () => _openAttachment(resolvedUrl) : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showImage && hasUrl)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: CachedNetworkImage(
                    imageUrl: resolvedUrl,
                    cacheKey: cacheKey,
                    key: ValueKey(cacheKey),
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) {
                      return _AttachmentFallback(
                        icon: widget.icon,
                        title:
                            widget.message.fileName ?? widget.message.content,
                        subtitle: 'Unable to load image',
                        color: widget.bubbleText,
                      );
                    },
                  ),
                )
              else
                _AttachmentFallback(
                  icon: widget.icon,
                  title: widget.message.fileName ?? widget.message.content,
                  subtitle: isResolvingUrl
                      ? 'Loading attachment...'
                      : [
                          if (widget.message.mimeType?.isNotEmpty == true)
                            widget.message.mimeType!,
                          if ((widget.message.fileSize ?? 0) > 0)
                            Formatters.formatAttachmentSize(
                              widget.message.fileSize,
                            ),
                        ].join(' • '),
                  color: widget.bubbleText,
                ),
              if (!_isAutoGeneratedLabel(widget.message))
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingSm),
                  child: Text(
                    widget.message.content,
                    style: TextStyle(
                      color: widget.bubbleText,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
