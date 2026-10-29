import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'application/ledger_controller.dart';
import 'data/demo_data.dart';
import 'data/encrypted_repository.dart';
import 'data/ledger_repository.dart';
import 'ui/home.dart';
import 'ui/theme.dart';
import 'ui/privacy.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PennyWiseApp());
}

class PennyWiseApp extends StatelessWidget {
  const PennyWiseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PennyWise • Your money, in focus',
    navigatorKey: appNavigatorKey,
    builder: (_, child) => PrivacyShield(child: child!),
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: const VaultGate(),
  );
}

class VaultGate extends StatefulWidget {
  const VaultGate({super.key});
  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> with WidgetsBindingObserver {
  LedgerController? _controller;
  bool _unlocked = false, _busy = false;
  String? _error;
  bool get _native =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.repository.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_busy &&
        !PrivacySession.externalActive &&
        _controller?.isDemo == false &&
        state == AppLifecycleState.paused) {
      appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() => _unlocked = false);
    }
  }

  Future<void> _open({required bool demo}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!demo) {
        final auth = LocalAuthentication();
        if (!await auth.isDeviceSupported()) {
          throw StateError(
            'Enable a device screen lock to protect your vault.',
          );
        }
        if (!await auth.authenticate(
          localizedReason: 'Unlock your private PennyWise vault',
          persistAcrossBackgrounding: true,
        )) {
          return;
        }
      }
      if (_controller == null || _controller!.isDemo != demo) {
        await _controller?.repository.close();
        _controller?.dispose();
        _controller = null;
        final repository = demo
            ? MemoryLedgerRepository(demoData())
            : await EncryptedLedgerRepository.open();
        final next = LedgerController(repository, isDemo: demo);
        try {
          await next.load();
        } catch (_) {
          await repository.close();
          next.dispose();
          rethrow;
        }
        _controller = next;
      }
      if (mounted) setState(() => _unlocked = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to unlock the vault. Check your device screen lock and try again. Existing data is preserved; no replacement vault is created.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked && _controller != null) {
      return FinanceHome(
        controller: _controller!,
        onLock: () => setState(() => _unlocked = false),
      );
    }
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: forest,
                    child: Icon(Icons.spa_outlined, size: 34, color: lime),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'PennyWise',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'A little clarity.\nA lot more possibility.',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'One thoughtful home for your money, shared moments, and everything you’re building towards.',
                  style: TextStyle(color: muted, fontSize: 16, height: 1.65),
                ),
                const SizedBox(height: 30),
                if (_native) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _open(demo: false),
                    icon: const Icon(Icons.fingerprint),
                    label: Text(_busy ? 'Unlocking…' : 'Unlock my local vault'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Encrypted on this device. Uses your phone’s biometric or screen lock. Online account sign-in is a future integration.',
                    style: TextStyle(fontSize: 12, color: muted, height: 1.6),
                  ),
                  const SizedBox(height: 14),
                ] else
                  const Notice(
                    'Browser preview · sample data lives in memory and resets on refresh. Use the Android or iOS app for a persistent local vault.',
                  ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _open(demo: true),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Explore the demo'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Notice(_error!, color: coral),
                  ),
                const SizedBox(height: 32),
                const Text(
                  'MADE FOR INDIA  /  BUILT AROUND YOUR PRIVACY',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
