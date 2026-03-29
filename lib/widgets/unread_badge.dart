import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class UnreadBadge extends StatelessWidget {
  final int count;
  final double size;

  const UnreadBadge({super.key, required this.count, this.size = 24});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.error,
        boxShadow: AppTheme.lightShadow,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
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
