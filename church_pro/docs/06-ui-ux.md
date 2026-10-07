# 06 · UI / UX

## Principles

1. **Role-first:** each person sees only what they can use. A leader sees People and Services; a pastor adds Work; the accountant adds Finance.
2. **Two taps for daily jobs:** clock in, mark attendance, raise a request.
3. **Money screens are calm and exact:** integers, currency from the church, red only for problems.
4. **Low-end friendly:** simple widgets, no heavy animation, cached data first.
5. **Works on Windows and phones:** same screens; the office team will use Windows.

## Navigation by role

| Tab | Admin | Accountant | Pastor | Staff | Leader | Member |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| Home | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| People | ✅ | ✅ | ✅ | ✅ | ✅ | |
| Services | ✅ | | ✅ | ✅ | ✅ | |
| Finance | ✅ all tabs | ✅ all tabs | Purchases | Purchases | Purchases | |
| Work | ✅ + Team | ✅ | ✅ | ✅ | | |

Drawer: Events · Team & logins (admin) · Change password · Switch church · Sign out.
Platform admin has a separate console (church list, add church).

## Screens

| Screen | Purpose |
|---|---|
| Login | Email, password, forgot password (no sign-up) |
| Change password | Forced at first sign-in |
| Church picker | Only when a user belongs to several churches |
| Platform console / Add church | List with status chips; form that ends with a credentials dialog |
| Home | Role cards: my work today, approvals waiting, month money, team today, members, last service |
| Finance › Overview | Income, expenses, net, all-funds total, active budget bar, fund balances |
| Finance › Ledger | Filter chips, entries with sign and colour, long-press to void, add-entry sheet |
| Finance › Budgets | Budget list; detail with lines, progress bars, add line, change planned, make active |
| Finance › Purchases | Request list with status chips; new request; detail with role-based action buttons |
| Work › My work | Clock in (segmented Office/Home/Field), clock out with notes, 30-day summary, past-day log |
| Work › Team | Today's board and 31-day summary per person |
| Team & logins | List with role chips, add login sheet, role/deactivate/reset menu |

## Key interaction details

- **Credentials dialog** shows email and password once with a Copy button.
- **Budget check text** appears under the budget-line field while typing the amount: "Available in …", or an error when over budget.
- **Voided** ledger entries are struck through and grey, never hidden.
- **Request detail** shows only the buttons the signed-in role may use for the current status.
- **Work card** adapts: not clocked in → mode picker; clocked in → notes + clock out; done → summary.

## Copy guidelines

Plain language ("Make active", "Record payment"); say what happens ("Cancel and release budget"); errors tell the user what to do next.

## Accessibility

Tap targets ≥ 48 dp, text scales, colour is never the only signal (status chips carry labels, voided has strikethrough), tooltips on icon buttons.
