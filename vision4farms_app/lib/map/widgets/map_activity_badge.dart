import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class MapActivityBadge extends StatelessWidget {
  final int pendingCount;
  final int overdueCount;
  final VoidCallback onTap;

  const MapActivityBadge({
    super.key,
    required this.pendingCount,
    required this.overdueCount,
    required this.onTap,
  });

  int get total => pendingCount + overdueCount;
  bool get hasOverdue => overdueCount > 0;

  @override
  Widget build(BuildContext context) {
    final color = hasOverdue ? AppTheme.warning : AppTheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            total > 99 ? '99+' : total.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}