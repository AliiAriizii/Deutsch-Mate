import 'package:flutter/material.dart';

import '../core/progress/progress_store.dart';

/// Makes the [ProgressStore] reachable from any screen, and rebuilds them when
/// it changes - so finishing a section on one screen updates the numbers on
/// every other one without any manual plumbing.
class ProgressScope extends InheritedNotifier<ProgressStore> {
  const ProgressScope({
    super.key,
    required ProgressStore store,
    required super.child,
  }) : super(notifier: store);

  static ProgressStore of(BuildContext context) {
    final store = context
        .dependOnInheritedWidgetOfExactType<ProgressScope>()
        ?.notifier;
    assert(store != null, 'No ProgressScope above this widget');
    return store!;
  }

  static ProgressStore? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ProgressScope>()
      ?.notifier;
}
