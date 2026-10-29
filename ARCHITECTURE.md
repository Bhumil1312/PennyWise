# PennyWise Architecture

> **2026-10-10 mobile direction:** The India-first Flutter/local-vault design and phased backend plan are documented in [docs/ARCHITECTURE_INDIA.md](docs/ARCHITECTURE_INDIA.md). That decision supersedes the target choices below for new mobile work. This older document and its scaffold are retained as project history; they do not describe a deployed or load-tested system.

Target: a finance management platform for **10M users** — expenses (per account and overall), income, investments (live market data), and future financial plans — built as **Go microservices** on **AWS**, using **distributed SQL**, with the existing **Next.js** app as the frontend/BFF.

## Design decisions

| Decision | Choice | Why |
|---|---|---|
| Architecture | Microservices (from day one) | Independent scaling + ownership per domain |
| Backend language | Go | Concurrency, single static binaries, deployment simplicity |
| OOP model | Go idioms: structs + methods, composition, interfaces, DI (`uber/fx`) | Encapsulation, polymorphism, dependency inversion per service |
| Service comms | gRPC + ConnectRPC, proto contracts in `protos/` | Typed contracts, codegen for Go and TS |
| Event backbone | Kafka (MSK) | Event sourcing for the ledger, replay, consumer groups |
| Database | CockroachDB (distributed SQL) | Auto-sharding, partitioning, Postgres wire protocol |
| Cache | Redis (ElastiCache) | Sessions, quote cache, rate limiting |
| Identity | Own Go auth-service (OIDC, MFA, JWT) | Replaces Clerk; staged strangler migration |
| Investment data | Yahoo Finance via `marketdata-service` | Free coverage; cached + secondary provider adapter (Polygon) |
| Deployment | AWS EKS, Terraform, GitHub Actions | GitOps + autoscaling |

## Service map

| Service | Responsibility | DB tables (own schema) |
|---|---|---|
| `api-gateway` | Edge: JWT validation, rate limiting, routing, tracing | — |
| `auth` | OIDC provider: register/login, MFA, token minting, API keys | users, refresh_sessions, audit_log |
| `user` | Profiles, preferences, GDPR export/deletion | user_profiles |
| `ledger` | Accounts, income/expense transactions, event-sourced balances | ledger_entries, account_balances |
| `budget` | Per-account budgets, spend tracking, threshold alerts | budgets, spend_rollups |
| `marketdata` | Yahoo Finance ingestion, quote cache, price history | securities, price_history |
| `investment` | Portfolios, holdings, P&L, dividends | portfolios, holdings, investment_txns |
| `planning` | Goals, savings targets, projections, net worth | goals, plans, projections |
| `reporting` | Dashboard aggregates, monthly reports, materialized views | report_views |
| `notification` | Email (Resend), in-app, push | notifications, delivery_log |
| `billing` | Stripe subscriptions, quotas, webhooks | subscriptions, quotas |

## Money correctness

- Money is an `int64` of **minor units** (cents) — never floats. `libs/money` provides the immutable, overflow-checked value object used everywhere.
- The ledger is **event-sourced**: `ledger_entries` is append-only; `account_balances` is a projection updated atomically in the same CockroachDB transaction. Balances are never computed in app code.
- Kafka publishing uses the **transactional outbox** pattern — no dual-write problems.

## Event flows (Kafka topics)

- `ledger.transactions` — transaction created/updated → budget thresholds, reporting rollups, notifications
- `marketdata.quotes` — price ticks → investment P&L refresh
- `notifications.*` — email/push dispatch
- `billing.*` — subscription lifecycle
- `plans.*` — projection recomputation triggers
- Every consumer is idempotent (dedupe by event ID); DLQs per consumer group.

## Auth

- Own OIDC provider (battle-tested libraries), Argon2id password hashing, RS256 JWTs with rotating refresh tokens (Redis), TOTP + WebAuthn MFA.
- **Strangler migration from Clerk**: new users onboard on auth-service; existing users migrated with password-reset flow; feature-flag switch; Clerk decommissioned.

## Repo layout (Phase P0)

```
├── app/                      # Next.js frontend (existing PennyWise app)
├── protos/                   # Proto contracts (source of truth)
│   └── pennywise/{auth,common,health}/v1/
├── gen/go/                   # Generated Go code (buf)
├── libs/
│   ├── money/                # Money value object (int64 minor units)
│   └── observability/        # slog setup
├── services/
│   └── auth/                 # auth-service (reference implementation)
│       ├── cmd/server/       #   fx wiring
│       └── internal/         #   domain / application / infrastructure / delivery
├── infra/terraform/          # AWS: VPC, EKS, MSK, Redis, CockroachDB
└── .github/workflows/ci.yml  # proto + go + frontend checks
```

### Go module layout

- `go.work` at the root wires: `gen/go`, `libs/*`, `services/*`
- Each service has `replace` directives to local libs so it builds standalone
- Shared code goes in `libs/`; generated contracts in `gen/go`

### Service template (layered, hexagonal)

```
services/<name>/
  cmd/server/main.go           # fx DI wiring
  internal/
    domain/                    # entities, value objects, aggregates (zero deps)
    application/               # use cases + port interfaces
    infrastructure/            # CockroachDB/Redis/Kafka adapters
    delivery/grpc/             # gRPC handlers, error mapping
    config/                    # env config
```

## Scaling math (validation)

- 10M users × ~60 txns/month ≈ 600M txns/month (~7B/yr); ~0.3 KB per ledger row ≈ 2 TB/yr — CockroachDB scales horizontally; ledger partitioned by time.
- Reads hit projections + Redis (90%+ cache hit on dashboards); writes are strongly consistent via CockroachDB serializable transactions.
- SLOs: p95 API < 100 ms, availability 99.95%.

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| P0 | Monorepo, protos, libs, auth-service skeleton, Terraform, CI | ✅ scaffolded |
| P1 | auth-service hardened (OIDC, MFA, DB repo), gateway, user-service, Clerk migration | pending |
| P2 | ledger-service (accounts/transactions/balances), budgets, reporting | pending |
| P3 | marketdata + investment services (Yahoo Finance) | pending |
| P4 | planning-service (goals, projections, net worth) | pending |
| P5 | billing (Stripe), hardening, load/chaos testing, cutover | pending |

## Risks

- **Custom auth** = largest security surface → battle-tested libs, staged migration, independent review.
- **Yahoo Finance is unofficial** → Redis cache, secondary provider behind `PriceProvider` interface, graceful degradation.
- **CockroachDB serializable txns** → standard retry helper in the DB adapter.
- **Eventual consistency** acceptable for reads; ledger writes remain strongly consistent.
