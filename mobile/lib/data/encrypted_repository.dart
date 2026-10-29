import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../domain/models.dart';
import 'ledger_repository.dart';

class EncryptedLedgerRepository implements LedgerRepository {
  EncryptedLedgerRepository._(this._db);
  final Database _db;
  static Future<EncryptedLedgerRepository> open() async {
    const storage = FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    );
    final path = '${await getDatabasesPath()}/pennywise-v1.db';
    var key = await storage.read(key: 'pennywise-vault-key-v1');
    if (key == null) {
      if (await databaseExists(path)) {
        throw StateError(
          'The vault key is missing. Your existing database has been preserved. Recovery is required.',
        );
      }
      final random = Random.secure();
      key = base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
      await storage.write(key: 'pennywise-vault-key-v1', value: key);
    }
    final db = await openDatabase(
      path,
      password: key,
      version: 2,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE accounts (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE entries (id TEXT PRIMARY KEY, source_key TEXT UNIQUE, payload TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE holdings (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        );
        await _createCaptureTables(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createCaptureTables(db);
      },
    );
    return EncryptedLedgerRepository._(db);
  }

  static Future<void> _createCaptureTables(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE captures (id TEXT PRIMARY KEY, evidence_key TEXT NOT NULL UNIQUE, payload TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE merchant_rules (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
    );
  }

  @override
  Future<LedgerState> load() async {
    Future<List<Map<String, dynamic>>> read(String table) async =>
        (await _db.query(table, orderBy: 'rowid'))
            .map(
              (r) =>
                  Map<String, dynamic>.from(jsonDecode(r['payload'] as String)),
            )
            .toList();
    return LedgerState(
      accounts: (await read('accounts')).map(Account.fromJson).toList(),
      entries: (await read('entries')).map(LedgerEntry.fromJson).toList(),
      holdings: (await read('holdings')).map(Holding.fromJson).toList(),
      captures: (await read(
        'captures',
      )).map(CapturedTransaction.fromJson).toList(),
      merchantRules: (await read(
        'merchant_rules',
      )).map(MerchantRule.fromJson).toList(),
    );
  }

  @override
  Future<void> commit(LedgerState before, LedgerState after) async {
    await _db.transaction((tx) async {
      Future<void> write(
        String table,
        List<Map<String, dynamic>> old,
        List<Map<String, dynamic>> next,
      ) async {
        final previous = {for (final item in old) item['id']: jsonEncode(item)};
        final ids = next.map((item) => item['id']).toSet();
        for (final id in previous.keys.where((id) => !ids.contains(id))) {
          await tx.delete(table, where: 'id = ?', whereArgs: [id]);
        }
        final batch = tx.batch();
        for (final item in next) {
          final payload = jsonEncode(item);
          if (previous[item['id']] == payload) continue;
          final values = <String, Object?>{
            'id': item['id'],
            'payload': payload,
          };
          if (table == 'entries') values['source_key'] = item['sourceKey'];
          if (table == 'captures') values['evidence_key'] = item['evidenceKey'];
          if (previous.containsKey(item['id'])) {
            batch.update(
              table,
              values,
              where: 'id = ?',
              whereArgs: [item['id']],
            );
          } else {
            batch.insert(table, values);
          }
        }
        await batch.commit(noResult: true);
      }

      await write(
        'accounts',
        before.accounts.map((x) => x.toJson()).toList(),
        after.accounts.map((x) => x.toJson()).toList(),
      );
      await write(
        'entries',
        before.entries.map((x) => x.toJson()).toList(),
        after.entries.map((x) => x.toJson()).toList(),
      );
      await write(
        'holdings',
        before.holdings.map((x) => x.toJson()).toList(),
        after.holdings.map((x) => x.toJson()).toList(),
      );
      await write(
        'captures',
        before.captures.map((x) => x.toJson()).toList(),
        after.captures.map((x) => x.toJson()).toList(),
      );
      await write(
        'merchant_rules',
        before.merchantRules.map((x) => x.toJson()).toList(),
        after.merchantRules.map((x) => x.toJson()).toList(),
      );
    });
  }

  @override
  Future<void> close() => _db.close();
}
