import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/ledger.dart';
import '../services/auth_service.dart';
import '../services/ledger_store.dart';
import '../services/client_recurring_scheduler.dart';
import '../widgets/editors.dart';
import '../widgets/quick_transaction_card.dart';
import '../widgets/account_order_editor.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import '../widgets/recurring_editor.dart';
import '../widgets/recurring_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});
  final User user;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ClientRecurringScheduler _scheduler = ClientRecurringScheduler(
    widget.user.uid,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduler.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduler.resume();
    } else {
      _scheduler.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduler.dispose();
    super.dispose();
  }

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

  void _openRule(List<BankAccount> accounts) {
    final active = accounts.where((account) => !account.archived).toList();
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an account first to set up recurring payments.'),
        ),
      );
      editAccount(context, _store);
      return;
    }
    editRecurringRule(context, _store, active);
  }

  void _openEntry(List<BankAccount> accounts, [String kind = 'expense']) {
    final active = accounts.where((a) => !a.archived).toList();
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an account first to record a transaction.'),
        ),
      );
      editAccount(context, _store);
      return;
    }
    if (kind == 'transfer' && active.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a second account to transfer money.'),
        ),
      );
      return;
    }
    editEntry(context, _store, active, null, kind);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<BankAccount>>(
    stream: _accounts,
    builder: (context, accountsSnapshot) => StreamBuilder<List<LedgerEntry>>(
      stream: _entries,
      builder: (context, entriesSnapshot) {
        final accounts = accountsSnapshot.data ?? <BankAccount>[];
        final entries = entriesSnapshot.data ?? <LedgerEntry>[];
        final ready =
            accountsSnapshot.hasData &&
            entriesSnapshot.hasData &&
            !accountsSnapshot.hasError &&
            !entriesSnapshot.hasError;
        final wide = MediaQuery.sizeOf(context).width >= 900;
        final page = !ready
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
            : AnimatedSwitcher(
                duration: motionDuration(context),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .025),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Align(
                  key: ValueKey('$_tab-${_month.year}-${_month.month}'),
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 36 : 20,
                        20,
                        wide ? 36 : 20,
                        120,
                      ),
                      children: [
                        if (_tab == 0) ..._overview(accounts, entries),
                        if (_tab == 1) ..._transactions(accounts, entries),
                        if (_tab == 2) ..._accountSettings(accounts, entries),
                        if (_tab == 3)
                          RecurringSection(
                            store: _store,
                            accounts: accounts,
                            scheduler: _scheduler,
                          ),
                      ],
                    ),
                  ),
                ),
              );
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Pocket Ledger',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.6,
                  ),
                ),
              ],
            ),
            actions: [
              const AppearanceButton(),
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => _action(AuthService.signOut),
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.transparent,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: Text('Overview'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Transactions'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_outlined),
                      selectedIcon: Icon(Icons.account_balance_rounded),
                      label: Text('Accounts'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.autorenew_rounded),
                      label: Text('Recurring'),
                    ),
                  ],
                ),
              Expanded(child: page),
            ],
          ),
          floatingActionButton: !ready
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _tab == 2
                      ? editAccount(context, _store)
                      : _tab == 3
                      ? _openRule(accounts)
                      : _openEntry(accounts),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    _tab == 2
                        ? 'Add account'
                        : _tab == 3
                        ? 'Add rule'
                        : 'Add transaction',
                  ),
                ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: 'Transactions',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_outlined),
                      selectedIcon: Icon(Icons.account_balance_rounded),
                      label: 'Accounts',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.autorenew_rounded),
                      label: 'Recurring',
                    ),
                  ],
                ),
        );
      },
    ),
  );

  Widget _quickActions(List<BankAccount> accounts) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      FilledButton.icon(
        onPressed: () => _openEntry(accounts),
        icon: const Icon(Icons.north_east_rounded),
        label: const Text('Expense'),
      ),
      OutlinedButton.icon(
        onPressed: () => _openEntry(accounts, 'income'),
        icon: const Icon(Icons.south_west_rounded),
        label: const Text('Income'),
      ),
      OutlinedButton.icon(
        onPressed: () => _openEntry(accounts, 'transfer'),
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Transfer'),
      ),
    ],
  );

  List<Widget> _overview(
    List<BankAccount> accounts,
    List<LedgerEntry> entries,
  ) {
    final net = totalBalance(accounts, entries);
    final withoutLoans = totalBalance(accounts, entries, includeLoans: false);
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
      Text(
        'Your money, with a little more clarity.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, constraints) {
          final withLoansCard = _balanceCard(
            title: 'NET WORTH INCLUDING LOANS',
            cents: net,
            subtitle: 'EUR · All account balances, including loan debt',
          );
          final withoutLoansCard = _balanceCard(
            title: 'BALANCE EXCLUDING LOANS',
            cents: withoutLoans,
            subtitle: 'EUR · Current, savings and joint accounts',
          );
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                withLoansCard,
                const SizedBox(height: 16),
                withoutLoansCard,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: withLoansCard),
              const SizedBox(width: 16),
              Expanded(child: withoutLoansCard),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      _quickActions(accounts),
      const SizedBox(height: 16),
      QuickTransactionCard(
        key: ValueKey(widget.user.uid),
        store: _store,
        accounts: accounts,
        userId: widget.user.uid,
      ),
      const SizedBox(height: 16),
      _monthPicker(),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metric('Income', income, incomeColor(context)),
          _metric('Expenses', spending, expenseColor(context)),
          _metric(
            'Cash flow',
            income - spending,
            Theme.of(context).colorScheme.primary,
          ),
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
          .map((a) => _accountCard(a, entries, accounts: accounts)),
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
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: spending == 0 ? 0 : c.value / spending,
                  ),
                  duration: motionDuration(context, 500),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                  ),
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

  Widget _balanceCard({
    required String title,
    required int cents,
    required String subtitle,
  }) => Reveal(
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xff164d47), Color(0xff142d46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xff7ce3c4).withValues(alpha: .25),
        ),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xffb4d7d0),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.insights_rounded, color: Color(0xff7ce3c4)),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedMoney(
              cents: cents,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(subtitle, style: const TextStyle(color: Color(0xffb4d7d0))),
          const SizedBox(height: 8),
          const Text(
            'Archived balances included',
            style: TextStyle(color: Color(0xffb4d7d0), fontSize: 11),
          ),
        ],
      ),
    ),
  );

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
            AnimatedMoney(
              cents: cents,
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
      _quickActions(accounts),
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
        ? incomeColor(context)
        : e.kind == 'expense'
        ? expenseColor(context)
        : Theme.of(context).colorScheme.primary;
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
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: accounts.length < 2
          ? null
          : () => editAccountOrder(context, accounts, _store.reorderAccounts),
      icon: const Icon(Icons.swap_vert),
      label: const Text('Reorder accounts'),
    ),
    const Card(
      child: ListTile(
        leading: Icon(Icons.palette_outlined),
        title: Text('Appearance'),
        subtitle: Text('Dark, light or your device theme'),
        trailing: AppearanceButton(),
      ),
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
        .map(
          (a) => _accountCard(a, entries, accounts: accounts, editable: true),
        ),
    const SizedBox(height: 24),
    const Text(
      'Opening balances are your starting point. To update a balance later, record the missing income or expense, or edit the opening balance. Archived accounts retain their history and remain in net worth.',
    ),
  ];
  Widget _accountCard(
    BankAccount a,
    List<LedgerEntry> entries, {
    required List<BankAccount> accounts,
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
      title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${a.type}${a.archived ? ' · Archived' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            money(accountBalance(a, entries)),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (!a.archived)
            IconButton(
              tooltip: 'Add transaction to ${a.name}',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => editEntry(
                context,
                _store,
                accounts.where((account) => !account.archived).toList(),
                null,
                'expense',
                a.id,
              ),
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
