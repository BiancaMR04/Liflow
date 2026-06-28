import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFFFFF7FA);
  static const surface = Color(0xFFFFFFFF);

  static const primary = Color(0xFFF47AA7);
  static const primarySoft = Color(0xFFFFE1EC);

  static const text = Color(0xFF2B2B2F);
  static const textMuted = Color(0xFF6B6B75);

  static const brandDark = Color(0xFF7A1E44);

  static const outline = Color(0xFFF2D7E2);
  static const outlineSoft = Color(0xFFF6E3EC);
}

ThemeData buildAppTheme() {
  final scheme = const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: Color(0xFF5A1430),

    secondary: Color(0xFFFFB3CC),
    onSecondary: AppColors.text,
    secondaryContainer: Color(0xFFFFEAF1),
    onSecondaryContainer: Color(0xFF3A1021),

    tertiary: Color(0xFFFFC4D6),
    onTertiary: AppColors.text,
    tertiaryContainer: Color(0xFFFFF2F6),
    onTertiaryContainer: AppColors.text,

    error: Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),

    surface: AppColors.background,
    onSurface: AppColors.text,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerHighest: Color(0xFFFFEFF5),
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineSoft,

    shadow: Color(0x0A000000),
    scrim: Color(0x33000000),
    inverseSurface: AppColors.text,
    onInverseSurface: Color(0xFFF8F8FA),
    inversePrimary: Color(0xFFFFB3CC),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: GoogleFonts.dmSansTextTheme(),
  );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSerifDisplay(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        color: AppColors.brandDark,
        height: 1.05,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: scheme.outline, width: 1.2),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      visualDensity: VisualDensity.compact,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: const StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      hintStyle: GoogleFonts.dmSans(color: scheme.onSurfaceVariant),
      labelStyle: GoogleFonts.dmSans(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.2),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: rounded,
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

ThemeData buildDarkAppTheme() {
  final scheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF8FBC),
    onPrimary: Color(0xFF3E0D21),
    primaryContainer: Color(0xFF5B1C37),
    onPrimaryContainer: Color(0xFFFFD8E7),
    secondary: Color(0xFFFFB5CF),
    onSecondary: Color(0xFF3A1021),
    secondaryContainer: Color(0xFF4C2232),
    onSecondaryContainer: Color(0xFFFFD9E7),
    tertiary: Color(0xFFFFC2D5),
    onTertiary: Color(0xFF36111F),
    tertiaryContainer: Color(0xFF482434),
    onTertiaryContainer: Color(0xFFFFE0EA),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF151116),
    onSurface: Color(0xFFF4EDF1),
    surfaceContainerLowest: Color(0xFF1D181E),
    surfaceContainerHighest: Color(0xFF302830),
    onSurfaceVariant: Color(0xFFD0BEC7),
    outline: Color(0xFF6F5965),
    outlineVariant: Color(0xFF3F333B),
    shadow: Color(0x66000000),
    scrim: Color(0x99000000),
    inverseSurface: Color(0xFFF4EDF1),
    onInverseSurface: Color(0xFF1D181E),
    inversePrimary: AppColors.primary,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
  );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSerifDisplay(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        color: scheme.primary,
        height: 1.05,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: scheme.outline, width: 1.2),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      visualDensity: VisualDensity.compact,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: const StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      hintStyle: GoogleFonts.dmSans(color: scheme.onSurfaceVariant),
      labelStyle: GoogleFonts.dmSans(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.2),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: rounded,
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
