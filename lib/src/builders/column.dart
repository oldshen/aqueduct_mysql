import 'package:aqueduct/src/db/managed/key_path.dart';
import 'package:aqueduct/src/db/managed/managed.dart';
import 'package:aqueduct/src/db/managed/relationship_type.dart';
import 'package:aqueduct/src/db/query/matcher_internal.dart';
import 'table.dart';

/// Common interface for values that can be mapped to/from a database.
abstract class Returnable {}

class ColumnBuilder extends Returnable {
  ColumnBuilder(this.table, this.property, {this.documentKeyPath});

  static List<Returnable> fromKeys(TableBuilder table, List<KeyPath> keys) {
    final entity = table.entity;

    // Ensure the primary key is always available and at 0th index.
    int primaryKeyIndex;
    for (var i = 0; i < keys.length; i++) {
      final firstElement = keys[i].path.first;
      if (firstElement is ManagedAttributeDescription &&
          firstElement.isPrimaryKey) {
        primaryKeyIndex = i;
        break;
      }
    }

    if (primaryKeyIndex == null) {
      keys.insert(0, KeyPath(entity.primaryKeyAttribute));
    } else if (primaryKeyIndex > 0) {
      keys.removeAt(primaryKeyIndex);
      keys.insert(0, KeyPath(entity.primaryKeyAttribute));
    }

    return List.from(keys.map((key) {
      return ColumnBuilder(table, propertyForName(entity, key.path.first.name),
          documentKeyPath: key.dynamicElements);
    }));
  }

  static ManagedPropertyDescription propertyForName(
      ManagedEntity entity, String propertyName) {
    var property = entity.properties[propertyName];

    if (property == null) {
      throw ArgumentError(
          "Could not construct query. Column '$propertyName' does not exist for table '${entity.tableName}'.");
    }

    if (property is ManagedRelationshipDescription &&
        property.relationshipType != ManagedRelationshipType.belongsTo) {
      throw ArgumentError(
          "Could not construct query. Column '$propertyName' does not exist for table '${entity.tableName}'. "
          "'$propertyName' recognized as ORM relationship, use 'Query.join' instead.");
    }
    return property;
  }

  static Map<ManagedPropertyType, MySqlDataType> typeMap = {
    ManagedPropertyType.integer: MySqlDataType.integer,
    ManagedPropertyType.bigInteger: MySqlDataType.bigInteger,
    ManagedPropertyType.string: MySqlDataType.text,
    ManagedPropertyType.datetime: MySqlDataType.timestampWithoutTimezone,
    ManagedPropertyType.boolean: MySqlDataType.boolean,
    ManagedPropertyType.doublePrecision: MySqlDataType.double,
    ManagedPropertyType.document: MySqlDataType.json
  };

  static Map<PredicateOperator, String> symbolTable = {
    PredicateOperator.lessThan: "<",
    PredicateOperator.greaterThan: ">",
    PredicateOperator.notEqual: "!=",
    PredicateOperator.lessThanEqualTo: "<=",
    PredicateOperator.greaterThanEqualTo: ">=",
    PredicateOperator.equalTo: "="
  };

  final TableBuilder table;
  final ManagedPropertyDescription property;
  final List<dynamic> documentKeyPath;

  dynamic convertValueForStorage(dynamic value) {
    if (value == null) {
      return null;
    }

    if (property is ManagedAttributeDescription) {
      final p = property as ManagedAttributeDescription;
      if (p.isEnumeratedValue) {
        return value.toString().split(".").last;
      } else if (p.type.kind == ManagedPropertyType.document) {
        if (value is Document) {
          return value.data;
        } else if (value is Map || value is List) {
          return value;
        }

        throw ArgumentError(
            "Invalid data type for 'Document'. Must be 'Document', 'Map', or 'List'.");
      }
    }

    return value;
  }

  dynamic convertValueFromStorage(dynamic value) {
    if (value == null) {
      return null;
    }

    if (property is ManagedAttributeDescription) {
      final p = property as ManagedAttributeDescription;
      if (p.isEnumeratedValue) {
        if (!p.enumerationValueMap.containsKey(value)) {
          throw ValidationException(["invalid option for key '${p.name}'"]);
        }
        return p.enumerationValueMap[value];
      } else if (p.type.kind == ManagedPropertyType.document) {
        return Document(value);
      }
    }

    return value;
  }

  String get sqlTypeSuffix {
    // var type =
    //     PostgreSQLFormat.dataTypeStringForDataType(typeMap[property.type.kind]);
    var type; // TOOD:
    if (type != null) {
      return ":$type";
    }

    return "";
  }

  String sqlColumnName(
      {bool withTypeSuffix = false,
      bool withTableNamespace = false,
      String withPrefix}) {
    var name = property.name;

    if (property is ManagedRelationshipDescription) {
      var relatedPrimaryKey = (property as ManagedRelationshipDescription)
          .destinationEntity
          .primaryKey;
      name = "${name}_$relatedPrimaryKey";
    } else if (documentKeyPath != null) {
      final keys =
          documentKeyPath.map((k) => k is String ? "'$k'" : k).join("->");
      name = "$name->$keys";
    }

    if (withTypeSuffix) {
      name = "$name$sqlTypeSuffix";
    }

    if (withTableNamespace) {
      return "${table.sqlTableReference}.`$name`";
    } else if (withPrefix != null) {
      return "`$withPrefix$name`";
    }

    return name;
  }
}

enum MySqlDataType {
  /// Must be a [String].
  text,

  /// Must be an [int] (4-byte integer)
  integer,

  /// Must be an [int] (2-byte integer)
  smallInteger,

  /// Must be an [int] (8-byte integer)
  bigInteger,

  /// Must be an [int] (autoincrementing 4-byte integer)
  serial,

  /// Must be an [int] (autoincrementing 8-byte integer)
  bigSerial,

  /// Must be a [double] (32-bit floating point value)
  real,

  /// Must be a [double] (64-bit floating point value)
  double,

  /// Must be a [bool]
  boolean,

  /// Must be a [DateTime] (microsecond date and time precision)
  timestampWithoutTimezone,

  /// Must be a [DateTime] (microsecond date and time precision)
  timestampWithTimezone,

  /// Must be a [DateTime] (contains year, month and day only)
  date,

  /// Must be encodable via [json.encode].
  ///
  /// Values will be encoded via [json.encode] before being sent to the database.
  json,

  /// Must be a [List] of [int].
  ///
  /// Each element of the list must fit into a byte (0-255).
  byteArray,

  /// Must be a [String]
  ///
  /// Used for internal pg structure names
  name,

  /// Must be a [String].
  ///
  /// Must contain 32 hexadecimal characters. May contain any number of '-' characters.
  /// When returned from database, format will be xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
  uuid
}

// class MySqlFormat {
//   static int _AtSignCodeUnit = "@".codeUnitAt(0);

//   static String id(String name, {MySqlDataType type: null}) {
//     if (type != null) {
//       return "@$name:${dataTypeStringForDataType(type)}";
//     }

//     return "@$name";
//   }

//   static String dataTypeStringForDataType(MySqlDataType dt) {
//     switch (dt) {
//       case MySqlDataType.text:
//         return "text";
//       case MySqlDataType.integer:
//         return "int4";
//       case MySqlDataType.smallInteger:
//         return "int2";
//       case MySqlDataType.bigInteger:
//         return "int8";
//       case MySqlDataType.serial:
//         return "int4";
//       case MySqlDataType.bigSerial:
//         return "int8";
//       case MySqlDataType.real:
//         return "float4";
//       case MySqlDataType.double:
//         return "float8";
//       case MySqlDataType.boolean:
//         return "boolean";
//       case MySqlDataType.timestampWithoutTimezone:
//         return "timestamp";
//       case MySqlDataType.timestampWithTimezone:
//         return "timestamptz";
//       case MySqlDataType.date:
//         return "date";
//       case MySqlDataType.json:
//         return "jsonb";
//       case MySqlDataType.byteArray:
//         return "bytea";
//       case MySqlDataType.name:
//         return "name";
//       case MySqlDataType.uuid:
//         return "uuid";
//     }

//     return null;
//   }

//   static String substitute(String fmtString, Map<String, dynamic> values,
//       {SQLReplaceIdentifierFunction replace: null}) {
//     final converter = new PostgresTextEncoder(true);
//     values ??= {};
//     replace ??= (spec, index) => converter.convert(values[spec.name]);

//     var items = <PostgreSQLFormatToken>[];
//     PostgreSQLFormatToken currentPtr = null;
//     var iterator = new RuneIterator(fmtString);

//     iterator.moveNext();
//     while (iterator.current != null) {
//       if (currentPtr == null) {
//         if (iterator.current == _AtSignCodeUnit) {
//           currentPtr = new PostgreSQLFormatToken(PostgreSQLFormatTokenType.variable);
//           currentPtr.buffer.writeCharCode(iterator.current);
//           items.add(currentPtr);
//         } else {
//           currentPtr = new PostgreSQLFormatToken(PostgreSQLFormatTokenType.text);
//           currentPtr.buffer.writeCharCode(iterator.current);
//           items.add(currentPtr);
//         }
//       } else if (currentPtr.type == PostgreSQLFormatTokenType.text) {
//         if (iterator.current == _AtSignCodeUnit) {
//           currentPtr = new PostgreSQLFormatToken(PostgreSQLFormatTokenType.variable);
//           currentPtr.buffer.writeCharCode(iterator.current);
//           items.add(currentPtr);
//         } else {
//           currentPtr.buffer.writeCharCode(iterator.current);
//         }
//       } else if (currentPtr.type == PostgreSQLFormatTokenType.variable) {
//         if (iterator.current == _AtSignCodeUnit) {
//           iterator.movePrevious();
//           if (iterator.current == _AtSignCodeUnit) {
//             currentPtr.buffer.writeCharCode(iterator.current);
//             currentPtr.type = PostgreSQLFormatTokenType.text;
//           } else {
//             currentPtr =
//                 new PostgreSQLFormatToken(PostgreSQLFormatTokenType.variable);
//             currentPtr.buffer.writeCharCode(iterator.current);
//             items.add(currentPtr);
//           }
//           iterator.moveNext();
//         } else if (_isIdentifier(iterator.current)) {
//           currentPtr.buffer.writeCharCode(iterator.current);
//         } else {
//           currentPtr = new PostgreSQLFormatToken(PostgreSQLFormatTokenType.text);
//           currentPtr.buffer.writeCharCode(iterator.current);
//           items.add(currentPtr);
//         }
//       }

//       iterator.moveNext();
//     }

//     var idx = 1;
//     return items.map((t) {
//       if (t.type == PostgreSQLFormatTokenType.text) {
//         return t.buffer;
//       } else if (t.buffer.length == 1 && t.buffer.toString() == '@') {
//         return t.buffer;
//       } else {
//         var identifier = new PostgreSQLFormatIdentifier(t.buffer.toString());

//         if (!values.containsKey(identifier.name)) {
//           throw new FormatException(
//               "Format string specified identifier with name ${identifier
//                   .name}, but key was not present in values. Format string: $fmtString");
//         }

//         var val = replace(identifier, idx);
//         idx++;

//         if (identifier.typeCast != null) {
//           return val + "::" + identifier.typeCast;
//         }

//         return val;
//       }
//     }).join("");
//   }

//   static int _lowercaseACodeUnit = "a".codeUnitAt(0);
//   static int _uppercaseACodeUnit = "A".codeUnitAt(0);
//   static int _lowercaseZCodeUnit = "z".codeUnitAt(0);
//   static int _uppercaseZCodeUnit = "Z".codeUnitAt(0);
//   static int _0CodeUnit = "0".codeUnitAt(0);
//   static int _9CodeUnit = "9".codeUnitAt(0);
//   static int _underscoreCodeUnit = "_".codeUnitAt(0);
//   static int _ColonCodeUnit = ":".codeUnitAt(0);

//   static bool _isIdentifier(int charCode) {
//     return (charCode >= _lowercaseACodeUnit &&
//             charCode <= _lowercaseZCodeUnit) ||
//         (charCode >= _uppercaseACodeUnit && charCode <= _uppercaseZCodeUnit) ||
//         (charCode >= _0CodeUnit && charCode <= _9CodeUnit) ||
//         (charCode == _underscoreCodeUnit) ||
//         (charCode == _ColonCodeUnit);
//   }
// }
