# PennyWise: India-first mobile application

This is the mobile continuation of `Typeface_AI/my-app`, not a replacement for the existing Next.js application. The Flutter application is in [`mobile/`](../mobile). The existing web app, PostgreSQL records and Go auth experiment have not been migrated or deployed.

## What is working in this milestone

| Capability | Current implementation |
|---|---|
| Local access | Android/iOS device authentication; separate browser demo |
| Storage | SQLCipher database; random key in platform secure storage; no financial API calls |
| Accounts | Manual bank, savings, cash, wallet and credit-card balance tracking in INR |
| Ledger | Create, inspect, edit and delete income, expenses, own-account transfers and personal loans |
| Categories | Categories and subcategories; multiple items per transaction, with exact total validation |
| People | Equal or custom shares, either you or another participant paying, receivables/payables, partial repayments |
| Sharing | User-operated share sheet with a balance message; no automatic sending |
| Text capture | Bounded on-device rules produce a draft and clarification prompts; not a connected LLM |
| Statement import | CSV, PDF text and scanned-PDF OCR; review inbox, reference deduplication and possible-match warnings |
| Receipt images | Android/iOS Latin-script ML Kit text recognition wired to the review form; physical-device validation still required |
| Investments | Manual cost/value records, valuation date and simple unrealised gain/loss |
| Dashboard | Account balances, net worth, monthly income/personal spending and actual daily spending bars |
| Bank SMS | Opt-in Android capture from allowed senders; encrypted queue and account matching |
| Analytics | Reviewed spending by category, subcategory and merchant; monthly trends and separate pending totals |
| Privacy controls | Lock, background privacy cover, Android screenshot protection, local data deletion |

Matched Android bank alerts record the account movement once, with metadata pending review. Reviewing their category, merchant or splits updates that entry without applying its amount again. Uncertain document extractions remain drafts until confirmed. Receipt items are extracted only where their amounts reconcile; ambiguous totals and dates require correction. See [capture and analytics setup](CAPTURE_AND_ANALYTICS.md).

## Run it

Use Flutter 3.47.7 or newer (CI uses 3.47.7). From PowerShell:

```powershell
cd D:\Projects\Typeface_AI\my-app\mobile
flutter pub get
flutter run -d chrome
```

Choose **Explore the demo**. Its sample records and changes live in memory and disappear when the browser refreshes. For native use, connect an Android phone, enable USB debugging, run `flutter devices`, then `flutter run -d <device-id>`. Set a device screen lock before opening the local vault. The real vault starts empty; demo data is never inserted into it.

```powershell
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

iOS compilation, signing and device testing require macOS and Xcode. The source targets iOS 15.5+ because of the selected OCR plugin. Android minimum API is 24. Release signing has deliberately not been configured with a debug key.

Example CSV: [`mobile/examples/statement.csv`](../mobile/examples/statement.csv). Supported required columns are `date,description,amount,type`; use ISO dates, positive rupee amounts and `income`/`expense`. Optional columns are `reference,category,subcategory`. Export formats from different banks will need adapters. Transfers and loans must be classified manually rather than imported as income/spending. References should identify one transaction uniquely within an account.

## What still needs implementation and external setup

This is an initial working local application, **not the complete product or a store-ready financial service**.

1. **Online sign-in:** reuse a managed identity provider, with mobile OAuth/OIDC, secure refresh-token handling, device registration and account deletion. A device fingerprint unlock is not an online account.
2. **Encrypted recovery:** implement export/restore and optional encrypted backup before real-user release. Currently losing/resetting a phone can lose its vault. OS database backup is disabled/excluded by the native configuration; verify this on devices. The browser intentionally has no persistence.
3. **Bank connections:** select an Indian Account Aggregator integration and eligible regulated operating arrangement; verify institution coverage, supported account types, consent terms, onboarding and pricing. Build sandbox consent, ingestion, reconciliation and revocation.
4. **Broker and market data:** select broker APIs and licensed quote distribution. No current holding value is live. Add trade lots, realised P&L, dividends, fees, corporate actions, XIRR and benchmarks.
5. **Collaborative groups:** identities, invitations, accepted obligations, encrypted/shared record policy, conflicts, settlement confirmation and push notifications. Local names are labels, not verified people; two people with the same name currently share a local balance.
6. **Documents and AI:** broaden bank-specific format coverage and receipt fixtures; add model-assisted extraction with explicit disclosure. Current extraction uses local OCR and deterministic rules, with learned merchant categories. The existing web Gemini integration remains separate.
7. **Broader finance:** recurring transactions, budgets, refunds/reversals, credit-card billing cycles, loans with interest/due dates, currencies/FX, reconciliation, tax/insurance views, holdings disposal and per-item participant assignment.
8. **Production backend and release:** authenticated Go APIs, durable persistence, workers, observability, quota enforcement, disaster recovery, load tests, native security review and store submission.

## Phased delivery

| Phase | Deliverable and exit condition |
|---|---|
| 1A — this milestone | Working local ledger, imports, splits and manual portfolio; domain/widget checks and preview |
| 1B — private alpha | Online identity, encrypted recovery, native storage/OCR/device tests, budgets and import reconciliation; safe recovery on a second device |
| 1C — connected beta | Provider sandbox → consented bank/broker connections, shared groups and opt-in notifications; revocation and retry tests |
| 1D — public release | Signed Android/iOS builds, privacy disclosures and deletion, accessibility, security review, measured reliability and load tests |
| **2 — dynamic planning** | Goals, emergency buffer, debt payoff, income/expense forecasts, inflation/tax/FX assumptions, scenarios, changing life events and plan recalculation |

Phase two should expose assumptions, versions and uncertainty. Product-specific investment recommendations need suitability and regulatory design before launch; a generic disclaimer does not substitute for that work.

Read next: [architecture and data ownership](ARCHITECTURE_INDIA.md), then [system-design learning guide](SYSTEM_DESIGN_LEARNING.md).
