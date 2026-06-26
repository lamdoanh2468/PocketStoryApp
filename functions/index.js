const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

exports.sendBudgetAlertOnExpenseCreated = onDocumentCreated(
  'users/{uid}/entries/{entryId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const uid = event.params.uid;
    const entry = snapshot.data();

    if (entry.type !== 'expense') {
      return;
    }

    const happenedAt = entry.happenedAt && entry.happenedAt.toDate
      ? entry.happenedAt.toDate()
      : new Date();

    const budgetsSnap = await db
      .collection('users')
      .doc(uid)
      .collection('budgets')
      .get();

    const matchedBudgets = budgetsSnap.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((budget) => {
        const start = budget.periodStart?.toDate?.() ?? new Date(0);
        const end = budget.periodEnd?.toDate?.() ?? new Date(8640000000000000);
        const sameCategory = budget.category === entry.category || budget.category === 'Tất cả';
        return sameCategory && happenedAt >= start && happenedAt < end;
      });

    if (matchedBudgets.length === 0) {
      return;
    }

    const tokensSnap = await db
      .collection('users')
      .doc(uid)
      .collection('fcmTokens')
      .get();

    const tokens = tokensSnap.docs
      .map((doc) => doc.data().token)
      .filter(Boolean);

    if (tokens.length === 0) {
      logger.info('No FCM tokens for user', { uid });
      return;
    }

    for (const budget of matchedBudgets) {
      const entriesSnap = await db
        .collection('users')
        .doc(uid)
        .collection('entries')
        .where('happenedAt', '>=', budget.periodStart)
        .where('happenedAt', '<', budget.periodEnd)
        .get();

      const totalSpent = entriesSnap.docs
        .map((doc) => doc.data())
        .filter((item) => item.type === 'expense')
        .filter((item) => budget.category === 'Tất cả' || item.category === budget.category)
        .reduce((sum, item) => sum + Number(item.amount || 0), 0);

      const ratio = budget.limitAmount > 0 ? totalSpent / budget.limitAmount : 0;
      if (ratio < 0.8) {
        continue;
      }

      const title = ratio >= 1 ? 'Bạn đã vượt ngân sách' : 'Bạn sắp chạm ngân sách';
      const body = ratio >= 1
        ? `Danh mục ${budget.category} đã vượt hạn mức tháng này.`
        : `Danh mục ${budget.category} đã dùng ${(ratio * 100).toFixed(0)}% ngân sách.`;

      await db
        .collection('users')
        .doc(uid)
        .collection('alerts')
        .add({
          title,
          body,
          category: budget.category,
          ratio,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: {
          type: 'budget_alert',
          category: budget.category,
          ratio: String(ratio),
        },
      });

      logger.info('Budget alert sent', { uid, budgetId: budget.id, ratio });
    }
  }
);
