import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'access_policy.dart';

class AccessDeniedException implements Exception {
  const AccessDeniedException();
}

class AuthService {
  static Future<void>? _initialization;
  static String? lastSignInError;
  static Future<void> configurePersistence() async {
    // Android uses persistent Firebase sessions automatically.
    if (kIsWeb) await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  static Future<bool> isAllowedSession(User user) async {
    final token = await user.getIdTokenResult();
    return isAllowedGoogleIdentity(
      email: user.email,
      emailVerified: user.emailVerified,
      signInProvider: token.signInProvider,
    );
  }

  static Future<void> signIn() async {
    lastSignInError = null;
    UserCredential credential;
    if (kIsWeb) {
      credential = await FirebaseAuth.instance.signInWithPopup(
        GoogleAuthProvider()
          ..setCustomParameters({'login_hint': allowedGoogleEmail}),
      );
    } else {
      await (_initialization ??= GoogleSignIn.instance.initialize());
      final user = await GoogleSignIn.instance.authenticate();
      if (user.email.trim().toLowerCase() != allowedGoogleEmail) {
        lastSignInError = 'Access is restricted to $allowedGoogleEmail.';
        await signOut();
        throw const AccessDeniedException();
      }
      credential = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: user.authentication.idToken),
      );
    }
    final user = credential.user;
    if (user == null || !await isAllowedSession(user)) {
      lastSignInError =
          'Access is restricted to the verified Google account $allowedGoogleEmail.';
      await signOut();
      throw const AccessDeniedException();
    }
  }

  static Future<void> signOut() async {
    try {
      if (!kIsWeb && _initialization != null)
        await GoogleSignIn.instance.signOut();
    } finally {
      await FirebaseAuth.instance.signOut();
    }
  }
}

String friendlyError(Object error) {
  if (error is AccessDeniedException)
    return 'Access is restricted to the Google account $allowedGoogleEmail.';
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Access denied. Check that the Firestore rules in this repo have been deployed.',
      'unavailable' =>
        'Cannot reach Firebase. Check your internet connection and try again.',
      'unauthorized-domain' => 'This website domain must be added to Firebase Authentication → Settings → Authorized domains.',
      'operation-not-allowed' =>
        'Enable Google sign-in in Firebase Authentication.',
      'popup-closed-by-user' ||
      'cancelled-popup-request' => 'Sign-in was cancelled. You can try again.',
      _ => 'Something went wrong (${error.code}). Please try again.',
    };
  }
  return 'Could not complete the action. Please retry. For Android sign-in, check your Firebase SHA-1 fingerprint.';
}
