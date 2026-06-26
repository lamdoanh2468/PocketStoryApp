import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_categories.dart';
import '../../models/budget.dart';
import '../../models/money_entry.dart';
import '../../services/analysis_service.dart';
import '../../services/finance_repository.dart';
import '../../utils/date_utils.dart';
import '../../utils/money_formatter.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key, required this.user});

  final User user;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _amountController = TextEditingController();
  String _category = AppCategories.budget.first;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final limit = double.tryParse(_amountController.text.replaceAll(',', '').trim());
    if (limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập ngân sách hợp lệ.')));
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final budget = Budget(
      id: AppDateUtils.monthBudgetId(_category, now),
      category: _category,
      limitAmount: limit,
      periodStart: AppDateUtils.startOfMonth(now),
      periodEnd: AppDateUtils.endOfMonth(now),
      createdAt: DateTime.now(),
    );

    try {
      await context.read<FinanceRepository>().upsertBudget(widget.user.uid, budget);
      _amountController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu ngân sách.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<FinanceRepository>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Quản lý ngân sách', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  items: AppCategories.budget.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                  onChanged: (value) => setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hạn mức tháng này'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveBudget,
                    icon: const Icon(Icons.savings_rounded),
                    label: const Text('Lưu ngân sách'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<MoneyEntry>>(
          stream: repo.watchEntries(widget.user.uid),
          builder: (context, entrySnapshot) {
            final entries = entrySnapshot.data ?? const <MoneyEntry>[];
            return StreamBuilder<List<Budget>>(
              stream: repo.watchBudgets(widget.user.uid),
              builder: (context, budgetSnapshot) {
                final budgets = budgetSnapshot.data ?? const <Budget>[];
                if (budgets.isEmpty) {
                  return const Card(
                    child: ListTile(
                      leading: Icon(Icons.info_rounded),
                      title: Text('Chưa có ngân sách nào.'),
                    ),
                  );
                }

                return Column(
                  children: budgets.map((budget) {
                    final spent = AnalysisService.between(entries, budget.periodStart, budget.periodEnd)
                        .where((entry) => entry.isExpense)
                        .where((entry) => budget.category == AppCategories.allBudgetCategory || entry.category == budget.category)
                        .fold<double>(0, (sum, entry) => sum + entry.amount);
                    final ratio = budget.limitAmount == 0 ? 0 : spent / budget.limitAmount;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(budget.category, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                ),
                                IconButton(
                                  onPressed: () => repo.deleteBudget(widget.user.uid, budget.id),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: ratio.clamp(0, 1).toDouble()),
                            const SizedBox(height: 8),
                            Text('${MoneyFormatter.vnd(spent)} / ${MoneyFormatter.vnd(budget.limitAmount)}'),
                            if (ratio >= 1)
                              const Text('Đã vượt ngân sách', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                            else if (ratio >= 0.8)
                              const Text('Sắp chạm ngân sách', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
