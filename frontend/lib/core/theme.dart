import 'package:flutter/material.dart';

// Dark: deep violet (not pink), Light: rich purple (not blue)
const _darkSeed  = Color(0xFF6D28D9); // violet-700 — deep, dark
const _lightSeed = Color(0xFF8B6BD1); // softer violet

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(seedColor: _lightSeed, brightness: Brightness.light).copyWith(
    primary: const Color(0xFF6B46B2),
    onSurface: const Color(0xFF120A22),
    onSurfaceVariant: const Color(0xFF2F234B),
    surface: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: Colors.white,
    surfaceContainerHigh: Colors.white,
    surfaceContainerHighest: Colors.white,
    outline: const Color(0xFF5A2E91),
    outlineVariant: const Color(0xFF5A2E91),
  ),
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: Colors.white,
  textTheme: Typography.blackMountainView.apply(
    bodyColor: const Color(0xFF120A22),
    displayColor: const Color(0xFF120A22),
  ),
  iconTheme: const IconThemeData(color: Color(0xFF5C3FA3)),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 1,
    foregroundColor: Color(0xFF1A102B),
    shape: Border(bottom: BorderSide(color: Color(0xFF5A2E91), width: 1.2)),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF5A2E91), width: 1.15),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFF5A2E91), thickness: 1),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 70,
    indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    indicatorColor: _lightSeed.withAlpha(24),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return IconThemeData(color: _lightSeed, size: 24);
      return const IconThemeData(size: 24);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _lightSeed);
      return const TextStyle(fontSize: 12);
    }),
  ),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _darkSeed,
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF000000),
    surfaceContainerLowest: const Color(0xFF000000),
    surfaceContainerLow: const Color(0xFF000000),
    surfaceContainer: const Color(0xFF000000),
    surfaceContainerHigh: const Color(0xFF2D1554),
    surfaceContainerHighest: const Color(0xFF000000),
    outline: const Color(0xFFCAB8F5),
    outlineVariant: const Color(0xFFCAB8F5),
  ),
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: const Color(0xFF000000),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: Color(0xFF000000),
    foregroundColor: Color(0xFFCAB8F5),
    shape: Border(bottom: BorderSide(color: Color(0xFFCAB8F5), width: 1.2)),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFCAB8F5), width: 1.15),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    color: const Color(0xFF000000),
    surfaceTintColor: Colors.transparent,
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFFCAB8F5), thickness: 1),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 70,
    indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    indicatorColor: _darkSeed.withAlpha(35),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return IconThemeData(color: _darkSeed, size: 24);
      return const IconThemeData(size: 24);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _darkSeed);
      return const TextStyle(fontSize: 12);
    }),
  ),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  ),
);
