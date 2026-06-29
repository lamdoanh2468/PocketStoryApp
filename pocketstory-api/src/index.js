import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import admin from 'firebase-admin';
import helmet from 'helmet';
import morgan from 'morgan';

const ONE_DAY_MS = 24 * 60 * 60 * 1000;
const DEFAULT_RANGE_DAYS = 30;
const MAX_RANGE_DAYS = 180;
const MAX_ENTRIES = 160;

const config = {
  port: Number(process.env.PORT || 3000),
  allowedOrigin: process.env.CORS_ORIGIN || '*',
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || 'pocketstory-6d696',
  openAiApiKey: process.env.OPENAI_API_KEY || '',
  openAiModel: process.env.OPENAI_MODEL || 'gpt-4.1-mini',
};

function createFirebaseCredential() {
  const rawServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

  if (rawServiceAccount) {
    const serviceAccount = JSON.parse(rawServiceAccount);
    return admin.credential.cert(serviceAccount);
  }

  return admin.credential.applicationDefault();
}

function initializeFirebase() {
  if (admin.apps.length > 0) return;

  admin.initializeApp({
    credential: createFirebaseCredential(),
    projectId: config.firebaseProjectId,
  });
}

initializeFirebase();

const db = admin.firestore();
const app = express();

app.use(helmet());
app.use(cors({ origin: config.allowedOrigin }));
app.use(express.json({ limit: '512kb' }));
app.use(morgan('combined'));

function timestampToDate(value, fallback = new Date()) {
  if (value && typeof value.toDate === 'function') {
    return value.toDate();
  }

  if (value instanceof Date) {
    return value;
  }

  const parsed = Date.parse(value ?? '');
  return Number.isNaN(parsed) ? fallback : new Date(parsed);
}

function clampRangeDays(value) {
  const parsed = Number(value || DEFAULT_RANGE_DAYS);
  if (!Number.isFinite(parsed)) {
    return DEFAULT_RANGE_DAYS;
  }

  return Math.min(MAX_RANGE_DAYS, Math.max(7, Math.round(parsed)));
}

function formatCurrency(value) {
  return `${Math.round(Number(value || 0)).toLocaleString('vi-VN')}đ`;
}

function isSameCategory(budget, entry) {
  return budget.category === entry.category || budget.category === 'Tất cả';
}

function compactEntry(doc) {
  const data = doc.data() || {};
  const happenedAt = timestampToDate(data.happenedAt);
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
  const expenseByCategory = new Map();
  const expenseByDay = new Map();
  const recentNotes = [];
  const totals = { income: 0, expense: 0 };
  let entriesWithImages = 0;

  for (const entry of entries) {
    totals[entry.type] += entry.amount;

    if (entry.type === 'expense') {
      expenseByCategory.set(
        entry.category,
        (expenseByCategory.get(entry.category) || 0) + entry.amount,
      );
      expenseByDay.set(
        entry.happenedAt,
        (expenseByDay.get(entry.happenedAt) || 0) + entry.amount,
      );
    }

    if (entry.hasImage) {
      entriesWithImages += 1;
    }

    if (entry.note) {
      recentNotes.push({
        type: entry.type,
        category: entry.category,
        amount: entry.amount,
        note: entry.note,
        happenedAt: entry.happenedAt,
      });
    }
  }

  return {
    totalIncome: totals.income,
    totalExpense: totals.expense,
    balance: totals.income - totals.expense,
    entryCount: entries.length,
    entriesWithImages,
    topExpenseCategories: [...expenseByCategory.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8)
      .map(([category, amount]) => ({ category, amount })),
    highestExpenseDays: [...expenseByDay.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([date, amount]) => ({ date, amount })),
    recentNotes: recentNotes
      .sort((a, b) => b.happenedAt.localeCompare(a.happenedAt))
      .slice(0, 12),
  };
}

function summarizeBudgets(budgets, entries) {
  return budgets
    .map((budget) => {
      const spent = entries
        .filter((entry) => entry.type === 'expense')
        .filter((entry) => isSameCategory(budget, entry))
        .filter(
          (entry) =>
            entry.happenedAtDate >= budget.periodStart &&
            entry.happenedAtDate < budget.periodEnd,
        )
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

async function callOpenAi(prompt) {
  if (!config.openAiApiKey) {
    throw new Error('OPENAI_API_KEY is not configured.');
  }

  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.openAiApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: config.openAiModel,
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
    const body = await response.text();
    throw new Error(`OpenAI request failed ${response.status}: ${body}`);
  }

  return extractOpenAiText(await response.json());
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
    topCategories
      ? `Danh mục chi nhiều nhất: ${topCategories}.`
      : 'Chưa có khoản chi nào đáng kể theo danh mục.',
    riskyBudgets
      ? `Ngân sách cần chú ý: ${riskyBudgets}.`
      : 'Hiện chưa có ngân sách nào vượt ngưỡng 80% trong dữ liệu đã lấy.',
    'AI chưa được cấu hình hoặc chưa phản hồi, nên đây là bản phân tích cục bộ từ backend.',
  ].join('\n');
}

function getBearerToken(req) {
  const authorization = req.headers.authorization || '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return null;
  }

  return token;
}

async function authenticateFirebaseUser(req, res, next) {
  try {
    const token = getBearerToken(req);

    if (!token) {
      return res.status(401).json({ message: 'Missing Firebase ID token.' });
    }

    req.user = await admin.auth().verifyIdToken(token);
    return next();
  } catch (error) {
    console.error('Firebase token verification failed:', error);
    return res.status(401).json({ message: 'Invalid or expired Firebase ID token.' });
  }
}

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'pocketstory-api' });
});

app.post('/api/chatbot/analyze', authenticateFirebaseUser, async (req, res) => {
  const uid = req.user.uid;
  const rangeDays = clampRangeDays(req.body?.rangeDays);
  const question = req.body?.question?.toString().trim() ||
    `Hãy phân tích chi tiêu của tôi trong ${rangeDays} ngày gần đây.`;
  const now = new Date();
  const start = new Date(now.getTime() - rangeDays * ONE_DAY_MS);

  try {
    const [entriesSnapshot, budgetsSnapshot] = await Promise.all([
      db
        .collection('users')
        .doc(uid)
        .collection('entries')
        .where('happenedAt', '>=', admin.firestore.Timestamp.fromDate(start))
        .orderBy('happenedAt', 'desc')
        .limit(MAX_ENTRIES)
        .get(),
      db.collection('users').doc(uid).collection('budgets').get(),
    ]);

    const entries = entriesSnapshot.docs.map(compactEntry);
    const budgets = budgetsSnapshot.docs.map(compactBudget);
    const entriesSummary = summarizeEntries(entries);
    const budgetsSummary = summarizeBudgets(budgets, entries);
    const prompt = buildPrompt({ question, rangeDays, entriesSummary, budgetsSummary });

    try {
      const answer = await callOpenAi(prompt);
      return res.json({
        answer: answer || buildLocalFallback({ rangeDays, entriesSummary, budgetsSummary }),
        source: answer ? 'openai' : 'local_fallback_empty_ai_response',
        rangeDays,
        entriesCount: entries.length,
        budgetsCount: budgets.length,
      });
    } catch (error) {
      console.error('OpenAI analysis failed:', error);
      return res.json({
        answer: buildLocalFallback({ rangeDays, entriesSummary, budgetsSummary }),
        source: 'local_fallback_ai_error',
        rangeDays,
        entriesCount: entries.length,
        budgetsCount: budgets.length,
      });
    }
  } catch (error) {
    console.error('Chatbot analysis failed:', error);
    return res.status(500).json({ message: 'Cannot analyze personal spending right now.' });
  }
});

app.use((req, res) => {
  res.status(404).json({ message: `Route not found: ${req.method} ${req.path}` });
});

app.listen(config.port, () => {
  console.log(`PocketStory API is running on port ${config.port}`);
});
