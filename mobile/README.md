# PennyWise mobile

Use Flutter 3.47.7 or newer. The [capture and analytics guide](../docs/CAPTURE_AND_ANALYTICS.md) explains receipt/PDF import, Android bank SMS setup, metadata review and automatic categories.

See [Start here](../docs/START_HERE.md) for features, limitations and setup, [Architecture](../docs/ARCHITECTURE_INDIA.md) for the connected design, and [Learning](../docs/SYSTEM_DESIGN_LEARNING.md) for system-design lessons.

```powershell
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
```

Browser demo: in-memory sample records. Native Android/iOS: encrypted device vault with device unlock; no online account or provider credentials required. Native behaviour still requires physical-device testing before use with real financial records. Recovery/backup is not implemented.

Directory map:

- `lib/domain/`: exact money, models, ledger invariants and local draft/CSV parsing.
- `lib/data/`: SQLCipher persistence plus separate in-memory demo repository.
- `lib/application/`: atomic operations and view state.
- `lib/ui/`: responsive Material screens, forms, draft review and privacy cover.
- `test/`: money/split/transfer/debt/idempotency/failure tests and widget flows.
- `examples/statement.csv`: synthetic import template.

Avoid treating browser preview as secure financial storage. No web persistence is configured. Never put private keys, provider secrets or financial records into source control. Keep the committed lockfile to reproduce dependencies.
