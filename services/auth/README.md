# auth-service

Identity provider for PennyWise — OIDC-style authentication for the 10M-user platform.
This is the **reference implementation** of the layered service template (hexagonal architecture).

## Layout

```
cmd/server/main.go            # fx DI wiring
internal/
  domain/                     # User entity + value objects (zero external deps)
  application/                # AuthService use cases + port interfaces
  infrastructure/
    repo/memory/              # in-memory UserRepository (CockroachDB repo in P1)
    password/                 # Argon2id hashing
    tokens/                   # JWT access/refresh tokens (HS256; RS256 in P1)
  delivery/grpc/              # gRPC handlers + error mapping
  config/                     # env config
```

## Run locally

```sh
export AUTH_JWT_SECRET=0123456789abcdef0123456789abcdef   # min 32 bytes
go run ./cmd/server
```

gRPC server listens on `0.0.0.0:50051` (override with `AUTH_GRPC_ADDRESS`).

## Env vars

| Variable | Default | Purpose |
|---|---|---|
| `AUTH_ENV` | `development` | Log level: dev=debug, prod=info |
| `AUTH_GRPC_ADDRESS` | `0.0.0.0:50051` | gRPC listen address |
| `AUTH_JWT_SECRET` | (required) | Token signing key, min 32 bytes |
| `AUTH_ISSUER` | `pennywise-auth` | Token issuer claim |

## Build & test

```sh
go build ./...
go test ./...
```

## Contract

Protos in `protos/pennywise/auth/v1/auth.proto`; generated code in `gen/go`.
Regenerate with `make proto` (buf).

## P1 roadmap

- CockroachDB `UserRepository` (replaces memory repo)
- RS256 signing via KMS, refresh-token rotation + Redis sessions
- MFA (TOTP/WebAuthn), email verification
- OIDC endpoints, API keys, audit log