import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;
  final bool isOnline;
  final VoidCallback? onTap;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.initials,
    this.size = 48,
    this.isOnline = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveImageUrl = (imageUrl?.trim().isEmpty ?? true)
        ? null
        : imageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.2),
              image: effectiveImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(effectiveImageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: effectiveImageUrl == null
                ? Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: size * 0.4,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
