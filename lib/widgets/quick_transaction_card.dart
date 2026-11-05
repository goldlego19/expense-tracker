import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ledger.dart';
import '../services/auth_service.dart';
import '../services/ledger_store.dart';
import 'glass_panel.dart';

class QuickTransactionCard extends StatefulWidget {
  const QuickTransactionCard({
    super.key,
    required this.store,
    required this.accounts,
    required this.userId,
  });
  final LedgerStore store;
  final List<BankAccount> accounts;
  final String userId;
  @override
  State<QuickTransactionCard> createState() => _QuickTransactionCardState();
}

class _QuickTransactionCardState extends State<QuickTransactionCard> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _accountId;
  String _kind = 'expense';
  bool _busy = false;
  bool _selectionChanged = false;
  String? _error;
  String get _preferenceKey => 'quickTransactionAccount:${widget.userId}';
  @override
  void initState() {
    super.initState();
    unawaited(_restoreAccount());
  }

  Future<void> _restoreAccount() async {
    try {
      final id = await SharedPreferencesAsync().getString(_preferenceKey);
      if (mounted && !_selectionChanged) setState(() => _accountId = id);
    } catch (_) {
      /* The widget still works when preferences are unavailable. */
    }
  }

  Future<void> _rememberAccount(String id) async {
    try {
      await SharedPreferencesAsync().setString(_preferenceKey, id);
    } catch (_) {
      /* Keep the choice for this session. */
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(String accountId) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.saveEntry(
        kind: _kind,
        accountId: accountId,
        amountCents: parseMoney(_amount.text)!,
        category: 'Other',
        note: _note.text,
        date: DateTime.now(),
      );
      if (!mounted) return;
      _amount.clear();
      _note.clear();
      final name =
          widget.accounts.where((a) => a.id == accountId).firstOrNull?.name ??
          'account';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Transaction saved to $name.')));
      unawaited(_rememberAccount(accountId));
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.accounts
        .where((account) => !account.archived)
        .toList();
    final selected = active.any((account) => account.id == _accountId)
        ? _accountId
        : active.firstOrNull?.id;
    return GlassPanel(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PanelHeading(
              title: 'Quick transaction',
              icon: Icons.add_card_outlined,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add an expense or income to a specific account. Saved under Other; use Add transaction for categories, transfers and dates.',
            ),
            const SizedBox(height: 16),
            if (active.isEmpty)
              const Text('Add an account to start recording transactions.')
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey(selected),
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Transaction account',
                ),
                items: active
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (id) {
                        if (id == null) return;
                        _selectionChanged = true;
                        setState(() => _accountId = id);
                        unawaited(_rememberAccount(id));
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Quick transaction type',
                ),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                ],
                onChanged: _busy
                    ? null
                    : (kind) => setState(() => _kind = kind!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Quick amount (€)',
                ),
                validator: (value) => (parseMoney(value ?? '') ?? 0) <= 0
                    ? 'Enter a positive amount with up to 2 decimals'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                enabled: !_busy,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Transaction name or note (optional)',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _busy ? null : () => _save(selected!),
                icon: const Icon(Icons.add),
                label: Text(_busy ? 'Saving…' : 'Save transaction'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
