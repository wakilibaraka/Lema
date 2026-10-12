import 'package:flutter/cupertino.dart';

/// One entry in Lema's navigation, named once.
///
/// The sidebar, the window title bar, the mobile app bar and the dock tab bar
/// all render the same destination, so they all read from this list. They used
/// to keep three parallel label lists and drifted: the same screen was
/// "Publish Queue" in the sidebar, "Publishing Queue" in the title bar and
/// "Queue" in the tab bar.
class NavDestination {
  /// Full name, used where there is room (sidebar, window title bar).
  final String label;

  /// Compact name for the mobile app bar and the dock tab bar.
  final String shortLabel;

  final IconData icon;

  const NavDestination({
    required this.label,
    required this.shortLabel,
    required this.icon,
  });
}

/// Order matters: it is the destination index used by `AppProvider`.
const List<NavDestination> lemaDestinations = [
  NavDestination(
    label: 'Home',
    shortLabel: 'Home',
    icon: CupertinoIcons.house_fill,
  ),
  NavDestination(
    label: 'Simulator',
    shortLabel: 'Simulator',
    icon: CupertinoIcons.device_phone_portrait,
  ),
  NavDestination(
    label: 'Queue',
    shortLabel: 'Queue',
    icon: CupertinoIcons.layers_alt,
  ),
  NavDestination(
    label: 'Calendar',
    shortLabel: 'Calendar',
    icon: CupertinoIcons.calendar,
  ),
  NavDestination(
    label: 'AI Studio',
    shortLabel: 'AI Studio',
    icon: CupertinoIcons.sparkles,
  ),
  NavDestination(
    label: 'Composer',
    shortLabel: 'Composer',
    icon: CupertinoIcons.pencil_circle,
  ),
  NavDestination(
    label: 'Analytics',
    shortLabel: 'Analytics',
    icon: CupertinoIcons.chart_bar,
  ),
  NavDestination(
    label: 'Hooks',
    shortLabel: 'Hooks',
    icon: CupertinoIcons.film,
  ),
  NavDestination(
    label: 'Daily Tick',
    shortLabel: 'Daily Tick',
    icon: CupertinoIcons.checkmark_circle,
  ),
  NavDestination(
    label: 'Settings',
    shortLabel: 'Settings',
    icon: CupertinoIcons.gear_alt,
  ),
  NavDestination(
    label: 'Simulation',
    shortLabel: 'Simulation',
    icon: CupertinoIcons.speedometer,
  ),
];

/// How many leading destinations the mobile dock shows. The dock is the tab
/// bar, so its items are derived from the same list rather than duplicated.
const int lemaDockTabCount = 5;

/// Destinations the mobile dock can show.
List<NavDestination> get lemaDockDestinations =>
    lemaDestinations.take(lemaDockTabCount).toList();

/// Index of a destination by its label, or -1. Used by actions that send the
/// user somewhere else ("Reconnect" → Settings) without repeating an index.
int destinationIndexOf(String label) =>
    lemaDestinations.indexWhere((d) => d.label == label);

/// Where account reconnection lives.
int get settingsDestinationIndex => destinationIndexOf('Settings');
