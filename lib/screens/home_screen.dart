import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ledger.dart';
import '../services/auth_service.dart';
import '../services/ledger_store.dart';
import '../widgets/editors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});
  final User user;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final LedgerStore _store = LedgerStore(widget.user.uid);
  late final Stream<List<BankAccount>> _accounts = _store.watchAccounts();
  late final Stream<List<LedgerEntry>> _entries = _store.watchEntries();
  int _tab = 0;
  String? _filterAccount;
  String _filterKind = 'all';
  bool _showArchived = false;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<BankAccount>>(
    stream: _accounts,
    builder: (context, accountsSnapshot) => StreamBuilder<List<LedgerEntry>>(
      stream: _entries,
      builder: (context, entriesSnapshot) {
        final accounts = accountsSnapshot.data ?? [];
        final entries = entriesSnapshot.data ?? [];
        final ready =
            accountsSnapshot.hasData &&
            entriesSnapshot.hasData &&
            !accountsSnapshot.hasError &&
            !entriesSnapshot.hasError;
        final active = accounts.where((a) => !a.archived).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pocket Ledger'),
            actions: [
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => _action(AuthService.signOut),
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: !ready
              ? Center(
                  child: accountsSnapshot.hasError || entriesSnapshot.hasError
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            friendlyError(
                              accountsSnapshot.error ?? entriesSnapshot.error!,
                            ),
                          ),
                        )
                      : const CircularProgressIndicator(),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1050),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                      children: [
                        if (_tab == 0) ..._overview(accounts, entries),
                        if (_tab == 1) ..._transactions(accounts, entries),
                        if (_tab == 2) ..._accountSettings(accounts, entries),
                      ],
                    ),
                  ),
                ),
          floatingActionButton: !ready
              ? null
              : FloatingActionButton.extended(
                  onPressed: () {
                    if (_tab == 2 || active.isEmpty) {
                      editAccount(context, _store);
                    } else {
                      editEntry(context, _store, active);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    _tab == 2 || active.isEmpty
                        ? 'Add account'
                        : 'Add transaction',
                  ),
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Transactions',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_outlined),
                label: 'Accounts',
              ),
            ],
          ),
        );
      },
    ),
  );
  List<Widget> _overview(
    List<BankAccount> accounts,
    List<LedgerEntry> entries,
  ) {
    final net = accounts.fold(0, (sum, a) => sum + accountBalance(a, entries));
    final monthly = entries.where(
      (e) => e.date.year == _month.year && e.date.month == _month.month,
    );
    final income = monthly
        .where((e) => e.kind == 'income')
        .fold(0, (sum, e) => sum + e.amountCents);
    final spending = monthly
        .where((e) => e.kind == 'expense')
        .fold(0, (sum, e) => sum + e.amountCents);
    final byCategory = <String, int>{};
    for (final e in monthly.where((e) => e.kind == 'expense')) {
      byCategory.update(
        e.category,
        (v) => v + e.amountCents,
        ifAbsent: () => e.amountCents,
      );
    }
    final breakdown = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      Text(
        'Hello, ${widget.user.displayName?.split(' ').first ?? 'there'}',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      const Text('Your accounts, in one place.'),
      const SizedBox(height: 24),
      Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NET WORTH · EUR'),
              const SizedBox(height: 8),
              Text(money(net), style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              const Text('All accounts, including loans and archived balances'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _monthPicker(),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metric('Income', income, Colors.teal),
          _metric('Expenses', spending, Colors.deepOrange),
          _metric('Cash flow', income - spending, Colors.blueGrey),
        ],
      ),
      const SizedBox(height: 24),
      Text('Your accounts', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (accounts.where((a) => !a.archived).isEmpty)
        const _Empty(
          icon: Icons.account_balance_outlined,
          title: 'Start with your first account',
          message: 'Add your bank balance, then record income, expenses and transfers.',
        ),
      ...accounts
          .where((a) => !a.archived)
          .map((a) => _accountCard(a, entries)),
      const SizedBox(height: 24),
      Text(
        'Spending by category',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      if (breakdown.isEmpty) const Text('No expenses recorded for this month.'),
      ...breakdown.map(
        (c) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(c.key)),
                    Text(money(c.value)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: spending == 0 ? 0 : c.value / spending,
                  minHeight: 6,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Recent transactions',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (entries.isEmpty)
        const Text('Your recorded transactions will appear here.'),
      ...entries.take(5).map((e) => _entryTile(e, accounts)),
    ];
  }

  Widget _metric(String label, int cents, Color color) => SizedBox(
    width: 225,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(
              money(cents),
              style: TextStyle(
                fontSize: 24,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _monthPicker() => Row(
    children: [
      IconButton(
        tooltip: 'Previous month',
        onPressed: () =>
            setState(() => _month = DateTime(_month.year, _month.month - 1)),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Text(
          '${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][_month.month - 1]} ${_month.year}',
          textAlign: TextAlign.center,
        ),
      ),
      IconButton(
        tooltip: 'Next month',
        onPressed: () =>
            setState(() => _month = DateTime(_month.year, _month.month + 1)),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
  List<Widget> _transactions(
    List<BankAccount> accounts,
    List<LedgerEntry> entries,
  ) {
    final filtered = entries
        .where(
          (e) =>
              e.date.year == _month.year &&
              e.date.month == _month.month &&
              (_filterKind == 'all' || e.kind == _filterKind) &&
              (_filterAccount == null ||
                  e.accountId == _filterAccount ||
                  e.targetId == _filterAccount),
        )
        .toList();
    return [
      Text('Transactions', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      _monthPicker(),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _filterAccount ?? 'all',
        decoration: const InputDecoration(labelText: 'Account'),
        items: [
          const DropdownMenuItem(value: 'all', child: Text('All accounts')),
          ...accounts.map(
            (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
          ),
        ],
        onChanged: (v) =>
            setState(() => _filterAccount = v == 'all' ? null : v),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _filterKind,
        decoration: const InputDecoration(labelText: 'Type'),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All types')),
          DropdownMenuItem(value: 'expense', child: Text('Expenses')),
          DropdownMenuItem(value: 'income', child: Text('Income')),
          DropdownMenuItem(value: 'transfer', child: Text('Transfers')),
        ],
        onChanged: (v) => setState(() => _filterKind = v!),
      ),
      const SizedBox(height: 20),
      if (filtered.isEmpty)
        const _Empty(
          icon: Icons.receipt_long_outlined,
          title: 'No transactions here yet',
          message: 'Add a transaction or choose a different month or filter.',
        ),
      ...filtered.map((e) => _entryTile(e, accounts)),
    ];
  }

  Widget _entryTile(LedgerEntry e, List<BankAccount> accounts) {
    String name(String? id) =>
        accounts.where((a) => a.id == id).firstOrNull?.name ??
        'Unknown account';
    final archived = accounts.any(
      (a) => (a.id == e.accountId || a.id == e.targetId) && a.archived,
    );
    final color = e.kind == 'income'
        ? Colors.teal
        : e.kind == 'expense'
        ? Colors.deepOrange
        : Colors.blueGrey;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            e.kind == 'transfer'
                ? Icons.swap_horiz
                : e.kind == 'income'
                ? Icons.south_west
                : Icons.north_east,
            color: color,
          ),
        ),
        title: Text(
          e.note.isEmpty
              ? e.kind == 'transfer'
                    ? 'Transfer'
                    : e.category
              : e.note,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${dateLabel(e.date)} · ${name(e.accountId)}${e.kind == 'transfer' ? ' → ${name(e.targetId)}' : '\n${e.category}'}',
        ),
        isThreeLine: e.kind != 'transfer',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${e.kind == 'income'
                  ? '+'
                  : e.kind == 'expense'
                  ? '-'
                  : ''}${money(e.amountCents)}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            PopupMenuButton<String>(
              tooltip: 'Transaction actions',
              onSelected: (v) async {
                if (v == 'edit') {
                  await editEntry(
                    context,
                    _store,
                    accounts.where((a) => !a.archived).toList(),
                    e,
                  );
                } else if (await _confirm(
                  'Delete transaction?',
                  'This removes the entry and recalculates the affected balances.',
                )) {
                  await _action(() => _store.deleteEntry(e.id));
                }
              },
              itemBuilder: (_) => [
                if (!archived)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _accountSettings(
    List<BankAccount> accounts,
    List<LedgerEntry> entries,
  ) => [
    Text('Account settings', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 8),
    const Text(
      'Add accounts and manage your opening balances. All amounts use EUR.',
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Show archived accounts'),
      value: _showArchived,
      onChanged: (v) => setState(() => _showArchived = v),
    ),
    if (accounts.where((a) => !a.archived || _showArchived).isEmpty)
      const _Empty(
        icon: Icons.account_balance_outlined,
        title: 'No accounts to show',
        message: 'Add a current, savings, joint or loan account.',
      ),
    ...accounts
        .where((a) => !a.archived || _showArchived)
        .map((a) => _accountCard(a, entries, editable: true)),
    const SizedBox(height: 24),
    const Text(
      'Opening balances are your starting point. To update a balance later, record the missing income or expense, or edit the opening balance. Archived accounts retain their history and remain in net worth.',
    ),
  ];
  Widget _accountCard(
    BankAccount a,
    List<LedgerEntry> entries, {
    bool editable = false,
  }) => Card(
    child: ListTile(
      leading: Icon(
        a.type == 'Loan'
            ? Icons.credit_card
            : a.type == 'Savings'
            ? Icons.savings_outlined
            : a.type == 'Joint'
            ? Icons.people_outline
            : Icons.account_balance_outlined,
      ),
      title: Text(a.name),
      subtitle: Text('${a.type}${a.archived ? ' · Archived' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            money(accountBalance(a, entries)),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (editable)
            PopupMenuButton<String>(
              tooltip: 'Account actions',
              onSelected: (v) async {
                if (v == 'edit') {
                  await editAccount(context, _store, a);
                } else if (await _confirm(
                  a.archived ? 'Restore account?' : 'Archive account?',
                  a.archived
                      ? 'This account will be available for new transactions again.'
                      : 'History and balance are kept. Restore the account to add or edit its transactions.',
                )) {
                  await _action(() => _store.archiveAccount(a));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit account')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(a.archived ? 'Restore' : 'Archive'),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}
