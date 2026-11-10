// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/ZoneRecurrenceTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: Transition is a class, so C#'s `.Value` disappears.

import 'package:noda_dart/src/Calendars/GregorianYearMonthDayCalculator.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/TimeZones/Transition.dart';
import 'package:noda_dart/src/TimeZones/TransitionMode.generated.dart';
import 'package:noda_dart/src/TimeZones/ZoneRecurrence.dart';
import 'package:noda_dart/src/TimeZones/ZoneYearOffset.dart';
import 'package:noda_dart/src/Utility/Int64.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../helpers/TestHelper.dart';
import '../../scenarios/TimeZones/ZoneRecurrenceTest.generated.dart' as scenarios;
import 'IO/DtzIoHelper.dart';

void main() {
  port(scenarios.fixture, {
    'Next_BeforeFirstYear': (args) {
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1972);
      Transition? actual = recurrence.Next(Instant.MinValue, Offset.Zero, Offset.Zero);
      Transition? expected = Transition.NewInstantNewOffset(NodaConstants.UnixEpoch, Offset.Zero);
      Assert.AreEqual(expected, actual);
    },

    'Next_FirstYear': (args) {
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1972);
      Transition? actual = recurrence.Next(NodaConstants.UnixEpoch, Offset.Zero, Offset.Zero);
      Transition? expected = Transition.NewInstantNewOffset(Instant.FromUtc(1971, 1, 1, 0, 0), Offset.Zero);
      Assert.AreEqual(expected, actual);
    },

    'NextTwice_FirstYear': (args) {
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1972);
      Transition? actual = recurrence.Next(NodaConstants.UnixEpoch, Offset.Zero, Offset.Zero);
      actual = recurrence.Next(actual!.Instant, Offset.Zero, Offset.Zero);
      Transition? expected = Transition.NewInstantNewOffset(Instant.FromUtc(1972, 1, 1, 0, 0), Offset.Zero);
      Assert.AreEqual(expected, actual);
    },

    'Next_BeyondLastYear_null': (args) {
      var afterRecurrenceEnd = Instant.FromUtc(1980, 1, 1, 0, 0);
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1972);
      Transition? actual = recurrence.Next(afterRecurrenceEnd, Offset.Zero, Offset.Zero);
      Transition? expected;
      Assert.AreEqual(expected, actual);
    },

    'PreviousOrSame_AfterLastYear': (args) {
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1972);
      Transition? actual = recurrence.PreviousOrSame(Instant.MaxValue, Offset.Zero, Offset.Zero);
      Transition? expected = Transition.NewInstantNewOffset(Instant.FromUtc(1972, 1, 1, 0, 0), Offset.Zero);
      Assert.AreEqual(expected, actual);
    },

    'PreviousOrSame_LastYear': (args) {
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1972);
      Transition? actual = recurrence.PreviousOrSame(Instant.FromUtc(1971, 1, 1, 0, 0).MinusDuration(Duration.Epsilon), Offset.Zero, Offset.Zero);
      Transition? expected = Transition.NewInstantNewOffset(NodaConstants.UnixEpoch, Offset.Zero);
      Assert.AreEqual(expected, actual);
    },

    'PreviousOrSameTwice_LastYear': (args) {
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1973);
      Transition? actual = recurrence.PreviousOrSame(Instant.FromUtc(1972, 1, 1, 0, 0).MinusDuration(Duration.Epsilon), Offset.Zero, Offset.Zero);
      actual = recurrence.PreviousOrSame(actual!.Instant.MinusDuration(Duration.Epsilon), Offset.Zero, Offset.Zero);
      Transition? expected = Transition.NewInstantNewOffset(NodaConstants.UnixEpoch, Offset.Zero);
      Assert.AreEqual(expected, actual);
    },

    'PreviousOrSame_OnFirstYear_null': (args) {
      // Transition is on January 2nd, but we're asking for January 1st.
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 2, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1972);
      Transition? actual = recurrence.PreviousOrSame(NodaConstants.UnixEpoch, Offset.Zero, Offset.Zero);
      Transition? expected;
      Assert.AreEqual(expected, actual);
    },

    'PreviousOrSame_BeforeFirstYear_null': (args) {
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1972);
      Transition? actual = recurrence.PreviousOrSame(NodaConstants.UnixEpoch.MinusDuration(Duration.Epsilon), Offset.Zero, Offset.Zero);
      Transition? expected;
      Assert.AreEqual(expected, actual);
    },

    'Next_ExcludesGivenInstant': (args) {
      var january10thMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 10, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('x', Offset.Zero, january10thMidnight, 2000, 3000);
      var transition = Instant.FromUtc(2500, 1, 10, 0, 0);
      var next = recurrence.Next(transition, Offset.Zero, Offset.Zero);
      Assert.AreEqual(2501, next!.Instant.InUtc().Year);
    },

    'PreviousOrSame_IncludesGivenInstant': (args) {
      var january10thMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 10, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('x', Offset.Zero, january10thMidnight, 2000, 3000);
      var transition = Instant.FromUtc(2500, 1, 10, 0, 0);
      var next = recurrence.PreviousOrSame(transition, Offset.Zero, Offset.Zero);
      Assert.AreEqual(transition, next!.Instant);
    },

    'NextOrFail_Fail': (args) {
      var afterRecurrenceEnd = Instant.FromUtc(1980, 1, 1, 0, 0);
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1972);
      Assert.Throws<StateError>(() => recurrence.NextOrFail(afterRecurrenceEnd, Offset.Zero, Offset.Zero));
    },

    'PreviousOrSameOrFail_Fail': (args) {
      var beforeRecurrenceStart = Instant.FromUtc(1960, 1, 1, 0, 0);
      var januaryFirstMidnight = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 1, 1, 0, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('bob', Offset.Zero, januaryFirstMidnight, 1970, 1972);
      Assert.Throws<StateError>(() => recurrence.PreviousOrSameOrFail(beforeRecurrenceStart, Offset.Zero, Offset.Zero));
    },

    'Serialization': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();
      var yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);
      var expected = ZoneRecurrence('bob', Offset.Zero, yearOffset, 1971, 2009);
      dio.TestZoneRecurrence(expected);
    },

    'Serialization_Infinite': (args) {
      var dio = DtzIoHelper.CreateNoStringPool();
      var yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);
      var expected = ZoneRecurrence('bob', Offset.Zero, yearOffset, Int64.Int32MinValue, Int64.Int32MaxValue);
      dio.TestZoneRecurrence(expected);
    },

    'IEquatable_Tests': (args) {
      var yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);

      var value = ZoneRecurrence('bob', Offset.Zero, yearOffset, 1971, 2009);
      var equalValue = ZoneRecurrence('bob', Offset.Zero, yearOffset, 1971, 2009);
      var unequalValue = ZoneRecurrence('foo', Offset.Zero, yearOffset, 1971, 2009);

      TestHelper.TestEqualsClass(value, equalValue, [unequalValue]);
    },

    'December31st2400_MaxYear_UtcTransition': (args) {
      // Each year, the transition is at the midnight at the *end* of December 31st...
      var yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(TransitionMode.Utc, 12, 31, 0, true, LocalTime.Midnight, true);
      // ... and the recurrence is valid for the whole of time
      var recurrence = ZoneRecurrence('awkward', Offset.FromHours(1), yearOffset, GregorianYearMonthDayCalculator.MinGregorianYear, GregorianYearMonthDayCalculator.MaxGregorianYear);

      var next = recurrence.Next(Instant.FromUtc(9999, 6, 1, 0, 0), Offset.Zero, Offset.Zero);
      Assert.AreEqual(Instant.AfterMaxValue, next!.Instant);
    },

    'December31st2400_AskAtNanoBeforeLastTransition': (args) {
      // The transition occurs after the end of the maximum
      // Each year, the transition is at the midnight at the *end* of December 31st...
      var yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(TransitionMode.Utc, 12, 31, 0, true, LocalTime.Midnight, true);
      // ... and the recurrence is valid for the whole of time
      var recurrence = ZoneRecurrence('awkward', Offset.FromHours(1), yearOffset, 1, 5000);

      // We can find the final transition
      var finalTransition = Instant.FromUtc(5001, 1, 1, 0, 0);
      var next = recurrence.Next(finalTransition.MinusDuration(Duration.Epsilon), Offset.Zero, Offset.Zero);
      Transition? expected = Transition.NewInstantNewOffset(finalTransition, Offset.FromHours(1));
      Assert.AreEqual(expected, next);

      // But we correctly reject anything after that
      Assert.IsNull(recurrence.Next(finalTransition, Offset.Zero, Offset.Zero));
    },

    'WithName': (args) {
      var yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);
      var original = ZoneRecurrence('original', Offset.FromHours(1), yearOffset, 1900, 2000);
      var renamed = original.WithName('renamed');
      Assert.AreEqual('renamed', renamed.Name);
      Assert.AreEqual(original.Savings, renamed.Savings);
      Assert.AreEqual(original.YearOffset, renamed.YearOffset);
      Assert.AreEqual(original.FromYear, renamed.FromYear);
      Assert.AreEqual(original.ToYear, renamed.ToYear);
    },

    'ForSingleYear': (args) {
      var yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);
      var original = ZoneRecurrence('original', Offset.FromHours(1), yearOffset, 1900, 2000);
      var singleYear = original.ForSingleYear(2017);
      Assert.AreEqual(original.Name, singleYear.Name);
      Assert.AreEqual(original.Savings, singleYear.Savings);
      Assert.AreEqual(original.YearOffset, singleYear.YearOffset);
      Assert.AreEqual(2017, singleYear.FromYear);
      Assert.AreEqual(2017, singleYear.ToYear);
    },

    'ZoneRecurrenceToString': (args) {
      var yearOffset = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Utc, 10, 31, IsoDayOfWeek.Wednesday.value, true, LocalTime.Midnight);
      var recurrence = ZoneRecurrence('name', Offset.FromHours(1), yearOffset, 1900, 2000);
      Assert.AreEqual('name +01 ZoneYearOffset[mode:Utc monthOfYear:10 dayOfMonth:31 dayOfWeek:3 advance:True timeOfDay:00:00:00 addDay:False] [1900-2000]', recurrence.toString());
    },
  }, skip: {
    'Constructor_nullName_exception': SkipReasons.NullSafety,
    'Constructor_nullYearOffset_exception': SkipReasons.NullSafety,
  });
}
