import 'package:flutter/foundation.dart';

/// Index of the bottom-navigation tab that is currently visible.
///
/// The main tabs keep their state while hidden, so a tab cannot rely on being
/// rebuilt to show fresh data. Screens that live in a tab listen to this
/// notifier and reload when their own index becomes the active one.
abstract final class MainTabs {
  static const home = 0;
  static const offers = 1;
  static const followUp = 2;
  static const account = 3;

  static final ValueNotifier<int> active = ValueNotifier<int>(home);
}
