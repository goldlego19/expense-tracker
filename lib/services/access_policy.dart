const allowedGoogleEmail = 'gremblinu@gmail.com';

bool isAllowedGoogleIdentity({
  required String? email,
  required bool emailVerified,
  required String? signInProvider,
}) =>
    email?.trim().toLowerCase() == allowedGoogleEmail &&
    emailVerified &&
    signInProvider == 'google.com';
