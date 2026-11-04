import 'dart:io';

/// Headers proving this app may talk to the local daemon, which keeps its
/// token in ~/.lema/token. Empty when there is no daemon on this device.
Map<String, String> daemonHeaders() {
  try {
    // Inside the macOS sandbox HOME is the app's container, not the real home.
    final home = Platform.environment['HOME']!.split('/Library/Containers/').first;
    return {'x-lema-token': File('$home/.lema/token').readAsStringSync().trim()};
  } catch (_) {
    return const {};
  }
}
