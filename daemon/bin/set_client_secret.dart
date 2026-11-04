import 'dart:convert';
import 'dart:io';

import 'package:lema_daemon/accounts.dart';

/// Saves a platform app's client secret to the keychain. You type it; it is
/// not echoed and never lands in shell history.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run bin/set_client_secret.dart <platform>');
    exit(64);
  }
  stdout.write('Client secret for ${args.first}: ');
  stdin.echoMode = false;
  final value = stdin.readLineSync(encoding: utf8)?.trim() ?? '';
  stdin.echoMode = true;
  stdout.writeln();
  if (value.isEmpty) exit(1);
  await KeychainSecrets().write('client-secret:${args.first}', value);
  stdout.writeln('Saved.');
}
