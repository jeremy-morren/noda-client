// Ported from NodaTime 6e024dde: src/NodaTime.Test/LocalInstantTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalInstant.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Text/InstantPatternParser.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/LocalInstantTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'Equality': (args) {
      LocalInstant equal = LocalInstant.NewDaysNanoOfDay(1, 100);
      LocalInstant different1 = LocalInstant.NewDaysNanoOfDay(1, 200);
      LocalInstant different2 = LocalInstant.NewDaysNanoOfDay(2, 100);

      TestHelper.TestEqualsStruct(equal, equal, [different1]);
      TestHelper.TestOperatorEquality(equal, equal, different1);

      TestHelper.TestEqualsStruct(equal, equal, [different2]);
      TestHelper.TestOperatorEquality(equal, equal, different2);
    },

    'MinusOffset_Zero_IsNeutralElement': (args) {
      Instant sampleInstant = Instant.NewDaysNanoOfDay(1, 23456);
      LocalInstant sampleLocalInstant = LocalInstant.NewDaysNanoOfDay(1, 23456);
      Assert.AreEqual(sampleInstant, sampleLocalInstant.Minus(Offset.Zero));
      Assert.AreEqual(sampleInstant, sampleLocalInstant.MinusZeroOffset());
    },

    'ToString_Valid': (args) {
      final [int day, int nanoOfDay, String expectedText] = args;
      Assert.AreEqual(expectedText, LocalInstant.NewDaysNanoOfDay(day, nanoOfDay).toString());
    },

    'ToString_Extremes': (args) {
      Assert.AreEqual(InstantPatternParser.BeforeMinValueText, LocalInstant.BeforeMinValue.toString());
      Assert.AreEqual(InstantPatternParser.AfterMaxValueText, LocalInstant.AfterMaxValue.toString());
    },

    'SafeMinus_NormalTime': (args) {
      var start = LocalInstant.NewDaysNanoOfDay(0, 0);
      var end = start.SafeMinus(Offset.FromHours(1));
      Assert.AreEqual(Duration.FromHours(-1), end.TimeSinceEpoch);
    },

    // A null offset indicates "BeforeMinValue". Otherwise, MinValue.Plus(offset)
    'SafeMinus_NearStartOfTime': (args) {
      final [int? initialOffset, int offsetToSubtract, int? finalOffset] = args;
      var start = initialOffset == null
          ? LocalInstant.BeforeMinValue
          : Instant.MinValue.PlusOffset(Offset.FromHours(initialOffset));
      var expected = finalOffset == null
          ? Instant.BeforeMinValue
          : Instant.MinValue + Duration.FromHours(finalOffset);
      var actual = start.SafeMinus(Offset.FromHours(offsetToSubtract));
      Assert.AreEqual(expected, actual);
    },

    // A null offset indicates "AfterMaxValue". Otherwise, MaxValue.Plus(offset)
    'SafeMinus_NearEndOfTime': (args) {
      final [int? initialOffset, int offsetToSubtract, int? finalOffset] = args;
      var start = initialOffset == null
          ? LocalInstant.AfterMaxValue
          : Instant.MaxValue.PlusOffset(Offset.FromHours(initialOffset));
      var expected = finalOffset == null
          ? Instant.AfterMaxValue
          : Instant.MaxValue + Duration.FromHours(finalOffset);
      var actual = start.SafeMinus(Offset.FromHours(offsetToSubtract));
      Assert.AreEqual(expected, actual);
    },

    'IsValid': (args) {
      Assert.IsFalse(LocalInstant.BeforeMinValue.IsValid);
      Assert.IsTrue(LocalInstant.NewNanoseconds(Instant.MinValue - NodaConstants.UnixEpoch).IsValid);
      Assert.IsTrue(LocalInstant.NewNanoseconds(Instant.MaxValue - NodaConstants.UnixEpoch).IsValid);
      Assert.IsFalse(LocalInstant.AfterMaxValue.IsValid);
    },
  });
}
