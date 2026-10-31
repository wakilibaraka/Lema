import 'package:flutter/cupertino.dart';

/// One entry in Lema's navigation. The sidebar, the mobile bar and the page
/// titles all read from [lemaDestinations], so a screen has one name.
class NavDestination {
  final String label;
  final IconData icon;

  const NavDestination({required this.label, required this.icon});
}

/// Order matters: it is the index stored in `AppProvider.selectedNavIndex`.
const List<NavDestination> lemaDestinations = [
  NavDestination(label: 'Analytics', icon: CupertinoIcons.chart_bar),
  NavDestination(label: 'Queue', icon: CupertinoIcons.calendar),
  NavDestination(label: 'Composer', icon: CupertinoIcons.square_pencil),
  NavDestination(label: 'Vault', icon: CupertinoIcons.photo_on_rectangle),
  NavDestination(label: 'Settings', icon: CupertinoIcons.gear),
];

/// Index of a destination by its label, or -1.
int destinationIndexOf(String label) =>
    lemaDestinations.indexWhere((d) => d.label == label);

int get composerDestinationIndex => destinationIndexOf('Composer');
int get settingsDestinationIndex => destinationIndexOf('Settings');
