import 'package:aqueduct/aqueduct.dart';

import 'column.dart' as mysql;
import 'table.dart' as mysql;

class ColumnSortBuilder extends mysql.ColumnBuilder {
  ColumnSortBuilder(mysql.TableBuilder table, String key, QuerySortOrder order)
      : order = order == QuerySortOrder.ascending ? "ASC" : "DESC",
        super(table, table.entity.properties[key]);

  final String order;

  String get sqlOrderBy => "${sqlColumnName(withTableNamespace: true)} $order";
}
