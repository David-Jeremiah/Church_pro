import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../finance/domain/finance_models.dart';
import '../../team/domain/team_member.dart';
import '../data/budget_ai_service.dart';
import '../domain/budget_models.dart';

final budgetCommentsProvider = StreamProvider.family<List<BudgetComment>, String>((ref, budgetId) {
  final churchId = ref.watch(activeChurchIdProvider);
  if (churchId == null) return Stream.value(const <BudgetComment>[]);
  return ref.watch(budgetRepositoryProvider).watchComments(churchId, budgetId);
});

/// One budget: where it is in the approval journey, the AI summary, the lines
/// with spending against them, and the discussion.
class BudgetDetailScreen extends ConsumerStatefulWidget {
  const BudgetDetailScreen({super.key, required this.budgetId});

  final String budgetId;

  @override
  ConsumerState<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends ConsumerState<BudgetDetailScreen> {
  final _comment = TextEditingController();
  bool _summarizing = false;
  String? _freshSummary;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  String get _churchId => ref.read(activeChurchIdProvider)!;
  String get _name => ref.read(authStateProvider).value?.displayName ?? '';
  String get _roleName => ref.read(currentRoleProvider).name;

  Future<void> _summarize() async {
    setState(() => _summarizing = true);
    try {
      final text = await BudgetAiService().summarize(churchId: _churchId, budgetId: widget.budgetId);
      if (mounted) setState(() => _freshSummary = text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  Future<void> _requestChanges() async {
    final note = await promptText(context, title: 'Ask for changes', label: 'What should change?');
    if (note == null || note.isEmpty) return;
    await ref.read(budgetRepositoryProvider).decide(_churchId, widget.budgetId,
        approve: false, byName: _name, byRole: _roleName, note: note);
  }

  Future<void> _post() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    _comment.clear();
    await ref.read(budgetRepositoryProvider).comment(_churchId, widget.budgetId,
        text: text, byName: _name, byRole: _roleName);
  }

  void _openSharing(Budget budget, List<TeamMember> team) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShareSheet(budget: budget, team: team),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    bool can(Permission p) => Permissions.can(role, p);
    final canManage = can(Permission.manageBudgets);
    final canApprove = can(Permission.approveBudget);
    final canComment = can(Permission.commentBudget);
    final currency = ref.watch(currencyProvider);
    String money(int v) => formatMoney(v, currency: currency);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    final me = ref.watch(authStateProvider).value?.uid;

    final budget = ref.watch(budgetsProvider).value?.where((b) => b.id == widget.budgetId).firstOrNull;
    final lines = ref.watch(budgetLinesProvider(widget.budgetId)).value ?? const <BudgetLine>[];
    final comments = ref.watch(budgetCommentsProvider(widget.budgetId));
    final team = ref.watch(teamProvider).value ?? const <TeamMember>[];
    final hasLeadPastor = team.any((m) => m.active && m.role == ChurchRole.leadPastor);
    final repo = ref.read(budgetRepositoryProvider);

    if (budget == null) {
      return Scaffold(appBar: AppBar(title: const Text('Budget')), body: const Center(child: CircularProgressIndicator()));
    }

    final expense = lines.where((l) => l.type == TxType.expense).toList();
    final planned = expense.fold<int>(0, (s, l) => s + l.planned);
    final used = expense.fold<int>(0, (s, l) => s + l.committed + l.actual);
    final summary = _freshSummary ?? budget.aiSummary;
    final canSummarize = canManage || canApprove;

    // What can this person do now?
    final canSend = canManage && (budget.isDraft || budget.needsChanges) && hasLeadPastor;
    final canActivate = canManage && (budget.isApproved || ((budget.isDraft || budget.needsChanges) && !hasLeadPastor));
    final canDecide = canApprove && budget.isPending;

    return Scaffold(
      appBar: AppBar(
        title: Text(budget.name),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Who can see this budget',
              icon: const Icon(Icons.group_outlined),
              onPressed: () => _openSharing(budget, team),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
          children: [
            // ── Progress ──
            _Journey(budget: budget),
            if (budget.needsChanges && budget.decisionNote.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${budget.decidedByName ?? 'The lead pastor'} asked for changes: ${budget.decisionNote}'),
              ),
            if (canSend || canActivate || canDecide) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (canSend)
                    FilledButton.icon(
                      onPressed: () => repo.submitForApproval(_churchId, budget.id, byName: _name, byRole: _roleName),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Send to the lead pastor'),
                    ),
                  if (canDecide) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: () => repo.decide(_churchId, budget.id, approve: true, byName: _name, byRole: _roleName),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _requestChanges,
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Ask for changes'),
                    ),
                  ],
                  if (canActivate)
                    FilledButton.icon(
                      onPressed: () => repo.activate(_churchId, budget.id,
                          previousActiveId: ref.read(activeBudgetProvider)?.id, byName: _name, byRole: _roleName),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(budget.isApproved ? 'Make it the active budget' : 'Make active (no approval needed)'),
                    ),
                ],
              ),
            ],
            if (canManage && (budget.isDraft || budget.needsChanges) && !hasLeadPastor)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'This church has no lead pastor login yet, so the budget can go straight to active. '
                      'Add a lead pastor under Team and logins to use the approval step.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),

            // ── Spending ──
            if (expense.isNotEmpty) ...[
              const SectionTitle('Spending so far'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: planned <= 0 ? 0 : (used / planned).clamp(0, 1).toDouble(),
                      color: used > planned ? AppColors.danger : null,
                    ),
                    const SizedBox(height: 8),
                    Text('${money(used)} spent or reserved of ${money(planned)} planned'
                        '${planned > 0 ? ' (${(100 * used / planned).round()}%)' : ''}'),
                  ],
                ),
              ),
            ],

            // ── AI summary ──
            if (canSummarize) ...[
              const SectionTitle('AI summary'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.auto_awesome, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summary.isEmpty ? 'Get a plain-language summary' : 'Where this budget stands',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _summarizing ? null : _summarize,
                        icon: _summarizing
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(summary.isEmpty ? Icons.auto_awesome : Icons.refresh),
                        label: Text(summary.isEmpty ? 'Create summary' : 'Refresh'),
                      ),
                    ]),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SelectableText(summary),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Written by AI from this budget\'s numbers and comments. Check it before you rely on it.'
                          '${budget.aiSummaryAt != null ? '  Last updated ${formatDate(budget.aiSummaryAt!)}.' : ''}',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // ── Lines ──
            SectionTitle(
              'Budget lines',
              trailing: canManage && !budget.isClosed
                  ? TextButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _AddLineSheet(budgetId: budget.id),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add a line'),
              )
                  : null,
            ),
            if (lines.isEmpty)
              Text('No lines yet.', style: TextStyle(color: muted))
            else ...[
              for (final type in [TxType.expense, TxType.income])
                if (lines.any((l) => l.type == type)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6),
                    child: Text(type == TxType.expense ? 'Expenses' : 'Income',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: muted)),
                  ),
                  for (final l in lines.where((l) => l.type == type)) _LineTile(line: l, canManage: canManage, money: money),
                ],
            ],

            // ── Discussion ──
            const SectionTitle('Discussion'),
            comments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(
                'The discussion is private to the people this budget is shared with.',
                style: TextStyle(color: muted),
              ),
              data: (list) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('No comments yet. Start the conversation below.', style: TextStyle(color: muted)),
                    ),
                  for (final c in list) _CommentBubble(comment: c, mine: c.authorUid == me),
                  if (canComment) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _comment,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(hintText: 'Write a comment'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Send',
                          onPressed: _post,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four steps: Draft, Sent for approval, Approved, Active.
class _Journey extends StatelessWidget {
  const _Journey({required this.budget});

  final Budget budget;

  static const _labels = ['Draft', 'Sent for approval', 'Approved', 'Active'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    final current = budget.step;

    Widget dot(int i) {
      final done = i < current || (i == current && budget.isActive);
      final here = i == current && !done;
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppColors.success : (here ? AppColors.gold : scheme.outlineVariant),
        ),
        child: done
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: here ? AppColors.ink : muted)),
      );
    }

    final notes = <String>[
      if (budget.submittedAt != null) 'Sent by ${budget.submittedByName ?? 'someone'} on ${formatDate(budget.submittedAt!)}.',
      if (budget.decidedAt != null && budget.isApproved || budget.decidedAt != null && budget.isActive)
        'Approved by ${budget.decidedByName ?? 'the lead pastor'} on ${formatDate(budget.decidedAt!)}.',
      if (budget.isClosed) 'This budget is closed.',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(child: i == 0 ? const SizedBox() : Container(height: 3, color: i <= current ? AppColors.success : scheme.outlineVariant)),
                        dot(i),
                        Expanded(child: i == 3 ? const SizedBox() : Container(height: 3, color: i < current ? AppColors.success : scheme.outlineVariant)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        i == 0 && budget.needsChanges ? 'Changes requested' : _labels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                          color: i == current ? scheme.onSurface : muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final n in notes) Text(n, style: TextStyle(color: muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.comment, required this.mine});

  final BudgetComment comment;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    final when = '${formatDate(comment.createdAt)}, ${formatTime(comment.createdAt)}';

    if (comment.isEvent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history, size: 14, color: muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text('${comment.authorName}: ${comment.text}  ($when)',
                style: TextStyle(color: muted, fontSize: 12), textAlign: TextAlign.center),
          ),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mine ? scheme.primary.withValues(alpha: 0.08) : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(comment.authorName, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            Text(ChurchRole.fromName(comment.authorRole).label, style: TextStyle(color: muted, fontSize: 12)),
            const Spacer(),
            Text(when, style: TextStyle(color: muted, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          SelectableText(comment.text),
        ],
      ),
    );
  }
}

class _LineTile extends ConsumerWidget {
  const _LineTile({required this.line, required this.canManage, required this.money});

  final BudgetLine line;
  final bool canManage;
  final String Function(int) money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final over = line.remaining < 0;
    final isExpense = line.type == TxType.expense;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: canManage
            ? () async {
          final v = await promptText(context, title: 'Change planned amount', label: line.name);
          final amount = int.tryParse(v ?? '');
          if (amount != null && amount >= 0) {
            await ref
                .read(budgetRepositoryProvider)
                .updatePlanned(ref.read(activeChurchIdProvider)!, line.budgetId, line.id, amount);
          }
        }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: line.usedFraction, color: over ? AppColors.danger : null),
              const SizedBox(height: 8),
              Text(
                isExpense
                    ? 'Planned ${money(line.planned)}.  Spent ${money(line.actual)}.  Reserved ${money(line.committed)}.  Left ${money(line.remaining)}.'
                    : 'Target ${money(line.planned)}.  Received ${money(line.actual)}.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: over ? AppColors.danger : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddLineSheet extends ConsumerStatefulWidget {
  const _AddLineSheet({required this.budgetId});

  final String budgetId;

  @override
  ConsumerState<_AddLineSheet> createState() => _AddLineSheetState();
}

class _AddLineSheetState extends ConsumerState<_AddLineSheet> {
  final _name = TextEditingController();
  final _planned = TextEditingController();
  TxType _type = TxType.expense;

  @override
  void dispose() {
    _name.dispose();
    _planned.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final planned = int.tryParse(_planned.text.trim());
    if (_name.text.trim().isEmpty || planned == null || planned < 0) return;
    await ref.read(budgetRepositoryProvider).addLine(
      ref.read(activeChurchIdProvider)!,
      widget.budgetId,
      name: _name.text.trim(),
      type: _type,
      planned: planned,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.expense, label: Text('Expense')),
              ButtonSegment(value: TxType.income, label: Text('Income')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Line name (for example Electricity)')),
          const SizedBox(height: 12),
          TextField(
            controller: _planned,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Planned amount for the year'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Add line')),
        ],
      ),
    );
  }
}

/// Choose who else can see this budget while it is prepared.
class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.budget, required this.team});

  final Budget budget;
  final List<TeamMember> team;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  late final Set<String> _selected = {...widget.budget.sharedWith};

  @override
  Widget build(BuildContext context) {
    final people = widget.team
        .where((m) => m.active && const [ChurchRole.pastor, ChurchRole.leader, ChurchRole.staff].contains(m.role))
        .toList();
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Who can see this budget', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('The admin, accountant and lead pastor always can.', style: TextStyle(color: muted)),
          const SizedBox(height: 8),
          Flexible(
            child: people.isEmpty
                ? Padding(padding: const EdgeInsets.all(16), child: Text('No pastors, leaders or staff yet.', style: TextStyle(color: muted)))
                : ListView(
              shrinkWrap: true,
              children: [
                for (final m in people)
                  CheckboxListTile(
                    value: _selected.contains(m.uid),
                    title: Text(m.name),
                    subtitle: Text(m.title.isEmpty ? m.role.label : '${m.title} (${m.role.label})'),
                    onChanged: (v) => setState(() => v == true ? _selected.add(m.uid) : _selected.remove(m.uid)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(budgetRepositoryProvider)
                  .updateSharing(ref.read(activeChurchIdProvider)!, widget.budget.id, _selected.toList());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}