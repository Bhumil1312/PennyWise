# Learn system design by building PennyWise

Work through one lesson at a time. Explain the failure case before picking a technology. Each exercise produces a reviewable artifact in this project.

## Lesson 1 — Requirements and invariants

Functional requirements describe actions: record a transaction, split a bill, import a statement. Non-functional requirements describe their qualities: offline access, correctness, privacy, recovery and latency. One million users is a population target, not a performance specification.

Trace [`mobile/lib/domain/ledger.dart`](../mobile/lib/domain/ledger.dart). Why must both item totals and participant totals equal the transaction amount? Because they are two views of one bill, not two additional expenses. Run `flutter test test/ledger_test.dart` and read the shared-bill and transfer examples.

**Exercise:** draw balance changes for ₹900 dinner, paid by you, split ₹300/₹200/₹400. Then record a ₹150 partial repayment from the ₹200 participant. Expected: initial bank −₹900, spending ₹300, receivables ₹600; after repayment, bank recovers ₹150 and receivables fall to ₹450. Net worth changes only by your ₹300 expense.

## Lesson 2 — Estimate load

Use explicit assumptions, then replace them with telemetry. Example planning workload, not a measured capacity claim:

| Input | Assumption | Derived demand |
|---|---|---|
| Registered users | 1,000,000 | Does not equal concurrent users |
| Daily active users | 20% | 200,000 DAU |
| Mutations per DAU/day | 4 | 800,000/day ≈ 9.3/second average |
| Peak mutation factor | 20× average | ≈185 mutations/second |
| Remote reads per DAU/day | 15 | 3,000,000/day ≈34.7/second; ≈695/second at 20× |
| Stored record budget | 1.5 KB/mutation | ≈438 GB/year before indexes, attachments, events, backups and replicas |

These are intentionally separate workloads. Most personal dashboard reads can stay on the device; encrypted sync may batch many local mutations into one request. OCR documents can be much larger than the transaction record, and provider polling has separate quotas.

**Exercise:** estimate the same workload at 40% DAU and 8 mutations/day. Answer: 3.2 million/day, about 37 writes/second average and 741/second at 20× peak. Discuss a salary-day spike rather than assuming a smooth average.

Initial **targets to test**, not promises: local interaction p95 <50 ms excluding initial vault unlock; ordinary backend requests p95 <200 ms within the chosen region; 99.9% monthly API availability. A 30-day month at 99.9% permits about 43.2 minutes of unavailability. Decide backup RPO/RTO separately.

## Lesson 3 — Boundaries before microservices

A module separates code; a service also introduces a network and an operating burden. Bank calls, OCR and push delivery should not delay a ledger save. Start with a Go API and workers sharing well-defined contracts, then extract measured bottlenecks.

**Exercise:** draw the request path for a manual transaction versus a bank import. The manual transaction can finish locally with no network. A bank import needs consent validation, a queued fetch, provider retries, normalisation, deduplication and a review state before posting. A provider outage should not disable manual entry.

## Lesson 4 — ACID and the double-write problem

Saving a transaction and its item splits must be atomic. Otherwise a crash can leave a bill without all its categories. The controller updates the visible state only after repository commit; the disk-failure test proves failure leaves the old state intact.

Later, writing a database record and publishing a queue message as separate actions introduces a crash window. Solve this with a transactional outbox: commit business data plus an outbox row together; a worker publishes that row and records delivery. Delivery may repeat, so every consumer must be idempotent. An outbox provides at-least-once delivery with an exactly-once business effect when idempotency is correct; it is not magic exactly-once transport.

**Exercise:** inject a crash after DB commit but before the HTTP response. On retry, return the result associated with the original operation ID. A new operation ID on every retry would create duplicate transactions.

## Lesson 5 — Offline sync and conflicts

Local-first improves speed and reliability, but creates multiple copies of state. Give mutations a stable operation ID and records a server revision. Download changes using an opaque cursor. Queue deletes as tombstones until other devices can observe them.

**Exercise:** two offline devices edit a ₹1,000 bill to ₹900 and ₹1,100. Do not choose whichever phone's clock is later. Require the expected revision and show the conflict, or model explicit reversing/correcting journal entries. Account balances must never merge as independently editable numbers.

Read [Flutter's offline-first guide](https://docs.flutter.dev/app-architecture/design-patterns/offline-first) for repository boundaries and synchronisation tradeoffs. The current mobile repository interface makes later sync possible; no sync implementation exists yet.

## Lesson 6 — Identity, authorisation and encryption

Authentication answers who is acting. Authorisation answers whether that identity can access this vault/group/consent. Encryption at rest protects disks; it does not stop an authenticated application server from reading plaintext. End-to-end encryption changes what server features are possible.

**Exercise:** a valid user changes `accountId` to another user's ID. The server must reject the action even though the JWT is valid. Test every route against cross-tenant IDs, revoked group membership and expired consent. Never accept the `userId` supplied in a body as authoritative.

For local storage, test a missing key, cancelled biometric prompt, app backgrounding with a dialog open, a failed database write and a lost phone. The code must fail closed and preserve an unreadable existing vault rather than replace it. Native tests must confirm these behaviours; widget tests cannot prove Keychain or SQLCipher security.

## Lesson 7 — Portfolio data and cache design

Separate market prices (shared, licensed data) from holdings (private data). Cache a quote by instrument and exchange, attach its timestamp and source, then combine it with the user's holdings at an allowed boundary. Never cache a user's dashboard solely by currency or route name.

**Exercise:** compare 20,000 connected users each polling 10 instruments every second (200,000 lookups/second before caching) with a licensed feed keyed by the set of distinct instruments and fan-out to subscribed users. Include bandwidth, entitlement checks, stale prices and reconnect storms in the design. Do not promise live updates when showing the last imported price.

Simple gain percentage is `(value − cost) / cost`. It is not XIRR, time-weighted return or benchmark-relative performance. A correct analytics model needs cash-flow dates, dividends, fees, corporate actions and splits. The app currently labels its simple metric explicitly.

## Lesson 8 — Prove scale and reliability

Before any million-user claim, create realistic datasets, tenant distributions and a workload mix. Run smoke, load, burst and soak tests against a production-like environment. Record p50/p95/p99, error rates, CPU, memory, database lock waits/connections, queue age, duplicate effects and provider throttles. Redact payloads from logs and traces.

Test failure, not only throughput: kill a worker mid-job, repeat a webhook, revoke a consent mid-fetch, restore a database backup, rotate a key and take the quote provider offline. Use exponential backoff and jitter, cap retries, dead-letter poison jobs and surface stale/failed status to users.

**Exit artifacts:** a capacity report with hardware/configuration, load scripts and dataset, latency/error charts, recovery exercise notes, costs under stated assumptions, and unresolved limits. Until those exist, the architecture has a scale target—not demonstrated capacity.

## Suggested learning sequence

### Applied example: bank capture versus metadata review

The capture update separates evidence (an SMS or receipt), an account movement, and its classification. A completed bank debit changes the local balance when processed, even if its category is unknown. Reviewing the category updates that same entry; it does not create another debit. A receipt can become additional evidence for the existing movement.

The native encrypted queue is acknowledged only after the ledger commit succeeds. A crash between commit and acknowledgement causes redelivery, so stable evidence keys and transaction references prevent duplicate effects. This is an example of at-least-once delivery with idempotent processing, a pattern you will reuse for bank-provider webhooks and sync workers.

Study `mobile/test/capture_controller_test.dart`: it exercises duplicate messages, conflicting references, failed commits and transfer reconciliation. Study `mobile/test/analytics_test.dart` for exact integer allocation of shared spending. Queue reliability and accounting correctness are separate responsibilities; neither proves million-user backend capacity.

### Next exercises

1. Explain the ledger tests; extend them for refunds and a debt interest component.
2. Normalise local SQL tables and page a 100k-entry history; measure on a real phone.
3. Implement managed mobile login and authorisation checks using sandbox accounts.
4. Add encrypted export/recovery; deliberately lose the old device and restore.
5. Build the sync outbox with duplicate, crash and conflict tests.
6. Integrate one AA sandbox and one broker sandbox/provider account.
7. Add accepted group obligations and consented notification delivery.
8. Complete load/security/native-release testing, then start phase-two planning.
