# Pocket Ledger

A Flutter expense tracker for Android and Web using Firebase Authentication (Google) and Cloud Firestore.

## Included

- Google sign-in and persistent Firebase sessions.
- Named Current, Savings, Joint and Loan accounts, with editable opening balances and archive/restore.
- Income, expenses and transfers, with categories, dates, notes, editing and deletion.
- Overview with net worth, monthly income/expenses/cash flow, category breakdown and recent activity.
- Transaction filters by month, account and type.
- EUR amounts stored as integer cents. Balances are calculated from opening balances and ledger entries, avoiding competing balance updates. A transfer is one document so its two sides cannot be partially saved.
- User-scoped Firestore rules with field validation, plus GitHub checks and model/widget tests.

Joint is a label, not shared access. There is no live bank connection. All accounts belong to the signed-in user. Loans start with a positive debt entered in the form and are stored as negative balances. Record a repayment as a transfer from your paying account to your loan. If interest is charged, record that as an expense on the loan.

## Local setup (PowerShell)

Install Flutter compatible with the Dart constraint in `pubspec.yaml`, Android Studio for Android, Node.js, and the Firebase CLI. The existing Firebase configuration points to `expense-tracker-ed1c1`.

```powershell
flutter pub get
npm install -g firebase-tools
firebase login
```

In Firebase Console:

1. Authentication → Sign-in method → enable Google and select a support email.
2. Firestore Database → create the default Standard database if it does not exist.
3. Deploy the included database rules (requires permissions on this Firebase project):

```powershell
firebase deploy --only firestore --project expense-tracker-ed1c1
```

Do not leave Firestore in open test mode. These rules restrict access to the owner's UID and reject invalid documents. The application creates collections as accounts and transactions are saved.

### Web

Add `localhost` to Authentication → Settings → Authorized domains if it is absent. Add the real hostname before using a deployed website. Then run:

```powershell
flutter run -d chrome
```

Google login uses the Firebase popup flow on Web. Allow the sign-in popup when prompted.

### Android Google login

Generate your local signing fingerprints:

```powershell
cd android
.\gradlew.bat signingReport
cd ..
```

Copy the debug SHA-1 (and SHA-256) into Firebase Console → Project settings → Your apps → the Android app `com.denzel.expense_tracker` → Add fingerprint. Then download the updated `google-services.json` and replace `android/app/google-services.json`. The file needs a Web OAuth client (client type 3); the existing config includes one. Rebuild the app after updating it. Register release/Play signing fingerprints too when distributing.

```powershell
flutter run
```

If using a different Firebase project, run `flutterfire configure` and update `.firebaserc` before deploying rules. Firebase client configuration is intentionally committed; never commit service-account private keys, signing keystores or passwords.

## Checks

```powershell
flutter analyze
flutter test
flutter build web --release
```

Tests cover exact decimal parsing, income/expense balances, loan transfers and net-worth conservation, deletion effects, login UI and startup recovery. GitHub Actions runs analysis, tests and a release Web build. Live authentication and Firestore authorization still need validation with the actual Firebase project. No Firebase deployment is performed by CI.

## Data model

```
users/{uid}/accounts/{accountId}
  name, type, openingCents, currency: EUR, archived
users/{uid}/transactions/{transactionId}
  kind: income|expense|transfer, accountId, targetId|null,
  amountCents, category, note, date
```

Account balances = opening amount + income − expenses − outgoing transfers + incoming transfers. Archived account balances remain in net worth and history; restore an account before adding or editing its transactions. Transactions may be deleted independently. Opening amounts should describe the starting point before recorded transactions, avoiding double counting.

This first version loads the user's ledger to calculate balances and sorts/filters locally. A larger ledger should use paginated history and server-maintained aggregates before broad public use. Dates use the recording device's timezone.
