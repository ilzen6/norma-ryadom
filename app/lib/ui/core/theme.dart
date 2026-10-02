import 'package:flutter/material.dart';

@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.hairline,
    required this.brand,
    required this.brandSoft,
    required this.onBrand,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.good,
    required this.goodSoft,
    required this.warn,
    required this.warnSoft,
    required this.neutral,
    required this.neutralSoft,
    required this.glass,
    required this.mapLand,
    required this.mapWater,
    required this.mapGreen,
    required this.mapBuilding,
    required this.mapBuildingEdge,
    required this.mapRoad,
    required this.mapRoadMajor,
    required this.mapRoadCasing,
    required this.mapRail,
    required this.metro,
  });

  static const light = Palette(
    canvas: Color(0xFFF2F5F0),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE8EEE7),
    ink: Color(0xFF13201A),
    inkMuted: Color(0xFF526158),
    inkSubtle: Color(0xFF6E7C74),
    hairline: Color(0xFFDCE4DB),
    brand: Color(0xFF1B6A46),
    brandSoft: Color(0xFFD9EEDF),
    onBrand: Color(0xFFFFFFFF),
    protein: Color(0xFF5B4BD6),
    fat: Color(0xFFC77A0E),
    carbs: Color(0xFF1F7DBE),
    good: Color(0xFF1A7647),
    goodSoft: Color(0xFFDCF1E3),
    warn: Color(0xFF94570A),
    warnSoft: Color(0xFFFBEBD2),
    neutral: Color(0xFF5E6A63),
    neutralSoft: Color(0xFFE9EDE9),
    glass: Color(0xD9FFFFFF),
    mapLand: Color(0xFFEFF2EB),
    mapWater: Color(0xFFBBD6E6),
    mapGreen: Color(0xFFD2E7CC),
    mapBuilding: Color(0xFFE2E6DE),
    mapBuildingEdge: Color(0xFFD3D9CF),
    mapRoad: Color(0xFFFFFFFF),
    mapRoadMajor: Color(0xFFFFF4DA),
    mapRoadCasing: Color(0xFFD5DCD2),
    mapRail: Color(0xFFBEC6BC),
    metro: Color(0xFFD6312B),
  );

  static const dark = Palette(
    canvas: Color(0xFF0D1511),
    surface: Color(0xFF16201B),
    surfaceMuted: Color(0xFF1E2A23),
    ink: Color(0xFFE7F0EA),
    inkMuted: Color(0xFFA9B8AF),
    inkSubtle: Color(0xFF8A988F),
    hairline: Color(0xFF29362F),
    brand: Color(0xFF63CC99),
    brandSoft: Color(0xFF1B3A2B),
    onBrand: Color(0xFF06140D),
    protein: Color(0xFFA79CFF),
    fat: Color(0xFFF2B85E),
    carbs: Color(0xFF6CBCEF),
    good: Color(0xFF63CC99),
    goodSoft: Color(0xFF1B3A2B),
    warn: Color(0xFFF2B05A),
    warnSoft: Color(0xFF3A2D17),
    neutral: Color(0xFFA2AFA7),
    neutralSoft: Color(0xFF232E28),
    glass: Color(0xCC16201B),
    mapLand: Color(0xFF17201B),
    mapWater: Color(0xFF1C3442),
    mapGreen: Color(0xFF1C3224),
    mapBuilding: Color(0xFF212B25),
    mapBuildingEdge: Color(0xFF2A352F),
    mapRoad: Color(0xFF2C3832),
    mapRoadMajor: Color(0xFF3B4636),
    mapRoadCasing: Color(0xFF111814),
    mapRail: Color(0xFF39443E),
    metro: Color(0xFFFF6B63),
  );

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color ink;
  final Color inkMuted;
  final Color inkSubtle;
  final Color hairline;
  final Color brand;
  final Color brandSoft;
  final Color onBrand;
  final Color protein;
  final Color fat;
  final Color carbs;
  final Color good;
  final Color goodSoft;
  final Color warn;
  final Color warnSoft;
  final Color neutral;
  final Color neutralSoft;
  final Color glass;
  final Color mapLand;
  final Color mapWater;
  final Color mapGreen;
  final Color mapBuilding;
  final Color mapBuildingEdge;
  final Color mapRoad;
  final Color mapRoadMajor;
  final Color mapRoadCasing;
  final Color mapRail;
  final Color metro;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < 0.5 || other == null ? this : other;
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>() ?? Palette.light;
}

abstract final class AppFonts {
  static const text = 'Onest';
  static const display = 'Unbounded';
  static const tabular = [FontFeature.tabularFigures()];
}

abstract final class AppRadii {
  static const card = 28.0;
  static const tile = 20.0;
  static const control = 16.0;
}

ThemeData buildTheme(Brightness brightness) {
  final palette = brightness == Brightness.light ? Palette.light : Palette.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Palette.light.brand,
        brightness: brightness,
      ).copyWith(
        primary: palette.brand,
        onPrimary: palette.onBrand,
        primaryContainer: palette.brandSoft,
        onPrimaryContainer: palette.ink,
        secondaryContainer: palette.brandSoft,
        onSecondaryContainer: palette.ink,
        surface: palette.canvas,
        onSurface: palette.ink,
        onSurfaceVariant: palette.inkMuted,
        surfaceContainerLowest: palette.surface,
        surfaceContainerLow: palette.surface,
        surfaceContainer: palette.surface,
        surfaceContainerHigh: palette.surface,
        surfaceContainerHighest: palette.surfaceMuted,
        outline: palette.inkSubtle,
        outlineVariant: palette.hairline,
      );
  final text = _textTheme(palette);
  const pill = WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder());
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: AppFonts.text,
    textTheme: text,
    scaffoldBackgroundColor: palette.canvas,
    extensions: [palette],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: InkRipple.splashFactory,
    dividerTheme: DividerThemeData(color: palette.hairline, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.canvas,
      foregroundColor: palette.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: pill,
        minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: pill,
        minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
        side: WidgetStatePropertyAll(BorderSide(color: palette.hairline, width: 1.5)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(shape: pill, textStyle: WidgetStatePropertyAll(text.labelLarge)),
    ),
    iconButtonTheme: IconButtonThemeData(style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(palette.ink))),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: pill,
        side: WidgetStatePropertyAll(BorderSide(color: palette.hairline)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? palette.ink : palette.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? palette.canvas : palette.ink,
        ),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: palette.hairline),
      backgroundColor: palette.surface,
      selectedColor: palette.brandSoft,
      checkmarkColor: palette.brand,
      labelStyle: text.labelLarge?.copyWith(color: palette.ink),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceMuted,
      labelStyle: text.bodyLarge?.copyWith(color: palette.inkMuted),
      floatingLabelStyle: text.bodyMedium?.copyWith(color: palette.brand, fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.control), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: palette.brand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? palette.onBrand : palette.surface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? palette.brand : palette.inkSubtle,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? palette.brand : palette.inkMuted,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.inkMuted,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: palette.inkMuted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: palette.brandSoft,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected) ? palette.ink : palette.inkMuted,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? palette.brand : palette.inkMuted),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: palette.hairline,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
      titleTextStyle: text.titleLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: palette.canvas),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.control)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.brand, linearTrackColor: palette.surfaceMuted),
  );
}

TextTheme _textTheme(Palette palette) {
  TextStyle style(String family, double size, FontWeight weight, double height, {Color? color, double spacing = 0}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color ?? palette.ink,
      );
  return TextTheme(
    displayLarge: style(AppFonts.display, 44, FontWeight.w700, 1.05, spacing: -1),
    displayMedium: style(AppFonts.display, 38, FontWeight.w700, 1.05, spacing: -0.8),
    displaySmall: style(AppFonts.display, 32, FontWeight.w700, 1.08, spacing: -0.6),
    headlineLarge: style(AppFonts.display, 28, FontWeight.w600, 1.12, spacing: -0.4),
    headlineMedium: style(AppFonts.display, 24, FontWeight.w600, 1.15, spacing: -0.3),
    headlineSmall: style(AppFonts.display, 20, FontWeight.w600, 1.2, spacing: -0.2),
    titleLarge: style(AppFonts.text, 20, FontWeight.w700, 1.25, spacing: -0.2),
    titleMedium: style(AppFonts.text, 17, FontWeight.w600, 1.3),
    titleSmall: style(AppFonts.text, 15, FontWeight.w600, 1.3),
    bodyLarge: style(AppFonts.text, 16, FontWeight.w400, 1.45),
    bodyMedium: style(AppFonts.text, 15, FontWeight.w400, 1.45),
    bodySmall: style(AppFonts.text, 13, FontWeight.w500, 1.4, color: palette.inkMuted),
    labelLarge: style(AppFonts.text, 15, FontWeight.w600, 1.2),
    labelMedium: style(AppFonts.text, 13, FontWeight.w600, 1.2),
    labelSmall: style(AppFonts.text, 12, FontWeight.w600, 1.2, spacing: 0.2),
  );
}
