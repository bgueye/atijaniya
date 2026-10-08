import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Empêche la mise en veille de l'écran tant que ce widget est affiché.
///
/// Ajouté pour le Tasbih (revue de design du 2026-10-06) : en mode voix, ou
/// entre deux répétitions lentes d'une formule longue, le téléphone
/// s'éteignait au milieu du wird. La veille normale reprend dès que l'écran
/// est quitté (`dispose`).
class KeepScreenOn extends StatefulWidget {
  const KeepScreenOn({super.key, required this.child});

  final Widget child;

  @override
  State<KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends State<KeepScreenOn> {
  @override
  void initState() {
    super.initState();
    _set(true);
  }

  @override
  void dispose() {
    _set(false);
    super.dispose();
  }

  /// Un confort, jamais une condition : si la plateforme refuse (ou en test,
  /// où le plugin natif n'existe pas), le comptage doit continuer comme si de
  /// rien n'était.
  void _set(bool enabled) {
    unawaited(() async {
      try {
        await WakelockPlus.toggle(enable: enabled);
      } catch (_) {}
    }());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
