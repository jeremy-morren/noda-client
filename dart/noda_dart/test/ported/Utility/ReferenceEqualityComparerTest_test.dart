// Ported from NodaTime 6e024dde: src/NodaTime.Test/Utility/ReferenceEqualityComparerTest.cs
// Copyright 2026 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: a new string instance is String.fromCharCodes; on dart2js strings have no identity.

import 'package:noda_dart/src/Utility/ReferenceEqualityComparer.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Utility/ReferenceEqualityComparerTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Equals': (args) {
      var instance = ReferenceEqualityComparer<String>();
      var s1 = 'test';
      var s2 = 'test';
      var s3 = String.fromCharCodes(s1.codeUnits);
      Assert.True(instance.Equals(s1, s2));
      // noda_dart: not on dart2js, where strings have no identity.
      if (!isDart2js) Assert.False(instance.Equals(s1, s3));
      Assert.True(instance.Equals(null, null));
    },

    'TestGetHashCode': (args) {
      var instance = ReferenceEqualityComparer<String>();
      var s1 = 'test';
      var s2 = 'test';
      // ignore: unused_local_variable
      var s3 = String.fromCharCodes(s1.codeUnits);
      Assert.AreEqual(instance.GetHashCode(s1), instance.GetHashCode(s2));
      // Not ported: the GetHashCode(s1) != GetHashCode(s3) check (a String's identityHashCode is its value's hash).
      Assert.AreEqual(0, instance.GetHashCode(null));
    },
  });
}
