import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(email, _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Type your email above, then tap "Forgot password".');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('If that email has an account, a reset link is on its way.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _form(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sign in', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Use the login your administrator gave you.',
          style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: _hide,
          onSubmitted: (_) => _signIn(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _hide ? 'Show password' : 'Hide password',
              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.error_outline, color: scheme.error, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!, style: TextStyle(color: scheme.error))),
            ]),
          ),
        ],
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          child: _busy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
              : const Text('Sign in'),
        ),
        const SizedBox(height: 6),
        TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 860;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            const Expanded(flex: 5, child: _BrandPanel()),
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: _form(context)),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _BrandPanel(compact: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: _form(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final soft = Colors.white.withValues(alpha: 0.80);

    Widget logo() => Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.church, color: AppColors.ink),
      ),
      const SizedBox(width: 12),
      Text('Church CMS', style: t.titleLarge?.copyWith(color: Colors.white)),
    ]);

    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.gold, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: t.bodyLarge?.copyWith(color: soft))),
      ]),
    );

    if (compact) {
      return Container(
        color: AppColors.forestDeep,
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
              child: Align(alignment: Alignment.centerLeft, child: logo()),
            ),
            const PatternBand(height: 16),
          ]),
        ),
      );
    }

    return Container(
      color: AppColors.forestDeep,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  logo(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Run your church\nfrom one place.',
                        style: t.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 28),
                      point(Icons.account_balance_wallet_outlined, 'Funds, budgets and purchases that add up.'),
                      point(Icons.badge_outlined, 'See who is working from the office, home or the field.'),
                      point(Icons.lock_outline, 'Each church\'s records stay private to that church.'),
                    ],
                  ),
                  const SizedBox.shrink(),
                ],
              ),
            ),
          ),
          const PatternBand(height: 28),
        ],
      ),
    );
  }
}