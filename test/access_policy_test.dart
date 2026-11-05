import 'package:expense_tracker/services/access_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the verified allowed Google identity enters', () {
    expect(
      isAllowedGoogleIdentity(
        email: 'gremblinu@gmail.com',
        emailVerified: true,
        signInProvider: 'google.com',
      ),
      isTrue,
    );
  });
  test('other addresses and lookalike addresses are rejected', () {
    for (final email in [
      'other@gmail.com',
      'gremblinu@gmail.com.evil.test',
      'gremblinu+other@gmail.com',
      '',
      null,
    ]) {
      expect(
        isAllowedGoogleIdentity(
          email: email,
          emailVerified: true,
          signInProvider: 'google.com',
        ),
        isFalse,
      );
    }
  });
  test('an unverified matching address is rejected', () {
    expect(
      isAllowedGoogleIdentity(
        email: allowedGoogleEmail,
        emailVerified: false,
        signInProvider: 'google.com',
      ),
      isFalse,
    );
  });
  test('matching email with password or another provider is rejected', () {
    for (final provider in [
      'password',
      'anonymous',
      'custom',
      'github.com',
      null,
    ]) {
      expect(
        isAllowedGoogleIdentity(
          email: allowedGoogleEmail,
          emailVerified: true,
          signInProvider: provider,
        ),
        isFalse,
      );
    }
  });
  test('Google email comparison is case insensitive', () {
    expect(
      isAllowedGoogleIdentity(
        email: 'Gremblinu@Gmail.com',
        emailVerified: true,
        signInProvider: 'google.com',
      ),
      isTrue,
    );
  });
}
