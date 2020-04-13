import 'dart:async';

import 'package:aqueduct/src/cli/command.dart';
import 'package:aqueduct/src/cli/mixins/database_managing.dart';
import 'package:aqueduct/src/cli/mixins/project.dart';
import 'package:aqueduct_mysql/src/cli/mixins/database_connecting.dart';

class CLIMySqlDatabaseShowMigrations extends CLICommand
    with CLIDatabaseManagingCommand, CLIProject, CLIMySqlDatabaseConnectingCommand {
  @override
  Future<int> handle() async {
    var files = projectMigrations.map((mig) {
      var versionString = "${mig.versionNumber}".padLeft(8, "0");
      return " $versionString | ${mig.uri.pathSegments.last}";
    }).join("\n");

    print(" Version  | Path");
    print("----------|-----------");
    print("$files");

    return 0;
  }

  @override
  String get name {
    return "list";
  }

  @override
  String get description {
    return "Show the path and version all migration files for this project.";
  }
}
