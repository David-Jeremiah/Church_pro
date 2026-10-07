import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a new login's details once so they can be copied and shared securely.
Future<void> showCredentials(
  BuildContext context, {
  required String title,
  required String email,
  required String password,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share these details securely. The password is shown only now, '
              'and the user must change it the first time they sign in.'),
          const SizedBox(height: 16),
          SelectableText('Email: $email'),
          const SizedBox(height: 4),
          SelectableText('Password: $password'),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copy'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: 'Email: $email\nPassword: $password'));
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Copied')));
          },
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
      ],
    ),
  );
}
