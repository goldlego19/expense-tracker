import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/access_policy.dart';
import 'services/home_widget_bridge.dart';
import 'screens/authorized_session.dart';
import 'theme/app_theme.dart';
import 'widgets/motion.dart';
import 'widgets/glass_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AuthService.configurePersistence();
  } catch (error) {
    startupError = error;
  }
  await HomeWidgetBridge.initialize();
  final appearance = ThemeController();
  await appearance.load();
  runApp(ExpenseApp(startupError: startupError, appearance: appearance));
}

class ExpenseApp extends StatefulWidget {
  const ExpenseApp({super.key, this.startupError, this.appearance});
  final Object? startupError;
  final ThemeController? appearance;
  @override
  State<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> {
  late final ThemeController _appearance =
      widget.appearance ?? ThemeController();
  @override
  void dispose() {
    if (widget.appearance == null) _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ThemeScope(
    controller: _appearance,
    child: ListenableBuilder(
      listenable: _appearance,
      builder: (context, _) => MaterialApp(
        title: 'Pocket Ledger',
        debugShowCheckedModeBanner: false,
        theme: ledgerTheme(Brightness.light, accent: _appearance.accentColor),
        darkTheme: ledgerTheme(
          Brightness.dark,
          accent: _appearance.accentColor,
        ),
        themeMode: _appearance.mode,
        builder: (context, child) =>
            DashboardBackdrop(child: child ?? const SizedBox.shrink()),
        themeAnimationDuration: motionDuration(context),
        home: widget.startupError != null
            ? const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Firebase could not start. Check your configuration and restart the app.',
                    ),
                  ),
                ),
              )
            : StreamBuilder<User?>(
                stream: FirebaseAuth.instance.idTokenChanges(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Scaffold(
                      body: Center(
                        child: Text(
                          'Unable to read your sign-in session. Restart the app.',
                        ),
                      ),
                    );
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  return snapshot.data == null
                      ? const LoginScreen()
                      : AuthorizedSession(
                          key: ValueKey(snapshot.data!.uid),
                          user: snapshot.data!,
                        );
                },
              ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error = AuthService.lastSignInError;
  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.signIn();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(actions: const [AppearanceButton(), SizedBox(width: 12)]),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Reveal(
            child: GlassPanel(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pocket Ledger',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A clearer view of your money.',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Keep your current, savings, joint and loan accounts together. Record spending and see where you stand.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Private access · $allowedGoogleEmail',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You stay signed in on this device until you sign out.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _login,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(_busy ? 'Signing in…' : 'Continue with Google'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Balances are entered manually. Joint is an account label; your records stay within your login.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
