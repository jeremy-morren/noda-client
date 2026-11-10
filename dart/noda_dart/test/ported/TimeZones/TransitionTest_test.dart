// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/TransitionTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/Transition.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../helpers/TestHelper.dart';
import '../../scenarios/TimeZones/TransitionTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Equality': (args) {
      var equal1 = Transition.NewInstantNewOffset(Instant.FromUnixTimeSeconds(100), Offset.FromHours(1));
      var equal2 = Transition.NewInstantNewOffset(Instant.FromUnixTimeSeconds(100), Offset.FromHours(1));
      var unequal1 = Transition.NewInstantNewOffset(Instant.FromUnixTimeSeconds(101), Offset.FromHours(1));
      var unequal2 = Transition.NewInstantNewOffset(Instant.FromUnixTimeSeconds(100), Offset.FromHours(2));
      TestHelper.TestEqualsStruct(equal1, equal2, [unequal1]);
      TestHelper.TestEqualsStruct(equal1, equal2, [unequal2]);
      TestHelper.TestOperatorEquality(equal1, equal2, unequal1);
      TestHelper.TestOperatorEquality(equal1, equal2, unequal2);
    },

    'TransitionToString': (args) {
      var transition = Transition.NewInstantNewOffset(Instant.FromUtc(2017, 8, 25, 15, 26, 30), Offset.FromHours(1));
      Assert.AreEqual('Transition to +01 at 2017-08-25T15:26:30Z', transition.toString());
    },
  });
}
