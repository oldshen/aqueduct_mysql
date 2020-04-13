import 'dart:async';
import 'dart:io';
import 'package:aqueduct_mysql/src/cli/mysql_runner.dart';

Future main(List<String> args) async {
  final runner = MySqlRunner();
  final values = runner.options.parse(args);
  exitCode = await runner.process(values);
}
