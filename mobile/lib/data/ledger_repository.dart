import '../domain/models.dart';

abstract interface class LedgerRepository {
  Future<LedgerState> load();
  Future<void> commit(LedgerState before, LedgerState after);
  Future<void> close();
}

class MemoryLedgerRepository implements LedgerRepository {
  MemoryLedgerRepository([LedgerState? initial])
    : _state = initial ?? LedgerState();
  LedgerState _state;
  @override
  Future<LedgerState> load() async => _state;
  @override
  Future<void> commit(LedgerState before, LedgerState after) async {
    _state = after;
  }

  @override
  Future<void> close() async {}
}
