// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/BclDateTimeZoneTest.cs (+ BclDateTimeZoneTest.LinuxAdjustmentRules.cs)
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: BclDateTimeZone is SystemDateTimeZone. The every-host-zone tests are excluded (test/system compares with
// .NET instead); TransitionAtMidnight reads a fake registry. LinuxAdjustmentRules isn't ported (we read TZif).

import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/System/DateTime.dart';
import 'package:noda_dart/src/System/TimeZoneInfo.AdjustmentRule.dart';
import 'package:noda_dart/src/System/TimeZoneInfo.TransitionTime.dart';
import 'package:noda_dart/src/System/TimeZoneInfo.dart';
import 'package:noda_dart/src/TimeZones/SystemDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/TimeZoneInfoInterceptor.dart';
import 'package:noda_dart/src/TimeZones/ZoneInterval.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/FakeWindowsTimeZoneApi.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/BclDateTimeZoneTest.LinuxAdjustmentRules.generated.dart' as linux_scenarios;
import '../../scenarios/TimeZones/BclDateTimeZoneTest.generated.dart' as scenarios;
import 'TimeZoneInfoReplacer.dart';

/// TimeSpan.FromHours, as ticks.
int _FromHours(int hours) => hours * TimeSpanTicks.PerHour;

void main() {
  port(scenarios.fixture, {
    'ForSystemDefault': (args) {
      // Assume that the local time zone doesn't change between two calls...
      // noda_dart: without TimeZoneInfo (TZif files, Intl), the zones have no OriginalZone.
      TimeZoneInfo? local = TimeZoneInfoInterceptor.Shim == null ? null : TimeZoneInfoInterceptor.Local;
      SystemDateTimeZone nodaLocal1 = SystemDateTimeZone.ForSystemDefault();
      SystemDateTimeZone nodaLocal2 = SystemDateTimeZone.ForSystemDefault();
      // Check it's actually the right zone
      Assert.AreSame(local, nodaLocal1.OriginalZone);
      // Check it's cached
      Assert.AreSame(nodaLocal1, nodaLocal2);
    },

    'DateTimeMinValueStartRuleExtendsToBeginningOfTime': (args) {
      // .NET Core on Unix loses data from rules provided to CreateCustomTimeZone :(
      // (It assumes the rules have been created from tzif files, which isn't the case here.)
      // See https://github.com/dotnet/corefx/issues/29912
      // noda_dart: (Ignore.When(TestHelper.IsRunningOnDotNetCoreUnix, ...): never.)

      var rules = [
        // Rule for the whole of time, with DST of 1 hour commencing on March 1st
        // and ending on September 1st.
        TimeZoneInfoAdjustmentRule.CreateAdjustmentRule(
            DateTime.MinValue,
            DateTime.MaxValue.Date,
            _FromHours(1),
            TimeZoneInfoTransitionTime.CreateFixedDateRule(DateTime.MinValue, 3, 1),
            TimeZoneInfoTransitionTime.CreateFixedDateRule(DateTime.MinValue, 9, 1))
      ];
      var bclZone = TimeZoneInfo.CreateCustomTimeZone('custom', 0, 'DisplayName', 'Standard', 'Daylight', rules);
      var nodaZone = SystemDateTimeZone.FromTimeZoneInfo(bclZone);
      // Standard time in February BC 101
      Assert.AreEqual(Offset.Zero, nodaZone.GetUtcOffset(Instant.FromUtc(-100, 2, 1, 0, 0)));
      // Daylight time in July BC 101
      Assert.AreEqual(Offset.FromHours(1), nodaZone.GetUtcOffset(Instant.FromUtc(-100, 7, 1, 0, 0)));
      // Standard time in October BC 101
      Assert.AreEqual(Offset.Zero, nodaZone.GetUtcOffset(Instant.FromUtc(-100, 10, 1, 0, 0)));
    },

    'AwkwardLeapYears': (args) {
      // This mimics the data on Mono on Linux for Europe/Malta, where there's a BCL adjustment rule for
      // each rule for quite a long time. One of those years is 1948, and the daylight transition is February
      // 29th. That then fails when we try to build a ZoneInterval at the end of that year.
      // See https://github.com/nodatime/nodatime/issues/743 for more details. We've simplified this to just
      // a single rule here...

      // Amusingly, trying to reproduce the test on Mono with a custom time zone causes Mono to throw -
      // quite possibly due to the same root cause that we're testing we've fixed in Noda Time.
      // See https://bugzilla.xamarin.com/attachment.cgi?id=21192&action=edit
      // noda_dart: (Ignore.When(TestHelper.IsRunningOnMono, ...): never.)

      // .NET Core on Unix loses data from rules provided to CreateCustomTimeZone :(
      // (It assumes the rules have been created from tzif files, which isn't the case here.)
      // noda_dart: (Ignore.When(TestHelper.IsRunningOnDotNetCoreUnix, ...): never.)

      var rules = [
        TimeZoneInfoAdjustmentRule.CreateAdjustmentRule(
            /* dateStart: */ DateTime.Create(1948, 1, 1),
            /* dateEnd: */ DateTime.Create(1949, 1, 1).AddDays(-1),
            /* daylightDelta: */ _FromHours(1),
            /* daylightTransitionStart: */ TimeZoneInfoTransitionTime.CreateFixedDateRule(
                /* timeOfDay: */ DateTime.Create(1, 1, 1, 2, 0, 0), /* month: */ 2, /* day: */ 29),
            /* daylightTransitionEnd: */ TimeZoneInfoTransitionTime.CreateFixedDateRule(
                /* timeOfDay: */ DateTime.Create(1, 1, 1, 3, 0, 0), /* month: */ 10, /* day: */ 3))
      ];

      var bclZone = TimeZoneInfo.CreateCustomTimeZone('Europe/Malta', 0, 'Malta', 'Standard', 'Daylight', rules);
      var nodaZone = SystemDateTimeZone.FromTimeZoneInfo(bclZone);

      var expectedTransition1 = Instant.FromUtc(1948, 2, 29, 2, 0, 0);
      var expectedTransition2 = Instant.FromUtc(1948, 10, 3, 2, 0, 0); // 3am local time

      var zoneIntervalBefore = nodaZone.GetZoneInterval(Instant.FromUtc(1947, 1, 1, 0, 0));
      Assert.AreEqual(ZoneInterval('Standard', Instant.BeforeMinValue, expectedTransition1, Offset.Zero, Offset.Zero),
          zoneIntervalBefore);

      var daylightZoneInterval = nodaZone.GetZoneInterval(Instant.FromUtc(1948, 6, 1, 0, 0));
      Assert.AreEqual(
          ZoneInterval('Daylight', expectedTransition1, expectedTransition2, Offset.FromHours(1), Offset.FromHours(1)),
          daylightZoneInterval);

      var zoneIntervalAfter = nodaZone.GetZoneInterval(Instant.FromUtc(1949, 1, 1, 0, 0));
      Assert.AreEqual(ZoneInterval('Standard', expectedTransition2, Instant.AfterMaxValue, Offset.Zero, Offset.Zero),
          zoneIntervalAfter);
    },

    'LocalZoneIsNull': (args) {
      var systemZone = TimeZoneInfo.CreateCustomTimeZone('Normal zone', 0, 'Display', 'Standard');
      var replacer = TimeZoneInfoReplacer.Replace(null, [systemZone]);
      try {
        Assert.Throws<StateError>(() => SystemDateTimeZone.ForSystemDefault());
      } finally {
        replacer.Dispose();
      }
    },

    'FakeDaylightSavingTime': (args) {
      // .NET Core on Unix loses data from rules provided to CreateCustomTimeZone :(
      // (It assumes the rules have been created from tzif files, which isn't the case here.)
      // noda_dart: (Ignore.When(TestHelper.IsRunningOnDotNetCoreUnix, ...): never.)

      // Linux time zones on Mono can have a strange situation with a "0 savings" adjustment rule to represent
      // "we want to change standard time but we can't".
      // See https://github.com/nodatime/nodatime/issues/746
      // Normally the odd rule would only be in place for a year, but it's simplest to just make it all the time.
      // We go into daylight savings at midday on March 10th, and out again at midday on September 25.

      // We should be able to use DateTime.MaxValue for dateEnd, but not in .NET 4.5 apparently.
      var rule = TimeZoneInfoAdjustmentRule.CreateAdjustmentRule(DateTime.MinValue, DateTime.Create(9999, 12, 31), 0,
          TimeZoneInfoTransitionTime.CreateFixedDateRule(DateTime.Create(1, 1, 1, 12, 0, 0), 3, 10),
          TimeZoneInfoTransitionTime.CreateFixedDateRule(DateTime.Create(1, 1, 1, 12, 0, 0), 9, 25));
      var bclZone = TimeZoneInfo.CreateCustomTimeZone('Nasty', _FromHours(4), 'Display', 'Standard', 'Daylight', [rule]);
      var nodaZone = SystemDateTimeZone.FromTimeZoneInfo(bclZone);
      var winterInterval = nodaZone.GetZoneInterval(Instant.FromUtc(2017, 2, 1, 0, 0));
      var summerInterval = nodaZone.GetZoneInterval(Instant.FromUtc(2017, 6, 1, 0, 0));

      var expectedWinter = ZoneInterval('Standard', Instant.FromUtc(2016, 9, 25, 8, 0), Instant.FromUtc(2017, 3, 10, 8, 0),
          Offset.FromHours(4), Offset.Zero);
      var expectedSummer = ZoneInterval('Daylight', Instant.FromUtc(2017, 3, 10, 8, 0), Instant.FromUtc(2017, 9, 25, 8, 0),
          Offset.FromHours(4), Offset.FromHours(1));

      Assert.AreEqual(expectedWinter, winterInterval);
      Assert.AreEqual(expectedSummer, summerInterval);
    },

    // See https://github.com/nodatime/nodatime/issues/1524 for the background
    // It would be nice to test earlier dates (e.g. 1967 and 1998) where transitions
    // actually occurred on the first of the "next month", but the Windows database has very different
    // data from TZDB in those cases.
    'TransitionAtMidnight': (args) {
      var bclZone = GetBclZoneOrIgnore('E. South America Standard Time');
      var nodaTzdbZone = DateTimeZoneProviders.Tzdb['America/Sao_Paulo'];
      var nodaBclZone = SystemDateTimeZone.FromTimeZoneInfo(bclZone);

      // Brazil in 2012:
      // Fall back from -02:00 to -03:00 at midnight on February 26th
      var expectedFallBack = Instant.FromUtc(2012, 2, 26, 2, 0, 0);
      // Spring forward from -03:00 to -02:00 at midnight on October 21st
      var expectedSpringForward = Instant.FromUtc(2012, 10, 21, 3, 0, 0);
      // This is an arbitrary instant between the fall back and spring forward.
      var betweenTransitions = Instant.FromUtc(2012, 6, 1, 0, 0, 0);

      // Check that these transitions are as expected when we use TZDB.
      var nodaTzdbInterval = nodaTzdbZone.GetZoneInterval(betweenTransitions);
      Assert.AreEqual(expectedFallBack, nodaTzdbInterval.Start);
      Assert.AreEqual(expectedSpringForward, nodaTzdbInterval.End);

      // Check that the real BCL time zone behaves as reported in the issue: the transitions occur one millisecond early
      // Not ported: the UTC-kind GetUtcOffset assertions (our TimeZoneInfo handles Unspecified only).

      // Assert that Noda Time accounts for the Windows time zone data weirdness, and corrects it to
      // a transition at midnight.
      var nodaBclInterval = nodaBclZone.GetZoneInterval(betweenTransitions);
      Assert.AreEqual(nodaTzdbInterval.Start, nodaBclInterval.Start);
      Assert.AreEqual(nodaTzdbInterval.End, nodaBclInterval.End);

      // Finally check the use case that was actually reported
      var actualStartOfDayAfterSpringForward = nodaBclZone.AtStartOfDay(LocalDate(2012, 10, 21));
      var expectedStartOfDayAfterSpringForward = LocalDateTime(2012, 10, 21, 1, 0, 0).InZoneStrictly(nodaBclZone);
      Assert.AreEqual(expectedStartOfDayAfterSpringForward, actualStartOfDayAfterSpringForward);
    },
  });

  // BclDateTimeZoneTest.LinuxAdjustmentRules: excluded by the generator (see the file comment).
  port(linux_scenarios.fixture, {});
}

/// noda_dart: the zones of a fake Windows registry (FakeWindowsTimeZoneApi.dart).
TimeZoneInfo GetBclZoneOrIgnore(String systemTimeZoneId) {
  for (final z in FakeWindowsTimeZoneApi(FakeZones).CreateShim().GetSystemTimeZones()) {
    if (z.Id == systemTimeZoneId) {
      return z;
    }
  }
  Assert.Ignore('Time zone $systemTimeZoneId not found');
}
