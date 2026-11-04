import 'dart:io';

import 'package:lema_daemon/daemon.dart';

Future<void> main() async {
  final home = Platform.environment['LEMA_HOME'] ??
      '${Platform.environment['HOME']}/.lema';
  final daemon = Daemon(Directory(home), fakeAdapter);
  await daemon.serve(port: 3001);
  stdout.writeln('Lema daemon on 127.0.0.1:3001, data in $home');
}
