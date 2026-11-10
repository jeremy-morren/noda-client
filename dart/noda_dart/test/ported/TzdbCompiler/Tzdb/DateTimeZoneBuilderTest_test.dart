// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/Tzdb/DateTimeZoneBuilderTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/FixedDateTimeZone.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/DateTimeZoneBuilder.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/ZoneRuleSet.dart';
import 'package:noda_dart/src/Utility/Int64.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TzdbCompiler/Tzdb/DateTimeZoneBuilderTest.generated.dart' as scenarios;

/// Tests for DateTimeZoneBuilder; currently only scant coverage based on bugs which have
/// previously been found.
void main() {
  port(scenarios.fixture, {
    'FixedZone_Western': (args) {
      var offset = Offset.FromHours(-5);
      var rules = <ZoneRuleSet>[
        ZoneRuleSet.NewNameStandardOffsetSavingsUpperYearUpperYearOffset(
            'GMT+5', offset, Offset.Zero, Int64.Int32MaxValue, null)
      ];
      var zone = DateTimeZoneBuilder.Build('GMT+5', rules);
      FixedDateTimeZone fixedZone = zone as FixedDateTimeZone;
      Assert.AreEqual(offset, fixedZone.Offset);
    },

    'FixedZone_Eastern': (args) {
      var offset = Offset.FromHours(5);
      var rules = <ZoneRuleSet>[
        ZoneRuleSet.NewNameStandardOffsetSavingsUpperYearUpperYearOffset(
            'GMT-5', offset, Offset.Zero, Int64.Int32MaxValue, null)
      ];
      var zone = DateTimeZoneBuilder.Build('GMT-5', rules);
      FixedDateTimeZone fixedZone = zone as FixedDateTimeZone;
      Assert.AreEqual(offset, fixedZone.Offset);
    },
  });
}
