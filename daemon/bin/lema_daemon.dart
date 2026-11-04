import 'dart:io';

import 'package:lema_daemon/accounts.dart';
import 'package:lema_daemon/daemon.dart';
import 'package:lema_daemon/publisher.dart';

Future<void> main() async {
  final home = Platform.environment['LEMA_HOME'] ??
      '${Platform.environment['HOME']}/.lema';
  late final Publisher publisher;
  final daemon = Daemon(Directory(home), (post) => publisher(post));
  publisher = Publisher(daemon.accounts, Directory('$home/uploads'));
  await daemon.serve(port: 3001);
  stdout.writeln('Lema daemon on 127.0.0.1:3001, data in $home');
}
