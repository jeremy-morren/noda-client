// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/CachedDateTimeZoneTest.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/CachedDateTimeZone.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/CachedDateTimeZoneTest.generated.dart' as scenarios;
import 'TzTestHelper.dart';

// Note that this tests CachingZoneIntervalMap as much as CachedDateTimeZone...
final CachedDateTimeZone timeZone = DateTimeZoneProviders.Tzdb['America/Los_Angeles'] as CachedDateTimeZone;
final Instant summer = Instant.FromUtc(2010, 6, 1, 0, 0);

void main() {
  port(scenarios.fixture, {
    'GetZoneIntervalInstant_NotNull': (args) {
      var actual = timeZone.GetZoneInterval(summer);
      Assert.IsNotNull(actual);
    },

    'GetZoneIntervalInstant_RepeatedCallsReturnSameObject': (args) {
      var actual = timeZone.GetZoneInterval(summer);
      for (int i = 0; i < 100; i++) {
        var newPeriod = timeZone.GetZoneInterval(summer);
        Assert.AreSame(actual, newPeriod);
      }
    },

    'GetZoneIntervalInstant_RepeatedCallsReturnSameObjectWithOthersInterspersed': (args) {
      var actual = timeZone.GetZoneInterval(summer);
      Assert.IsNotNull(timeZone.GetZoneInterval(NodaConstants.UnixEpoch));
      Assert.IsNotNull(timeZone.GetZoneInterval(NodaConstants.UnixEpoch + Duration.FromDays(2000 * 7)));
      Assert.IsNotNull(timeZone.GetZoneInterval(NodaConstants.UnixEpoch + Duration.FromDays(3000 * 7)));
      Assert.IsNotNull(timeZone.GetZoneInterval(NodaConstants.UnixEpoch + Duration.FromDays(4000 * 7)));
      var newPeriod = timeZone.GetZoneInterval(summer);
      Assert.AreSame(actual, newPeriod);
    },

    'MinMaxOffsets': (args) {
      Assert.AreEqual(timeZone.Uncached().MinOffset, timeZone.MinOffset);
      Assert.AreEqual(timeZone.Uncached().MaxOffset, timeZone.MaxOffset);
    },

    'ForZone_Fixed': (args) {
      var zone = DateTimeZone.ForOffset(Offset.FromHours(1));
      Assert.AreSame(zone, CachedDateTimeZone.ForZone(zone));
    },

    'ForZone_AlreadyCached': (args) {
      Assert.AreSame(timeZone, CachedDateTimeZone.ForZone(timeZone));
    },
  });
}
