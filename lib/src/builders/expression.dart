import 'package:aqueduct/src/db/managed/managed.dart';

import 'package:aqueduct/src/db/query/matcher_internal.dart';
import 'package:aqueduct/src/db/query/query.dart';

import 'column.dart' as mysql;
import 'table.dart' as mysql;

class ColumnExpressionBuilder extends mysql.ColumnBuilder {
  ColumnExpressionBuilder(
      mysql.TableBuilder table, ManagedPropertyDescription property, this.expression,
      {this.prefix = ""})
      : super(table, property);

  final String prefix;
  PredicateExpression expression;

  String get defaultPrefix => "$prefix${table.sqlTableReference}_";

  QueryPredicate get predicate {
    final expr = expression;
    if (expr is ComparisonExpression) {
      return comparisonPredicate(expr.operator, expr.value);
    } else if (expr is RangeExpression) {
      return rangePredicate(expr.lhs, expr.rhs, insideRange: expr.within);
    } else if (expr is NullCheckExpression) {
      return nullPredicate(isNull: expr.shouldBeNull);
    } else if (expr is SetMembershipExpression) {
      return containsPredicate(expr.values, within: expr.within);
    } else if (expr is StringExpression) {
      return stringPredicate(expr.operator, expr.value,
          caseSensitive: expr.caseSensitive,
          invertOperator: expr.invertOperator,
          allowSpecialCharacters: expr.allowSpecialCharacters);
    }

    throw UnsupportedError(
        "Unknown expression applied to 'Query'. '${expr.runtimeType}' is not supported by 'MySQL'.");
  }

  QueryPredicate comparisonPredicate(
      PredicateOperator operator, dynamic value) {
    final name = sqlColumnName(withTableNamespace: true);
    final variableName = sqlColumnName(withPrefix: defaultPrefix);

    // return QueryPredicate(
    //     "$name ${mysql.ColumnBuilder.symbolTable[operator]} $variableName$sqlTypeSuffix",
    //     {variableName: convertValueForStorage(value)});

    return QueryPredicate(
        "$name ${mysql.ColumnBuilder.symbolTable[operator]} ?/*$variableName$sqlTypeSuffix*/",
        {variableName: convertValueForStorage(value)});
  }

  QueryPredicate containsPredicate(Iterable<dynamic> values,
      {bool within = true}) {
    var tokenList = [];
    var pairedMap = <String, dynamic>{};

    var counter = 0;
    values.forEach((value) {
      final prefix = "$defaultPrefix${counter}_";

      final variableName = sqlColumnName(withPrefix: prefix);
      tokenList.add("?/*$variableName$sqlTypeSuffix*/");
      pairedMap[variableName] = convertValueForStorage(value);

      counter++;
    });

    final name = sqlColumnName(withTableNamespace: true);
    final keyword = within ? "IN" : "NOT IN";
    return QueryPredicate("$name $keyword (${tokenList.join(",")})", pairedMap);
  }

  QueryPredicate nullPredicate({bool isNull = true}) {
    final name = sqlColumnName(withTableNamespace: true);
    return QueryPredicate("$name ${isNull ? "IS NULL" : "IS NOT NULL"}", {});
  }

  QueryPredicate rangePredicate(dynamic lhsValue, dynamic rhsValue,
      {bool insideRange = true}) {
    final name = sqlColumnName(withTableNamespace: true);
    final lhsName = sqlColumnName(withPrefix: "${defaultPrefix}lhs_");
    final rhsName = sqlColumnName(withPrefix: "${defaultPrefix}rhs_");
    final operation = insideRange ? "BETWEEN" : "NOT BETWEEN";

    return QueryPredicate(
        "$name $operation ?/*$lhsName$sqlTypeSuffix*/ AND ?/*$rhsName$sqlTypeSuffix*/",
        {
          lhsName: convertValueForStorage(lhsValue),
          rhsName: convertValueForStorage(rhsValue)
        });
  }

  QueryPredicate stringPredicate(PredicateStringOperator operator, String value,
      {bool caseSensitive = true,
      bool invertOperator = false,
      bool allowSpecialCharacters = true}) {
    final n = sqlColumnName(withTableNamespace: true);
    final variableName = sqlColumnName(withPrefix: defaultPrefix);

    var matchValue = allowSpecialCharacters ? value : escapeLikeString(value);

    if(operator==PredicateStringOperator.equals){
      return QueryPredicate("$n = ?/*$variableName$sqlTypeSuffix*/",{variableName:matchValue});
    }

    var operation = caseSensitive ? "LIKE" : "ILIKE";
    if (invertOperator) {
      operation = "NOT $operation";
    }
    switch (operator) {
      case PredicateStringOperator.beginsWith:
        matchValue = "$matchValue%";
        break;
      case PredicateStringOperator.endsWith:
        matchValue = "%$matchValue";
        break;
      case PredicateStringOperator.contains:
        matchValue = "%$matchValue%";
        break;
      default:
        break;
    }

    // return QueryPredicate("$n $operation @$variableName$sqlTypeSuffix",
    //     {variableName: matchValue});
    return QueryPredicate("$n $operation ?/*$variableName$sqlTypeSuffix*/",
        {variableName: matchValue});
  }

  String escapeLikeString(String input) {
    return input.replaceAllMapped(
        RegExp(r"(\\|%|_)"), (Match m) => "\\${m[0]}");
  }
}
