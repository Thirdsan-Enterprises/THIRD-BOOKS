// AccountSearchField — a tappable field that opens a searchable CoA picker dialog.
// Replaces plain DropdownButtonFormField<String> wherever accounts are selected.
// © 2026 ThirdBooks. All rights reserved.

import 'package:flutter/material.dart';
import '../models/account.dart';

class AccountSearchField extends StatelessWidget {
  final List<Account> accounts;

  /// Currently-selected account id (null = nothing selected).
  final String? value;

  final void Function(String? accountId) onChanged;
  final InputDecoration? decoration;
  final bool isDense;

  const AccountSearchField({
    super.key,
    required this.accounts,
    required this.onChanged,
    this.value,
    this.decoration,
    this.isDense = true,
  });

  Account? get _selected =>
      accounts.cast<Account?>().firstWhere((a) => a?.id == value, orElse: () => null);

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final dec = decoration ??
        InputDecoration(
          hintText: 'Select account',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: isDense,
          suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
        );

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => _openPicker(context),
      child: InputDecorator(
        decoration: dec,
        child: Text(
          selected != null ? '${selected.code} – ${selected.name}' : '',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: selected == null
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final searchCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final query = searchCtrl.text.toLowerCase();
          final filtered = query.isEmpty
              ? accounts
              : accounts
                  .where((a) =>
                      a.name.toLowerCase().contains(query) ||
                      a.code.toLowerCase().contains(query))
                  .toList();

          return AlertDialog(
            title: const Text('Select Account'),
            contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
            content: SizedBox(
              width: 420,
              height: 500,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search by name or code…',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                      ),
                      onChanged: (_) => setS(() {}),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No accounts match "$query"',
                              style: TextStyle(
                                  color:
                                      Theme.of(ctx).colorScheme.outline),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final acc = filtered[i];
                              final isSelected = acc.id == value;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Theme.of(ctx)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.08),
                                leading: SizedBox(
                                  width: 44,
                                  child: Text(
                                    acc.code,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(acc.name,
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(
                                  acc.type.name[0].toUpperCase() +
                                      acc.type.name.substring(1),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check,
                                        size: 16, color: Colors.green)
                                    : null,
                                onTap: () {
                                  onChanged(acc.id);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              if (value != null)
                TextButton(
                  onPressed: () {
                    onChanged(null);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Clear'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }
}
