// Ported from NodaTime 6e024dde: src/NodaTime.Test/Utility/BclConversionsTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: excluded by the generator; ported anyway. A DayOfWeek is its int value, so ToIsoDayOfWeek isn't ported.

import 'package:noda_dart/src/Extensions/IsoDayOfWeekExtensions.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/Utility/BclConversions.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Utility/BclConversionsTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    // This tests both directions for all valid values.
    // Alternatively, we could have checked names...
    // it doesn't matter much.
    'DayOfWeek_BothWaysValid': (args) {
      final [int bcl, IsoDayOfWeek noda] = args;
      Assert.AreEqual(bcl, BclConversions.ToDayOfWeek(noda));
      Assert.AreEqual(noda, BclConversions.ToIsoDayOfWeek(bcl));
      Assert.AreEqual(bcl, noda.ToDayOfWeek());
      // Not ported: Assert.AreEqual(noda, bcl.ToIsoDayOfWeek()) (DayOfWeekExtensions: Dart has no DayOfWeek type).
    },

    'ToDayOfWeek_InvalidValues': (args) {
      final [IsoDayOfWeek noda] = args;
      Assert.Throws<RangeError>(() => BclConversions.ToDayOfWeek(noda));
      Assert.Throws<RangeError>(() => noda.ToDayOfWeek());
    },

    'ToIsoDayOfWeek_InvalidValues': (args) {
      final [int bcl] = args;
      Assert.Throws<RangeError>(() => BclConversions.ToIsoDayOfWeek(bcl));
      // Not ported: bcl.ToIsoDayOfWeek() (Dart has no DayOfWeek type).
    },
  });
}
