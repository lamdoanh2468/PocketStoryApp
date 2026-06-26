class ReportSummary {
  const ReportSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.expenseByCategory,
  });

  final double totalIncome;
  final double totalExpense;
  final double balance;
  final Map<String, double> expenseByCategory;
}

class PeriodComparison {
  const PeriodComparison({
    required this.currentExpense,
    required this.previousExpense,
    required this.difference,
    required this.percentChange,
  });

  final double currentExpense;
  final double previousExpense;
  final double difference;
  final double percentChange;

  bool get increased => difference > 0;
  bool get decreased => difference < 0;
}
