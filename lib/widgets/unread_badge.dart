import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class UnreadBadge extends StatelessWidget {
  final int count;
  final double size;

  const UnreadBadge({super.key, required this.count, this.size = 24});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    final label = count > 99 ? '99+' : count.toString();

    return Container(
      height: size,
      constraints: BoxConstraints(minWidth: size),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size),
        color: AppTheme.error,
        boxShadow: AppTheme.lightShadow,
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
