import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_alert.dart';
import '../models/budget.dart';
import '../models/money_entry.dart';
import 'notification_service.dart';

class FinanceRepository {
  FinanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const double _warningRatio = 0.8;

  CollectionReference<Map<String, dynamic>> _entriesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('entries');
  }

  CollectionReference<Map<String, dynamic>> _budgetsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('budgets');
  }

  CollectionReference<Map<String, dynamic>> _alertsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('alerts');
  }

  Stream<List<MoneyEntry>> watchEntries(String uid) {
    return _entriesRef(uid)
        .orderBy('happenedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MoneyEntry.fromDoc).toList());
  }

  Future<List<MoneyEntry>> fetchEntriesBetween({
    required String uid,
    required DateTime start,
    required DateTime end,
  }) async {
    final snapshot = await _entriesRef(uid)
        .where('happenedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('happenedAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('happenedAt', descending: true)
        .get();

    return snapshot.docs.map(MoneyEntry.fromDoc).toList();
  }

  Future<void> upsertEntry(String uid, MoneyEntry entry) async {
    await _entriesRef(uid).doc(entry.id).set(entry.toFirestore());
    await _evaluateBudgetAlerts(uid: uid, changedEntry: entry);
  }

  Future<void> deleteEntry(String uid, MoneyEntry entry) async {
    await _entriesRef(uid).doc(entry.id).delete();
    await _evaluateBudgetAlerts(uid: uid, changedEntry: entry);
  }

  Stream<List<Budget>> watchBudgets(String uid) {
    return _budgetsRef(uid)
        .orderBy('periodStart', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Budget.fromDoc).toList());
  }

  Future<void> upsertBudget(String uid, Budget budget) async {
    await _budgetsRef(uid).doc(budget.id).set(budget.toFirestore());
    await _evaluateSingleBudget(uid: uid, budget: budget);
  }

  Future<void> deleteBudget(String uid, String budgetId) async {
    await _budgetsRef(uid).doc(budgetId).delete();
    await _alertsRef(uid).doc(_budgetAlertId(budgetId)).delete();
  }

  Stream<List<AppAlert>> watchAlerts(String uid) {
    return _alertsRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppAlert.fromDoc).toList());
  }

  Future<void> markAlertAsRead(String uid, String alertId) async {
    await _alertsRef(uid).doc(alertId).set({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteAlert(String uid, String alertId) async {
    await _alertsRef(uid).doc(alertId).delete();
  }

  Future<void> _evaluateBudgetAlerts({
    required String uid,
    required MoneyEntry changedEntry,
  }) async {
    final budgetSnapshot = await _budgetsRef(uid).get();
    final budgets = budgetSnapshot.docs
        .map(Budget.fromDoc)
        .where((budget) => _isDateInBudgetPeriod(changedEntry.happenedAt, budget))
        .where((budget) => _doesBudgetApplyToEntry(budget, changedEntry))
        .toList();

    for (final budget in budgets) {
      await _evaluateSingleBudget(uid: uid, budget: budget);
    }
  }

  Future<void> _evaluateSingleBudget({
    required String uid,
    required Budget budget,
  }) async {
    if (budget.limitAmount <= 0) return;

    final entries = await fetchEntriesBetween(
      uid: uid,
      start: budget.periodStart,
      end: budget.periodEnd,
    );

    final totalSpent = entries
        .where((entry) => entry.isExpense)
        .where((entry) => _doesBudgetApplyToEntry(budget, entry))
        .fold<double>(0, (sum, entry) => sum + entry.amount);

    final ratio = totalSpent / budget.limitAmount;
    final alertRef = _alertsRef(uid).doc(_budgetAlertId(budget.id));

    if (ratio < _warningRatio) {
      await alertRef.delete();
      return;
    }

    final level = ratio >= 1 ? 'danger' : 'warning';
    final percent = (ratio * 100).clamp(0, 999).toStringAsFixed(0);
    final title = level == 'danger'
        ? 'Bạn đã vượt ngân sách ${budget.category}'
        : 'Bạn sắp chạm ngân sách ${budget.category}';
    final body = level == 'danger'
        ? 'Bạn đã dùng $percent% ngân sách ${budget.category}. Tổng chi: ${_formatVnd(totalSpent)} / ${_formatVnd(budget.limitAmount)}.'
        : 'Bạn đã dùng $percent% ngân sách ${budget.category}. Hãy cân nhắc chi tiêu trong thời gian còn lại.';

    final existingAlert = await alertRef.get();
    final existingLevel = existingAlert.data()?['level']?.toString();
    final shouldNotify = !existingAlert.exists || existingLevel != level;

    final data = <String, dynamic>{
      'title': title,
      'body': body,
      'category': budget.category,
      'type': 'budget_alert',
      'level': level,
      'ratio': ratio,
      'totalSpent': totalSpent,
      'limitAmount': budget.limitAmount,
      'budgetId': budget.id,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existingAlert.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['read'] = false;
    }

    if (existingAlert.exists && existingLevel != level) {
      data['read'] = false;
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await alertRef.set(data, SetOptions(merge: true));

    if (shouldNotify) {
      await NotificationService.instance.showBudgetAlert(
        title: title,
        body: body,
        data: {
          'type': 'budget_alert',
          'alertId': alertRef.id,
          'budgetId': budget.id,
          'category': budget.category,
          'level': level,
          'ratio': ratio.toStringAsFixed(2),
        },
      );
    }
  }

  bool _isDateInBudgetPeriod(DateTime date, Budget budget) {
    final start = budget.periodStart;
    final end = budget.periodEnd;
    return !date.isBefore(start) && date.isBefore(end);
  }

  bool _doesBudgetApplyToEntry(Budget budget, MoneyEntry entry) {
    if (_isAllCategory(budget.category)) return true;
    return _normalizeCategory(budget.category) == _normalizeCategory(entry.category);
  }

  bool _isAllCategory(String category) {
    final normalized = _normalizeCategory(category);
    return normalized == 'tat ca' || normalized == 'tất cả' || normalized == 'all';
  }

  String _normalizeCategory(String value) {
    return value.trim().toLowerCase();
  }

  String _budgetAlertId(String budgetId) {
    return 'budget_$budgetId';
  }

  String _formatVnd(num amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      final positionFromEnd = digits.length - i;
      buffer.write(digits[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${buffer} VND';
  }
}
