// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/ZoneYearOffsetTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: (int) DayOfWeek.X is BclConversions.ToDayOfWeek(IsoDayOfWeek.X).

import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalInstant.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/TimeZones/TransitionMode.generated.dart';
import 'package:noda_dart/src/TimeZones/ZoneYearOffset.dart';
import 'package:noda_dart/src/Utility/BclConversions.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../helpers/TestHelper.dart';
import '../../scenarios/TimeZones/ZoneYearOffsetTest.generated.dart' as scenarios;
import 'IO/DtzIoHelper.dart';

void main() {
  port(scenarios.fixture, {
    'Construct_InvalidMonth_Exception': (args) {
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 0, 1, 1, true, LocalTime.Midnight), 'Month 0');
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 34, 1, 1, true, LocalTime.Midnight), 'Month 34');
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, -3, 1, 1, true, LocalTime.Midnight), 'Month -3');
    },

    'Construct_InvalidDayOfMonth_Exception': (args) {
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 2, 0, 1, true, LocalTime.Midnight), 'Day of Month 0');
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 2, 32, 1, true, LocalTime.Midnight), 'Day of Month 32');
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 2, 475, 1, true, LocalTime.Midnight),
        'Day of Month 475');
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 2, -32, 1, true, LocalTime.Midnight),
        'Day of Month -32');
    },

    'Construct_InvalidDayOfWeek_Exception': (args) {
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 2, 3, -1, true, LocalTime.Midnight), 'Day of Week -1');
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 2, 3, 8, true, LocalTime.Midnight), 'Day of Week 8');
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 2, 3, 5756, true, LocalTime.Midnight),
        'Day of Week 5856');
      Assert.Throws<RangeError>(() => ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 2, 3, -347, true, LocalTime.Midnight),
        'Day of Week -347');
    },

    'Construct_ValidMonths': (args) {
      for (int month = 1; month <= 12; month++) {
        Assert.NotNull(ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, month, 1, 1, true, LocalTime.Midnight), 'Month $month');
      }
    },

    'Construct_ValidDays': (args) {
      for (int day = 1; day <= 31; day++) {
        Assert.NotNull(ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 1, day, 1, true, LocalTime.Midnight), 'Day $day');
      }
      for (int day = -1; day >= -31; day--) {
        Assert.NotNull(ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 1, day, 1, true, LocalTime.Midnight), 'Day $day');
      }
    },

    'Construct_ValidDaysOfWeek': (args) {
      for (int dayOfWeek = 0; dayOfWeek <= 7; dayOfWeek++) {
        Assert.NotNull(ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Standard, 1, 1, dayOfWeek, true, LocalTime.Midnight), 'Day of week $dayOfWeek');
      }
    },

    'GetOccurrenceForYear_Defaults_Epoch': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(1970);
      var expected = LocalDateTime(1970, 1, 1, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_Year_1971': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(1971);
      var expected = LocalDateTime(1971, 1, 1, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_Milliseconds': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime(0, 0, 0, 1));
      var actual = offset.GetOccurrenceForYear(1970);
      var expected = LocalDateTime(1970, 1, 1, 0, 0, 0, 1).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_WednesdayForward': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, BclConversions.ToDayOfWeek(IsoDayOfWeek.Wednesday), true, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(1970);
      var expected = LocalDateTime(1970, 1, 7, 0, 0).ToLocalInstant(); // 1970-01-01 was a Thursday
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_WednesdayBackward': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 15, BclConversions.ToDayOfWeek(IsoDayOfWeek.Wednesday), false, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(1970);
      var expected = LocalDateTime(1970, 1, 14, 0, 0).ToLocalInstant(); // 1970-01-15 was a Thursday
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_JanMinusTwo': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, -2, 0, true, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(1970);
      var expected = LocalDateTime(1970, 1, 30, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_JanFive': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 5, 0, true, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(1970);
      var expected = LocalDateTime(1970, 1, 5, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_Feb': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 2, 1, 0, true, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(1970);
      var expected = LocalDateTime(1970, 2, 1, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_LastSundayInOctober': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, -1, IsoDayOfWeek.Sunday.value, false, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(1996);
      var expected = LocalDateTime(1996, 10, 27, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_ExactlyFeb29th_LeapYear': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 2, 29, 0, false, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(2012);
      var expected = LocalDateTime(2012, 2, 29, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_ExactlyFeb29th_NotLeapYear': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 2, 29, 0, false, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(2013);
      var expected = LocalDateTime(2013, 2, 28, 0, 0).ToLocalInstant(); // For 'exact', go to Feb 28th
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_AtLeastFeb29th_LeapYear': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 2, 29, IsoDayOfWeek.Sunday.value, true, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(2012);
      var expected = LocalDateTime(2012, 3, 4, 0, 0).ToLocalInstant(); // March 4th is the first Sunday after 2012-02-29
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_AtLeastFeb29th_NotLeapYear': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 2, 29, IsoDayOfWeek.Sunday.value, true, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(2013);
      var expected = LocalDateTime(2013, 3, 3, 0, 0).ToLocalInstant(); // March 3rd is the first Sunday after the non-existent 2013-02-29
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_AtMostFeb29th_LeapYear': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 2, 29, IsoDayOfWeek.Sunday.value, false, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(2012);
      var expected = LocalDateTime(2012, 2, 26, 0, 0).ToLocalInstant(); // Feb 26th is the last Sunday before 2012-02-29
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_AtMostFeb29th_NotLeapYear': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 2, 29, IsoDayOfWeek.Sunday.value, false, LocalTime.Midnight);
      var actual = offset.GetOccurrenceForYear(2013);
      var expected = LocalDateTime(2013, 2, 24, 0, 0).ToLocalInstant(); // Feb 24th is the last Sunday is February 2013
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_WithAddDay': (args) {
      // Last Thursday in October, then add 24 hours. The last Thursday in October 2013 is the 31st, so
      // we should get the start of November 1st.
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(TransitionMode.Utc, 10, -1, IsoDayOfWeek.Thursday.value, false, LocalTime.Midnight, true);
      var actual = offset.GetOccurrenceForYear(2013);
      var expected = LocalDateTime(2013, 11, 1, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'GetOccurrenceForYear_WithAddDay_December31st9999': (args) {
      var offset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(TransitionMode.Utc, 12, 31, 0, false, LocalTime.Midnight, true);
      var actual = offset.GetOccurrenceForYear(9999);
      var expected = LocalInstant.AfterMaxValue;
      Assert.AreEqual(expected, actual);
    },

    'Serialization': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();
      var expected = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday.value, true,
        LocalTime(12, 34, 45, 678));
      dio.TestZoneYearOffset(expected);

      dio.Reset();
      expected = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, -31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);
      dio.TestZoneYearOffset(expected);
    },

    'IEquatable_Tests': (args) {
      var value = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);
      var equalValue = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);
      var unequalValue = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 9, 31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);

      TestHelper.TestEqualsClass(value, equalValue, [unequalValue]);
    },
  });
}
