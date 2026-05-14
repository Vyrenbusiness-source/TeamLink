// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

/// Material 3 Design-Tokens für TeamLink.
///
/// Seed-Farbe: #2563EB (Tailwind blue-600).
/// Alle Tonal-Paletten werden automatisch aus dem Seed abgeleitet.
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF2563EB);

  static const _radius12 = Radius.circular(12);
  static const _radius8 = Radius.circular(8);
  static const _radius28 = Radius.circular(28);

  static const _shapeM = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(_radius12),
  );
  static const _shapeL = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(_radius28),
  );

  // -------------------------------------------------------------------------
  // Public factory
  // -------------------------------------------------------------------------

  static ThemeData light() => _build(
        ColorScheme.fromSeed(seedColor: _seed),
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
      );

  // -------------------------------------------------------------------------
  // Shared component tokens
  // -------------------------------------------------------------------------

  static ThemeData _build(ColorScheme cs) {
    final textTheme = _buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: textTheme,

      // -- AppBar ----------------------------------------------------------
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: cs.surfaceTint,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),

      // -- Card ------------------------------------------------------------
      cardTheme: CardThemeData(
        elevation: 0,
        shape: _shapeM,
        color: cs.surfaceContainerLow,
        margin: EdgeInsets.zero,
      ),

      // -- Input -----------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(_radius12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(_radius12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(_radius12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(_radius12),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(_radius12),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: cs.primary),
        hintStyle: TextStyle(
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),

      // -- Buttons ---------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: _shapeM,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: _shapeM,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: _shapeM,
          side: BorderSide(color: cs.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: _shapeM),
      ),

      // -- FloatingActionButton --------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: _shapeM,
        elevation: 3,
        highlightElevation: 6,
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
      ),

      // -- Chip ------------------------------------------------------------
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        elevation: 0,
        pressElevation: 0,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // -- ListTile --------------------------------------------------------
      listTileTheme: ListTileThemeData(
        shape: _shapeM,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
        ),
        iconColor: cs.onSurfaceVariant,
      ),

      // -- Dialog ----------------------------------------------------------
      dialogTheme: const DialogThemeData(
        shape: _shapeL,
        elevation: 3,
      ),

      // -- Snackbar --------------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: _shapeM,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        actionTextColor: cs.inversePrimary,
      ),

      // -- Tooltip ---------------------------------------------------------
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: const BorderRadius.all(_radius8),
        ),
        textStyle: TextStyle(color: cs.onInverseSurface, fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 3),
      ),

      // -- Divider ---------------------------------------------------------
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: cs.outlineVariant,
      ),

      // -- ProgressIndicator -----------------------------------------------
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHighest,
      ),

      // -- NavigationBar ---------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
        indicatorColor: cs.secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: cs.onSecondaryContainer);
          }
          return IconThemeData(color: cs.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final style = textTheme.labelSmall;
          if (states.contains(WidgetState.selected)) {
            return style?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            );
          }
          return style?.copyWith(color: cs.onSurfaceVariant);
        }),
      ),

      scaffoldBackgroundColor: cs.surface,
    );
  }

  // -------------------------------------------------------------------------
  // Typography — M3 type scale
  // -------------------------------------------------------------------------

  static TextTheme _buildTextTheme() {
    return const TextTheme(
      // Display
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        height: 1.22,
      ),
      // Headline
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.29,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.33,
      ),
      // Title
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      // Body
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
      ),
      // Label
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.45,
      ),
    );
  }
}
