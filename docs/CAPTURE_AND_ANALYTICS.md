# Automatic capture, review and analytics

Implemented for the Flutter application on 2026-10-27.

## Where to find it

Open **Review inbox** from the buttons under the page heading. Choose **Capture a transaction** to import a receipt image, PDF, CSV or text. Choose the right document type before selecting a PDF: Receipt or Statement. You can also paste a bank SMS or describe a transaction.

Images and scanned PDFs use on-device ML Kit recognition on Android/iOS. Selectable-text PDFs work on all supported platforms. PDFs accept an optional password for this import only. Imports are bounded to 15 MB and 40 pages, processed sequentially; an unreadable page rejects the whole extraction rather than silently importing a partial statement. No document or bank SMS is sent to cloud AI.

OCR is machine-learning text recognition. Financial field extraction and categorisation use explainable local rules, plus merchant/category choices learned from reviewed entries. This is not a connected generative-AI service. Statement support covers recognisable dated rows with debit/credit columns or markers; unsupported multi-line layouts need a CSV export or manual correction. Receipts preserve item splits only when they reconcile exactly to the total; subtotal, tax, cash tendered and change are not interchangeable.

## What pending review means

| State | Account balance | Income/spending analytics |
|---|---|---|
| Document/SMS draft with uncertain details or unmatched account | Unchanged until explicitly posted | Excluded |
| Recognised new bank SMS, allowed sender and uniquely matched account | Bank debit/credit recorded once on unlocked processing | Unclassified movement shown separately as awaiting review |
| Reviewed expense/income/loan/transfer | Original movement is classified/updated; review does not post it again | Correct classification contributes to the appropriate metric |
| Additional receipt/statement evidence linked to an existing movement | Unchanged | No second transaction |

Review lets you correct the account, date, amount, merchant, categories, item splits and people splits. A debit is not assumed to be consumption; it can be a transfer, money lent, or a repayment. A credit is not assumed to be income. Loan principal and own-account transfers remain excluded from income/spending.

Reference IDs take priority in duplicate detection. Conflicting amounts for an existing reference stay in review. Distinct references can represent legitimate equal payments on the same day. Without a reference, matching date/amount/account is only a possible duplicate: the user chooses whether to link it or record a separate transaction. Two captured sides of an own-account transfer collapse into one balanced transfer during review when their references match.

Learned merchant rules suggest future categories; a single-item reviewed entry teaches its merchant's category. You can clear these rules in Settings. Suggestions are not a claim that an uncertain financial purpose has been verified.

## Enable Android bank-message capture

1. Unlock the real local vault. Demo mode cannot enable phone SMS permissions.
2. Create manual accounts with opening balances **before** the transactions you want to capture. Existing balance snapshots plus historical imports would count the same money twice.
3. Open **Review inbox → Bank SMS settings**.
4. Add exact bank sender IDs, such as the sender shown in your real bank alert. Prefixes such as VM-/AX- and common telecom suffixes are normalised; bank sender identity is still only a local filter, not cryptographic proof.
5. Link each sender and last four account/card digits to one account.
6. Press **Allow SMS & enable capture**, then grant Android's SMS permission.

Only new matching completed financial messages are captured. The app does not read your SMS history. OTPs, offers, failed and pending-payment messages are excluded. Captured messages wait in an Android Keystore AES-GCM queue while Flutter is closed/locked; account effects are applied when the vault is next unlocked, or during the unlocked polling pass. There is no claim that the encrypted Flutter database is updated while it is closed.

An alert is acknowledged only after its capture and any ledger effect are committed durably. Retry/restart therefore does not apply money twice. Queue failures preserve existing ciphertext; a bounded 500-message queue exposes overflow/error status for reconciliation. Disabling capture stops new collection. Deleting local data disables capture, clears the native queue and removes vault records.

Android OS restrictions, force-stop, message delivery rules and battery settings can delay or prevent receipt. Bank statements remain the reconciliation source. Google Play requires its SMS permissions declaration/approval for the money-management exception; see [Android implementation notes](ANDROID_SMS_CAPTURE.md). iOS does not expose equivalent SMS inbox access; use document import or pasted alerts there.

## Analytics

Open **Analytics** from the page-heading buttons. Select a month to inspect confirmed income, personal spending, income less spending, categories, subcategories, merchants and a six-month timeline.

Shared bills contribute only your share. Category allocation uses exact integer paise and deterministic remainder allocation; category totals reconcile to personal spending. Transfers, borrowing/lending and principal repayments do not inflate income or expenses. Pending metadata movements have a separate count/amount and do not appear as confirmed income/spending.

Current-month comparisons use the same elapsed days of the previous month (clamped for shorter months); complete past months compare full months. A zero baseline shows no percentage change rather than infinity. Portfolio recommendations and dynamic financial planning remain outside these descriptive analytics.

## Data migration and validation

SQLCipher schema version 2 adds captures and merchant rules. Existing accounts, ledger entries and holdings retain their rows and encryption key. New JSON fields default safely for old records. The upgrade adds tables instead of replacing an existing database.

The automated suite covers parser fixtures, duplicate/retry handling, immediate bank effects, reviewed metadata without a second money movement, transfer merging, atomic failure, exact category allocation and screen layouts. Android Keystore, broadcast delivery, SMS permission behaviour and camera/scanned-document accuracy still need real-device validation.
