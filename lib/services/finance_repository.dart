import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_alert.dart';
import '../models/budget.dart';
import '../models/money_entry.dart';

class FinanceRepository {
  FinanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
  }

  Future<void> deleteEntry(String uid, MoneyEntry entry) async {
    await _entriesRef(uid).doc(entry.id).delete();
  }

  Stream<List<Budget>> watchBudgets(String uid) {
    return _budgetsRef(uid)
        .orderBy('periodStart', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Budget.fromDoc).toList());
  }

  Future<void> upsertBudget(String uid, Budget budget) async {
    await _budgetsRef(uid).doc(budget.id).set(budget.toFirestore());
  }

  Future<void> deleteBudget(String uid, String budgetId) async {
    await _budgetsRef(uid).doc(budgetId).delete();
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
}
