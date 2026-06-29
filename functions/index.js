const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const ONE_DAY_MS = 24 * 60 * 60 * 1000;

function timestampToDate(value, fallback) {
  if (value && typeof value.toDate === 'function') {
    return value.toDate();
  }
  return fallback;
}

function startOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function endOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1);
}

function formatDateKey(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function formatMonthKey(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  return `${year}-${month}`;
}

function daysBetween(start, end) {
  const normalizedStart = startOfDay(start);
  const normalizedEnd = startOfDay(end);
  return Math.max(1, Math.ceil((normalizedEnd.getTime() - normalizedStart.getTime()) / ONE_DAY_MS));
}

function isSameCategory(budget, entry) {
  return budget.category === entry.category || budget.category === 'Tất cả';
}

async function getTokens(uid) {
  const tokensSnap = await db
    .collection('users')
    .doc(uid)
    .collection('fcmTokens')
    .get();

  return tokensSnap.docs
    .map((doc) => doc.data().token)
    .filter(Boolean);
}

async function calculateSpent({ uid, start, end, category }) {
  const entriesSnap = await db
    .collection('users')
    .doc(uid)
    .collection('entries')
    .where('happenedAt', '>=', admin.firestore.Timestamp.fromDate(start))
    .where('happenedAt', '<', admin.firestore.Timestamp.fromDate(end))
    .get();

  return entriesSnap.docs
    .map((doc) => doc.data())
    .filter((item) => item.type === 'expense')
    .filter((item) => category === 'Tất cả' || item.category === category)
    .reduce((sum, item) => sum + Number(item.amount || 0), 0);
}

async function createAlertOnce({ uid, alertId, payload, tokens }) {
  const alertRef = db
    .collection('users')
    .doc(uid)
    .collection('alerts')
    .doc(alertId);

  const created = await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(alertRef);
    if (existing.exists) {
      return false;
    }

    transaction.set(alertRef, {
      ...payload,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  });

  if (!created) {
    logger.info('Alert skipped because it already exists', { uid, alertId });
    return false;
  }

  if (tokens.length > 0) {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: {
        type: payload.type,
        alertId,
        category: payload.category,
        level: payload.level,
        ratio: String(payload.ratio),
      },
    });
  }

  logger.info('Alert sent', { uid, alertId, category: payload.category, ratio: payload.ratio });
  return true;
}

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

    const happenedAt = timestampToDate(entry.happenedAt, new Date());

    const budgetsSnap = await db
      .collection('users')
      .doc(uid)
      .collection('budgets')
      .get();

    const matchedBudgets = budgetsSnap.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((budget) => {
        const start = timestampToDate(budget.periodStart, new Date(0));
        const end = timestampToDate(budget.periodEnd, new Date(8640000000000000));
        return isSameCategory(budget, entry) && happenedAt >= start && happenedAt < end;
      });

    if (matchedBudgets.length === 0) {
      return;
    }

    const tokens = await getTokens(uid);
    if (tokens.length === 0) {
      logger.info('No FCM tokens for user. Alerts will still be saved in Firestore.', { uid });
    }

    for (const budget of matchedBudgets) {
      const periodStart = timestampToDate(budget.periodStart, new Date(0));
      const periodEnd = timestampToDate(budget.periodEnd, new Date(8640000000000000));
      const limitAmount = Number(budget.limitAmount || 0);
      if (limitAmount <= 0) continue;

      const totalSpent = await calculateSpent({
        uid,
        start: periodStart,
        end: periodEnd,
        category: budget.category,
      });
      const monthlyRatio = totalSpent / limitAmount;

      if (monthlyRatio >= 0.8) {
        const monthlyLevel = monthlyRatio >= 1 ? 'danger' : 'warning';
        const monthlyAlertId = `monthly_${formatMonthKey(happenedAt)}_${budget.id}_${monthlyLevel}`;
        const monthlyTitle = monthlyRatio >= 1 ? 'Bạn đã vượt ngân sách tháng' : 'Bạn sắp chạm ngân sách tháng';
        const monthlyBody = monthlyRatio >= 1
          ? `Danh mục ${budget.category} đã vượt hạn mức tháng này.`
          : `Danh mục ${budget.category} đã dùng ${(monthlyRatio * 100).toFixed(0)}% ngân sách tháng.`;

        await createAlertOnce({
          uid,
          alertId: monthlyAlertId,
          tokens,
          payload: {
            title: monthlyTitle,
            body: monthlyBody,
            category: budget.category,
            type: 'monthly_budget_alert',
            level: monthlyLevel,
            ratio: monthlyRatio,
            totalSpent,
            limitAmount,
            budgetId: budget.id,
          },
        });
      }

      const dayStart = startOfDay(happenedAt);
      const dayEnd = endOfDay(happenedAt);
      const dailySpent = await calculateSpent({
        uid,
        start: dayStart,
        end: dayEnd,
        category: budget.category,
      });
      const dailyLimit = limitAmount / daysBetween(periodStart, periodEnd);
      const dailyRatio = dailyLimit > 0 ? dailySpent / dailyLimit : 0;

      if (dailyRatio < 1) {
        continue;
      }

      const dailyAlertId = `daily_${formatDateKey(happenedAt)}_${budget.id}_danger`;
      await createAlertOnce({
        uid,
        alertId: dailyAlertId,
        tokens,
        payload: {
          title: 'Bạn đã vượt ngân sách hôm nay',
          body: `Hôm nay danh mục ${budget.category} đã chi ${(dailyRatio * 100).toFixed(0)}% hạn mức trung bình ngày.`,
          category: budget.category,
          type: 'daily_budget_alert',
          level: 'danger',
          ratio: dailyRatio,
          totalSpent: dailySpent,
          limitAmount: dailyLimit,
          budgetId: budget.id,
          budgetPeriodStart: budget.periodStart,
          budgetPeriodEnd: budget.periodEnd,
        },
      });
    }
  }
);
