// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/StandardDaylightAlternatingMapTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneReader.dart';
import 'package:noda_dart/src/TimeZones/IO/DateTimeZoneWriter.dart';
import 'package:noda_dart/src/TimeZones/PrecalculatedDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/StandardDaylightAlternatingMap.dart';
import 'package:noda_dart/src/TimeZones/TransitionMode.generated.dart';
import 'package:noda_dart/src/TimeZones/ZoneInterval.dart';
import 'package:noda_dart/src/TimeZones/ZoneLocalMapping.dart';
import 'package:noda_dart/src/TimeZones/ZoneRecurrence.dart';
import 'package:noda_dart/src/TimeZones/ZoneYearOffset.dart';
import 'package:noda_dart/src/Utility/Int64.dart';
import 'package:noda_dart/src/Utility/Stream.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../helpers/TestHelper.dart';
import '../../scenarios/TimeZones/StandardDaylightAlternatingMapTest.generated.dart' as scenarios;

final ZoneRecurrence Winter = ZoneRecurrence('Winter', Offset.Zero,
    ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 10, 5, 0, false, LocalTime(2, 0)), 2000, Int64.Int32MaxValue);

final ZoneRecurrence Summer = ZoneRecurrence('Summer', Offset.FromHours(1),
    ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 10, 0, false, LocalTime(1, 0)), 2000, Int64.Int32MaxValue);

/// Time zone with the following characteristics:
/// - Only valid from March 10th 2000
/// - Standard offset of +5 (so 4am UTC = 9am local)
/// - Summer time (DST = 1 hour) always starts at 1am local time on March 10th (skips to 2am)
/// - Winter time (DST = 0) always starts at 2am local time on October 5th (skips to 1am)
final StandardDaylightAlternatingMap TestMap =
    StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.FromHours(5), Winter, Summer);

final DateTimeZone TestZone =
    PrecalculatedDateTimeZone.NewIdIntervalsTailZone(
        'zone',
        [ZoneInterval('Before', Instant.BeforeMinValue, Instant.FromUtc(1999, 12, 1, 0, 0), Offset.FromHours(5), Summer.Savings)],
        StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.FromHours(5), Winter, Summer));

void main() {
  port(scenarios.fixture, {
    'MinMaxOffsets': (args) {
      Assert.AreEqual(Offset.FromHours(6), TestMap.MaxOffset);
      Assert.AreEqual(Offset.FromHours(5), TestMap.MinOffset);
    },

    'GetZoneInterval_Instant_Summer': (args) {
      var interval = TestMap.GetZoneInterval(Instant.FromUtc(2010, 6, 1, 0, 0));
      Assert.AreEqual('Summer', interval.Name);
      Assert.AreEqual(Offset.FromHours(6), interval.WallOffset);
      Assert.AreEqual(Offset.FromHours(5), interval.StandardOffset);
      Assert.AreEqual(Offset.FromHours(1), interval.Savings);
      Assert.AreEqual(LocalDateTime(2010, 3, 10, 2, 0), interval.IsoLocalStart);
      Assert.AreEqual(LocalDateTime(2010, 10, 5, 2, 0), interval.IsoLocalEnd);
    },

    'GetZoneInterval_Instant_Winter': (args) {
      var interval = TestMap.GetZoneInterval(Instant.FromUtc(2010, 11, 1, 0, 0));
      Assert.AreEqual('Winter', interval.Name);
      Assert.AreEqual(Offset.FromHours(5), interval.WallOffset);
      Assert.AreEqual(Offset.FromHours(5), interval.StandardOffset);
      Assert.AreEqual(Offset.FromHours(0), interval.Savings);
      Assert.AreEqual(LocalDateTime(2010, 10, 5, 1, 0), interval.IsoLocalStart);
      Assert.AreEqual(LocalDateTime(2011, 3, 10, 1, 0), interval.IsoLocalEnd);
    },

    'GetZoneInterval_Instant_StartOfFirstSummer': (args) {
      // This is only just about valid
      var firstSummer = Instant.FromUtc(2000, 3, 9, 20, 0);
      var interval = TestMap.GetZoneInterval(firstSummer);
      Assert.AreEqual('Summer', interval.Name);
    },

    'MapLocal_WithinFirstSummer': (args) {
      var early = LocalDateTime(2000, 6, 1, 0, 0);
      CheckMapping(TestZone.MapLocal(early), 'Summer', 'Summer', 1);
    },

    'MapLocal_WithinFirstWinter': (args) {
      var winter = LocalDateTime(2000, 12, 1, 0, 0);
      CheckMapping(TestZone.MapLocal(winter), 'Winter', 'Winter', 1);
    },

    'MapLocal_AtFirstGapStart': (args) {
      var startOfFirstGap = LocalDateTime(2000, 3, 10, 1, 0);
      CheckMapping(TestZone.MapLocal(startOfFirstGap), 'Winter', 'Summer', 0);
    },

    'MapLocal_WithinFirstGap': (args) {
      var middleOfFirstGap = LocalDateTime(2000, 3, 10, 1, 30);
      CheckMapping(TestZone.MapLocal(middleOfFirstGap), 'Winter', 'Summer', 0);
    },

    'MapLocal_EndOfFirstGap': (args) {
      var endOfFirstGap = LocalDateTime(2000, 3, 10, 2, 0);
      CheckMapping(TestZone.MapLocal(endOfFirstGap), 'Summer', 'Summer', 1);
    },

    'MapLocal_StartOfFirstAmbiguity': (args) {
      var firstAmbiguity = LocalDateTime(2000, 10, 5, 1, 0);
      CheckMapping(TestZone.MapLocal(firstAmbiguity), 'Summer', 'Winter', 2);
    },

    'MapLocal_MiddleOfFirstAmbiguity': (args) {
      var firstAmbiguity = LocalDateTime(2000, 10, 5, 1, 30);
      CheckMapping(TestZone.MapLocal(firstAmbiguity), 'Summer', 'Winter', 2);
    },

    'MapLocal_AfterFirstAmbiguity': (args) {
      var unambiguousWinter = LocalDateTime(2000, 10, 5, 2, 0);
      CheckMapping(TestZone.MapLocal(unambiguousWinter), 'Winter', 'Winter', 1);
    },

    'MapLocal_WithinArbitrarySummer': (args) {
      var summer = LocalDateTime(2010, 6, 1, 0, 0);
      CheckMapping(TestZone.MapLocal(summer), 'Summer', 'Summer', 1);
    },

    'MapLocal_WithinArbitraryWinter': (args) {
      var winter = LocalDateTime(2010, 12, 1, 0, 0);
      CheckMapping(TestZone.MapLocal(winter), 'Winter', 'Winter', 1);
    },

    'MapLocal_AtArbitraryGapStart': (args) {
      var startOfGap = LocalDateTime(2010, 3, 10, 1, 0);
      CheckMapping(TestZone.MapLocal(startOfGap), 'Winter', 'Summer', 0);
    },

    'MapLocal_WithinArbitraryGap': (args) {
      var middleOfGap = LocalDateTime(2010, 3, 10, 1, 30);
      CheckMapping(TestZone.MapLocal(middleOfGap), 'Winter', 'Summer', 0);
    },

    'MapLocal_EndOfArbitraryGap': (args) {
      var endOfGap = LocalDateTime(2010, 3, 10, 2, 0);
      CheckMapping(TestZone.MapLocal(endOfGap), 'Summer', 'Summer', 1);
    },

    'MapLocal_StartOfArbitraryAmbiguity': (args) {
      var ambiguity = LocalDateTime(2010, 10, 5, 1, 0);
      CheckMapping(TestZone.MapLocal(ambiguity), 'Summer', 'Winter', 2);
    },

    'MapLocal_MiddleOfArbitraryAmbiguity': (args) {
      var ambiguity = LocalDateTime(2010, 10, 5, 1, 30);
      CheckMapping(TestZone.MapLocal(ambiguity), 'Summer', 'Winter', 2);
    },

    'MapLocal_AfterArbitraryAmbiguity': (args) {
      var unambiguousWinter = LocalDateTime(2010, 10, 5, 2, 0);
      CheckMapping(TestZone.MapLocal(unambiguousWinter), 'Winter', 'Winter', 1);
    },

    'Equality': (args) {
      // Order of recurrences doesn't matter
      var map1 = StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.FromHours(1), Summer, Winter);
      var map2 = StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.FromHours(1), Winter, Summer);
      var map3 = StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.FromHours(1), Winter,
          // Summer, but starting from 1900
          ZoneRecurrence('Summer', Offset.FromHours(1),
              ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 10, 0, false, LocalTime(1, 0)), 1900, Int64.Int32MaxValue));
      // Standard offset does matter
      var map4 = StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.FromHours(0), Summer, Winter);

      TestHelper.TestEqualsClass(map1, map2, [map4]);
      TestHelper.TestEqualsClass(map1, map3, [map4]);

      // Recurrences like Summer, but different in one aspect each, *except* (comment incomplete for years...)
      var unequalMaps = [
        ZoneRecurrence('Different name', Offset.FromHours(1),
            ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 10, 0, false, LocalTime(1, 0)), 2000, Int64.Int32MaxValue),
        ZoneRecurrence('Summer', Offset.FromHours(2),
            ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 10, 0, false, LocalTime(1, 0)), 2000, Int64.Int32MaxValue),
        ZoneRecurrence('Summer', Offset.FromHours(1),
            ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 3, 10, 0, false, LocalTime(1, 0)), 2000, Int64.Int32MaxValue),
        ZoneRecurrence('Summer', Offset.FromHours(1),
            ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 4, 10, 0, false, LocalTime(1, 0)), 2000, Int64.Int32MaxValue),
        ZoneRecurrence('Summer', Offset.FromHours(1),
            ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 9, 0, false, LocalTime(1, 0)), 2000, Int64.Int32MaxValue),
        ZoneRecurrence('Summer', Offset.FromHours(1),
            ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 10, 1, false, LocalTime(1, 0)), 2000, Int64.Int32MaxValue),
        // Advance with day-of-week 0 doesn't make any real difference, but they compare non-equal...
        ZoneRecurrence('Summer', Offset.FromHours(1),
            ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 10, 0, true, LocalTime(1, 0)), 2000, Int64.Int32MaxValue),
        ZoneRecurrence('Summer', Offset.FromHours(1),
            ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 10, 0, false, LocalTime(2, 0)), 2000, Int64.Int32MaxValue)
      ].map((recurrence) => StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.FromHours(1), Winter, recurrence)).toList();
      TestHelper.TestEqualsClass(map1, map2, unequalMaps);
    },

    'ReadWrite': (args) {
      var map1 = StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.FromHours(1), Summer, Winter);
      var stream = MemoryStream();
      var writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
      map1.Write(writer);
      stream.Position = 0;

      var reader = DateTimeZoneReader.NewInputStringPool(stream, null);
      var map2 = StandardDaylightAlternatingMap.Read(reader);
      Assert.AreEqual(map1, map2);
    },

    'Extremes': (args) {
      ZoneRecurrence winter = ZoneRecurrence('Winter', Offset.Zero,
          ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 10, 5, 0, false, LocalTime(2, 0)), Int64.Int32MinValue, Int64.Int32MaxValue);

      ZoneRecurrence summer = ZoneRecurrence('Summer', Offset.FromHours(1),
          ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 10, 0, false, LocalTime(1, 0)), Int64.Int32MinValue, Int64.Int32MaxValue);

      var zone = StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.Zero, winter, summer);

      var firstSpring = Instant.FromUtc(-9998, 3, 10, 1, 0);
      var firstAutumn = Instant.FromUtc(-9998, 10, 5, 1, 0); // 1am UTC = 2am wall

      var lastSpring = Instant.FromUtc(9999, 3, 10, 1, 0);
      var lastAutumn = Instant.FromUtc(9999, 10, 5, 1, 0); // 1am UTC = 2am wall

      var dstOffset = Offset.FromHours(1);

      // Check both year -9998 and 9999, both the infinite interval and the next one in
      var firstWinter = ZoneInterval('Winter', Instant.BeforeMinValue, firstSpring, Offset.Zero, Offset.Zero);
      var firstSummer = ZoneInterval('Summer', firstSpring, firstAutumn, dstOffset, dstOffset);
      var lastSummer = ZoneInterval('Summer', lastSpring, lastAutumn, dstOffset, dstOffset);
      var lastWinter = ZoneInterval('Winter', lastAutumn, Instant.AfterMaxValue, Offset.Zero, Offset.Zero);

      Assert.AreEqual(firstWinter, zone.GetZoneInterval(Instant.MinValue));
      Assert.AreEqual(firstWinter, zone.GetZoneInterval(Instant.FromUtc(-9998, 2, 1, 0, 0)));
      Assert.AreEqual(firstSummer, zone.GetZoneInterval(firstSpring));
      Assert.AreEqual(firstSummer, zone.GetZoneInterval(Instant.FromUtc(-9998, 5, 1, 0, 0)));

      Assert.AreEqual(lastSummer, zone.GetZoneInterval(lastSpring));
      Assert.AreEqual(lastSummer, zone.GetZoneInterval(Instant.FromUtc(9999, 5, 1, 0, 0)));
      Assert.AreEqual(lastWinter, zone.GetZoneInterval(lastAutumn));
      Assert.AreEqual(lastWinter, zone.GetZoneInterval(Instant.FromUtc(9999, 11, 1, 0, 0)));
      Assert.AreEqual(lastWinter, zone.GetZoneInterval(Instant.MaxValue));
    },

    'InvalidMap_SimultaneousTransition': (args) {
      // Two recurrences with different savings, but which occur at the same instant in time every year.
      ZoneRecurrence r1 = ZoneRecurrence('Recurrence1', Offset.Zero,
          ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 5, 0, false, LocalTime(2, 0)), Int64.Int32MinValue, Int64.Int32MaxValue);

      ZoneRecurrence r2 = ZoneRecurrence('Recurrence2', Offset.FromHours(1),
          ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 5, 0, false, LocalTime(2, 0)), Int64.Int32MinValue, Int64.Int32MaxValue);

      var map = StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(Offset.Zero, r1, r2);

      Assert.Throws<StateError>(() => map.GetZoneInterval(Instant.FromUtc(2017, 8, 25, 0, 0, 0)));
    },
  });
}

void CheckMapping(ZoneLocalMapping mapping, String earlyIntervalName, String lateIntervalName, int count) {
  Assert.AreEqual(earlyIntervalName, mapping.EarlyInterval.Name);
  Assert.AreEqual(lateIntervalName, mapping.LateInterval.Name);
  Assert.AreEqual(count, mapping.Count);
}
