# Android bank SMS capture

The app can receive new Android SMS messages after the user opts in, grants the operating-system permission, and lists their bank's sender IDs. It does not request `READ_SMS` or `SEND_SMS`, scan SMS history, inspect notifications, or send messages. iOS and browser builds return an unavailable status and continue to support explicit receipt/statement/text import.

## User flow

1. Add the bank account and identify its last four digits in the account's capture settings.
2. Open bank SMS settings, read the disclosure, add sender IDs such as `HDFCBK`, and press the enable button. The system permission prompt appears only from this explicit action.
3. Incoming completed debit/credit alerts from allowlisted senders enter a local encrypted queue. OTPs, failed/pending requests and promotional messages are excluded by conservative pre-filtering; the Dart financial parser validates facts again.
4. At the next app unlock/foreground refresh, the app processes queued alerts into the capture/review workflow. It acknowledges each queue record only after a durable vault commit. Repeated delivery or a crash before acknowledgement must not duplicate ledger effects.
5. Disable capture to stop future collection. Account/app deletion must first disable capture, then clear the native queue as well as the Flutter vault.

`VM-HDFCBK` and `VM-HDFCBK-S` normalize to `HDFCBK`; sender IDs are otherwise exact matches, never partial substrings. Alphanumeric sender labels are not proof of bank authenticity. Users must reconcile captured amounts against their bank records. No default bank sender is silently enabled.

## Platform bridge

The Android `MethodChannel` is `dev.pennywise/bank_sms`. Dart's `BankSmsBridge` exposes:

| Method | Result / behaviour |
|---|---|
| `status()` | `BankSmsStatus`: supported, enabled, permissionGranted, senders, pendingCount, overflowCount, error |
| `configure(enabled: ..., senders: ...)` | Save explicit capture setting and normalized allowlist; enabling requires a nonempty valid list |
| `requestPermission()` | Show Android `RECEIVE_SMS` runtime prompt; returns granted boolean |
| `pending()` | Read queued `BankSmsMessage(id, sender, body, receivedAt)` records without deleting them |
| `acknowledge(ids)` | Remove only IDs durably committed to the vault |
| `clear()` | Explicitly delete staged queue records and reset queue warnings |

`receivedAt` is converted to a Dart `DateTime` from Android epoch milliseconds. Android message timestamps are evidence, not trusted ledger ordering. The parser must reject implausible/future dates or ask for review.

Native queue operations serialize through a process-wide lock. Queue contents are AES-256-GCM encrypted with a random encryption nonce on every write and an Android Keystore key that is never exported. An `AtomicFile` provides recoverable writes. The ciphertext is stored in `noBackupFilesDir`; sender settings contain no message text. An unreadable/missing-key queue fails closed and is preserved. Native and bridge error messages contain no transaction text, bank references or key material.

The bounded queue retains at most 500 matching alerts. It rejects new alerts after capacity and increments a durable `overflowCount`, which the UI must show so users know to reconcile missed activity. A generic queue-write error flag is also visible in status. Successful reads never clear the queue. Clearing the queue is a deliberate data-deletion operation.

This queue allows collection while the Flutter engine is absent. **The encrypted Flutter ledger is updated on the next unlocked processing pass**, not independently while its vault is locked. Force-stopping the app, OS restrictions, revoked permission, pre-first-unlock reboot state, missing/changed bank senders, or queue overflow can prevent capture. Treat SMS as a useful observation source, never an authoritative guaranteed bank feed.

## Store and distribution requirements

Google Play lists SMS-based money management as an exception category for restricted SMS permissions, subject to eligibility, prominent disclosure, declarations and review/approval. A working APK does not itself provide Play approval. See [Google Play SMS permission policy](https://support.google.com/googleplay/android-developer/answer/10208820).

Google Play Protect may block internet-sideloaded APKs declaring sensitive SMS permissions in supported markets. Use an appropriate developer/test distribution route and official review/appeal mechanisms; do not instruct users to disable device protection. See [Play Protect developer guidance](https://developers.google.com/android/play-protect/warning-dev-guidance).

Apple's message-filter extension APIs are for filtering incoming eligible messages and are not equivalent to granting a finance app general SMS inbox access. The iOS build therefore uses user-selected imports and future bank-provider integrations. See [Apple message filter extension documentation](https://developer.apple.com/documentation/identitylookup/creating-a-message-filter-app-extension).

## Native verification before release

Use synthetic fixtures, not real banking/OTP messages, when recording test results. On an Android test device/emulator verify: permission deny/grant/revoke; disabled capture; exact/wrong sender; multipart SMS; OTP/promotion/failed/pending exclusion; valid debit/credit; repeated broadcast; app engine absent; force-stop limitation; missing queue key/corrupt ciphertext; full queue warning; disk-write failure; crash after vault commit before acknowledgement; disabling followed by complete app-data deletion. Flutter mocks cannot prove Keystore encryption or operating-system broadcast delivery.
