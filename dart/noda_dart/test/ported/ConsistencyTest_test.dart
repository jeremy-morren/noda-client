// Ported from NodaTime 6e024dde: src/NodaTime.Test/ConsistencyTest.cs
// Copyright 2020 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: checks NodaTime's API as captured in test/api/nodatime-api.generated.dart (no reflection in Dart).

import '../api/nodatime-api.generated.dart';
import '../api/types.dart';
import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/ConsistencyTest.generated.dart' as scenarios;

const List<ApiType> AllPublicTypes = NodaTimeApi;

void main() {
  port(scenarios.fixture, {
    'EqualityOperatorForEquatable': (args) {
      var expectedExceptions = ['MapZone'];

      var failures = AllPublicTypes
          .where((t) => ImplementsGeneric(t, 'Equals', 'bool'))
          .where((t) => !HasMember(t, 'op_Equality'))
          .map((t) => t.name)
          .where((t) => !expectedExceptions.contains(t))
          .toList();
      Assert.IsEmpty(failures);
    },

    'ComparisonOperatorForComparable': (args) {
      var expectedExceptions = <String>[];

      var failures = AllPublicTypes
          .where((t) => ImplementsGeneric(t, 'CompareTo', 'int'))
          .where((t) => !HasMember(t, 'op_LessThan') || !HasMember(t, 'op_LessThanOrEqual'))
          .map((t) => t.name)
          .where((t) => !expectedExceptions.contains(t))
          .toList();
      Assert.IsEmpty(failures);
    },
  });
}

    /// noda_dart: whether the type has `(<type> x): <result>` [csName] (`IEquatable<T>` / `IComparable<T>`).
bool ImplementsGeneric(ApiType type, String csName, String result) {
  final pattern = RegExp(r'^\(' + RegExp.escape(type.name) + r' \w+\): ' + RegExp.escape(result) + r'$');
  return type.members.any((m) => m.csName == csName && !m.isStatic && m.signatures.any(pattern.hasMatch));
}

bool HasMember(ApiType type, String csName) => type.members.any((m) => m.csName == csName);
