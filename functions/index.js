const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const openAiApiKey = defineSecret('OPENAI_API_KEY');

const ONE_DAY_MS = 24 * 60 * 60 * 1000;
const DEFAULT_CHATBOT_RANGE_DAYS = 30;
const MAX_CHATBOT_RANGE_DAYS = 180;
const MAX_CHATBOT_ENTRIES = 160;

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

function clampRangeDays(value) {
  const parsed = Number(value || DEFAULT_CHATBOT_RANGE_DAYS);
  if (!Number.isFinite(parsed)) {
    return DEFAULT_CHATBOT_RANGE_DAYS;
  }
  return Math.min(MAX_CHATBOT_RANGE_DAYS, Math.max(7, Math.round(parsed)));
}

function formatCurrency(value) {
  return `${Math.round(Number(value || 0)).toLocaleString('vi-VN')}đ`;
}

function compactEntry(doc) {
  const data = doc.data() || {};
  const happenedAt = timestampToDate(data.happenedAt, new Date());
  const type = data.type === 'income' ? 'income' : 'expense';

  return {
    id: doc.id,
    type,
    amount: Number(data.amount || 0),
    category: data.category?.toString() || 'Khác',
    note: data.note?.toString().trim().slice(0, 160) || '',
    hasImage: Boolean(data.imageUrl || data.imagePath),
    happenedAt: happenedAt.toISOString().slice(0, 10),
    happenedAtDate: happenedAt,
  };
}

function compactBudget(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    category: data.category?.toString() || 'Tất cả',
    limitAmount: Number(data.limitAmount || 0),
    periodStart: timestampToDate(data.periodStart, new Date(0)),
    periodEnd: timestampToDate(data.periodEnd, new Date(8640000000000000)),
  };
}

function summarizeEntries(entries) {
  const byCategory = new Map();
  const byType = { income: 0, expense: 0 };
  const byDay = new Map();
  const notes = [];
  let entriesWithImages = 0;

  for (const entry of entries) {
    byType[entry.type] += entry.amount;

    if (entry.type === 'expense') {
      byCategory.set(entry.category, (byCategory.get(entry.category) || 0) + entry.amount);
      byDay.set(entry.happenedAt, (byDay.get(entry.happenedAt) || 0) + entry.amount);
    }

    if (entry.hasImage) {
      entriesWithImages += 1;
    }

    if (entry.note) {
      notes.push({
        type: entry.type,
        category: entry.category,
        amount: entry.amount,
        note: entry.note,
        happenedAt: entry.happenedAt,
      });
    }
  }

  const topExpenseCategories = [...byCategory.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([category, amount]) => ({ category, amount }));

  const highestExpenseDays = [...byDay.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([date, amount]) => ({ date, amount }));

  const recentNotes = notes
    .sort((a, b) => b.happenedAt.localeCompare(a.happenedAt))
    .slice(0, 12);

  return {
    totalIncome: byType.income,
    totalExpense: byType.expense,
    balance: byType.income - byType.expense,
    entryCount: entries.length,
    entriesWithImages,
    topExpenseCategories,
    highestExpenseDays,
    recentNotes,
  };
}

function summarizeBudgets(budgets, entries) {
  return budgets
    .map((budget) => {
      const spent = entries
        .filter((entry) => entry.type === 'expense')
        .filter((entry) => isSameCategory(budget, entry))
        .filter((entry) => entry.happenedAtDate >= budget.periodStart && entry.happenedAtDate < budget.periodEnd)
        .reduce((sum, entry) => sum + entry.amount, 0);

      const ratio = budget.limitAmount > 0 ? spent / budget.limitAmount : 0;
      return {
        category: budget.category,
        limitAmount: budget.limitAmount,
        spent,
        remaining: budget.limitAmount - spent,
        ratio,
        periodStart: budget.periodStart.toISOString().slice(0, 10),
        periodEnd: budget.periodEnd.toISOString().slice(0, 10),
      };
    })
    .filter((budget) => budget.limitAmount > 0)
    .sort((a, b) => b.ratio - a.ratio)
    .slice(0, 12);
}

function buildPrompt({ question, rangeDays, entriesSummary, budgetsSummary }) {
  return JSON.stringify({
    role: 'PocketStory personal finance chatbot',
    language: 'vi-VN',
    userQuestion: question,
    analysisWindowDays: rangeDays,
    instruction: [
      'Phân tích dữ liệu thu/chi cá nhân dựa trên số liệu tóm tắt.',
      'Không bịa số liệu không có trong dữ liệu.',
      'Không đưa lời khuyên đầu tư, vay nợ rủi ro hoặc cam kết tài chính chắc chắn.',
      'Ưu tiên nhận xét theo loại thu/chi, danh mục, ghi chú, thời gian và ngân sách.',
      'Trả lời ngắn gọn, dễ hiểu, có gạch đầu dòng hành động cụ thể.',
    ],
    entriesSummary,
    budgetsSummary,
  });
}

function extractOpenAiText(payload) {
  if (typeof payload.output_text === 'string' && payload.output_text.trim()) {
    return payload.output_text.trim();
  }

  const output = Array.isArray(payload.output) ? payload.output : [];
  const text = [];
  for (const item of output) {
    const content = Array.isArray(item.content) ? item.content : [];
    for (const block of content) {
      if (typeof block.text === 'string') {
        text.push(block.text);
      }
    }
  }
  return text.join('\n').trim();
}

async function callOpenAi({ apiKey, prompt }) {
  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: process.env.OPENAI_MODEL || 'gpt-4.1-mini',
      input: [
        {
          role: 'system',
          content: [
            {
              type: 'input_text',
              text: 'Bạn là chatbot phân tích chi tiêu cá nhân cho ứng dụng PocketStory. Trả lời bằng tiếng Việt, rõ ràng, an toàn và không bịa số liệu.',
            },
          ],
        },
        {
          role: 'user',
          content: [{ type: 'input_text', text: prompt }],
        },
      ],
      max_output_tokens: 900,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI request failed ${response.status}: ${errorText}`);
  }

  const payload = await response.json();
  return extractOpenAiText(payload);
}

function buildLocalFallback({ rangeDays, entriesSummary, budgetsSummary }) {
  if (entriesSummary.entryCount === 0) {
    return `Trong ${rangeDays} ngày gần đây chưa có giao dịch nào để phân tích. Bạn hãy thêm vài khoản thu/chi trước, sau đó chatbot sẽ nhận xét được xu hướng rõ hơn.`;
  }

  const topCategories = entriesSummary.topExpenseCategories
    .slice(0, 3)
    .map((item) => `${item.category}: ${formatCurrency(item.amount)}`)
    .join(', ');

  const riskyBudgets = budgetsSummary
    .filter((item) => item.ratio >= 0.8)
    .slice(0, 3)
    .map((item) => `${item.category} đã dùng ${(item.ratio * 100).toFixed(0)}%`)
    .join(', ');

  return [
    `Trong ${rangeDays} ngày gần đây, bạn có ${entriesSummary.entryCount} giao dịch.`,
    `Tổng thu: ${formatCurrency(entriesSummary.totalIncome)}. Tổng chi: ${formatCurrency(entriesSummary.totalExpense)}. Số dư: ${formatCurrency(entriesSummary.balance)}.`,
    topCategories ? `Danh mục chi nhiều nhất: ${topCategories}.` : 'Chưa có khoản chi nào đáng kể theo danh mục.',
    riskyBudgets ? `Ngân sách cần chú ý: ${riskyBudgets}.` : 'Hiện chưa có ngân sách nào vượt ngưỡng 80% trong dữ liệu đã lấy.',
    'AI chưa được cấu hình hoặc chưa phản hồi, nên đây là bản phân tích cục bộ từ backend.',
  ].join('\n');
}

exports.analyzePersonalSpending = onCall(
  {
    secrets: [openAiApiKey],
    timeoutSeconds: 60,
    memory: '512MiB',
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Bạn cần đăng nhập để dùng chatbot phân tích chi tiêu.');
    }

    const rangeDays = clampRangeDays(request.data?.rangeDays);
    const question = request.data?.question?.toString().trim() ||
      `Hãy phân tích chi tiêu của tôi trong ${rangeDays} ngày gần đây.`;
    const now = new Date();
    const start = new Date(now.getTime() - rangeDays * ONE_DAY_MS);

    const [entriesSnap, budgetsSnap] = await Promise.all([
      db
        .collection('users')
        .doc(uid)
        .collection('entries')
        .where('happenedAt', '>=', admin.firestore.Timestamp.fromDate(start))
        .orderBy('happenedAt', 'desc')
        .limit(MAX_CHATBOT_ENTRIES)
        .get(),
      db.collection('users').doc(uid).collection('budgets').get(),
    ]);

    const entries = entriesSnap.docs.map(compactEntry);
    const budgets = budgetsSnap.docs.map(compactBudget);
    const entriesSummary = summarizeEntries(entries);
    const budgetsSummary = summarizeBudgets(budgets, entries);
    const prompt = buildPrompt({ question, rangeDays, entriesSummary, budgetsSummary });
    const apiKey = openAiApiKey.value();

    if (!apiKey) {
      return {
        answer: buildLocalFallback({ rangeDays, entriesSummary, budgetsSummary }),
        source: 'local_fallback_missing_api_key',
        rangeDays,
        entriesCount: entries.length,
        budgetsCount: budgets.length,
      };
    }

    try {
      const answer = await callOpenAi({ apiKey, prompt });
      return {
        answer: answer || buildLocalFallback({ rangeDays, entriesSummary, budgetsSummary }),
        source: answer ? 'openai' : 'local_fallback_empty_ai_response',
        rangeDays,
        entriesCount: entries.length,
        budgetsCount: budgets.length,
      };
    } catch (error) {
      logger.error('AI spending analysis failed', { uid, error: error.message });
      return {
        answer: buildLocalFallback({ rangeDays, entriesSummary, budgetsSummary }),
        source: 'local_fallback_ai_error',
        rangeDays,
        entriesCount: entries.length,
        budgetsCount: budgets.length,
      };
    }
  }
);

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
