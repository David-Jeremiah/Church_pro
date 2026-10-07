# 03 · Roles and Permissions Matrix

Two levels:
1. **Platform admin**: system owner, listed in `platformAdmins`. Manages churches only.
2. **Church roles**: per church; the same person may hold different roles in different churches.

Source of truth in code: `lib/core/constants/roles.dart` (UI) and `firestore.rules` (server).

## Church permissions

✅ allowed · ❌ not allowed · 👤 own records only

| Capability | Admin | Accountant | Pastor | Staff | Leader | Member |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| View members | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Add / edit / delete members | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Create services, events | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Mark attendance | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ |
| View events | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Ledger, funds, overview** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Record / void income and expenses** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Create / edit budgets, activate** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| View budget lines (to request purchases) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Raise purchase requests** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Approve / reject requests** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Order, receive, pay requests** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| See purchase requests | all | all | 👤 | 👤 | 👤 | ❌ |
| **Clock in/out (office/home/field)** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| View team work board | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Create team logins, change roles | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Edit church name / settings | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |

## Platform admin

| Action | Allowed |
|---|:-:|
| Create a church and its administrator login | ✅ |
| Suspend / activate a church | ✅ |
| Send a password reset to a church administrator | ✅ |
| Read members, ledger, budgets, requests, work logs | ❌ |

## Rules that always apply

1. Accounting is done by the **admin or the accountant**; when a church has no accountant the admin does everything.
2. Approval is admin-only, so when an accountant exists the same person does not both approve and pay.
3. The ledger is append-only; entries are voided, never deleted.
4. Requests move only through the allowed transitions: submitted → approved/rejected/cancelled → ordered → received → paid.
5. A church admin cannot create another admin or change an admin's role.
6. Nobody changes their own role.
7. A suspended church blocks all data access except reading its own status.
8. Work logs: each person writes only their own; only the admin reads everyone's.
