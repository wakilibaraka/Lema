import 'dart:convert';
import 'dart:io';

import 'package:lema_daemon/accounts.dart';

/// Registers your platform developer app with the daemon. You type the values;
/// the secret isn't echoed, never reaches shell history, and goes to the keychain.
Future<void> main(List<String> args) async {
  final known = args.length == 1 ? knownProviders[args.first] : null;
  if (known == null) {
    stderr.writeln('Usage: dart run bin/setup_app.dart <${knownProviders.keys.join('|')}>');
    exit(64);
  }
  stdout.write('Client ID: ');
  final id = stdin.readLineSync(encoding: utf8)?.trim() ?? '';
  stdout.write('Client secret: ');
  stdin.echoMode = false;
  final secret = stdin.readLineSync(encoding: utf8)?.trim() ?? '';
  stdin.echoMode = true;
  stdout.writeln();
  if (id.isEmpty || secret.isEmpty) exit(1);

  await KeychainSecrets().write('client-secret:${args.first}', secret);
  final home = Platform.environment['LEMA_HOME'] ??
      '${Platform.environment['HOME']}/.lema';
  final file = File('$home/providers.json');
  final all = file.existsSync()
      ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  all[args.first] = {...known, 'clientId': id};
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(all), flush: true);
  stdout.writeln('Saved. Restart the daemon.');
}
