# 02 · User Stories

P0 = this phase, P1 = next.

## Platform admin
- **PA-1 (P0) Add a church.** I enter church name, country, currency and the administrator's name and email; the system creates the church and the admin login and shows a temporary password once.
- **PA-2 (P0) Suspend / activate.** A suspended church shows a "suspended" screen to all its users.
- **PA-3 (P0) Reset admin password.** I can send a reset email to a church's administrator.
- **PA-4 (P0) Privacy.** I can see the list of churches but never their members, ledger or work logs.

## Logins and access
- **LG-1 (P0)** Sign in with the login my administrator gave me; there is no sign-up.
- **LG-2 (P0)** At first sign-in I must choose my own password.
- **LG-3 (P0)** Admin adds a login (name, email, role); can change role, deactivate, send reset.
- **LG-4 (P0)** If I belong to several churches I choose which one to open and can switch.

## People and services
- **PE-1 (P0)** Staff and pastors add, edit and delete members; leaders and accountants can view.
- **PE-2 (P0)** Pastors, staff and leaders mark attendance for a service.
- **PE-3 (P0)** Create and view events.

## Accounting (admin or accountant)
- **AC-1 (P0)** Record income (tithes, offerings, donations) with fund, category, method, date, optional giver.
- **AC-2 (P0)** Record an expense; I am warned when a fund does not have enough money, and restricted funds are labelled.
- **AC-3 (P0)** Void a manual entry; it stays visible, struck through, and balances are corrected.
- **AC-4 (P0)** See this month's income, expenses and net, and each fund's balance.
- **AC-5 (P0)** Funds and categories are created automatically for a new church.
- **AC-6 (P1)** Transfer money between funds; export the ledger.

## Budgeting
- **BU-1 (P0)** Create a yearly budget with income and expense lines and planned amounts.
- **BU-2 (P0)** Activate one budget; the previous active budget closes.
- **BU-3 (P0)** See per line: planned, spent, reserved by approved requests, and remaining; lines over budget show in red.
- **BU-4 (P0)** Link an expense or income entry to a budget line.

## Procurement
- **PR-1 (P0)** Any staff member raises a purchase request against an expense budget line and sees the available amount immediately.
- **PR-2 (P0)** Requests above the available amount cannot be submitted (setting).
- **PR-3 (P0)** The admin approves or rejects with a reason; approval reserves the amount.
- **PR-4 (P0)** Admin/accountant mark ordered, received, and paid; paying posts an expense to the ledger and releases the reservation.
- **PR-5 (P0)** A requester sees only their own requests; the admin and accountant see all.
- **PR-6 (P0)** A request can be cancelled before ordering; cancelling an approved request releases the reserved budget.

## Remote work
- **WK-1 (P0)** I clock in and choose Office, Home or Field; I clock out with notes about what I did.
- **WK-2 (P0)** I can log a day I forgot (date, mode, hours, notes).
- **WK-3 (P0)** I see my last 30 days split into office, home and field.
- **WK-4 (P0)** The admin sees who is in, where, and a 31-day summary per person.
- **WK-5 (P1)** Admin approval of home-work days; monthly export.
