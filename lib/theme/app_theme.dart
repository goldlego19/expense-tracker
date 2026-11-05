import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/appearance_values.dart';
import '../services/home_widget_bridge.dart';

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
  Color? _customAccent;
  Color? get customAccent => _customAccent;
  Color get accentColor => _customAccent ?? _accent.color;
  Future<void> syncWidgetAppearance() => HomeWidgetBridge.syncAppearance(
    accent: accentColor.toARGB32(),
    dark:
        _mode == ThemeMode.dark ||
        (_mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark),
  );
  Future<void> load() async {
    try {
      final savedCustom = await SharedPreferencesAsync().getString(
        'ledgerCustomAccent',
      );
      final customValue = savedCustom == null
          ? null
          : parseAccentHex(savedCustom);
      if (customValue != null) _customAccent = Color(customValue);
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
    await syncWidgetAppearance();
  }

  Future<bool> setAccent(LedgerAccent accent) async {
    _accent = accent;
    _customAccent = null;
    notifyListeners();
    await syncWidgetAppearance();
    try {
      await SharedPreferencesAsync().remove('ledgerCustomAccent');
      await SharedPreferencesAsync().setString('ledgerAccent', accent.name);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setCustomAccent(String value) async {
    final parsed = parseAccentHex(value);
    if (parsed == null)
      throw const FormatException('Enter a colour such as #7C3AED.');
    _customAccent = Color(parsed);
    notifyListeners();
    await syncWidgetAppearance();
    try {
      await SharedPreferencesAsync().setString(
        'ledgerCustomAccent',
        accentHex(parsed),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    await syncWidgetAppearance();
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
            ? ColorScheme.fromSeed(
                seedColor: accent,
                brightness: Brightness.dark,
              ).primary
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
    return IconButton(
      tooltip: 'Appearance',
      icon: const Icon(Icons.palette_outlined),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => AppearanceEditor(controller: controller),
      ),
    );
  }
}

class AppearanceEditor extends StatefulWidget {
  const AppearanceEditor({super.key, required this.controller});
  final ThemeController controller;
  @override
  State<AppearanceEditor> createState() => _AppearanceEditorState();
}

class _AppearanceEditorState extends State<AppearanceEditor> {
  late final TextEditingController _hex = TextEditingController(
    text: accentHex(widget.controller.accentColor.toARGB32()),
  );
  String? _error;
  bool _busy = false;
  Future<void> _save(Future<bool> Function() save) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await save();
      if (mounted)
        setState(() {
          _hex.text = accentHex(widget.controller.accentColor.toARGB32());
          if (!saved)
            _error =
                'Applied for this session. Could not save this device preset.';
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Enter a six-digit colour such as #7C3AED.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.palette_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Make it yours',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close appearance',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your appearance preset is saved on this device only. Other devices keep their own colours and theme.',
                ),
                const SizedBox(height: 24),
                Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    for (final mode in ThemeMode.values)
                      ChoiceChip(
                        label: Text(switch (mode) {
                          ThemeMode.dark => 'Dark',
                          ThemeMode.light => 'Light',
                          ThemeMode.system => 'Device',
                        }),
                        selected: widget.controller.mode == mode,
                        onSelected: _busy
                            ? null
                            : (_) =>
                                  _save(() => widget.controller.setMode(mode)),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Accent colour',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final accent in LedgerAccent.values)
                      Tooltip(
                        message: accent.name,
                        child: Semantics(
                          label: '${accent.name} accent',
                          button: true,
                          selected:
                              widget.controller.customAccent == null &&
                              widget.controller.accent == accent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: _busy
                                ? null
                                : () => _save(
                                    () => widget.controller.setAccent(accent),
                                  ),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.color,
                                border: Border.all(
                                  color:
                                      widget.controller.customAccent == null &&
                                          widget.controller.accent == accent
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child:
                                  widget.controller.customAccent == null &&
                                      widget.controller.accent == accent
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 22,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _hex,
                  enabled: !_busy,
                  maxLength: 7,
                  decoration: InputDecoration(
                    labelText: 'Custom colour',
                    hintText: '#7C3AED',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: widget.controller.accentColor,
                      ),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _save(
                          () => widget.controller.setCustomAccent(_hex.text),
                        ),
                  icon: const Icon(Icons.color_lens_outlined),
                  label: const Text('Apply custom colour'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'The Android home-screen widget follows this device preset too.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Color incomeColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff7ce3c4)
    : const Color(0xff006b55);
Color expenseColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xfff59a83)
    : const Color(0xffb43f2a);
