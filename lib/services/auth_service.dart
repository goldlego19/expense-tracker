import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static Future<void>? _initialization;
  static Future<void> signIn() async {
    if (kIsWeb) {
      await FirebaseAuth.instance.signInWithPopup(
        GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}),
      );
      return;
    }
    await (_initialization ??= GoogleSignIn.instance.initialize());
    final user = await GoogleSignIn.instance.authenticate();
    await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: user.authentication.idToken),
    );
  }

  static Future<void> signOut() async {
    if (!kIsWeb && _initialization != null)
      await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}

String friendlyError(Object error) {
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
