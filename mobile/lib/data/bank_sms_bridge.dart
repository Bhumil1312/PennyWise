import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BankSmsMessage {
  const BankSmsMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
  });
  final String id, sender, body;
  final DateTime receivedAt;
  factory BankSmsMessage.fromMap(Map<Object?, Object?> value) => BankSmsMessage(
    id: value['id'] as String,
    sender: value['sender'] as String,
    body: value['body'] as String,
    receivedAt: DateTime.fromMillisecondsSinceEpoch(value['receivedAt'] as int),
  );
}

class BankSmsStatus {
  const BankSmsStatus({
    this.supported = false,
    this.enabled = false,
    this.permissionGranted = false,
    this.senders = const [],
    this.pendingCount = 0,
    this.overflowCount = 0,
    this.error,
  });
  final bool supported, enabled, permissionGranted;
  final List<String> senders;
  final int pendingCount, overflowCount;
  final String? error;
  factory BankSmsStatus.fromMap(Map<Object?, Object?> value) => BankSmsStatus(
    supported: value['supported'] == true,
    enabled: value['enabled'] == true,
    permissionGranted: value['permissionGranted'] == true,
    senders: List<String>.from(value['senders'] as List? ?? const []),
    pendingCount: value['pendingCount'] as int? ?? 0,
    overflowCount: value['overflowCount'] as int? ?? 0,
    error: value['error'] as String?,
  );
}

/// Android receives new SMS only. This does not read SMS history on any platform.
class BankSmsBridge {
  const BankSmsBridge();
  static const _channel = MethodChannel('dev.pennywise/bank_sms');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<BankSmsStatus> status() async {
    if (!supported) return const BankSmsStatus();
    final value = await _channel.invokeMapMethod<Object?, Object?>('status');
    return BankSmsStatus.fromMap(value ?? const {});
  }

  Future<void> configure({
    required bool enabled,
    required List<String> senders,
  }) async {
    if (!supported) {
      if (enabled) {
        throw UnsupportedError('Automatic SMS capture requires Android.');
      }
      return;
    }
    await _channel.invokeMethod<void>('configure', {
      'enabled': enabled,
      'senders': senders,
    });
  }

  /// Call only after a disclosure and an explicit user button press.
  Future<bool> requestPermission() async => supported
      ? await _channel.invokeMethod<bool>('requestPermission') ?? false
      : false;

  Future<List<BankSmsMessage>> pending() async {
    if (!supported) return const [];
    final values =
        await _channel.invokeListMethod<Object?>('pending') ?? const [];
    return values
        .map(
          (value) =>
              BankSmsMessage.fromMap(Map<Object?, Object?>.from(value as Map)),
        )
        .toList();
  }

  /// Acknowledge only after the corresponding vault mutation is durable.
  Future<void> acknowledge(List<String> ids) async {
    if (supported && ids.isNotEmpty) {
      await _channel.invokeMethod<void>('acknowledge', {'ids': ids});
    }
  }

  Future<void> clear() async {
    if (supported) await _channel.invokeMethod<void>('clear');
  }
}
