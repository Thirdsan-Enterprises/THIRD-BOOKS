// AttachmentPanel — offline-first multi-file attachment widget.
// Files are copied to local app storage immediately on pick and are always
// visible regardless of connectivity. Server upload is a background concern.
// © 2026 ThirdBooks. All rights reserved.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../providers/local_attachments_provider.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// AttachmentPanel
// ---------------------------------------------------------------------------
/// Embed this widget in any create/detail dialog or screen.
///
/// Both new and existing records use the same API — always pass the local UUID:
///
///   AttachmentPanel(
///     attachableType: 'bill',
///     localRecordId: billId,   // UUID — always available before sync
///   )
///
/// No GlobalKey, no uploadPending(), no server ID required up-front.
class AttachmentPanel extends ConsumerWidget {
  final String attachableType;
  final String localRecordId;
  final bool readOnly;

  const AttachmentPanel({
    super.key,
    required this.attachableType,
    required this.localRecordId,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref
        .watch(localAttachmentsProvider)
        .where((a) =>
            a.attachableType == attachableType &&
            a.localRecordId == localRecordId)
        .toList();

    final theme = Theme.of(context);
    final count = attachments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ─────────────────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.attach_file, size: 16),
            const SizedBox(width: 6),
            Text(
              'Attachments${count > 0 ? ' ($count)' : ''}',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (!readOnly)
              TextButton.icon(
                onPressed: () => _pickFiles(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Files'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Empty state ─────────────────────────────────────────────────────
        if (attachments.isEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 18, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'No attachments yet. Tap "Add Files" to attach receipts, PDFs, or images.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              ],
            ),
          )

        // ── Attachment list ─────────────────────────────────────────────────
        else
          Column(
            children: attachments
                .map((att) => _AttachmentTile(
                      attachment: att,
                      readOnly: readOnly,
                      onDelete: () => _confirmDelete(context, ref, att),
                      onOpen: () => _openFile(context, att),
                    ))
                .toList(),
          ),
      ],
    );
  }

  // ── Pick files and store locally ─────────────────────────────────────────
  Future<void> _pickFiles(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'jpg', 'jpeg', 'png', 'gif',
        'xlsx', 'xls', 'csv', 'doc', 'docx', 'txt',
      ],
      allowMultiple: true,
      dialogTitle: 'Attach Files',
      withData: false, // we only need the path, not the bytes in memory
    );
    if (result == null || result.files.isEmpty) return;

    final notifier = ref.read(localAttachmentsProvider.notifier);
    const uuid = Uuid();

    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;

      await notifier.addFromPath(
        id: uuid.v4(),
        attachableType: attachableType,
        localRecordId: localRecordId,
        sourcePath: path,
        fileName: file.name,
        mimeType: _mimeFromName(file.name),
        fileSize: file.size,
      );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${result.files.length} file${result.files.length == 1 ? '' : 's'} attached'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ── Open a file using the OS default application ─────────────────────────
  Future<void> _openFile(BuildContext context, LocalAttachment att) async {
    final file = File(att.localPath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('File not found on this device.'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [att.localPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [att.localPath]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [att.localPath]);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open file: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Confirm and delete ────────────────────────────────────────────────────
  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, LocalAttachment att) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Attachment'),
        content: Text('Remove "${att.fileName}" from this record?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(localAttachmentsProvider.notifier).remove(att.id);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String? _mimeFromName(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'xls': 'application/vnd.ms-excel',
      'csv': 'text/csv',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
    };
    return map[ext];
  }
}

// ---------------------------------------------------------------------------
// Individual attachment tile
// ---------------------------------------------------------------------------
class _AttachmentTile extends StatelessWidget {
  final LocalAttachment attachment;
  final bool readOnly;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _AttachmentTile({
    required this.attachment,
    required this.readOnly,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final att = attachment;
    final isLocal = att.isLocal;

    final subtitle = [
      if (att.sizeHuman.isNotEmpty) att.sizeHuman,
      DateFormat('d MMM yyyy').format(att.createdAt),
    ].join('  •  ');

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(_iconFor(att.mimeType, att.fileName),
                size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    att.fileName,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isLocal
                    ? Colors.orange.withOpacity(0.12)
                    : Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isLocal
                      ? Colors.orange.withOpacity(0.5)
                      : Colors.green.withOpacity(0.5),
                ),
              ),
              child: Text(
                isLocal ? 'Local' : 'Synced',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isLocal ? Colors.orange[700] : Colors.green[700],
                ),
              ),
            ),
            if (!readOnly) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.error,
                tooltip: 'Remove attachment',
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? mime, String name) {
    if (mime?.contains('pdf') == true || name.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (mime?.contains('image') == true) return Icons.image_outlined;
    if (name.endsWith('.xlsx') ||
        name.endsWith('.xls') ||
        name.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    if (name.endsWith('.doc') || name.endsWith('.docx')) {
      return Icons.article_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}
