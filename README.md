# Pocket Ledger

A Flutter expense tracker for Android and Web using Firebase Authentication (Google) and Cloud Firestore.

## Included

- Google sign-in and persistent Firebase sessions.
- Dark-first Material 3 design with mint accents, gradient balance cards and responsive desktop navigation.
- Dark, light and device theme choices saved on the device, available from the appearance icon and Accounts.
- Expense, Income and Transfer shortcuts on Overview and Transactions.
- Animated screen transitions, balance changes, spending bars and editors; device reduced-motion preferences are respected.
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

## Recurring transactions

Open **Recurring → Add rule**. Set the name, EUR amount, account, expense/income type, category, frequency, start/end dates, and the payment day. Frequencies: daily; weekly with weekday; monthly with day 1–31; yearly with month/day. The end date is inclusive. Days 29–31 clamp to the last day in shorter months. Schedules use `Europe/Malta`, including daylight saving time.

For example: amount `96.00`, expense, your chosen current account, Monthly, payment day `15`, your desired start date, end date `31 October 2028`. This includes the payment on 15 October 2028 if within the start range.

Rules can be edited, paused, resumed or deleted. Editing or resuming applies from the Malta calendar date of the save; earlier dates are skipped. The scheduler never backfills dates before rule creation. Pausing/deleting preserves posted transactions. Archived or unavailable accounts skip due payments; skipped dates are not backfilled when restored. These rules record tracker transactions only; they do not instruct a bank or move real money.

### Deploy the server scheduler

Automatic posting while the app is closed requires Firebase **Blaze billing**, Cloud Functions and Cloud Scheduler. No deployment or billing changes are made by this repository. A saved rule alone does not activate the scheduler.

Install Node.js 22, sign in with an account that can deploy to your Firebase project, and run from the project root:

```powershell
npm --prefix functions ci
firebase deploy --only firestore --project expense-tracker-ed1c1
firebase deploy --only functions:postRecurringTransactions --project expense-tracker-ed1c1
```

Wait for the Firestore collection-group index to finish building. The function runs hourly at minute 15, in `europe-west1`, using Malta calendar dates. A due payment normally appears at about 00:15 Malta time; after an outage it catches up on the next successful run. It processes up to 40 overdue occurrences per rule per run and continues in later runs. You can manually run the created Cloud Scheduler job for an immediate check. Do not expose the scheduler function as a public endpoint.

The Recurring screen shows whether the backend has checked a rule and any account/configuration error. If rules save but payments never appear, verify that the function is deployed, the Scheduler job is enabled, the index exists and the function logs show successful runs. Ending dates stop posting but do not delete rule history.

### Duplicate prevention and validation

Each due date has a deterministic transaction ID plus a server-only occurrence receipt. The receipt, transaction and progress cursor are written in one Firestore transaction. Retries/overlapping runs cannot post a second payment. Deleting a generated transaction intentionally leaves its receipt, so it will not be recreated. Editing an already-posted transaction does not change future rule settings.

Client rules restrict recurring configurations to the signed-in user. Processing cursors, run status and receipts are writable only by the server. The scheduler validates the configuration again and reads the latest account/rule inside its transaction, protecting concurrent edits, pauses and deletion. Rule deletion retains occurrence receipts as an audit trail; long-term cleanup can be added separately.

```powershell
npm --prefix functions run check
npm --prefix functions test
```

The backend tests cover monthly/weekly/daily/yearly dates, inclusive ranges, month ends, leap years, Malta DST, catch-up limits, retries, duplicate suppression, atomic failures, paused/deleted rules and archived accounts. Processor tests use an in-memory Firestore transaction double; production IAM, indexes and deployed rules still require validation after deployment.
