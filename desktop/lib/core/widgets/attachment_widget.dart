// AttachmentPanel — reusable multi-file attachment widget
// Supports pending (local) files before a record is saved, and
// uploaded files fetched from the API for existing records.
// © 2026 ThirdBooks. All rights reserved.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Model for an already-uploaded attachment returned from the API
// ---------------------------------------------------------------------------
class UploadedAttachment {
  final int id;
  final String fileName;
  final String? label;
  final int? fileSize;
  final String? url;
  final String? mimeType;
  final String uploadedAt;

  const UploadedAttachment({
    required this.id,
    required this.fileName,
    this.label,
    this.fileSize,
    this.url,
    this.mimeType,
    required this.uploadedAt,
  });

  factory UploadedAttachment.fromJson(Map<String, dynamic> j) =>
      UploadedAttachment(
        id: j['id'] as int,
        fileName: j['file_name'] as String,
        label: j['label'] as String?,
        fileSize: j['file_size'] as int?,
        url: j['url'] as String?,
        mimeType: j['mime_type'] as String?,
        uploadedAt: j['created_at'] as String? ?? '',
      );

  String get sizeHuman {
    final b = fileSize ?? 0;
    if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '$b B';
  }
}

// ---------------------------------------------------------------------------
// AttachmentPanel
// ---------------------------------------------------------------------------
/// Embed this widget in any create/detail dialog.
///
/// Usage — new record:
///   final _attachKey = GlobalKey<AttachmentPanelState>();
///   AttachmentPanel(key: _attachKey, attachableType: 'bill')
///   // After record created:
///   await _attachKey.currentState?.uploadPending(newRecordId, apiClient);
///
/// Usage — existing record:
///   AttachmentPanel(
///     attachableType: 'invoice',
///     attachableId: invoice.id,
///     apiClient: apiClient,
///   )
class AttachmentPanel extends StatefulWidget {
  final String attachableType; // 'invoice' | 'bill' | 'journal-entry' | 'bill-payment' | 'payment'
  final int? attachableId;     // null when creating a new record
  final ApiClient? apiClient;
  final bool readOnly;

  const AttachmentPanel({
    super.key,
    required this.attachableType,
    this.attachableId,
    this.apiClient,
    this.readOnly = false,
  });

  @override
  State<AttachmentPanel> createState() => AttachmentPanelState();
}

class AttachmentPanelState extends State<AttachmentPanel> {
  // Files picked locally but not yet uploaded (only while creating a new record)
  final List<PlatformFile> _pending = [];

  // Files already uploaded and returned from the API
  final List<UploadedAttachment> _uploaded = [];

  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.attachableId != null && widget.apiClient != null) {
      _loadAttachments();
    }
  }

  // ── Load existing attachments from API ────────────────────────────────────
  Future<void> _loadAttachments() async {
    if (widget.apiClient == null || widget.attachableId == null) return;
    setState(() => _isLoading = true);
    try {
      final resp = await widget.apiClient!.get(
        '/attachments',
        queryParameters: {
          'type': widget.attachableType,
          'attachable_id': widget.attachableId,
        },
      );
      if (resp.statusCode == 200) {
        final data = resp.data['data'] as List? ?? resp.data as List? ?? [];
        setState(() {
          _uploaded.clear();
          _uploaded.addAll(data
              .cast<Map<String, dynamic>>()
              .map(UploadedAttachment.fromJson));
        });
      }
    } catch (_) {
      // Network not available — silently skip
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Pick multiple local files ─────────────────────────────────────────────
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'xlsx', 'xls', 'csv', 'doc', 'docx', 'txt'],
      allowMultiple: true,
      dialogTitle: 'Attach Files',
    );
    if (result == null) return;

    // If we already know the record ID and have an API client, upload immediately.
    if (widget.attachableId != null && widget.apiClient != null) {
      setState(() => _isUploading = true);
      try {
        final newAttachments = await widget.apiClient!.uploadAttachments(
          widget.attachableType,
          widget.attachableId!,
          result.files,
        );
        setState(() => _uploaded.addAll(newAttachments));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} file(s) uploaded'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // Upload failed — queue as pending so user can retry
        setState(() {
          for (final f in result.files) {
            if (!_pending.any((p) => p.name == f.name)) _pending.add(f);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed (offline?): $e'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        setState(() => _isUploading = false);
      }
    } else {
      // New record — queue files; parent calls uploadPending() after save
      setState(() {
        for (final f in result.files) {
          if (!_pending.any((p) => p.name == f.name)) _pending.add(f);
        }
      });
    }
  }

  // ── Upload pending files manually (for create dialogs, or retry) ──────────
  Future<void> _uploadPendingNow() async {
    if (_pending.isEmpty || widget.attachableId == null || widget.apiClient == null) return;
    setState(() => _isUploading = true);
    try {
      final newAttachments = await widget.apiClient!.uploadAttachments(
        widget.attachableType,
        widget.attachableId!,
        _pending,
      );
      setState(() {
        _uploaded.addAll(newAttachments);
        _pending.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ── Remove a pending (not-yet-uploaded) file ──────────────────────────────
  void _removePending(PlatformFile f) {
    setState(() => _pending.remove(f));
  }

  // ── Delete an uploaded attachment via API ─────────────────────────────────
  Future<void> _deleteUploaded(UploadedAttachment att) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Attachment'),
        content: Text('Remove "${att.fileName}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (widget.apiClient != null) {
        await widget.apiClient!.delete('/attachments/${att.id}');
      }
      setState(() => _uploaded.remove(att));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment deleted'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ── Upload all pending files (called by parent after record is saved) ─────
  Future<void> uploadPending(int recordId, ApiClient apiClient) async {
    if (_pending.isEmpty) return;
    setState(() => _isUploading = true);
    try {
      final newAttachments = await apiClient.uploadAttachments(
        widget.attachableType,
        recordId,
        _pending,
      );
      setState(() {
        _uploaded.addAll(newAttachments);
        _pending.clear();
      });
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ── Returns true if there are pending files ready to upload ──────────────
  bool get hasPending => _pending.isNotEmpty;

  int get totalCount => _pending.length + _uploaded.length;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Icon(Icons.attach_file, size: 16),
            const SizedBox(width: 6),
            Text(
              'Attachments${totalCount > 0 ? ' ($totalCount)' : ''}',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (widget.attachableId != null && widget.apiClient != null)
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Reload attachments',
                onPressed: _isLoading ? null : _loadAttachments,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            // Hide "Add Files" when existing record hasn't synced (no server ID to attach to)
            if (!widget.readOnly &&
                !(widget.attachableId == null && widget.apiClient != null))
              TextButton.icon(
                onPressed: _isUploading ? null : _pickFiles,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Files'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_uploaded.isEmpty && _pending.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Existing record that hasn't synced to the server yet
                if (widget.attachableId == null && widget.apiClient != null) ...[
                  Icon(Icons.sync_disabled, size: 18, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Sync this record to the server first, then you can attach and view files here.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                ] else ...[
                  Icon(Icons.cloud_upload_outlined, size: 18, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'No attachments yet. Click "Add Files" to attach receipts, PDFs, or images.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Column(
            children: [
              // Uploaded attachments
              ..._uploaded.map((att) => _AttachmentTile(
                    icon: _iconFor(att.mimeType, att.fileName),
                    name: att.fileName,
                    subtitle: '${att.sizeHuman}  •  ${att.label ?? _friendlyDate(att.uploadedAt)}',
                    trailing: widget.readOnly
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: AppColors.error,
                            tooltip: 'Delete attachment',
                            onPressed: () => _deleteUploaded(att),
                          ),
                    onTap: att.url != null ? () => _openOrCopyUrl(att.url!) : null,
                  )),
              // Pending (not yet uploaded) files
              ..._pending.map((f) => _AttachmentTile(
                    icon: _iconForPath(f.name),
                    name: f.name,
                    subtitle: _isUploading
                        ? 'Uploading…'
                        : '${_sizeHuman(f.size)}  •  Pending upload',
                    subtitleColor: _isUploading ? AppColors.primary : theme.colorScheme.outline,
                    trailing: _isUploading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Remove',
                            onPressed: () => _removePending(f),
                          ),
                  )),
              // "Upload now" bar — only shown when there are queued files and
              // we have a record ID + API client to upload them to
              if (_pending.isNotEmpty &&
                  widget.attachableId != null &&
                  widget.apiClient != null &&
                  !_isUploading)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: FilledButton.icon(
                    onPressed: _uploadPendingNow,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                    label: Text('Upload ${_pending.length} pending file(s)'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  IconData _iconFor(String? mime, String name) {
    if (mime?.contains('pdf') == true || name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (mime?.contains('image') == true) return Icons.image_outlined;
    if (name.endsWith('.xlsx') || name.endsWith('.xls') || name.endsWith('.csv')) return Icons.table_chart_outlined;
    if (name.endsWith('.doc') || name.endsWith('.docx')) return Icons.article_outlined;
    return Icons.insert_drive_file_outlined;
  }

  IconData _iconForPath(String name) => _iconFor(null, name);

  String _sizeHuman(int? bytes) {
    final b = bytes ?? 0;
    if (b >= 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '$b B';
  }

  String _friendlyDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat('d MMM yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _openOrCopyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File URL copied to clipboard — paste in your browser to open'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Individual attachment tile
// ---------------------------------------------------------------------------
class _AttachmentTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _AttachmentTile({
    required this.icon,
    required this.name,
    required this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  Text(subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: subtitleColor ?? theme.colorScheme.outline)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
