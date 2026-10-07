import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF3F51B5);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );
}
