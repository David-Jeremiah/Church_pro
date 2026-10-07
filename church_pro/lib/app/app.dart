import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_messenger.dart';
import 'router.dart';

class ChurchApp extends ConsumerWidget {
  const ChurchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Church CMS',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      scaffoldMessengerKey: rootMessengerKey,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
