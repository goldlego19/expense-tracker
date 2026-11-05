import 'package:flutter/material.dart';

import '../models/ledger.dart';
import '../services/auth_service.dart';
import 'motion.dart';

Future<void> editAccountOrder(
  BuildContext context,
  List<BankAccount> accounts,
  Future<void> Function(List<String>) onSave,
) => showLedgerEditor(
  context,
  AccountOrderEditor(accounts: accounts, onSave: onSave),
);

class AccountOrderEditor extends StatefulWidget {
  const AccountOrderEditor({
    super.key,
    required this.accounts,
    required this.onSave,
  });
  final List<BankAccount> accounts;
  final Future<void> Function(List<String>) onSave;
  @override
  State<AccountOrderEditor> createState() => _AccountOrderEditorState();
}

class _AccountOrderEditorState extends State<AccountOrderEditor> {
  late final List<BankAccount> _accounts = List.of(widget.accounts);
  bool _busy = false;
  String? _error;
  void _move(int oldIndex, int newIndex) {
    if (_busy || oldIndex == newIndex) return;
    setState(() {
      final account = _accounts.removeAt(oldIndex);
      _accounts.insert(newIndex, account);
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(_accounts.map((a) => a.id).toList());
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reorder accounts'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Drag the handles or use the arrows. This order is used throughout the app. Archived accounts keep their place.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * .42,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _accounts.length,
              onReorderItem: _move,
              itemBuilder: (context, index) {
                final account = _accounts[index];
                return ListTile(
                  key: ValueKey(account.id),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${account.type}${account.archived ? ' · Archived' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Move ${account.name} up',
                        onPressed: _busy || index == 0
                            ? null
                            : () => _move(index, index - 1),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      IconButton(
                        tooltip: 'Move ${account.name} down',
                        onPressed: _busy || index == _accounts.length - 1
                            ? null
                            : () => _move(index, index + 1),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        enabled: !_busy,
                        child: const Tooltip(
                          message: 'Drag to reorder',
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Saving…' : 'Save order'),
      ),
    ],
  );
}
