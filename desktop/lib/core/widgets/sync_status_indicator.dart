import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Static badge shown in the title bar indicating manual sync mode.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Manual sync — use Settings > Export Backup / Import Backup\nto share data between computers.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz, size: 16, color: AppColors.secondary),
            const SizedBox(width: 6),
            Text(
              'Manual Sync',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact version for status bar — same static badge, icon only.
class SyncStatusCompact extends StatelessWidget {
  const SyncStatusCompact({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.swap_horiz, size: 18, color: AppColors.secondary);
  }
}
