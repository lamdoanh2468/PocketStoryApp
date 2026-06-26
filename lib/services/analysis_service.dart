import '../constants/app_categories.dart';
import '../models/budget.dart';
import '../models/money_entry.dart';
import '../models/report_summary.dart';

class AnalysisService {
  static ReportSummary summarize(List<MoneyEntry> entries) {
    final totalIncome = entries
        .where((entry) => entry.isIncome)
        .fold<double>(0, (sum, entry) => sum + entry.amount);

    final totalExpense = entries
        .where((entry) => entry.isExpense)
        .fold<double>(0, (sum, entry) => sum + entry.amount);

    final byCategory = <String, double>{};
    for (final entry in entries.where((entry) => entry.isExpense)) {
      byCategory.update(entry.category, (value) => value + entry.amount,
          ifAbsent: () => entry.amount);
    }

    return ReportSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      expenseByCategory: byCategory,
    );
  }

  static List<MoneyEntry> between(
      List<MoneyEntry> entries, DateTime start, DateTime end) {
    return entries.where((entry) {
      final date = entry.happenedAt;
      return !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  static PeriodComparison compare({
    required List<MoneyEntry> entries,
    required DateTime currentStart,
    required DateTime currentEnd,
    required DateTime previousStart,
    required DateTime previousEnd,
  }) {
    final current =
        summarize(between(entries, currentStart, currentEnd)).totalExpense;
    final previous =
        summarize(between(entries, previousStart, previousEnd)).totalExpense;
    final diff = current - previous;
    final double percent =
        previous == 0 ? (current == 0 ? 0.0 : 100.0) : diff / previous * 100.0;
    return PeriodComparison(
      currentExpense: current,
      previousExpense: previous,
      difference: diff,
      percentChange: percent,
    );
  }

  static List<String> budgetAlerts({
    required List<MoneyEntry> entries,
    required List<Budget> budgets,
    required DateTime now,
  }) {
    final alerts = <String>[];

    for (final budget in budgets) {
      if (now.isBefore(budget.periodStart) || !now.isBefore(budget.periodEnd)) {
        continue;
      }

      final spent = entries.where((entry) {
        final samePeriod = !entry.happenedAt.isBefore(budget.periodStart) &&
            entry.happenedAt.isBefore(budget.periodEnd);
        final sameCategory =
            budget.category == AppCategories.allBudgetCategory ||
                entry.category == budget.category;
        return entry.isExpense && samePeriod && sameCategory;
      }).fold<double>(0, (sum, entry) => sum + entry.amount);

      if (budget.limitAmount <= 0) continue;
      final ratio = spent / budget.limitAmount;

      if (ratio >= 1) {
        alerts.add(
            'Bạn đã vượt ngân sách ${budget.category}. Hãy giảm tốc độ chi tiêu trong thời gian còn lại.');
      } else if (ratio >= 0.8) {
        alerts.add(
            'Ngân sách ${budget.category} đã dùng ${(ratio * 100).toStringAsFixed(0)}%. Bạn nên chú ý hơn.');
      }
    }

    return alerts;
  }
}
