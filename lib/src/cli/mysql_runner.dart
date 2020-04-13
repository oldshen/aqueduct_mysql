
import 'package:aqueduct/src/cli/command.dart';
import 'package:aqueduct_mysql/src/cli/commands/auth.dart';
import 'package:aqueduct_mysql/src/cli/commands/db.dart';
class MySqlRunner extends CLICommand{

  MySqlRunner(){
    registerCommand(CLIMySqlDatabase());
    registerCommand(CLIMySqlAuth());
  }
  @override
  String get description => "MySql CLI Tools for Aqueduct Application.";

  @override
  Future<int> handle() async{
   printHelp();
    return 0;
  }

  @override
  String get name => "aqueduct_mysql";
}