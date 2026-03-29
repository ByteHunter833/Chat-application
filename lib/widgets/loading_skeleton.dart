import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double? borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkTertiary : AppTheme.lightTertiary,
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark ? AppTheme.darkTertiary : AppTheme.lightTertiary,
                isDark
                    ? AppTheme.darkTertiary.withValues(alpha: 0.5)
                    : AppTheme.lightTertiary.withValues(alpha: 0.5),
                isDark ? AppTheme.darkTertiary : AppTheme.lightTertiary,
              ],
              stops: [0, _controller.value, 1],
            ),
          ),
        );
      },
    );
  }
}

class ChatTileSkeleton extends StatelessWidget {
  const ChatTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLg,
        vertical: AppTheme.spacingSm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: isDark ? AppTheme.darkShadow : AppTheme.lightShadow,
        ),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Row(
          children: [
            SkeletonLoader(
              width: 56,
              height: 56,
              borderRadius: AppTheme.radiusFull,
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(
                    width: 150,
                    height: 16,
                    borderRadius: AppTheme.radiusSm,
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  SkeletonLoader(
                    width: double.infinity,
                    height: 12,
                    borderRadius: AppTheme.radiusSm,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            SkeletonLoader(
              width: 24,
              height: 24,
              borderRadius: AppTheme.radiusFull,
            ),
          ],
        ),
      ),
    );
  }
}
