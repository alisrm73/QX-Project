import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> qxThemeMode =
    ValueNotifier<ThemeMode>(ThemeMode.dark);

ThemeData qxDarkTheme() {
  const seed = Color(0xFF7C6CFF);
  const background = Color(0xFF0B0D13);
  const card = Color(0xFF151923);
  const muted = Color(0xFF969BAD);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF11131B),
    ).copyWith(
      onSurfaceVariant: muted,
      surfaceContainerHighest: const Color(0xFF111722),
    ),
    scaffoldBackgroundColor: background,
    cardColor: card,
    dividerColor: const Color(0x1AFFFFFF),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    fontFamily: 'Roboto',
  );
}

ThemeData qxLightTheme() {
  const seed = Color(0xFF7C6CFF);
  const background = Color(0xFFFAF9F6);
  const card = Color(0xFFFFFFFF);
  const foreground = Color(0xFF282633);
  const muted = Color(0xFF6F7180);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: card,
    ).copyWith(
      onSurface: foreground,
      onSurfaceVariant: muted,
      outlineVariant: const Color(0xFFE8E4DC),
      surfaceContainerHighest: const Color(0xFFEFEDE7),
    ),
    scaffoldBackgroundColor: background,
    cardColor: card,
    dividerColor: const Color(0xFFE8E4DC),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
    ),
    fontFamily: 'Roboto',
  );
}
