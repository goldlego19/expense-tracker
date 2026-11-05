import 'package:flutter/material.dart';

import '../models/ledger.dart';
import '../models/recurring_rule.dart';
import '../services/auth_service.dart';
import '../services/ledger_store.dart';
import 'motion.dart';

Future<void> editRecurringRule(
  BuildContext context,
  LedgerStore store,
  List<BankAccount> accounts, [
  RecurringRule? rule,
]) => showLedgerEditor(
  context,
  RecurringEditor(store: store, accounts: accounts, rule: rule),
);

class RecurringEditor extends StatefulWidget {
  const RecurringEditor({
    super.key,
    required this.store,
    required this.accounts,
    this.rule,
  });
  final LedgerStore store;
  final List<BankAccount> accounts;
  final RecurringRule? rule;
  @override
  State<RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<RecurringEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _amount;
  late String _account, _kind, _frequency, _category;
  late int _day, _weekday, _month;
  late DateTime _start, _end;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    final today = DateTime.now();
    _name = TextEditingController(text: r?.name ?? '');
    _amount = TextEditingController(
      text: r == null ? '' : moneyInput(r.amountCents),
    );
    _account = widget.accounts.any((a) => a.id == r?.accountId)
        ? r!.accountId
        : widget.accounts.first.id;
    _kind = r?.kind ?? 'expense';
    _frequency = r?.frequency ?? 'monthly';
    _category = r?.category ?? 'Bills';
    _day = r?.dayOfMonth ?? 15;
    _weekday = r?.weekday ?? today.weekday;
    _month = r?.month ?? today.month;
    _start = r == null
        ? DateTime(today.year, today.month, today.day)
        : DateTime.parse(r.startDate);
    _end = r == null
        ? DateTime(today.year + 1, today.month, today.day)
        : DateTime.parse(r.endDate);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted)
      setState(() {
        if (start) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_end.isBefore(_start)) {
      setState(() => _error = 'End date must be on or after the start date.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.saveRecurringRule(
        id: widget.rule?.id,
        name: _name.text,
        accountId: _account,
        kind: _kind,
        amountCents: parseMoney(_amount.text)!,
        category: _category,
        frequency: _frequency,
        dayOfMonth: _day,
        weekday: _weekday,
        month: _month,
        startDate: calendarDate(_start),
        endDate: calendarDate(_end),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _numberPicker(
    String label,
    int value,
    int count,
    ValueChanged<int> onChanged, {
    List<String>? names,
  }) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: List.generate(
      count,
      (i) => DropdownMenuItem(
        value: i + 1,
        child: Text(names == null ? '${i + 1}' : names[i]),
      ),
    ),
    onChanged: _busy ? null : (value) => onChanged(value!),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.rule == null
          ? 'New recurring transaction'
          : 'Edit recurring transaction',
    ),
    content: SizedBox(
      width: 460,
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
                  labelText: 'Transaction name',
                  hintText: 'e.g. Monthly insurance',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a transaction name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(
                  labelText: 'Amount (€)',
                  hintText: '96.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) => (parseMoney(value ?? '') ?? 0) <= 0
                    ? 'Enter a positive amount with up to 2 decimals'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _account,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Account'),
                items: widget.accounts
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
                    : (value) => setState(() => _account = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Transaction type',
                ),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _kind = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: frequencies
                    .map(
                      (frequency) => DropdownMenuItem(
                        value: frequency,
                        child: Text(
                          '${frequency[0].toUpperCase()}${frequency.substring(1)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _frequency = value!),
              ),
              if (_frequency == 'weekly') ...[
                const SizedBox(height: 16),
                _numberPicker(
                  'Payment weekday',
                  _weekday,
                  7,
                  (value) => setState(() => _weekday = value),
                  names: weekdayNames,
                ),
              ],
              if (_frequency == 'yearly') ...[
                const SizedBox(height: 16),
                _numberPicker(
                  'Payment month',
                  _month,
                  12,
                  (value) => setState(() => _month = value),
                  names: monthNames,
                ),
              ],
              if (_frequency == 'monthly' || _frequency == 'yearly') ...[
                const SizedBox(height: 16),
                _numberPicker(
                  'Payment day',
                  _day,
                  31,
                  (value) => setState(() => _day = value),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Start date'),
                subtitle: Text(dateLabel(_start)),
                onTap: _busy ? null : () => _pickDate(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('End date (inclusive)'),
                subtitle: Text(dateLabel(_end)),
                onTap: _busy ? null : () => _pickDate(false),
              ),
              const Text(
                'Schedule uses Europe/Malta time. Days 29–31 use the last day in shorter months. New rules, edits and resumes apply from today; earlier payments are not backfilled.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Records tracker transactions only. No money is moved at your bank. Due payments are recorded when you open or resume the app online. Payments catch up after the app has been closed.',
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
        child: Text(_busy ? 'Saving…' : 'Save rule'),
      ),
    ],
  );
}
