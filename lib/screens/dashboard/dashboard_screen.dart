import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/budget.dart';
import '../../models/money_entry.dart';
import '../../services/analysis_service.dart';
import '../../services/finance_repository.dart';
import '../../utils/date_utils.dart';
import '../../utils/money_formatter.dart';
import '../../widgets/amount_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<FinanceRepository>();

    return StreamBuilder<List<MoneyEntry>>(
      stream: repo.watchEntries(user.uid),
      builder: (context, entrySnapshot) {
        final entries = entrySnapshot.data ?? const <MoneyEntry>[];
        final now = DateTime.now();
        final monthEntries = AnalysisService.between(
          entries,
          AppDateUtils.startOfMonth(now),
          AppDateUtils.endOfMonth(now),
        );
        final summary = AnalysisService.summarize(monthEntries);

        return StreamBuilder<List<Budget>>(
          stream: repo.watchBudgets(user.uid),
          builder: (context, budgetSnapshot) {
            final budgets = budgetSnapshot.data ?? const <Budget>[];
            final alerts = AnalysisService.budgetAlerts(entries: entries, budgets: budgets, now: now);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Chào ${user.displayName?.isNotEmpty == true ? user.displayName : 'bạn'} 👋',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('Tổng quan tài chính tháng ${now.month}/${now.year}'),
                const SizedBox(height: 18),
                AmountCard(
                  title: 'Tổng thu',
                  amount: MoneyFormatter.vnd(summary.totalIncome),
                  icon: Icons.arrow_downward_rounded,
                ),
                AmountCard(
                  title: 'Tổng chi',
                  amount: MoneyFormatter.vnd(summary.totalExpense),
                  icon: Icons.arrow_upward_rounded,
                ),
                AmountCard(
                  title: 'Số dư',
                  amount: MoneyFormatter.vnd(summary.balance),
                  icon: Icons.account_balance_wallet_rounded,
                ),
                const SizedBox(height: 12),
                if (alerts.isNotEmpty) ...[
                  Text('Cảnh báo thông minh', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...alerts.map(
                    (alert) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded),
                        title: Text(alert),
                      ),
                    ),
                  ),
                ] else
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.check_circle_rounded),
                      title: Text('Chi tiêu hiện tại vẫn trong vùng an toàn.'),
                    ),
                  ),
                const SizedBox(height: 12),
                Text('Hoạt động gần đây', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...entries.take(5).map(
                  (entry) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(entry.isIncome ? Icons.add_rounded : Icons.remove_rounded),
                      ),
                      title: Text(entry.category),
                      subtitle: Text(entry.note.isEmpty ? 'Không có ghi chú' : entry.note),
                      trailing: Text(
                        '${entry.isIncome ? '+' : '-'}${MoneyFormatter.vnd(entry.amount)}',
                        style: TextStyle(
                          color: entry.isIncome ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
