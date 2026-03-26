import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_scaffold.dart';
import '../widget/app_motion.dart';

class MoneyDetailApp extends StatelessWidget {
  const MoneyDetailApp({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final fallbackLightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7490),
      brightness: Brightness.light,
    );
    final fallbackDarkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7490),
      brightness: Brightness.dark,
    );

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = (lightDynamic ?? fallbackLightScheme).harmonized();
        final darkScheme = (darkDynamic ?? fallbackDarkScheme).harmonized();

        return MaterialApp(
          title: 'Money Detail',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: lightScheme,
            scaffoldBackgroundColor: const Color(0xFFF3F7F9),
            textTheme: GoogleFonts.notoSansScTextTheme(),
            appBarTheme: AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: Colors.transparent,
              foregroundColor: lightScheme.onSurface,
              titleTextStyle: GoogleFonts.notoSansSc(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: lightScheme.onSurface,
              ),
            ),
            cardTheme: CardTheme(
              color: lightScheme.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              margin: EdgeInsets.zero,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: lightScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: lightScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: lightScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: lightScheme.primary, width: 1.4),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Color.alphaBlend(
                lightScheme.primary.withOpacity(0.04),
                lightScheme.surfaceVariant,
              ),
              indicatorColor: lightScheme.primaryContainer,
              labelTextStyle: MaterialStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 12,
                  fontWeight: states.contains(MaterialState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
            pageTransitionsTheme: AppMotion.pageTransitionsTheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            scaffoldBackgroundColor: const Color(0xFF0E1318),
            textTheme: GoogleFonts.notoSansScTextTheme(
              ThemeData(brightness: Brightness.dark).textTheme,
            ),
            appBarTheme: AppBarTheme(
              elevation: 0,
              centerTitle: false,
              backgroundColor: Colors.transparent,
              foregroundColor: darkScheme.onSurface,
              titleTextStyle: GoogleFonts.notoSansSc(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: darkScheme.onSurface,
              ),
            ),
            cardTheme: CardTheme(
              color: Color.alphaBlend(
                darkScheme.primary.withOpacity(0.10),
                darkScheme.surfaceVariant,
              ),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              margin: EdgeInsets.zero,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Color.alphaBlend(
                darkScheme.primary.withOpacity(0.10),
                darkScheme.surfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: darkScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: darkScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: darkScheme.primary, width: 1.4),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Color.alphaBlend(
                darkScheme.primary.withOpacity(0.10),
                darkScheme.surfaceVariant,
              ),
              indicatorColor: darkScheme.secondaryContainer,
              labelTextStyle: MaterialStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 12,
                  fontWeight: states.contains(MaterialState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
            pageTransitionsTheme: AppMotion.pageTransitionsTheme,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: HomeScaffold(initialTab: initialTab),
        );
      },
    );
  }
}
