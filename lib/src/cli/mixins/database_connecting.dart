import 'dart:async';
import 'dart:io';
import 'package:aqueduct/aqueduct.dart';
import 'package:aqueduct/src/cli/command.dart';
import 'package:aqueduct/src/cli/mixins/project.dart';
import 'package:aqueduct/src/cli/metadata.dart';
import 'package:aqueduct_mysql/mysql.dart';
abstract class CLIMySqlDatabaseConnectingCommand implements CLICommand, CLIProject {
  static const String flavorMySql = "mysql";

  DatabaseConfiguration connectedDatabase;

  @Flag("use-ssl",
      help: "Whether or not the database connection should use SSL",
      defaultsTo: false)
  bool get useSSL => decode("use-ssl");

  @Option("connect",
      abbr: "c",
      help:
          "A database connection URI string. If this option is set, database-config is ignored.",
      valueHelp: "mysql://user:password@localhost:port/databaseName")
  String get databaseConnectionString => decode("connect");

  @Option("flavor",
      abbr: "f",
      help: "The database driver flavor to use.",
      defaultsTo: "mysql",
      allowed: ["mysql"])
  String get databaseFlavor => decode("flavor");

  @Option("database-config",
      help:
          "A configuration file that provides connection information for the database. "
          "Paths are relative to project directory. If the connect option is set, this value is ignored. "
          "See 'aqueduct db -h' for details.",
      defaultsTo: "database.yaml")
  File get databaseConfigurationFile =>
      fileInProjectDirectory(decode("database-config"));

  PersistentStore _persistentStore;

  PersistentStore get persistentStore {
    if (_persistentStore != null) {
      return _persistentStore;
    }

    if (decode("flavor") == null) {
      throw CLIException("No database flavor selected. See --flavor.");
    }

    if (databaseFlavor == flavorMySql) {
      if (databaseConnectionString != null) {
        try {
          connectedDatabase = DatabaseConfiguration();
          connectedDatabase.decode(databaseConnectionString);
        } catch (_) {
          throw CLIException("Invalid database configuration.", instructions: [
            "Invalid connection string was: $databaseConnectionString",
            "Expected format:               database://user:password@host:port/databaseName"
          ]);
        }
      } else {
        if (!databaseConfigurationFile.existsSync()) {
          throw CLIException("No database configuration file found.",
              instructions: [
                "Expected file at: ${databaseConfigurationFile.path}.",
                "See --connect and --database-config. If not using --connect, "
                    "this tool expects a YAML configuration file with the following format:\n$_dbConfigFormat"
              ]);
        }

        try {
          connectedDatabase =
              DatabaseConfiguration.fromFile(databaseConfigurationFile);
        } catch (_) {
          throw CLIException("Invalid database configuration.", instructions: [
            "File located at ${databaseConfigurationFile.path}.",
            "See --connect and --database-config. If not using --connect, "
                "this tool expects a YAML configuration file with the following format:\n$_dbConfigFormat"
          ]);
        }
      }

      return _persistentStore = MySqlPersistentStore(
          connectedDatabase.username,
          connectedDatabase.password,
          connectedDatabase.host,
          connectedDatabase.port,
          connectedDatabase.databaseName,
          useSSL: useSSL);
    }

    throw CLIException("Invalid flavor $databaseFlavor");
  }

  @override
  Future cleanup() async {
    return _persistentStore?.close();
  }

  String get _dbConfigFormat {
    return "\n\tusername: username\n\tpassword: password\n\thost: host\n\tport: port\n\tdatabaseName: name\n";
  }
}