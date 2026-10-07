# 05 · Architecture and Data Model

## Principles

1. **Feature-first folders**; each feature has `domain`, `data`, `presentation`.
2. **Screens never touch Firebase.** They read providers (`app/providers.dart`); providers call repositories; only repositories use Firestore.
3. **Tenant-scoped by construction.** Every church repository method takes a `churchId`; data lives under `churches/{churchId}/...`.
4. **Permissions in one place** (`roles.dart` + `PermissionGate`/`canProvider`) and mirrored in `firestore.rules`.
5. **Money is an integer** in the smallest currency unit.
6. **Counters change in the same batch as the entry** that caused them.

## Layers

```
Presentation (screens)  →  Providers (Riverpod)  →  Repositories  →  Firestore / Auth
```

Older modules (auth, church, members, attendance, events) keep an abstract interface plus a Firebase class in `data/firebase/`. The new modules (platform, team, finance, budget, procurement, work) are concrete Firestore repositories inside their feature's `data/` folder; extract an interface if you need mocks.

## Routing and session

`go_router` with one `redirect`: splash while loading → login → forced password change → platform console (platform admin) → church picker → church shell. The shell shows only the tabs the role may use (People, Services, Finance, Work); the drawer holds Events, Team & logins and account actions.

## Firestore data model

```
platformAdmins/{uid}                         name                      (created by hand)
users/{uid}                                  displayName, email, createdAt, mustChangePassword, provisionedBy, provisionedChurchId?
users/{uid}/memberships/{churchId}           churchName, role, status, joinedAt
churches/{churchId}                          name, country, currency, status, createdBy, createdAt, adminUid, adminEmail, settings{blockOverBudget}
  team/{uid}                                 displayName, email, role, status, createdAt
  members/{id}                               firstName, lastName, phone, email, status, userUid?, createdAt, updatedAt
  services/{id}                              title, date                      └ attendance/{memberId}: markedBy, markedAt
  events/{id}                                title, start, location
  funds/{id}                                 name, restricted, active, balance
  categories/{id}                            name, type (income|expense)
  transactions/{id}                          type, amount, fundId/Name, categoryId/Name, method, date, description,
                                             memberId/Name?, source (manual|procurement), requisitionId?, budgetId?, budgetLineId?,
                                             status (confirmed|voided), recordedBy, createdAt, voidedAt?, voidedBy?
  budgets/{id}                               name, year, status (draft|active|closed)
    lines/{id}                               name, type, planned, committed, actual
  requisitions/{id}                          title, description, vendor, amount, budgetId, budgetLineId, budgetLineName,
                                             status, requestedBy/Name, approvedBy/Name?, approvedAt?, rejectionReason?,
                                             orderedAt?, receivedAt?, paidAt?, paymentMethod?, transactionId?, createdAt
  workLogs/{uid_yyyy-MM-dd}                  uid, userName, date, mode (office|home|field), clockIn, clockOut?, notes
```

## Accounting integrity

| Action | Writes (one batch) |
|---|---|
| Record income/expense | transaction + `funds/{id}.balance ±amount` + `lines/{id}.actual +amount` (if linked) |
| Void entry | status → voided + reverse balance + reverse `actual` |
| Approve request | request → approved + `lines.committed +amount` |
| Cancel approved request | request → cancelled + `lines.committed −amount` |
| Pay request | request → paid + expense transaction + fund balance + `lines.actual +amount` and `lines.committed −amount` |

Remaining on a line = `planned − committed − actual`.

## What is enforced where

| Control | Client | Rules | Next step |
|---|:-:|:-:|---|
| Role access, tenant isolation | ✅ | ✅ | |
| Ledger append-only, void-only | ✅ | ✅ | |
| Request status transitions | ✅ | ✅ | |
| Admin-only approval | ✅ | ✅ | |
| Budget available before submit/approve | ✅ | ❌ | Cloud Function / rules `get()` on the line |
| Counter correctness | ✅ | partial (field whitelist) | Nightly audit Function |
| Auth account creation/deletion | secondary app | n/a | Cloud Function with Admin SDK |

## Offline behaviour

Firestore persistence is enabled. Most writes use `queued(...)` so the UI continues after 3 seconds offline and the write syncs later; server rejections that arrive in that window still show as errors. Creating a church or a login needs a connection.

## Error handling

`PlatformDispatcher.onError` routes unhandled async errors to `showAppError`, which shows a readable SnackBar (permission denied, offline, etc.). Forms catch their own validation errors.

## Packages

`flutter_riverpod`, `go_router`, `intl`, `firebase_core`, `firebase_auth`, `cloud_firestore`. Later: `firebase_messaging` (not on Windows), `pdf`/`excel` for reports, `cloud_functions`, `firebase_app_check`.

## Conventions

`flutter analyze` clean; `const` where possible; check `mounted`/`context.mounted` after awaits; no business logic in `build()` beyond display derivations.
