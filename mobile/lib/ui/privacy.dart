import 'package:flutter/material.dart';
import 'theme.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

class PrivacySession {
  static int _externalCount = 0;
  static bool get externalActive => _externalCount > 0;
  static Future<T> external<T>(Future<T> Function() operation) async {
    _externalCount++;
    try {
      return await operation();
    } finally {
      _externalCount--;
    }
  }
}

/// Covers the whole navigator, including open dialogs, in the app switcher.
class PrivacyShield extends StatefulWidget {
  const PrivacyShield({super.key, required this.child});
  final Widget child;
  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield>
    with WidgetsBindingObserver {
  bool _hidden = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      setState(() => _hidden = state != AppLifecycleState.resumed);
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_hidden)
        const Positioned.fill(
          child: ColoredBox(
            color: canvas,
            child: Center(
              child: Icon(Icons.spa_outlined, color: forest, size: 64),
            ),
          ),
        ),
    ],
  );
}
