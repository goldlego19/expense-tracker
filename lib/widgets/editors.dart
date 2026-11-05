import 'package:flutter/material.dart';

import '../models/ledger.dart';
import '../services/auth_service.dart';
import '../services/ledger_store.dart';
import 'motion.dart';

Future<void> editAccount(
  BuildContext context,
  LedgerStore store, [
  BankAccount? account,
]) => showLedgerEditor(context, AccountEditor(store: store, account: account));
Future<void> editEntry(
  BuildContext context,
  LedgerStore store,
  List<BankAccount> accounts, [
  LedgerEntry? entry,
  String initialKind = 'expense',
  String? initialAccountId,
]) => showLedgerEditor(
  context,
  EntryEditor(
    store: store,
    accounts: accounts,
    entry: entry,
    initialKind: initialKind,
    initialAccountId: initialAccountId,
  ),
);

class AccountEditor extends StatefulWidget {
  const AccountEditor({super.key, required this.store, this.account});
  final LedgerStore store;
  final BankAccount? account;
  @override
  State<AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<AccountEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late String _type;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _type = a?.type ?? 'Current';
    _name = TextEditingController(text: a?.name ?? '');
    _balance = TextEditingController(
      text: moneyInput(
        a == null
            ? 0
            : a.type == 'Loan'
            ? -a.openingCents
            : a.openingCents,
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cents = parseMoney(_balance.text)!;
      await widget.store.saveAccount(
        id: widget.account?.id,
        name: _name.text,
        type: _type,
        openingCents: normalizeCents(_type == 'Loan' ? -cents : cents),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.account == null ? 'Add account' : 'Edit account'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Account name',
                  hintText: 'e.g. BOV Current',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter an account name'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Account type'),
                items: accountTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: _type == 'Loan'
                      ? 'Opening debt (€)'
                      : 'Opening balance (€)',
                ),
                validator: (v) {
                  final amount = parseMoney(v ?? '');
                  if (amount == null)
                    return 'Enter an amount with up to 2 decimals';
                  if (_type == 'Loan' && amount < 0)
                    return 'Enter debt as a positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                widget.account == null
                    ? 'Enter the amount you have now. Record subsequent transactions from this starting point.'
                    : 'Changing the opening amount also changes the calculated current balance. Existing transactions are kept.',
              ),
              if (_type == 'Loan')
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Debt reduces net worth. Record repayments as transfers from your paying account to this loan.',
                  ),
                ),
              if (_type == 'Joint')
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Joint is a label. Sharing with another login is not enabled.',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Saving…' : 'Save account'),
      ),
    ],
  );
}

class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    required this.store,
    required this.accounts,
    this.entry,
    this.initialKind = 'expense',
    this.initialAccountId,
  });
  final LedgerStore store;
  final List<BankAccount> accounts;
  final LedgerEntry? entry;
  final String initialKind;
  final String? initialAccountId;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _kind;
  late String _accountId;
  String? _targetId;
  late String _category;
  late DateTime _date;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _amount = TextEditingController(
      text: e == null ? '' : moneyInput(e.amountCents),
    );
    _note = TextEditingController(text: e?.note ?? '');
    _kind = e?.kind ?? widget.initialKind;
    _accountId =
        e?.accountId ??
        (widget.accounts.any((account) => account.id == widget.initialAccountId)
            ? widget.initialAccountId!
            : widget.accounts.first.id);
    _targetId = e?.targetId;
    _category = e?.category ?? categories.first;
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.saveEntry(
        id: widget.entry?.id,
        kind: _kind,
        accountId: _accountId,
        targetId: _targetId,
        amountCents: parseMoney(_amount.text)!,
        category: _kind == 'transfer' ? 'Other' : _category,
        note: _note.text,
        date: _date,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.entry == null ? 'Add transaction' : 'Edit transaction'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                  DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                ],
                onChanged: _busy ? null : (v) => setState(() => _kind = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _kind == 'transfer' ? 'From account' : 'Account',
                ),
                items: widget.accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _accountId = v!),
              ),
              if (_kind == 'transfer') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _targetId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'To account'),
                  items: widget.accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _targetId = v),
                  validator: (v) => v == null
                      ? 'Choose a destination'
                      : v == _accountId
                      ? 'Choose a different account'
                      : null,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Amount (€)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  final cents = parseMoney(v ?? '');
                  return cents == null || cents <= 0
                      ? 'Enter a positive amount with up to 2 decimals'
                      : null;
                },
              ),
              if (_kind != 'transfer') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _category = v!),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(dateLabel(_date)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _busy
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null && mounted)
                          setState(() => _date = date);
                      },
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Saving…' : 'Save transaction'),
      ),
    ],
  );
}
