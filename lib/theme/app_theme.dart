import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LedgerAccent {
  blue(Color(0xff3b82f6)),
  green(Color(0xff10b981)),
  purple(Color(0xff8b5cf6)),
  orange(Color(0xfff59e0b)),
  pink(Color(0xfff43f5e)),
  red(Color(0xffef4444));

  const LedgerAccent(this.color);
  final Color color;
}

class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initialMode = ThemeMode.dark})
    : _mode = initialMode;
  ThemeMode _mode;
  ThemeMode get mode => _mode;
  LedgerAccent _accent = LedgerAccent.blue;
  LedgerAccent get accent => _accent;
  Future<void> load() async {
    try {
      final savedAccent = await SharedPreferencesAsync().getString(
        'ledgerAccent',
      );
      _accent = LedgerAccent.values.firstWhere(
        (accent) => accent.name == savedAccent,
        orElse: () => LedgerAccent.blue,
      );
      final saved = await SharedPreferencesAsync().getString('appearance');
      _mode = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.dark,
      );
    } catch (_) {
      /* The app can still start if device storage is unavailable. */
    }
  }

  Future<bool> setAccent(LedgerAccent accent) async {
    _accent = accent;
    notifyListeners();
    try {
      await SharedPreferencesAsync().setString('ledgerAccent', accent.name);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      await SharedPreferencesAsync().setString('appearance', mode.name);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);
  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}

ThemeData ledgerTheme(
  Brightness brightness, {
  Color accent = const Color(0xff3b82f6),
}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: dark
            ? Color.lerp(accent, Colors.white, .32)!
            : ColorScheme.fromSeed(seedColor: accent).primary,
        onPrimary: dark ? const Color(0xff071121) : Colors.white,
        surface: dark ? const Color(0xff121a2c) : Colors.white,
        onSurface: dark ? const Color(0xffedf2fa) : const Color(0xff172235),
      );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: scheme.surface.withValues(alpha: dark ? .66 : .90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .3)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? Colors.black.withValues(alpha: .18)
          : Colors.white.withValues(alpha: .72),
      border: border,
      enabledBorder: border,
      contentPadding: const EdgeInsets.all(18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: .16),
      elevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xff12192a) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -.8,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        letterSpacing: -.4,
      ),
    ),
  );
}

class AppearanceButton extends StatelessWidget {
  const AppearanceButton({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Appearance',
      initialValue: 'theme:${controller.mode.name}',
      icon: Icon(
        controller.mode == ThemeMode.system
            ? Icons.brightness_auto_outlined
            : controller.mode == ThemeMode.dark
            ? Icons.dark_mode_outlined
            : Icons.light_mode_outlined,
      ),
      onSelected: (value) async {
        final saved = value.startsWith('accent:')
            ? await controller.setAccent(
                LedgerAccent.values.byName(value.substring(7)),
              )
            : await controller.setMode(
                ThemeMode.values.byName(value.substring(6)),
              );
        if (!saved && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Appearance changed for this session. Could not save the preference.',
              ),
            ),
          );
        }
      },
      itemBuilder: (_) => [
        for (final mode in ThemeMode.values)
          CheckedPopupMenuItem<String>(
            value: 'theme:${mode.name}',
            checked: controller.mode == mode,
            child: Text(switch (mode) {
              ThemeMode.dark => 'Dark',
              ThemeMode.light => 'Light',
              ThemeMode.system => 'Use device theme',
            }),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          enabled: false,
          child: Text('Accent colour'),
        ),
        for (final accent in LedgerAccent.values)
          CheckedPopupMenuItem<String>(
            value: 'accent:${accent.name}',
            checked: controller.accent == accent,
            child: Row(
              children: [
                Icon(Icons.circle, color: accent.color, size: 14),
                const SizedBox(width: 10),
                Text(
                  '${accent.name[0].toUpperCase()}${accent.name.substring(1)}',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Color incomeColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff7ce3c4)
    : const Color(0xff006b55);
Color expenseColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xfff59a83)
    : const Color(0xffb43f2a);
