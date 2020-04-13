import 'package:aqueduct/aqueduct.dart';

import 'column.dart' as mysql;
import 'table.dart' as mysql;
class ColumnValueBuilder extends mysql.ColumnBuilder {
  ColumnValueBuilder(
      mysql.TableBuilder table, ManagedPropertyDescription property, dynamic value)
      : super(table, property) {
    this.value = convertValueForStorage(value);
  }

  dynamic value;
}
