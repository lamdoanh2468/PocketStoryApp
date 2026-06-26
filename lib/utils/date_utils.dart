class AppDateUtils {
  static DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

  static DateTime endOfMonth(DateTime date) => DateTime(date.year, date.month + 1);

  static DateTime startOfPreviousMonth(DateTime date) => DateTime(date.year, date.month - 1);

  static DateTime endOfPreviousMonth(DateTime date) => DateTime(date.year, date.month);

  static String monthBudgetId(String category, DateTime date) {
    final normalized = category
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_\u00C0-\u1EF9]'), '');
    return '${date.year}_${date.month.toString().padLeft(2, '0')}_$normalized';
  }
}
