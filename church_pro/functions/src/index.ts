import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';
import * as admin from 'firebase-admin';

admin.initializeApp();

// Set once with:  firebase functions:secrets:set ANTHROPIC_API_KEY
const anthropicKey = defineSecret('ANTHROPIC_API_KEY');

// A fast, low-cost model is plenty for a short summary. Change it here if you like.
const MODEL = 'claude-haiku-4-5-20251001';

// Who may ask for a summary: the people who can see every budget.
const ALLOWED_ROLES = ['admin', 'accountant', 'leadPastor'];

interface Line {
    name: string;
    type: string;
    planned: number;
    committed: number;
    actual: number;
}

export const summarizeBudget = onRequest(
    { secrets: [anthropicKey], cors: true, region: 'us-central1', timeoutSeconds: 60, memory: '256MiB' },
    async (req, res) => {
        try {
            if (req.method !== 'POST') {
                res.status(405).json({ error: 'Use POST' });
                return;
            }

            // 1. Who is asking?
            const idToken = (req.headers.authorization ?? '').replace(/^Bearer /, '');
            if (!idToken) {
                res.status(401).json({ error: 'Please sign in again' });
                return;
            }
            const user = await admin.auth().verifyIdToken(idToken);

            const body = (req.body ?? {}) as { churchId?: string; budgetId?: string };
            if (!body.churchId || !body.budgetId) {
                res.status(400).json({ error: 'Missing churchId or budgetId' });
                return;
            }
            const { churchId, budgetId } = body;

            // 2. Are they allowed to see this church's budgets?
            const db = admin.firestore();
            const [membership, church] = await Promise.all([
                db.doc(`users/${user.uid}/memberships/${churchId}`).get(),
                db.doc(`churches/${churchId}`).get(),
            ]);
            const role = membership.get('role') as string | undefined;
            if (
                membership.get('status') !== 'active' ||
                !role ||
                !ALLOWED_ROLES.includes(role) ||
                church.get('status') !== 'active'
            ) {
                res.status(403).json({ error: 'You do not have access to summarise this budget' });
                return;
            }

            // 3. Read the budget, its lines and the discussion.
            const budgetRef = db.doc(`churches/${churchId}/budgets/${budgetId}`);
            const [budget, linesSnap, commentsSnap] = await Promise.all([
                budgetRef.get(),
                budgetRef.collection('lines').get(),
                budgetRef.collection('comments').get(),
            ]);
            if (!budget.exists) {
                res.status(404).json({ error: 'Budget not found' });
                return;
            }

            const currency: string = church.get('currency') ?? 'UGX';
            const money = (n: number) => `${currency} ${Math.round(n).toLocaleString('en-US')}`;

            const lines: Line[] = linesSnap.docs.map((d) => ({
                name: String(d.get('name') ?? ''),
                type: String(d.get('type') ?? 'expense'),
                planned: Number(d.get('planned') ?? 0),
                committed: Number(d.get('committed') ?? 0),
                actual: Number(d.get('actual') ?? 0),
            }));
            const expense = lines.filter((l) => l.type === 'expense');
            const income = lines.filter((l) => l.type === 'income');
            const total = (xs: Line[], pick: (l: Line) => number) => xs.reduce((s, l) => s + pick(l), 0);

            const recentComments = commentsSnap.docs
                .filter((d) => d.get('kind') === 'comment')
                .map((d) => ({
                    at: (d.get('createdAt') as admin.firestore.Timestamp | undefined)?.toMillis() ?? 0,
                    who: String(d.get('authorName') ?? ''),
                    text: String(d.get('text') ?? ''),
                }))
                .sort((a, b) => a.at - b.at)
                .slice(-12);

            const percent = (l: Line) =>
                l.planned > 0 ? `${Math.round(((l.committed + l.actual) / l.planned) * 100)}%` : 'n/a';

            const facts = [
                `Budget: ${budget.get('name')} (${budget.get('year')}). Status: ${budget.get('status')}.`,
                `Planned expenses: ${money(total(expense, (l) => l.planned))}. Spent: ${money(total(expense, (l) => l.actual))}. Reserved for approved purchases: ${money(total(expense, (l) => l.committed))}.`,
                `Planned income: ${money(total(income, (l) => l.planned))}. Received so far: ${money(total(income, (l) => l.actual))}.`,
                'Expense lines (name | planned | spent | reserved | used):',
                ...expense.map((l) => `- ${l.name} | ${money(l.planned)} | ${money(l.actual)} | ${money(l.committed)} | ${percent(l)}`),
                'Income lines (name | target | received):',
                ...income.map((l) => `- ${l.name} | ${money(l.planned)} | ${money(l.actual)}`),
                budget.get('decisionNote') ? `Latest note from the lead pastor: ${budget.get('decisionNote')}` : '',
                recentComments.length ? 'Recent comments:' : '',
                ...recentComments.map((c) => `- ${c.who}: ${c.text}`),
            ]
                .filter((x) => x !== '')
                .join('\n');

            // 4. Ask the AI.
            const system =
                'You help a church leadership team understand a budget. Write in plain, warm, simple English for ' +
                'people who are not accountants. Use ONLY the figures given and never invent numbers. ' +
                'Keep it under 180 words. Use this shape: one short paragraph titled "Where we stand"; ' +
                'then "Watch closely" with at most 3 short bullet points; then "Suggested next steps" with at most 3 ' +
                'short bullet points. If the budget is waiting for approval or changes were requested, say so. ' +
                'If nothing has been spent yet, say that and focus on whether planned income covers planned expenses.';

            const apiResponse = await (globalThis as any).fetch('https://api.anthropic.com/v1/messages', {
                method: 'POST',
                headers: {
                    'content-type': 'application/json',
                    'x-api-key': anthropicKey.value(),
                    'anthropic-version': '2023-06-01',
                },
                body: JSON.stringify({
                    model: MODEL,
                    max_tokens: 700,
                    system,
                    messages: [{ role: 'user', content: facts }],
                }),
            });

            if (!apiResponse.ok) {
                logger.error('AI request failed', apiResponse.status, await apiResponse.text());
                res.status(502).json({ error: 'The AI service could not be reached. Try again in a moment.' });
                return;
            }

            const out = (await apiResponse.json()) as { content?: Array<{ type: string; text?: string }> };
            const summary = (out.content ?? [])
                .filter((b) => b.type === 'text')
                .map((b) => b.text ?? '')
                .join('\n')
                .trim();

            if (!summary) {
                res.status(502).json({ error: 'The AI returned an empty summary. Try again.' });
                return;
            }

            // 5. Keep it on the budget so everyone with access can read it.
            await budgetRef.update({
                aiSummary: summary,
                aiSummaryAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            res.json({ summary });
        } catch (error) {
            logger.error(error);
            res.status(500).json({ error: 'Something went wrong. Please try again.' });
        }
    }
);