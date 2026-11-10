// Ported from NodaTime 6e024dde: src/NodaTime.Test/LocalDateTimeTest.cs (+ LocalDateTimeTest.Pseudomutators.cs)
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: DateTimeKind.Unspecified and Local are a local core.DateTime.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:noda_dart/src/AmbiguousTimeException.dart';
import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/GregorianYearMonthDayCalculator.dart';
import 'package:noda_dart/src/Calendars/IslamicEpoch.generated.dart';
import 'package:noda_dart/src/Calendars/IslamicLeapYearPattern.generated.dart';
import 'package:noda_dart/src/DateAdjusters.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/DateTimeZoneProviders.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Period.dart';
import 'package:noda_dart/src/PeriodBuilder.dart';
import 'package:noda_dart/src/SkippedTimeException.dart';
import 'package:noda_dart/src/TimeAdjusters.dart';
import 'package:noda_dart/src/TimeZones/Resolvers.dart';
import 'package:noda_dart/src/Utility/BclConversions.dart';
import 'package:noda_dart/src/Utility/Int64.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/LocalDateTimeTest.generated.dart' as scenarios;

final DateTimeZone Pacific = DateTimeZoneProviders.Tzdb['America/Los_Angeles'];

void main() {
  port(scenarios.fixture, {
    // #region LocalDateTimeTest.cs
    'ToDateTimeUnspecified': (args) {
      LocalDateTime ldt = LocalDateTime(2011, 3, 5, 1, 0, 0);
      core.DateTime expected = core.DateTime(2011, 3, 5, 1, 0, 0);
      core.DateTime actual = ldt.ToDateTimeUnspecified();
      Assert.AreEqual(expected, actual);
      // Kind isn't checked by Equals...
      // noda_dart: DateTimeKind.Unspecified is a local core.DateTime (isUtc false).
      Assert.AreEqual(false, actual.isUtc);
    },

    'ToDateTimeUnspecified_JulianCalendar': (args) {
      // Non-Gregorian calendar systems are handled by converting to the same
      // date, just like the DateTime constructor does.
      LocalDateTime ldt = LocalDateTime(2011, 3, 5, 1, 0, 0, 0, CalendarSystem.Julian);
          // noda_dart: Dart's DateTime is Gregorian: Julian 2011-03-05 as its Gregorian date.
      core.DateTime expected = core.DateTime(2011, 3, 18, 1, 0, 0, 0);
      core.DateTime actual = ldt.ToDateTimeUnspecified();
      Assert.AreEqual(expected, actual);
      // Kind isn't checked by Equals...
      Assert.AreEqual(false, actual.isUtc);
    },

    'ToDateTimeUnspecified_TruncatesTowardsStartOfTime': (args) {
      final [int year] = args;
      var ldt = LocalDateTime(year, 1, 1, 13, 15, 55).PlusNanoseconds(NodaConstants.NanosecondsPerSecond - 1);
          // noda_dart: truncated to the last microsecond (Dart's DateTime has no ticks).
      var expected = core.DateTime(year, 1, 1, 13, 15, 55)
          .add(core.Duration(microseconds: NodaConstants.TicksPerSecond ~/ 10 - 1));
      var actual = ldt.ToDateTimeUnspecified();
      Assert.AreEqual(expected, actual);
    },

    'ToDateTimeUnspecified_OutOfRange': (args) {
      // One day before 1st January, 1AD (which is DateTime.MinValue)
      var ldt = LocalDate(1, 1, 1).PlusDays(-1).AtMidnight();
      Assert.Throws<StateError>(() => ldt.ToDateTimeUnspecified());
    },

    'FromDateTime': (args) {
      LocalDateTime expected = LocalDateTime(2011, 08, 18, 20, 53);
      // noda_dart: DateTimeKind's values are Dart's isUtc false (Unspecified, Local) and true (Utc).
      for (var isUtc in [false, true]) {
        core.DateTime x = isUtc ? core.DateTime.utc(2011, 08, 18, 20, 53, 0) : core.DateTime(2011, 08, 18, 20, 53, 0);
        LocalDateTime actual = LocalDateTime.FromDateTime(x);
        Assert.AreEqual(expected, actual);
      }
    },

    'FromDateTime_WithCalendar': (args) {
      // Julian calendar is 13 days behind Gregorian calendar in the 21st century
      LocalDateTime expected = LocalDateTime.YearMonthDayHourMinuteCalendar(2011, 08, 05, 20, 53, CalendarSystem.Julian);
      for (var isUtc in [false, true]) {
        core.DateTime x = isUtc ? core.DateTime.utc(2011, 08, 18, 20, 53, 0) : core.DateTime(2011, 08, 18, 20, 53, 0);
        LocalDateTime actual = LocalDateTime.FromDateTime(x, CalendarSystem.Julian);
        Assert.AreEqual(expected, actual);
      }
    },

    'TimeProperties_AfterEpoch': (args) {
      // Use the largest valid year as part of validating against overflow
      LocalDateTime ldt = LocalDateTime(GregorianYearMonthDayCalculator.MaxGregorianYear, 1, 2, 15, 48, 25).PlusNanoseconds(123456789);
      Assert.AreEqual(15, ldt.Hour);
      Assert.AreEqual(3, ldt.ClockHourOfHalfDay);
      Assert.AreEqual(48, ldt.Minute);
      Assert.AreEqual(25, ldt.Second);
      Assert.AreEqual(123, ldt.Millisecond);
      Assert.AreEqual(1234567, ldt.TickOfSecond);
      Assert.AreEqual(15 * NodaConstants.TicksPerHour +
                      48 * NodaConstants.TicksPerMinute +
                      25 * NodaConstants.TicksPerSecond +
                      1234567, ldt.TickOfDay);
      Assert.AreEqual(15 * NodaConstants.NanosecondsPerHour +
                      48 * NodaConstants.NanosecondsPerMinute +
                      25 * NodaConstants.NanosecondsPerSecond +
                      123456789, ldt.NanosecondOfDay);
      Assert.AreEqual(123456789, ldt.NanosecondOfSecond);
    },

    'TimeProperties_BeforeEpoch': (args) {
      // Use the smallest valid year number as part of validating against overflow
      LocalDateTime ldt = LocalDateTime(GregorianYearMonthDayCalculator.MinGregorianYear, 1, 2, 15, 48, 25).PlusNanoseconds(123456789);
      Assert.AreEqual(15, ldt.Hour);
      Assert.AreEqual(3, ldt.ClockHourOfHalfDay);
      Assert.AreEqual(48, ldt.Minute);
      Assert.AreEqual(25, ldt.Second);
      Assert.AreEqual(123, ldt.Millisecond);
      Assert.AreEqual(1234567, ldt.TickOfSecond);
      Assert.AreEqual(15 * NodaConstants.TicksPerHour +
                      48 * NodaConstants.TicksPerMinute +
                      25 * NodaConstants.TicksPerSecond +
                      1234567, ldt.TickOfDay);
      Assert.AreEqual(15 * NodaConstants.NanosecondsPerHour +
                      48 * NodaConstants.NanosecondsPerMinute +
                      25 * NodaConstants.NanosecondsPerSecond +
                      123456789, ldt.NanosecondOfDay);
      Assert.AreEqual(123456789, ldt.NanosecondOfSecond);
    },

    'WithCalendar': (args) {
      LocalDateTime isoEpoch = LocalDateTime(1970, 1, 1, 0, 0, 0);
      LocalDateTime julianEpoch = isoEpoch.WithCalendar(CalendarSystem.Julian);
      Assert.AreEqual(1969, julianEpoch.Year);
      Assert.AreEqual(12, julianEpoch.Month);
      Assert.AreEqual(19, julianEpoch.Day);
      Assert.AreEqual(isoEpoch.TimeOfDay, julianEpoch.TimeOfDay);
    },

    // Verifies that negative local instant ticks don't cause a problem with the date
    'TimeOfDay_Before1970': (args) {
      LocalDateTime dateTime = LocalDateTime(1965, 11, 8, 12, 5, 23);
      LocalTime expected = LocalTime(12, 5, 23);
      Assert.AreEqual(expected, dateTime.TimeOfDay);
    },

    // Verifies that positive local instant ticks don't cause a problem with the date
    'TimeOfDay_After1970': (args) {
      LocalDateTime dateTime = LocalDateTime(1975, 11, 8, 12, 5, 23);
      LocalTime expected = LocalTime(12, 5, 23);
      Assert.AreEqual(expected, dateTime.TimeOfDay);
    },

    // Verifies that negative local instant ticks don't cause a problem with the date
    'Date_Before1970': (args) {
      LocalDateTime dateTime = LocalDateTime(1965, 11, 8, 12, 5, 23);
      LocalDate expected = LocalDate(1965, 11, 8);
      Assert.AreEqual(expected, dateTime.Date);
    },

    // Verifies that positive local instant ticks don't cause a problem with the date
    'Date_After1970': (args) {
      LocalDateTime dateTime = LocalDateTime(1975, 11, 8, 12, 5, 23);
      LocalDate expected = LocalDate(1975, 11, 8);
      Assert.AreEqual(expected, dateTime.Date);
    },

    'DayOfWeek_AroundEpoch': (args) {
      // Test about couple of months around the Unix epoch. If that works, I'm confident the rest will.
      LocalDateTime dateTime = LocalDateTime(1969, 12, 1, 0, 0);
      for (int i = 0; i < 60; i++) {
        // Check once per hour of the day, just in case something's messed up based on the time of day.
        for (int hour = 0; hour < 24; hour++) {
          // noda_dart: .NET's DateTime.DayOfWeek (Sunday = 0) is Dart's DateTime.weekday (Sunday = 7) % 7.
          Assert.AreEqual(BclConversions.ToIsoDayOfWeek(dateTime.ToDateTimeUnspecified().weekday % 7),
              dateTime.DayOfWeek);
          dateTime = dateTime.PlusHours(1);
        }
      }
    },

    'ClockHourOfHalfDay': (args) {
      Assert.AreEqual(12, LocalDateTime(1975, 11, 8, 0, 0, 0).ClockHourOfHalfDay);
      Assert.AreEqual(1, LocalDateTime(1975, 11, 8, 1, 0, 0).ClockHourOfHalfDay);
      Assert.AreEqual(12, LocalDateTime(1975, 11, 8, 12, 0, 0).ClockHourOfHalfDay);
      Assert.AreEqual(1, LocalDateTime(1975, 11, 8, 13, 0, 0).ClockHourOfHalfDay);
      Assert.AreEqual(11, LocalDateTime(1975, 11, 8, 23, 0, 0).ClockHourOfHalfDay);
    },

    'Operators_SameCalendar': (args) {
      LocalDateTime value1 = LocalDateTime(2011, 1, 2, 10, 30, 0);
      LocalDateTime value2 = LocalDateTime(2011, 1, 2, 10, 30, 0);
      LocalDateTime value3 = LocalDateTime(2011, 1, 2, 10, 45, 0);
      TestHelper.TestOperatorComparisonEquality(value1, value2, [value3]);
    },

    'Operators_DifferentCalendars_Throws': (args) {
      LocalDateTime value1 = LocalDateTime(2011, 1, 2, 10, 30);
      LocalDateTime value2 = LocalDateTime.YearMonthDayHourMinuteCalendar(2011, 1, 3, 10, 30, CalendarSystem.Julian);

      Assert.False(value1 == value2);
      Assert.True(value1 != value2);

      Assert.Throws<ArgumentError>(() => (value1 < value2).toString());
      Assert.Throws<ArgumentError>(() => (value1 <= value2).toString());
      Assert.Throws<ArgumentError>(() => (value1 > value2).toString());
      Assert.Throws<ArgumentError>(() => (value1 >= value2).toString());
    },

    'CompareTo_SameCalendar': (args) {
      LocalDateTime value1 = LocalDateTime(2011, 1, 2, 10, 30);
      LocalDateTime value2 = LocalDateTime(2011, 1, 2, 10, 30);
      LocalDateTime value3 = LocalDateTime(2011, 1, 2, 10, 45);

      Assert.That(value1.compareTo(value2), Is.EqualTo(0));
      Assert.That(value1.compareTo(value3), Is.LessThan(0));
      Assert.That(value3.compareTo(value2), Is.GreaterThan(0));
    },

    'CompareTo_DifferentCalendars_Throws': (args) {
      CalendarSystem islamic = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical);
      LocalDateTime value1 = LocalDateTime(2011, 1, 2, 10, 30);
      LocalDateTime value2 = LocalDateTime.YearMonthDayHourMinuteCalendar(1500, 1, 1, 10, 30, islamic);

      Assert.Throws<ArgumentError>(() => value1.compareTo(value2));
      // noda_dart: IComparable.CompareTo(object) is CompareTo(Object?).
      Assert.Throws<ArgumentError>(() => value1.CompareTo(value2));
    },

    /// IComparable.CompareTo works properly for LocalDateTime inputs with different calendars.
    'IComparableCompareTo_SameCalendar': (args) {
      LocalDateTime value1 = LocalDateTime(2011, 1, 2, 10, 30);
      LocalDateTime value2 = LocalDateTime(2011, 1, 2, 10, 30);
      LocalDateTime value3 = LocalDateTime(2011, 1, 2, 10, 45);

      LocalDateTime i_value1 = value1;
      LocalDateTime i_value3 = value3;

      Assert.That(i_value1.CompareTo(value2), Is.EqualTo(0));
      Assert.That(i_value1.CompareTo(value3), Is.LessThan(0));
      Assert.That(i_value3.CompareTo(value2), Is.GreaterThan(0));
    },

    /// IComparable.CompareTo returns a positive number for a null input.
    'IComparableCompareTo_Null_Positive': (args) {
      var instance = LocalDateTime(2012, 3, 5, 10, 45);
      var comparable = instance;
      var result = comparable.CompareTo(null);
      Assert.That(result, Is.GreaterThan(0));
    },

    /// IComparable.CompareTo throws an ArgumentException for non-null arguments
    /// that are not a LocalDateTime.
    'IComparableCompareTo_WrongType_ArgumentException': (args) {
      var instance = LocalDateTime(2012, 3, 5, 10, 45);
      var i_instance = instance;
      var arg = LocalDate(2012, 3, 6);
      Assert.Throws<ArgumentError>(() => i_instance.CompareTo(arg));
    },

    'WithOffset': (args) {
      var offset = Offset.FromHoursAndMinutes(5, 10);
      var localDateTime = LocalDateTime(2009, 12, 22, 21, 39, 30);
      var offsetDateTime = localDateTime.WithOffset(offset);
      Assert.AreEqual(localDateTime, offsetDateTime.LocalDateTime);
      Assert.AreEqual(offset, offsetDateTime.Offset);
    },

    'InUtc': (args) {
      var local = LocalDateTime(2009, 12, 22, 21, 39, 30);
      var zoned = local.InUtc();
      Assert.AreEqual(local, zoned.LocalDateTime);
      Assert.AreEqual(Offset.Zero, zoned.Offset);
      Assert.AreSame(DateTimeZone.Utc, zoned.Zone);
    },

    'InZoneStrictly_InWinter': (args) {
      var local = LocalDateTime(2009, 12, 22, 21, 39, 30);
      var zoned = local.InZoneStrictly(Pacific);
      Assert.AreEqual(local, zoned.LocalDateTime);
      Assert.AreEqual(Offset.FromHours(-8), zoned.Offset);
    },

    'InZoneStrictly_InSummer': (args) {
      var local = LocalDateTime(2009, 6, 22, 21, 39, 30);
      var zoned = local.InZoneStrictly(Pacific);
      Assert.AreEqual(local, zoned.LocalDateTime);
      Assert.AreEqual(Offset.FromHours(-7), zoned.Offset);
    },

    /// Pacific time changed from -7 to -8 at 2am wall time on November 2nd 2009,
    /// so 2am became 1am.
    'InZoneStrictly_ThrowsWhenAmbiguous': (args) {
      var local = LocalDateTime(2009, 11, 1, 1, 30, 0);
      Assert.Throws<AmbiguousTimeException>(() => local.InZoneStrictly(Pacific));
    },

    /// Pacific time changed from -8 to -7 at 2am wall time on March 8th 2009,
    /// so 2am became 3am. This means that 2.30am doesn't exist on that day.
    'InZoneStrictly_ThrowsWhenSkipped': (args) {
      var local = LocalDateTime(2009, 3, 8, 2, 30, 0);
      Assert.Throws<SkippedTimeException>(() => local.InZoneStrictly(Pacific));
    },

    /// Pacific time changed from -7 to -8 at 2am wall time on November 2nd 2009,
    /// so 2am became 1am. We'll return the earlier result, i.e. with the offset of -7
    'InZoneLeniently_AmbiguousTime_ReturnsEarlierMapping': (args) {
      var local = LocalDateTime(2009, 11, 1, 1, 30, 0);
      var zoned = local.InZoneLeniently(Pacific);
      Assert.AreEqual(local, zoned.LocalDateTime);
      Assert.AreEqual(Offset.FromHours(-7), zoned.Offset);
    },

    /// Pacific time changed from -8 to -7 at 2am wall time on March 8th 2009,
    /// so 2am became 3am. This means that 2:30am doesn't exist on that day.
    /// We'll return 3:30am, the forward-shifted value.
    'InZoneLeniently_ReturnsStartOfSecondInterval': (args) {
      var local = LocalDateTime(2009, 3, 8, 2, 30, 0);
      var zoned = local.InZoneLeniently(Pacific);
      Assert.AreEqual(LocalDateTime(2009, 3, 8, 3, 30, 0), zoned.LocalDateTime);
      Assert.AreEqual(Offset.FromHours(-7), zoned.Offset);
    },

    'InZone': (args) {
      // Don't need much for this - it only delegates.
      var ambiguous = LocalDateTime(2009, 11, 1, 1, 30, 0);
      var skipped = LocalDateTime(2009, 3, 8, 2, 30, 0);
      Assert.AreEqual(Pacific.AtLeniently(ambiguous), ambiguous.InZone(Pacific, Resolvers.LenientResolver));
      Assert.AreEqual(Pacific.AtLeniently(skipped), skipped.InZone(Pacific, Resolvers.LenientResolver));
    },

    'MinMax_DifferentCalendars_Throws': (args) {
      LocalDateTime ldt1 = LocalDateTime(2011, 1, 2, 2, 20);
      LocalDateTime ldt2 = LocalDateTime.YearMonthDayHourMinuteCalendar(1500, 1, 1, 5, 10, CalendarSystem.Julian);

      Assert.Throws<ArgumentError>(() => LocalDateTime.Max(ldt1, ldt2));
      Assert.Throws<ArgumentError>(() => LocalDateTime.Min(ldt1, ldt2));
    },

    'MinMax_SameCalendar': (args) {
      LocalDateTime ldt1 = LocalDateTime.YearMonthDayHourMinuteCalendar(1500, 1, 1, 7, 20, CalendarSystem.Julian);
      LocalDateTime ldt2 = LocalDateTime.YearMonthDayHourMinuteCalendar(1500, 1, 1, 5, 10, CalendarSystem.Julian);

      Assert.AreEqual(ldt1, LocalDateTime.Max(ldt1, ldt2));
      Assert.AreEqual(ldt1, LocalDateTime.Max(ldt2, ldt1));
      Assert.AreEqual(ldt2, LocalDateTime.Min(ldt1, ldt2));
      Assert.AreEqual(ldt2, LocalDateTime.Min(ldt2, ldt1));
    },

    'Deconstruction': (args) {
      var value = LocalDateTime(2017, 10, 15, 21, 30, 0);
      var expectedDate = LocalDate(2017, 10, 15);
      var expectedTime = LocalTime(21, 30, 0);

      var (actualDate, actualTime) = value.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(expectedDate, actualDate);
        Assert.AreEqual(expectedTime, actualTime);
      });
    },

    'Equality': (args) => TestHelper.TestEqualsStruct(
        LocalDateTime(2017, 10, 15, 21, 30, 0, 0, CalendarSystem.Iso),
        LocalDateTime(2017, 10, 15, 21, 30, 0, 0, CalendarSystem.Iso),
        [
          LocalDateTime(2018, 10, 15, 21, 30, 0, 0, CalendarSystem.Iso),
          LocalDateTime(2017, 11, 15, 21, 30, 0, 0, CalendarSystem.Iso),
          LocalDateTime(2017, 10, 16, 21, 30, 0, 0, CalendarSystem.Iso),
          LocalDateTime(2017, 10, 15, 22, 30, 0, 0, CalendarSystem.Iso),
          LocalDateTime(2017, 10, 15, 21, 31, 0, 0, CalendarSystem.Iso),
          LocalDateTime(2017, 10, 15, 21, 30, 1, 0, CalendarSystem.Iso),
          LocalDateTime(2017, 10, 15, 21, 30, 0, 1, CalendarSystem.Iso),
          LocalDateTime(2017, 10, 15, 21, 30, 0, 0, CalendarSystem.Gregorian),
        ]),

    'MaxIsoValue': (args) {
      var value = LocalDateTime.MaxIsoValue;
      Assert.AreEqual(CalendarSystem.Iso, value.Calendar);
      Assert.Throws<OverflowException>(() => value.PlusNanoseconds(1));
    },

    'MinIsoValue': (args) {
      var value = LocalDateTime.MinIsoValue;
      Assert.AreEqual(CalendarSystem.Iso, value.Calendar);
      Assert.Throws<OverflowException>(() => value.PlusNanoseconds(-1));
    },

    'TestToString': (args) {
      var ldt = LocalDateTime(2018, 10, 15, 21, 30, 0, 0, CalendarSystem.Iso);
      Assert.AreEqual(ldt.ToStringPattern(null, null), ldt.toString());
    },
    // #endregion

    // #region LocalDateTimeTest.Pseudomutators.cs
    'PlusYear_Simple': (args) {
      LocalDateTime start = LocalDateTime(2011, 6, 26, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2016, 6, 26, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusYears(5));

      expected = LocalDateTime(2006, 6, 26, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusYears(-5));
    },

    'PlusYear_LeapToNonLeap': (args) {
      LocalDateTime start = LocalDateTime(2012, 2, 29, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2013, 2, 28, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusYears(1));

      expected = LocalDateTime(2011, 2, 28, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusYears(-1));
    },

    'PlusYear_LeapToLeap': (args) {
      LocalDateTime start = LocalDateTime(2012, 2, 29, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2016, 2, 29, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusYears(4));
    },

    'PlusMonth_Simple': (args) {
      LocalDateTime start = LocalDateTime(2012, 4, 15, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2012, 8, 15, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusMonths(4));
    },

    'PlusMonth_ChangingYear': (args) {
      LocalDateTime start = LocalDateTime(2012, 10, 15, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2013, 2, 15, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusMonths(4));
    },

    'PlusMonth_WithTruncation': (args) {
      LocalDateTime start = LocalDateTime(2011, 1, 30, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2011, 2, 28, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusMonths(1));
    },

    'PlusDays_Simple': (args) {
      LocalDateTime start = LocalDateTime(2011, 1, 15, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2011, 1, 23, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusDays(8));

      expected = LocalDateTime(2011, 1, 7, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusDays(-8));
    },

    'PlusDays_MonthBoundary': (args) {
      LocalDateTime start = LocalDateTime(2011, 1, 26, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2011, 2, 3, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusDays(8));

      // Round-trip back across the boundary
      Assert.AreEqual(start, start.PlusDays(8).PlusDays(-8));
    },

    'PlusDays_YearBoundary': (args) {
      LocalDateTime start = LocalDateTime(2011, 12, 26, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2012, 1, 3, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusDays(8));

      // Round-trip back across the boundary
      Assert.AreEqual(start, start.PlusDays(8).PlusDays(-8));
    },

    'PlusDays_EndOfFebruary_InLeapYear': (args) {
      LocalDateTime start = LocalDateTime(2012, 2, 26, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2012, 3, 5, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusDays(8));
      // Round-trip back across the boundary
      Assert.AreEqual(start, start.PlusDays(8).PlusDays(-8));
    },

    'PlusDays_EndOfFebruary_NotInLeapYear': (args) {
      LocalDateTime start = LocalDateTime(2011, 2, 26, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2011, 3, 6, 12, 15, 8);
      Assert.AreEqual(expected, start.PlusDays(8));

      // Round-trip back across the boundary
      Assert.AreEqual(start, start.PlusDays(8).PlusDays(-8));
    },

    'PlusWeeks_Simple': (args) {
      LocalDateTime start = LocalDateTime(2011, 4, 2, 12, 15, 8);
      LocalDateTime expectedForward = LocalDateTime(2011, 4, 23, 12, 15, 8);
      LocalDateTime expectedBackward = LocalDateTime(2011, 3, 12, 12, 15, 8);
      Assert.AreEqual(expectedForward, start.PlusWeeks(3));
      Assert.AreEqual(expectedBackward, start.PlusWeeks(-3));
    },

    'PlusHours_Simple': (args) {
      LocalDateTime start = LocalDateTime(2011, 4, 2, 12, 15, 8);
      LocalDateTime expectedForward = LocalDateTime(2011, 4, 2, 14, 15, 8);
      LocalDateTime expectedBackward = LocalDateTime(2011, 4, 2, 10, 15, 8);
      Assert.AreEqual(expectedForward, start.PlusHours(2));
      Assert.AreEqual(expectedBackward, start.PlusHours(-2));
    },

    'PlusHours_CrossingDayBoundary': (args) {
      LocalDateTime start = LocalDateTime(2011, 4, 2, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2011, 4, 3, 8, 15, 8);
      Assert.AreEqual(expected, start.PlusHours(20));
      Assert.AreEqual(start, start.PlusHours(20).PlusHours(-20));
    },

    'PlusHours_CrossingYearBoundary': (args) {
      // Christmas day + 10 days and 1 hour
      LocalDateTime start = LocalDateTime(2011, 12, 25, 12, 15, 8);
      LocalDateTime expected = LocalDateTime(2012, 1, 4, 13, 15, 8);
      Assert.AreEqual(expected, start.PlusHours(241));
      Assert.AreEqual(start, start.PlusHours(241).PlusHours(-241));
    },

    // Having tested that hours cross boundaries correctly, the other time unit
    // tests are straightforward
    'PlusMinutes_Simple': (args) {
      LocalDateTime start = LocalDateTime(2011, 4, 2, 12, 15, 8);
      LocalDateTime expectedForward = LocalDateTime(2011, 4, 2, 12, 17, 8);
      LocalDateTime expectedBackward = LocalDateTime(2011, 4, 2, 12, 13, 8);
      Assert.AreEqual(expectedForward, start.PlusMinutes(2));
      Assert.AreEqual(expectedBackward, start.PlusMinutes(-2));
    },

    'PlusSeconds_Simple': (args) {
      LocalDateTime start = LocalDateTime(2011, 4, 2, 12, 15, 8);
      LocalDateTime expectedForward = LocalDateTime(2011, 4, 2, 12, 15, 18);
      LocalDateTime expectedBackward = LocalDateTime(2011, 4, 2, 12, 14, 58);
      Assert.AreEqual(expectedForward, start.PlusSeconds(10));
      Assert.AreEqual(expectedBackward, start.PlusSeconds(-10));
    },

    'PlusMilliseconds_Simple': (args) {
      LocalDateTime start = LocalDateTime(2011, 4, 2, 12, 15, 8, 300);
      LocalDateTime expectedForward = LocalDateTime(2011, 4, 2, 12, 15, 8, 700);
      LocalDateTime expectedBackward = LocalDateTime(2011, 4, 2, 12, 15, 7, 900);
      Assert.AreEqual(expectedForward, start.PlusMilliseconds(400));
      Assert.AreEqual(expectedBackward, start.PlusMilliseconds(-400));
    },

    'PlusTicks_Simple': (args) {
      LocalDate date = LocalDate(2011, 4, 2);
      LocalTime startTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 7500);
      LocalTime expectedForwardTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 301, 1500);
      LocalTime expectedBackwardTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 3500);
      // noda_dart: `date + time` is date.At(time).
      Assert.AreEqual(date.At(expectedForwardTime), (date.At(startTime)).PlusTicks(4000));
      Assert.AreEqual(date.At(expectedBackwardTime), (date.At(startTime)).PlusTicks(-4000));
    },

    'PlusTicks_Long': (args) {
      Assert.IsTrue(NodaConstants.TicksPerDay > Int64.Int32MaxValue);
      LocalDateTime start = LocalDateTime(2011, 4, 2, 12, 15, 8);
      LocalDateTime expectedForward = LocalDateTime(2011, 4, 3, 12, 15, 8);
      LocalDateTime expectedBackward = LocalDateTime(2011, 4, 1, 12, 15, 8);
      Assert.AreEqual(expectedForward, start.PlusTicks(NodaConstants.TicksPerDay));
      Assert.AreEqual(expectedBackward, start.PlusTicks(-NodaConstants.TicksPerDay));
    },

    'PlusNanoseconds_Simple': (args) {
      // Just use the ticks values
      LocalDate date = LocalDate(2011, 4, 2);
      LocalTime startTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 7500);
      LocalTime expectedForwardTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 7540);
      LocalTime expectedBackwardTime = LocalTime.FromHourMinuteSecondMillisecondTick(12, 15, 8, 300, 7460);
      Assert.AreEqual(date.At(expectedForwardTime), (date.At(startTime)).PlusNanoseconds(4000));
      Assert.AreEqual(date.At(expectedBackwardTime), (date.At(startTime)).PlusNanoseconds(-4000));
    },

    'PlusTicks_CrossingDay': (args) {
      LocalDateTime start = LocalDateTime(2011, 4, 2, 12, 15, 8);
      LocalDateTime expectedForward = LocalDateTime(2011, 4, 3, 12, 15, 8);
      LocalDateTime expectedBackward = LocalDateTime(2011, 4, 1, 12, 15, 8);
      Assert.AreEqual(expectedForward, start.PlusNanoseconds(NodaConstants.NanosecondsPerDay));
      Assert.AreEqual(expectedBackward, start.PlusNanoseconds(-NodaConstants.NanosecondsPerDay));
    },

    'Plus_FullPeriod': (args) {
      // Period deliberately chosen to require date rollover
      LocalDateTime start = LocalDateTime(2011, 4, 2, 12, 15, 8);
      var period = (PeriodBuilder()..Years = 1..Months = 2..Weeks = 3..Days = 4..Hours = 15..Minutes = 6
                                   ..Seconds = 7..Milliseconds = 8..Ticks = 9..Nanoseconds = 11).Build();
      var actual = start.Plus(period);
      var expected = LocalDateTime(2012, 6, 28, 3, 21, 15).PlusNanoseconds(8000911);
      Assert.AreEqual(expected, actual, '${_Format(expected)} != ${_Format(actual)}');
    },

    'Minus_FullPeriod': (args) {
      // Period deliberately chosen to require date rollover
      LocalDateTime start = LocalDateTime(2011, 4, 2, 12, 15, 8);
      var period = (PeriodBuilder()..Years = 1..Months = 2..Weeks = 3..Days = 4..Hours = 15..Minutes = 6
                                   ..Seconds = 7..Milliseconds = 8..Ticks = 9..Nanoseconds = 11).Build();
      var actual = start.Minus(period);
      var expected = LocalDateTime(2010, 1, 7, 21, 9, 0).PlusNanoseconds(991999089);
      Assert.AreEqual(expected, actual, '${_Format(expected)} != ${_Format(actual)}');
    },

    // Each test case gives a day-of-month in November 2011 and a target "next day of week";
    // the result is the next day-of-month in November 2011 with that target day.
    // The tests are picked somewhat arbitrarily...
    'Next': (args) {
      final [int dayOfMonth, IsoDayOfWeek targetDayOfWeek] = args;
      LocalDateTime start = LocalDateTime(2011, 11, dayOfMonth, 15, 25, 30).PlusNanoseconds(123456789);
      LocalDateTime target = start.Next(targetDayOfWeek);
      Assert.AreEqual(2011, target.Year);
      Assert.AreEqual(11, target.Month);
      Assert.AreEqual(start.TimeOfDay, target.TimeOfDay);
      return target.Day;
    },

    'Next_InvalidArgument': (args) {
      final [IsoDayOfWeek targetDayOfWeek] = args;
      LocalDateTime start = LocalDateTime(2011, 1, 1, 15, 25, 30).PlusNanoseconds(123456789);
      Assert.Throws<RangeError>(() => start.Next(targetDayOfWeek));
    },

    // Each test case gives a day-of-month in November 2011 and a target "next day of week";
    // the result is the next day-of-month in November 2011 with that target day.
    'Previous': (args) {
      final [int dayOfMonth, IsoDayOfWeek targetDayOfWeek] = args;
      LocalDateTime start = LocalDateTime(2011, 11, dayOfMonth, 15, 25, 30).PlusNanoseconds(123456789);
      LocalDateTime target = start.Previous(targetDayOfWeek);
      Assert.AreEqual(2011, target.Year);
      Assert.AreEqual(11, target.Month);
      return target.Day;
    },

    'Previous_InvalidArgument': (args) {
      final [IsoDayOfWeek targetDayOfWeek] = args;
      LocalDateTime start = LocalDateTime(2011, 1, 1, 15, 25, 30).PlusNanoseconds(123456789);
      Assert.Throws<RangeError>(() => start.Previous(targetDayOfWeek));
    },

    // No tests for non-ISO-day-of-week calendars as we don't have any yet.

    'Operator_MethodEquivalents': (args) {
      LocalDateTime start = LocalDateTime(2011, 1, 1, 15, 25, 30).PlusNanoseconds(123456789);
      Period period = Period.FromHours(1) + Period.FromDays(1);
      LocalDateTime end = start + period;
      Assert.AreEqual(start + period, LocalDateTime.Add(start, period));
      Assert.AreEqual(start + period, start.Plus(period));
      Assert.AreEqual(start - period, LocalDateTime.Subtract(start, period));
      Assert.AreEqual(start - period, start.Minus(period));
      // noda_dart: `end - start` and Subtract/Minus(LocalDateTime) are SubtractLocalDateTime / MinusLocalDateTime.
      Assert.AreEqual(period, LocalDateTime.SubtractLocalDateTime(end, start));
      Assert.AreEqual(period, LocalDateTime.SubtractLocalDateTime(end, start));
      Assert.AreEqual(period, end.MinusLocalDateTime(start));
    },

    'With_TimeAdjuster': (args) {
      LocalDateTime start = LocalDateTime(2014, 6, 27, 12, 15, 8).PlusNanoseconds(123456789);
      LocalDateTime expected = LocalDateTime(2014, 6, 27, 12, 15, 8);
      // noda_dart: With(Func<LocalTime, LocalTime>) is WithTimeAdjuster.
      Assert.AreEqual(expected, start.WithTimeAdjuster(TimeAdjusters.TruncateToSecond));
    },

    'With_DateAdjuster': (args) {
      LocalDateTime start = LocalDateTime(2014, 6, 27, 12, 5, 8).PlusNanoseconds(123456789);
      LocalDateTime expected = LocalDateTime(2014, 6, 30, 12, 5, 8).PlusNanoseconds(123456789);
      Assert.AreEqual(expected, start.With(DateAdjusters.EndOfMonth));
    },

    'PlusHours_Overflow': (args) {
      final [int year, int month, int day, int hours] = args;
      TestHelper.AssertOverflow(LocalDateTime(year, month, day, 0, 0).PlusHours, hours);
    },
    // #endregion
  }, skip: {
    'DateTime_Roundtrip_OtherCalendarInBcl': SkipReasons.BclCalendar,
    'DefaultConstructor': SkipReasons.DefaultConstructor,
    'XmlSerialization_Iso': SkipReasons.Xml,
    'XmlSerialization_NonIso': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
  });
}

/// C#'s `{value:uuuu-MM-dd HH:mm:ss.fffffffff}` in the assertion messages.
String _Format(LocalDateTime value) => value.ToStringPattern('uuuu-MM-dd HH:mm:ss.fffffffff');
