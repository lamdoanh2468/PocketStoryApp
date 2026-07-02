import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  Budget? _editingBudget;
  bool _saving = false;

  bool get _isEditing => _editingBudget != null;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? _parseVndAmount(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  void _clearForm() {
    setState(() {
      _editingBudget = null;
      _category = AppCategories.budget.first;
      _amountController.clear();
    });
  }

  void _startEditingBudget(Budget budget) {
    setState(() {
      _editingBudget = budget;
      _category = budget.category;
      _amountController.text = _VndInputFormatter.formatNumber(budget.limitAmount);
    });
  }

  Future<void> _saveBudget() async {
    final limit = _parseVndAmount(_amountController.text);
    if (limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập ngân sách hợp lệ.')));
      return;
    }

    final repo = context.read<FinanceRepository>();
    final editingBudget = _editingBudget;

    setState(() => _saving = true);
    final now = DateTime.now();
    final budget = Budget(
      id: AppDateUtils.monthBudgetId(_category, now),
      category: _category,
      limitAmount: limit,
      periodStart: editingBudget?.periodStart ?? AppDateUtils.startOfMonth(now),
      periodEnd: editingBudget?.periodEnd ?? AppDateUtils.endOfMonth(now),
      createdAt: editingBudget?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await repo.upsertBudget(widget.user.uid, budget);

      if (editingBudget != null && editingBudget.id != budget.id) {
        await repo.deleteBudget(widget.user.uid, editingBudget.id);
      }

      if (!mounted) return;
      _clearForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Đã cập nhật ngân sách.' : 'Đã lưu ngân sách.')),
      );
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditing) ...[
                  InputChip(
                    avatar: const Icon(Icons.edit_rounded),
                    label: Text('Đang chỉnh sửa: ${_editingBudget!.category}'),
                    onDeleted: _saving ? null : _clearForm,
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Danh mục'),
                  items: AppCategories.budget.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                  onChanged: _saving ? null : (value) => setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_VndInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Hạn mức tháng này',
                    hintText: 'Ví dụ: 1.000.000',
                    suffixText: 'VND',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveBudget,
                        icon: Icon(_isEditing ? Icons.check_rounded : Icons.savings_rounded),
                        label: Text(_isEditing ? 'Cập nhật ngân sách' : 'Lưu ngân sách'),
                      ),
                    ),
                    if (_isEditing) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _saving ? null : _clearForm,
                        child: const Text('Hủy'),
                      ),
                    ],
                  ],
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
                                  tooltip: 'Chỉnh sửa ngân sách',
                                  onPressed: () => _startEditingBudget(budget),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Xóa ngân sách',
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

class _VndInputFormatter extends TextInputFormatter {
  const _VndInputFormatter();

  static final NumberFormat _formatter = NumberFormat.decimalPattern('vi_VN');

  static String formatNumber(num value) => _formatter.format(value.round());

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final value = int.tryParse(digits);
    if (value == null) return oldValue;

    final formatted = _formatter.format(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
