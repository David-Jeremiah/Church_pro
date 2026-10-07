# 01 · Product Requirements Document (PRD)

| | |
|---|---|
| Product | Church CMS: church administration, accounting, procurement and remote-work platform |
| Version | 0.2 (redesign) |
| Platforms | Flutter (Android, iOS, Windows) + Firebase |
| Model | Multi-church; **the platform admin onboards every church** |

## 1. Vision

One secure system a church can run from the office or from home: people, services, **accounting, budgets, purchasing and staff work location**, with the platform owner in control of which churches exist and who administers them.

## 2. Problems

- Churches keep money records in notebooks and spreadsheets; restricted funds get mixed up.
- Purchases happen without approval or without checking the budget.
- Leaders cannot see who is working from the office, home or field.
- Generic church software ignores mobile money and unreliable internet.
- The platform owner needs control over who joins; open sign-up is not wanted.

## 3. Goals / non-goals

**Goals**
1. A church is onboarded (church + admin login) in under 3 minutes by the platform admin.
2. The admin or accountant can record every shilling in/out and see fund balances and budget use at any time.
3. No purchase is approved without a budget line; approval reserves the money.
4. Every staff member can record office / home / field work in two taps.
5. Strict tenant isolation: a church never sees another church's data; the platform admin cannot read church finances.

**Non-goals (this phase):** payroll, bank reconciliation, mobile-money API collection, SMS/WhatsApp bulk messaging, child check-in, member self-service portal, public website builder.

## 4. Users

| Who | Purpose |
|---|---|
| **Platform admin** | Add churches and administrators, suspend/activate, support. Listed in `platformAdmins` |
| **Church admin** | Runs the church: users, people, accounting (if no accountant), budgets, approvals, team work view |
| **Accountant** | Books, ledger, budgets, order/receive/pay purchases. Optional |
| **Pastor** | People, services, events, purchase requests, own work log |
| **Staff** (secretary, officers) | Members, services, events, purchase requests, own work log |
| **Leader** | View members, mark attendance, request purchases |
| **Member** | Limited (events); full member portal is a later phase |

## 5. Scope

| Module | Key features | Priority |
|---|---|---|
| Platform | Add church + admin login, suspend/activate, reset admin password | P0 |
| Logins | Church admin creates team logins with roles; temp password + forced change; deactivate; reset | P0 |
| People & services | Members, attendance, events | P0 |
| Accounting | Funds, categories, ledger, void, balances, overview | P0 |
| Budgeting | Budgets, lines, active budget, planned/actual/reserved | P0 |
| Procurement | Request, budget check, approve/reject, order, receive, pay, cancel | P0 |
| Remote work | Clock in/out with office/home/field, past-day log, team board and summary | P0 |
| Reports | Export ledger, budget vs actual PDF/Excel | P1 |
| Pledges, recurring income, transfers between funds | | P1 |
| Mobile money (MTN/Airtel) collection | | P2 |
| SMS / WhatsApp | | P2 |

## 6. Key rules

- Accounting is done by the **admin or accountant**. When both exist, **only the admin approves purchases** (separation of duties); the accountant orders, receives and pays.
- The ledger is **append-only**: entries are voided, never edited or deleted.
- Fund balances and budget counters are updated in the same batch as the ledger entry.
- Approving a request **reserves** its amount; paying releases the reservation and posts the expense.
- Over-budget requests are blocked by default (`settings.blockOverBudget`).
- Accounts are never self-registered. First sign-in forces a password change.
- A suspended church cannot use the app; its data is kept.

## 7. Non-functional

| Area | Requirement |
|---|---|
| Offline | Core writes continue offline (Firestore cache); creating churches/logins needs a connection |
| Security | Firestore rules enforce roles and tenant isolation; rules tested in the emulator |
| Privacy | Platform admin can manage churches but cannot read members, ledger or work logs |
| Devices | Android 8+, low-end phones, Windows desktop for office use |
| Currency | Per church (default UGX), amounts as integers |

## 8. Success metrics

Time to onboard a church; % churches with an active budget; % purchases that go through a request; daily work-log completion by staff; ledger entries per church per month; crash-free sessions.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Counters (balances, budget lines) drift if a client bug skips an update | Updates are in the same batch as the entry; add a Cloud Function that recalculates/audits nightly |
| Over-budget check is client-side | Rules enforce roles and transitions; add server-side budget validation with a Cloud Function in phase 2 |
| Temporary passwords shared insecurely | Shown once, forced change, reset emails |
| Secondary-app login creation breaks on a platform | Move provisioning to a Cloud Function (Admin SDK) |
| Work logs are self-reported | Admin team view, optional approval later; no GPS tracking by design |

## 10. Milestones

0 docs and research · 1 platform console + logins + roles · 2 people/services/events · 3 accounting + budgets · 4 procurement · 5 remote work · 6 reports/export, Cloud Functions hardening · 7 pilot church, Play Store.

## 11. Open questions

- Should the accountant be allowed to approve small purchases below a limit?
- Do churches need multiple branches under one church?
- Which mobile-money provider first, and who holds the merchant account?
- Subscription pricing and who invoices the churches?
