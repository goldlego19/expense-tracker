import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/access_policy.dart';
import '../services/home_widget_bridge.dart';
import 'home_screen.dart';

/// Never construct the ledger or its recurring runner until access is verified.
class AuthorizedSession extends StatefulWidget {
  const AuthorizedSession({super.key, required this.user});
  final User user;
  @override
  State<AuthorizedSession> createState() => _AuthorizedSessionState();
}

class _AuthorizedSessionState extends State<AuthorizedSession> {
  late Future<bool> _allowed = _verify();
  Future<bool> _verify() async {
    final allowed = await AuthService.isAllowedSession(widget.user);
    if (!allowed) await HomeWidgetBridge.clearAccounts();
    return allowed;
  }

  bool _signingOut = false;
  String? _error;
  @override
  void didUpdateWidget(covariant AuthorizedSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    // idTokenChanges emits after refresh as well as sign-in/session restoration.
    _allowed = _verify();
  }

  Future<void> _signOut() async {
    setState(() {
      _signingOut = true;
      _error = null;
    });
    try {
      await AuthService.signOut();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _allowed,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snapshot.data == true)
        return HomeScreen(key: ValueKey(widget.user.uid), user: widget.user);
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    snapshot.hasError
                        ? 'Could not verify access'
                        : 'This account cannot enter',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sign in with the verified Google account $allowedGoogleEmail.',
                    textAlign: TextAlign.center,
                  ),
                  if (snapshot.hasError)
                    Text(
                      friendlyError(snapshot.error!),
                      textAlign: TextAlign.center,
                    ),
                  if (_error != null)
                    Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  if (snapshot.hasError)
                    TextButton(
                      onPressed: () => setState(
                        () => _allowed = AuthService.isAllowedSession(
                          widget.user,
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  FilledButton(
                    onPressed: _signingOut ? null : _signOut,
                    child: Text(
                      _signingOut
                          ? 'Signing out…'
                          : 'Use the allowed Google account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
