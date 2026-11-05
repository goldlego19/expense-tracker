import 'package:flutter/material.dart';

import '../models/ledger.dart';
import '../models/recurring_rule.dart';
import '../services/auth_service.dart';
import '../services/ledger_store.dart';
import 'recurring_editor.dart';

class RecurringSection extends StatefulWidget {
  const RecurringSection({
    super.key,
    required this.store,
    required this.accounts,
  });
  final LedgerStore store;
  final List<BankAccount> accounts;
  @override
  State<RecurringSection> createState() => _RecurringSectionState();
}

class _RecurringSectionState extends State<RecurringSection> {
  late final Stream<List<RecurringRule>> _rules = widget.store
      .watchRecurringRules();
  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Recurring transactions',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'Set a payment once and let your tracker record it on schedule.',
      ),
      const SizedBox(height: 16),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Example: €96 from your chosen account on the 15th of each month, with an end date of 31 October 2028.\n\nSchedules use Malta time and run hourly at :15 after the server function is deployed. They record tracker entries only. No bank payment is made.',
          ),
        ),
      ),
      const SizedBox(height: 16),
      StreamBuilder<List<RecurringRule>>(
        stream: _rules,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Text(friendlyError(snapshot.error!));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final rules = snapshot.data!;
          if (rules.isEmpty)
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No recurring rules yet. Tap Add rule to get started.',
              ),
            );
          return Column(
            children: rules.map((rule) {
              final account = widget.accounts
                  .where((a) => a.id == rule.accountId)
                  .firstOrNull;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Switch(
                            value: rule.enabled,
                            onChanged: (enabled) => _action(
                              () => widget.store.setRecurringEnabled(
                                rule,
                                enabled,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${money(rule.amountCents)} · ${rule.kind == 'expense' ? 'Expense' : 'Income'} · ${account?.name ?? 'Unavailable account'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${rule.scheduleLabel}\n${rule.startDate} → ${rule.endDate} (inclusive)',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        !rule.enabled
                            ? 'Paused · missed dates are skipped on resume'
                            : rule.lastRunAt == null
                            ? 'Awaiting first server run · deploy scheduling if needed'
                            : 'Last server check: ${dateLabel(rule.lastRunAt!)}',
                      ),
                      if (rule.lastError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            rule.lastError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (account?.archived == true)
                        const Text(
                          'This account is archived. Payments will be skipped until it is restored.',
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: widget.accounts.every((a) => a.archived)
                                ? null
                                : () => editRecurringRule(
                                    context,
                                    widget.store,
                                    widget.accounts
                                        .where((a) => !a.archived)
                                        .toList(),
                                    rule,
                                  ),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete recurring rule?'),
                                  content: const Text(
                                    'Future payments stop. Previously recorded transactions stay in your history.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true)
                                await _action(
                                  () =>
                                      widget.store.deleteRecurringRule(rule.id),
                                );
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ],
  );
}
