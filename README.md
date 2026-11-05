# Pocket Ledger

A Flutter expense tracker for Android and Web using Firebase Authentication (Google) and Cloud Firestore.

## Included

- Google sign-in and persistent Firebase sessions.
- Dark-first Material 3 design with mint accents, gradient balance cards and responsive desktop navigation.
- Dark, light and device theme choices saved on the device, available from the appearance icon and Accounts.
- Expense, Income and Transfer shortcuts on Overview and Transactions.
- Animated screen transitions, balance changes, spending bars and editors; device reduced-motion preferences are respected.
- Named Current, Savings, Joint and Loan accounts, with editable opening balances and archive/restore.
- Accounts → Reorder accounts: drag handles or up/down arrows, then Save order. The saved order syncs through Firestore and applies to account lists and pickers. Existing accounts use alphabetical order until reordered; new accounts appear after explicitly ordered accounts. Archived accounts keep their position. Deploy the updated Firestore rules to enable ordering.
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

## Recurring transactions (no Blaze plan required)

Open **Recurring → Add rule**. Set the transaction name, EUR amount, account, expense/income type, category, frequency, inclusive start/end dates, and the payment day. Choose daily, weekly (weekday), monthly (day 1–31), or yearly (month/day). Days 29–31 use the last day of shorter months. All schedules use `Europe/Malta`, including daylight saving time.

Example: `96.00`, Expense, BOV Current, Monthly, day `15`, your desired start date, end `31 October 2028`. The final payment is 15 October 2028, if within the start range.

### Activate the app-based scheduler

From the project root:

```powershell
flutter pub get
firebase deploy --only firestore:rules --project expense-tracker-ed1c1
flutter run -d chrome
```

No Cloud Function, Cloud Scheduler, Node.js installation or Blaze upgrade is needed. Keep the existing Firebase project. Do not run the previous functions deployment commands. If a server scheduler was successfully deployed earlier, remove that old Scheduler job/function before using this client-only mode; the failed Blaze deployment did not create one.

### When payments are recorded

The signed-in app checks on opening, resuming, changing a recurring rule, and every five minutes while active. **Recurring → Check now** runs a manual check and shows errors/last-check status. Nothing runs while the app is closed. Due payments catch up the next time the app is online. Firestore transactions require a connection; an offline check cannot partially save a payment and retries on the next app check.

Each payment retains its scheduled Malta date in transaction history. A pass processes up to 100 overdue occurrences per rule; larger backlogs continue on the next check. Firebase's server timestamp provides the current date, protecting against an incorrectly set device clock. Timezone data is bundled with the app.

Rules can be edited, paused, resumed or deleted. New rules, edits and resumes apply from their saved Malta calendar date. They do not backfill earlier dates. Previously recorded transactions stay when a rule is paused or deleted. Archived/unavailable accounts skip due payments when checked; skipped dates are not backfilled after restoring the account.

These rules record tracker entries only. They do not move money at your bank. Standard Firestore read/write/storage quotas still apply on Firebase's free plan.

### Duplicate prevention and security

A payment, its immutable occurrence receipt and its progress cursor are saved in a single Firestore transaction. The rule and account are read again inside that transaction. Two devices can safely catch up simultaneously; retries cannot post the same occurrence twice. Receipts remain after deleting a generated entry, so it will not be recreated. Existing rules and receipts from the previous server implementation are retained.

Security rules restrict configurations, processing status and clock documents to the signed-in owner. Receipt creation requires a matching transaction for that rule; receipts cannot be changed or deleted by clients. This is a personal ledger: an owner can manage their own entries and processing state. Another user cannot read or write them.

Calendar tests cover inclusive ranges, daily/weekly/monthly/yearly frequencies, leap years, month-end clamping, Malta DST, catch-up chunking, and resumed-rule effective dates. Run:

```powershell
flutter test
flutter test --platform chrome test/recurring_calendar_test.dart
```

Calendar logic can be tested independently of Flutter. Firestore integration, concurrency and security rules should also be verified against the Firebase emulator or the deployed project before release.
