import '../../../core/utils/formatters.dart';
import '../../finance/domain/finance_models.dart';
import 'budget_models.dart';

/// A plain-language reading of a budget, worked out from its numbers.
/// No internet, no AI and no cost: it updates by itself as figures change.
class BudgetSummary {
  const BudgetSummary({required this.standing, required this.watch, required this.next});

  /// Short paragraphs about where the budget stands.
  final List<String> standing;

  /// Things that need attention (may be empty).
  final List<String> watch;

  /// Suggested next steps.
  final List<String> next;
}

BudgetSummary buildBudgetSummary({
  required Budget budget,
  required List<BudgetLine> lines,
  required List<BudgetComment> comments,
  required String currency,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  String money(int v) => formatMoney(v, currency: currency);
  String pct(num x) => '${(x * 100).round()}%';
  String plural(int n, String one, [String? many]) => n == 1 ? '1 $one' : '$n ${many ?? '${one}s'}';
  int daysSince(DateTime d) => today.difference(d).inDays;
  String ago(DateTime d) {
    final n = daysSince(d);
    return n <= 0 ? 'today' : (n == 1 ? 'yesterday' : '$n days ago');
  }

  int total(List<BudgetLine> xs, int Function(BudgetLine) pick) => xs.fold<int>(0, (s, l) => s + pick(l));

  final expense = lines.where((l) => l.type == TxType.expense).toList();
  final income = lines.where((l) => l.type == TxType.income).toList();
  final plannedOut = total(expense, (l) => l.planned);
  final spent = total(expense, (l) => l.actual);
  final reserved = total(expense, (l) => l.committed);
  final used = spent + reserved;
  final plannedIn = total(income, (l) => l.planned);
  final received = total(income, (l) => l.actual);

  final inThisYear = budget.isActive && budget.year == today.year;
  final yearGone = ((today.difference(DateTime(today.year)).inDays + 1) / 365).clamp(0.0, 1.0);

  final over = expense.where((l) => l.remaining < 0).toList()..sort((a, b) => a.remaining.compareTo(b.remaining));
  final near = expense
      .where((l) => l.planned > 0 && l.remaining >= 0 && (l.committed + l.actual) / l.planned >= 0.9)
      .toList();

  final standing = <String>[];
  final watch = <String>[];
  final next = <String>[];

  // Where is it in the approval journey?
  switch (budget.status) {
    case 'draft':
      standing.add('This budget is still a draft.');
    case 'pending_approval':
      final sender = budget.submittedByName ?? 'The finance team';
      final sentWhen = budget.submittedAt == null ? '' : ', ${ago(budget.submittedAt!)}';
      standing.add('It is waiting for the lead pastor to approve it. $sender sent it$sentWhen.');
      if (budget.submittedAt != null && daysSince(budget.submittedAt!) >= 7) {
        watch.add('It has been waiting for approval for ${plural(daysSince(budget.submittedAt!), 'day')}.');
      }
    case 'changes_requested':
      final reviewer = budget.decidedByName ?? 'The lead pastor';
      standing.add(budget.decisionNote.isEmpty
          ? '$reviewer asked for changes.'
          : '$reviewer asked for changes: ${budget.decisionNote}');
    case 'approved':
      final approver = budget.decidedByName ?? 'the lead pastor';
      final approvedWhen = budget.decidedAt == null ? '' : ' on ${formatDate(budget.decidedAt!)}';
      standing.add('It was approved by $approver$approvedWhen and is ready to be made the active budget.');
    case 'active':
      standing.add('This is the active budget for ${budget.year}.');
    case 'closed':
      standing.add('This budget is closed.');
  }

  if (lines.isEmpty) {
    standing.add('There are no lines yet. Add the expenses, and the income you expect, to see how the plan looks.');
    next.add('Add the budget lines.');
  } else {
    // Does the plan add up?
    if (plannedOut > 0 && plannedIn == 0) {
      standing.add('Planned expenses are ${money(plannedOut)}, but no income has been planned, '
          'so we cannot tell yet whether they are covered.');
    } else if (plannedIn > 0 || plannedOut > 0) {
      final gap = plannedIn - plannedOut;
      standing.add('Planned income is ${money(plannedIn)} and planned expenses are ${money(plannedOut)}. '
          '${gap >= 0 ? 'The plan leaves ${money(gap)} to spare.' : 'The plan is short by ${money(-gap)}.'}');
      if (gap < 0) watch.add('Planned expenses are higher than planned income by ${money(-gap)}.');
    }

    // How is spending going?
    if (plannedOut > 0 && (used > 0 || budget.isActive)) {
      final share = used / plannedOut;
      var text = 'So far ${money(spent)} has been spent'
          '${reserved > 0 ? ' and ${money(reserved)} is reserved for approved purchases' : ''}, '
          'which is ${pct(share)} of the planned expenses.';
      if (inThisYear) {
        text += ' About ${pct(yearGone)} of the year has passed.';
        if (share > yearGone + 0.15) {
          watch.add('Spending is running ahead of the calendar: ${pct(share)} used with ${pct(yearGone)} of the year gone.');
        } else if (yearGone > 0.25 && share < yearGone - 0.25) {
          watch.add('Spending is well behind the calendar. Money may be sitting unused, or expenses are not being recorded.');
        }
      }
      standing.add(text);
    }

    // How is income going?
    if (plannedIn > 0 && (received > 0 || budget.isActive)) {
      final share = received / plannedIn;
      standing.add('Income received so far is ${money(received)}, which is ${pct(share)} of the ${money(plannedIn)} expected.');
      if (inThisYear && yearGone > 0.5 && share < yearGone - 0.2) {
        watch.add('Income is behind: ${pct(share)} received with ${pct(yearGone)} of the year gone.');
      }
    }

    // Lines that need attention.
    for (final l in over.take(3)) {
      watch.add('"${l.name}" is over its plan by ${money(-l.remaining)}.');
    }
    if (over.length > 3) watch.add('${plural(over.length - 3, 'more line')} also over budget.');
    for (final l in near.take(3)) {
      watch.add('"${l.name}" has used ${pct((l.committed + l.actual) / l.planned)} of its plan.');
    }
  }

  // The discussion.
  final talk = comments.where((c) => !c.isEvent).toList();
  if (talk.isNotEmpty) {
    final last = talk.last;
    standing.add('${plural(talk.length, 'comment')} so far. The latest is from ${last.authorName}, ${ago(last.createdAt)}.');
  }

  // What to do next.
  switch (budget.status) {
    case 'draft':
      if (lines.isNotEmpty) next.add('Check that every line has a planned amount, then send the budget for approval.');
    case 'pending_approval':
      next.add('The lead pastor should read the lines and the comments, then approve or ask for changes.');
    case 'changes_requested':
      next.add('Make the changes that were asked for, then send the budget again.');
    case 'approved':
      next.add('Make it the active budget so purchase requests are checked against it.');
    case 'active':
      if (over.isNotEmpty || near.isNotEmpty) {
        next.add('Decide how to handle the lines that are over or close to their limit before approving more purchases.');
      }
      next.add('Keep recording every expense and gift against its budget line so these figures stay accurate.');
    default:
      next.add('Use this budget as a reference when preparing the next one.');
  }

  return BudgetSummary(standing: standing, watch: watch.take(6).toList(), next: next);
}
