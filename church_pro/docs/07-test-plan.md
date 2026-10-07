# 07 · Test Plan

## Levels

| Level | Tool | Scope |
|---|---|---|
| Unit | `flutter_test` | Permission matrix, formatters, budget line maths |
| Widget | `flutter_test` + provider overrides | Screens per role, forms, action buttons by status |
| Rules | Firebase Emulator + `@firebase/rules-unit-testing` | Tenant isolation, roles, transitions, ledger immutability |
| Integration | `integration_test` against the emulator | End-to-end flows below |
| UAT | Pilot church | Real use for 3-4 weeks |

## Unit tests (included)

`test/permissions_test.dart` covers the matrix: accountant can record transactions but not approve; admin approves; staff can log work and request purchases but not view finance; leader cannot log work; member has no staff permissions.

## Rules tests (must pass before every deploy)

**Tenant isolation:** user in church A cannot read or write church B; user with no membership reads nothing; suspended church blocks reads except the church doc.
**Platform admin:** can create a church, create users and memberships for a brand-new user, suspend; **cannot** read members, transactions, requisitions or work logs.
**Logins:** church admin can create a non-admin login in their own church; cannot create an admin; cannot add a membership for an existing user; user can only clear `mustChangePassword`.
**Accounting:** only admin/accountant read the ledger; create requires valid fields; no update except void; no delete; fund updates limited to allowed fields.
**Procurement:** staff create only for themselves with status `submitted`; only admin approves/rejects; requester can cancel own submitted request; accountant cannot approve; invalid jumps (submitted → paid) are denied; requesters read only their own.
**Work logs:** id must equal `uid_date`; user cannot write another user's log; only admin reads all.

## Integration scenarios

1. Platform admin adds a church → admin signs in, changes password → funds/categories appear.
2. Admin adds an accountant and a staff login → both must change password.
3. Accountant records tithe income and a manual expense → fund balances and month totals match the ledger.
4. Create budget, add lines, activate; staff raises a request within budget → admin approves → line "reserved" increases.
5. Accountant orders, receives, pays → expense appears in the ledger, reserved decreases, spent increases, fund balance drops.
6. Request over the remaining budget cannot be submitted (and cannot be approved if budget changed).
7. Void a manual entry → balance and line actual are restored.
8. Staff clock in as Home, clock out with notes → admin team board shows Home and the duration.
9. Staff logs a forgotten day → appears in history and counts.
10. Platform admin suspends the church → every user sees the suspended screen.

## Integrity checks (run regularly)

- Sum of all confirmed ledger entries per fund equals the fund `balance`.
- For each line: `actual` equals the sum of linked confirmed transactions; `committed` equals the sum of approved/ordered/received requests.
- Every paid request has exactly one linked transaction.

## Non-functional

Cold start < 3 s on a low-end phone; ledger of 1,000 entries scrolls smoothly; offline: members, attendance, ledger entry and clock-in work and sync later; Windows build runs the same flows; no sensitive data in logs.

## Exit criteria

All rules tests green; analyzer clean; integrity checks pass on the pilot data; pilot signs off the UAT list (record 1 week of real income/expenses, one purchase from request to payment, one week of staff work logs).
