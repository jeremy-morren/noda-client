// Ported from NodaTime 6e024dde: src/NodaTime.Test/LocalDateTest.cs (+ LocalDateTest.BasicProperties.cs,
// LocalDateTest.Comparison.cs, LocalDateTest.Construction.cs, LocalDateTest.Conversion.cs,
// LocalDateTest.PeriodArithmetic.cs, LocalDateTest.Pseudomutators.cs)
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:noda_dart/src/CalendarOrdinal.generated.dart';
import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/Calendars/IslamicEpoch.generated.dart';
import 'package:noda_dart/src/Calendars/IslamicLeapYearPattern.generated.dart';
import 'package:noda_dart/src/DateAdjusters.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/OffsetDate.dart';
import 'package:noda_dart/src/Period.dart';
import 'package:noda_dart/src/Utility/BclConversions.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/LocalDateTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    // #region LocalDateTest.BasicProperties.cs
    'EpochProperties': (args) {
      LocalDate date = NodaConstants.UnixEpoch.InUtc().Date;
      Assert.AreEqual(1970, date.Year);
      Assert.AreEqual(1970, date.YearOfEra);
      Assert.AreEqual(1, date.Day);
      Assert.AreEqual(IsoDayOfWeek.Thursday, date.DayOfWeek);
      Assert.AreEqual(1, date.DayOfYear);
      Assert.AreEqual(1, date.Month);
    },

    'ArbitraryDateProperties': (args) {
      core.DateTime bclDate = core.DateTime.utc(2011, 3, 5, 0, 0, 0);
      core.DateTime bclEpoch = core.DateTime.utc(1970, 1, 1, 0, 0, 0);
      // noda_dart: DateTime.Ticks → microsecondsSinceEpoch * 10 (a tick is 100ns).
      int bclTicks = bclDate.microsecondsSinceEpoch * 10 - bclEpoch.microsecondsSinceEpoch * 10;
      int bclDays = bclTicks ~/ NodaConstants.TicksPerDay;
      LocalDate date = LocalDate.NewDaysSinceEpochCalendar(bclDays, CalendarSystem.Iso);
      Assert.AreEqual(2011, date.Year);
      Assert.AreEqual(2011, date.YearOfEra);
      Assert.AreEqual(5, date.Day);
      Assert.AreEqual(IsoDayOfWeek.Saturday, date.DayOfWeek);
      Assert.AreEqual(64, date.DayOfYear);
      Assert.AreEqual(3, date.Month);
    },

    'DayOfWeek_AroundEpoch': (args) {
      // Test about couple of months around the Unix epoch. If that works, I'm confident the rest will.
      LocalDate date = LocalDate(1969, 12, 1);
      for (int i = 0; i < 60; i++) {
        // noda_dart: .NET's DateTime.DayOfWeek (Sunday = 0) is Dart's DateTime.weekday (Sunday = 7) % 7.
        Assert.AreEqual(
            BclConversions.ToIsoDayOfWeek(date.AtMidnight().ToDateTimeUnspecified().weekday % 7),
            date.DayOfWeek);
        date = date.PlusDays(1);
      }
    },
    // #endregion

    // #region LocalDateTest.Comparison.cs
    'Equals_EqualValues': (args) {
      CalendarSystem calendar = CalendarSystem.Julian;
      LocalDate date1 = LocalDate(2011, 1, 2, calendar);
      LocalDate date2 = LocalDate(2011, 1, 2, calendar);
      Assert.AreEqual(date1, date2);
      Assert.AreEqual(date1.hashCode, date2.hashCode);
      Assert.IsTrue(date1 == date2);
      Assert.IsFalse(date1 != date2);
      Assert.IsTrue(date1.Equals(date2)); // IEquatable implementation
    },

    'Equals_DifferentDates': (args) {
      CalendarSystem calendar = CalendarSystem.Julian;
      LocalDate date1 = LocalDate(2011, 1, 2, calendar);
      LocalDate date2 = LocalDate(2011, 1, 3, calendar);
      Assert.AreNotEqual(date1, date2);
      Assert.AreNotEqual(date1.hashCode, date2.hashCode);
      Assert.IsFalse(date1 == date2);
      Assert.IsTrue(date1 != date2);
      Assert.IsFalse(date1.Equals(date2)); // IEquatable implementation
    },

    'Equals_DifferentCalendars': (args) {
      CalendarSystem calendar = CalendarSystem.Julian;
      LocalDate date1 = LocalDate(2011, 1, 2, calendar);
      LocalDate date2 = LocalDate(2011, 1, 2, CalendarSystem.Iso);
      Assert.AreNotEqual(date1, date2);
      Assert.AreNotEqual(date1.hashCode, date2.hashCode);
      Assert.IsFalse(date1 == date2);
      Assert.IsTrue(date1 != date2);
      Assert.IsFalse(date1.Equals(date2)); // IEquatable implementation
    },

    'Equals_DifferentToNull': (args) {
      LocalDate date = LocalDate(2011, 1, 2);
      // noda_dart: C#'s Equals(object) with null is Dart's == with null.
      Object? other;
      Assert.IsFalse(date == other);
    },

    'Equals_DifferentToOtherType': (args) {
      LocalDate date = LocalDate(2011, 1, 2);
      // noda_dart: C#'s Equals(object) is Dart's ==.
      // ignore: unrelated_type_equality_checks
      Assert.IsFalse(date == Instant.FromUnixTimeTicks(0));
    },

    'ComparisonOperators_SameCalendar': (args) {
      LocalDate date1 = LocalDate(2011, 1, 2);
      LocalDate date2 = LocalDate(2011, 1, 2);
      LocalDate date3 = LocalDate(2011, 1, 5);

      Assert.IsFalse(date1 < date2);
      Assert.IsTrue(date1 < date3);
      Assert.IsFalse(date2 < date1);
      Assert.IsFalse(date3 < date1);

      Assert.IsTrue(date1 <= date2);
      Assert.IsTrue(date1 <= date3);
      Assert.IsTrue(date2 <= date1);
      Assert.IsFalse(date3 <= date1);

      Assert.IsFalse(date1 > date2);
      Assert.IsFalse(date1 > date3);
      Assert.IsFalse(date2 > date1);
      Assert.IsTrue(date3 > date1);

      Assert.IsTrue(date1 >= date2);
      Assert.IsFalse(date1 >= date3);
      Assert.IsTrue(date2 >= date1);
      Assert.IsTrue(date3 >= date1);
    },

    'ComparisonOperators_DifferentCalendars_Throws': (args) {
      LocalDate date1 = LocalDate(2011, 1, 2);
      LocalDate date2 = LocalDate(2011, 1, 3, CalendarSystem.Julian);

      Assert.Throws<ArgumentError>(() => (date1 < date2).toString());
      Assert.Throws<ArgumentError>(() => (date1 <= date2).toString());
      Assert.Throws<ArgumentError>(() => (date1 > date2).toString());
      Assert.Throws<ArgumentError>(() => (date1 >= date2).toString());
    },

    'CompareTo_SameCalendar': (args) {
      LocalDate date1 = LocalDate(2011, 1, 2);
      LocalDate date2 = LocalDate(2011, 1, 2);
      LocalDate date3 = LocalDate(2011, 1, 5);

      Assert.That(date1.compareTo(date2), Is.EqualTo(0));
      Assert.That(date1.compareTo(date3), Is.LessThan(0));
      Assert.That(date3.compareTo(date2), Is.GreaterThan(0));
    },

    'CompareTo_DifferentCalendars_Throws': (args) {
      CalendarSystem islamic = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical);
      LocalDate date1 = LocalDate(2011, 1, 2);
      LocalDate date2 = LocalDate(1500, 1, 1, islamic);

      Assert.Throws<ArgumentError>(() => date1.compareTo(date2));
      // noda_dart: IComparable.CompareTo(object) is CompareTo(Object?).
      Assert.Throws<ArgumentError>(() => date1.CompareTo(date2));
    },

    /// IComparable.CompareTo works properly with LocalDate inputs with same calendar.
    'IComparableCompareTo_SameCalendar': (args) {
      var instance = LocalDate(2012, 3, 5);
      var i_instance = instance;

      var later = LocalDate(2012, 6, 4);
      var earlier = LocalDate(2012, 1, 4);
      var same = LocalDate(2012, 3, 5);

      Assert.That(i_instance.CompareTo(later), Is.LessThan(0));
      Assert.That(i_instance.CompareTo(earlier), Is.GreaterThan(0));
      Assert.That(i_instance.CompareTo(same), Is.EqualTo(0));
    },

    /// IComparable.CompareTo returns a positive number for a null input.
    'IComparableCompareTo_Null_Positive': (args) {
      var instance = LocalDate(2012, 3, 5);
      var comparable = instance;
      var result = comparable.CompareTo(null);
      Assert.Greater(result, 0);
    },

    /// IComparable.CompareTo throws an ArgumentException for non-null arguments
    /// that are not a LocalDate.
    'IComparableCompareTo_WrongType_ArgumentException': (args) {
      var instance = LocalDate(2012, 3, 5);
      var i_instance = instance;
      var arg = LocalDateTime(2012, 3, 6, 15, 42);
      Assert.Throws<ArgumentError>(() {
        i_instance.CompareTo(arg);
      });
    },

    'MinMax_DifferentCalendars_Throws': (args) {
      LocalDate date1 = LocalDate(2011, 1, 2);
      LocalDate date2 = LocalDate(1500, 1, 1, CalendarSystem.Julian);

      Assert.Throws<ArgumentError>(() => LocalDate.Max(date1, date2));
      Assert.Throws<ArgumentError>(() => LocalDate.Min(date1, date2));
    },

    'MinMax_SameCalendar': (args) {
      LocalDate date1 = LocalDate(1500, 1, 2, CalendarSystem.Julian);
      LocalDate date2 = LocalDate(1500, 1, 1, CalendarSystem.Julian);

      Assert.AreEqual(date1, LocalDate.Max(date1, date2));
      Assert.AreEqual(date1, LocalDate.Max(date2, date1));
      Assert.AreEqual(date2, LocalDate.Min(date1, date2));
      Assert.AreEqual(date2, LocalDate.Min(date2, date1));
    },
    // #endregion

    // #region LocalDateTest.Construction.cs
    'Constructor_WithDays': (args) {
      final [int year] = args;
      LocalDate start = LocalDate(year, 1, 1);
      int startDays = start.DaysSinceEpoch;
      for (int i = 0; i < 366; i++) {
        Assert.AreEqual(start.PlusDays(i), LocalDate.NewDaysSinceEpoch(startDays + i));
      }
    },

    'Constructor_WithDaysAndCalendar': (args) {
      final [int year] = args;
      LocalDate start = LocalDate(year, 1, 1);
      int startDays = start.DaysSinceEpoch;
      for (int i = 0; i < 366; i++) {
        Assert.AreEqual(start.PlusDays(i), LocalDate.NewDaysSinceEpochCalendar(startDays + i, CalendarSystem.Iso));
      }
    },

    'Constructor_CalendarDefaultsToIso': (args) {
      LocalDate date = LocalDate(2000, 1, 1);
      Assert.AreEqual(CalendarSystem.Iso, date.Calendar);
    },

    'Constructor_PropertiesRoundTrip': (args) {
      LocalDate date = LocalDate(2023, 7, 27);
      Assert.AreEqual(2023, date.Year);
      Assert.AreEqual(7, date.Month);
      Assert.AreEqual(27, date.Day);
    },

    'Constructor_PropertiesRoundTrip_CustomCalendar': (args) {
      LocalDate date = LocalDate(2023, 7, 27, CalendarSystem.Julian);
      Assert.AreEqual(2023, date.Year);
      Assert.AreEqual(7, date.Month);
      Assert.AreEqual(27, date.Day);
    },

    'Constructor_Invalid': (args) {
      final [int year, int month, int day] = args;
      Assert.Throws<RangeError>(() => LocalDate(year, month, day));
    },

    'Constructor_Invalid_WithCalendar': (args) {
      final [int year, int month, int day] = args;
      Assert.Throws<RangeError>(() => LocalDate(year, month, day, CalendarSystem.Iso));
    },

    'Constructor_InvalidYearOfEra': (args) {
      Assert.Throws<RangeError>(() => LocalDate.EraYearOfEraMonthDay(Era.Common, 0, 1, 1));
      Assert.Throws<RangeError>(() => LocalDate.EraYearOfEraMonthDay(Era.BeforeCommon, 0, 1, 1));
      Assert.Throws<RangeError>(() => LocalDate.EraYearOfEraMonthDay(Era.Common, 10000, 1, 1));
      // Although our minimum year is -9998, that's 9999 BC.
      Assert.Throws<RangeError>(() => LocalDate.EraYearOfEraMonthDay(Era.BeforeCommon, 10000, 1, 1));
    },

    'Constructor_WithYearOfEra_BC': (args) {
      LocalDate absolute = LocalDate(-10, 1, 1);
      LocalDate withEra = LocalDate.EraYearOfEraMonthDay(Era.BeforeCommon, 11, 1, 1);
      Assert.AreEqual(absolute, withEra);
    },

    'Constructor_WithYearOfEra_AD': (args) {
      LocalDate absolute = LocalDate(50, 6, 19);
      LocalDate withEra = LocalDate.EraYearOfEraMonthDay(Era.Common, 50, 6, 19);
      Assert.AreEqual(absolute, withEra);
    },

    'Constructor_WithYearOfEra_NonIsoCalendar': (args) {
      var calendar = CalendarSystem.Coptic;
      LocalDate absolute = LocalDate(50, 6, 19, calendar);
      LocalDate withEra = LocalDate.EraYearOfEraMonthDay(Era.AnnoMartyrum, 50, 6, 19, calendar);
      Assert.AreEqual(absolute, withEra);
    },

    // Most tests are in IsoBasedWeekYearRuleTest.
    'FromWeekYearWeekAndDay_InvalidWeek53': (args) {
      // Week year 2005 only has 52 weeks
      Assert.Throws<RangeError>(() => LocalDate.FromWeekYearWeekAndDay(2005, 53, IsoDayOfWeek.Sunday));
    },

    'FromYearMonthWeekAndDay': (args) {
      final [int year, int month, int occurrence, IsoDayOfWeek dayOfWeek, int expectedDay] = args;
      var date = LocalDate.FromYearMonthWeekAndDay(year, month, occurrence, dayOfWeek);
      Assert.AreEqual(year, date.Year);
      Assert.AreEqual(month, date.Month);
      Assert.AreEqual(expectedDay, date.Day);
    },
    // #endregion

    // #region LocalDateTest.Conversion.cs
    'AtMidnight': (args) {
      LocalDate date = LocalDate(2011, 6, 29);
      LocalDateTime expected = LocalDateTime(2011, 6, 29, 0, 0, 0);
      Assert.AreEqual(expected, date.AtMidnight());
    },

    'WithCalendar': (args) {
      LocalDate isoEpoch = LocalDate(1970, 1, 1);
      LocalDate julianEpoch = isoEpoch.WithCalendar(CalendarSystem.Julian);
      Assert.AreEqual(1969, julianEpoch.Year);
      Assert.AreEqual(12, julianEpoch.Month);
      Assert.AreEqual(19, julianEpoch.Day);
    },

    'WithOffset': (args) {
      var date = LocalDate(2011, 6, 29);
      var offset = Offset.FromHours(5);
      var expected = OffsetDate(date, offset);
      Assert.AreEqual(expected, date.WithOffset(offset));
    },

    // noda_dart: DateTimeKind.Unspecified is a local (isUtc: false) core.DateTime.
    'ToDateTimeUnspecified': (args) {
      LocalDate noda = LocalDate(2015, 4, 2);
      core.DateTime bcl = core.DateTime(2015, 4, 2, 0, 0, 0);
      Assert.AreEqual(bcl, noda.ToDateTimeUnspecified());
    },

    'ToDateTimeUnspecified_JulianCalendar': (args) {
      // Non-Gregorian calendar systems are handled by converting to the same
      // date, just like the DateTime constructor does.
      LocalDate noda = LocalDate(2015, 4, 2, CalendarSystem.Julian);
          // noda_dart: Dart's DateTime is Gregorian: Julian 2015-04-02 as its Gregorian date.
      core.DateTime bcl = core.DateTime(2015, 4, 15, 0, 0, 0, 0);
      Assert.AreEqual(bcl, noda.ToDateTimeUnspecified());
    },

    'FromDateTime': (args) {
      var expected = LocalDate(2011, 08, 18);
      // noda_dart: DateTimeKind's values are Dart's isUtc false (Unspecified, Local) and true (Utc).
      for (var isUtc in [false, true]) {
        var bcl = isUtc ? core.DateTime.utc(2011, 08, 18, 20, 53, 0) : core.DateTime(2011, 08, 18, 20, 53, 0);
        var actual = LocalDate.FromDateTime(bcl);
        Assert.AreEqual(expected, actual);
      }
    },

    'FromDateTime_WithCalendar': (args) {
      // Julian calendar is 13 days behind Gregorian calendar in the 21st century
      var expected = LocalDate(2011, 08, 05, CalendarSystem.Julian);
      for (var isUtc in [false, true]) {
        var bcl = isUtc ? core.DateTime.utc(2011, 08, 18, 20, 53, 0) : core.DateTime(2011, 08, 18, 20, 53, 0);
        var actual = LocalDate.FromDateTime(bcl, CalendarSystem.Julian);
        Assert.AreEqual(expected, actual);
      }
    },

    'WithCalendar_OutOfRange': (args) {
      LocalDate start = LocalDate(1, 1, 1);
      Assert.Throws<RangeError>(() => start.WithCalendar(CalendarSystem.PersianSimple));
    },

    'WithCalendar_Unchanged': (args) {
      LocalDate isoEpoch = LocalDate(1970, 1, 1);
      LocalDate unchanged = isoEpoch.WithCalendar(CalendarSystem.Iso);
      Assert.AreEqual(isoEpoch.Year, unchanged.Year);
      Assert.AreEqual(isoEpoch.Month, unchanged.Month);
      Assert.AreEqual(isoEpoch.Day, unchanged.Day);
      Assert.AreSame(isoEpoch.Calendar, unchanged.Calendar);
    },
    // #endregion

    // #region LocalDateTest.cs
    'CombinationWithTime': (args) {
      // Test all three approaches in the same test - they're logically equivalent.
      var calendar = CalendarSystem.Julian;
      LocalDate date = LocalDate(2014, 3, 28, calendar);
      LocalTime time = LocalTime(20, 17, 30);
      LocalDateTime expected = LocalDateTime.YearMonthDayHourMinuteSecondCalendar(2014, 3, 28, 20, 17, 30, calendar);
      // noda_dart: C#'s operator +(LocalDate, LocalTime) is At (Dart's + takes the Period overload).
      Assert.AreEqual(expected, date.At(time));
      Assert.AreEqual(expected, date.At(time));
      Assert.AreEqual(expected, time.On(date));
    },

    'MaxIsoValue': (args) {
      var value = LocalDate.MaxIsoValue;
      Assert.AreEqual(CalendarSystem.Iso, value.Calendar);
      Assert.Throws<OverflowException>(() => value.PlusDays(1));
    },

    'MinIsoValue': (args) {
      var value = LocalDate.MinIsoValue;
      Assert.AreEqual(CalendarSystem.Iso, value.Calendar);
      Assert.Throws<OverflowException>(() => value.PlusDays(-1));
    },

    'Deconstruction': (args) {
      var value = LocalDate(2017, 11, 7);
      var expectedYear = 2017;
      var expectedMonth = 11;
      var expectedDay = 7;
      var (actualYear, actualMonth, actualDay) = value.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(expectedYear, actualYear);
        Assert.AreEqual(expectedMonth, actualMonth);
        Assert.AreEqual(expectedDay, actualDay);
      });
    },

    'Deconstruction_IncludingCalendar': (args) {
      var value = LocalDate(2017, 11, 7, CalendarSystem.Gregorian);
      var expectedYear = 2017;
      var expectedMonth = 11;
      var expectedDay = 7;
      var expectedCalendar = CalendarSystem.Gregorian;
      var (actualYear, actualMonth, actualDay, actualCalendar) = value.DeconstructCalendarSystem;

      Assert.Multiple(() {
        Assert.AreEqual(expectedYear, actualYear);
        Assert.AreEqual(expectedMonth, actualMonth);
        Assert.AreEqual(expectedDay, actualDay);
        Assert.AreEqual(expectedCalendar, actualCalendar);
      });
    },
    // #endregion

    // #region LocalDateTest.PeriodArithmetic.cs
    'Addition_WithPeriod': (args) {
      LocalDate start = LocalDate(2010, 6, 19);
      Period period = Period.FromMonths(3) + Period.FromDays(10);
      LocalDate expected = LocalDate(2010, 9, 29);
      Assert.AreEqual(expected, start + period);
    },

    'Addition_TruncatesOnShortMonth': (args) {
      LocalDate start = LocalDate(2010, 1, 30);
      Period period = Period.FromMonths(1);
      LocalDate expected = LocalDate(2010, 2, 28);
      Assert.AreEqual(expected, start + period);
    },

    'Subtraction_WithPeriod': (args) {
      LocalDate start = LocalDate(2010, 9, 29);
      Period period = Period.FromMonths(3) + Period.FromDays(10);
      LocalDate expected = LocalDate(2010, 6, 19);
      Assert.AreEqual(expected, start - period);
    },

    'Subtraction_TruncatesOnShortMonth': (args) {
      LocalDate start = LocalDate(2010, 3, 30);
      Period period = Period.FromMonths(1);
      LocalDate expected = LocalDate(2010, 2, 28);
      Assert.AreEqual(expected, start - period);
    },

    'Addition_PeriodWithTime': (args) {
      LocalDate date = LocalDate(2010, 1, 1);
      Period period = Period.FromHours(1);
      // Use method not operator here to form a valid statement
      Assert.Throws<ArgumentError>(() => LocalDate.Add(date, period));
    },

    'Subtraction_PeriodWithTime': (args) {
      LocalDate date = LocalDate(2010, 1, 1);
      Period period = Period.FromHours(1);
      // Use method not operator here to form a valid statement
      Assert.Throws<ArgumentError>(() => LocalDate.Subtract(date, period));
    },

    'PeriodAddition_MethodEquivalents': (args) {
      LocalDate start = LocalDate(2010, 6, 19);
      Period period = Period.FromMonths(3) + Period.FromDays(10);
      Assert.AreEqual(start + period, LocalDate.Add(start, period));
      Assert.AreEqual(start + period, start.Plus(period));
    },

    'PeriodSubtraction_MethodEquivalents': (args) {
      LocalDate start = LocalDate(2010, 6, 19);
      Period period = Period.FromMonths(3) + Period.FromDays(10);
      LocalDate end = start + period;
      Assert.AreEqual(start - period, LocalDate.Subtract(start, period));
      Assert.AreEqual(start - period, start.Minus(period));
      Assert.AreEqual(period, LocalDate.SubtractLocalDate(end, start));
      Assert.AreEqual(period, LocalDate.SubtractLocalDate(end, start));
      Assert.AreEqual(period, end.MinusLocalDate(start));
    },

    'PlusMonths_Overflow': (args) {
      final [int year, int month, int day, int monthsToAdd] = args;
      var start = LocalDate(year, month, day);
      Assert.Throws<OverflowException>(() => start.PlusMonths(monthsToAdd));
    },
    // #endregion

    // #region LocalDateTest.Pseudomutators.cs
    'PlusYears_Simple': (args) {
      LocalDate start = LocalDate(2011, 6, 26);
      LocalDate expected = LocalDate(2016, 6, 26);
      Assert.AreEqual(expected, start.PlusYears(5));

      expected = LocalDate(2006, 6, 26);
      Assert.AreEqual(expected, start.PlusYears(-5));
    },

    'PlusYears_LeapToNonLeap': (args) {
      LocalDate start = LocalDate(2012, 2, 29);
      LocalDate expected = LocalDate(2013, 2, 28);
      Assert.AreEqual(expected, start.PlusYears(1));

      expected = LocalDate(2011, 2, 28);
      Assert.AreEqual(expected, start.PlusYears(-1));
    },

    'PlusYears_LeapToLeap': (args) {
      LocalDate start = LocalDate(2012, 2, 29);
      LocalDate expected = LocalDate(2016, 2, 29);
      Assert.AreEqual(expected, start.PlusYears(4));
    },

    'PlusMonths_Simple': (args) {
      LocalDate start = LocalDate(2012, 4, 15);
      LocalDate expected = LocalDate(2012, 8, 15);
      Assert.AreEqual(expected, start.PlusMonths(4));
    },

    'PlusMonths_ChangingYear': (args) {
      LocalDate start = LocalDate(2012, 10, 15);
      LocalDate expected = LocalDate(2013, 2, 15);
      Assert.AreEqual(expected, start.PlusMonths(4));
    },

    'PlusMonths_WithTruncation': (args) {
      LocalDate start = LocalDate(2011, 1, 30);
      LocalDate expected = LocalDate(2011, 2, 28);
      Assert.AreEqual(expected, start.PlusMonths(1));
    },

    // See https://github.com/nodatime/nodatime/issues/1906
    // This ends up being a problem in RegularYearMonthCalendar, but this is a simpler place to collect
    // test cases.
    'PlusMonths_OutOfRange': (args) {
      final [int year, int month, int calendarOrdinal, int months] = args;
      var calendar = CalendarSystem.ForOrdinal(CalendarOrdinal(calendarOrdinal));
      var date = LocalDate(year, month, 1, calendar);
      // Arguably ArgumentOutOfRangeException would be better in this specific
      // case, but there may be other cases ending up at the same check,
      // where OverflowException is better. The existing code "tried" to throw
      // OverflowException, so in cases where we weren't already failing for
      // whatever reason, we're keeping the original behavior.
      Assert.Throws<OverflowException>(() => date.PlusMonths(months));
    },

    'PlusDays_SameMonth': (args) {
      LocalDate start = LocalDate(2011, 1, 15);
      LocalDate expected = LocalDate(2011, 1, 23);
      Assert.AreEqual(expected, start.PlusDays(8));

      expected = LocalDate(2011, 1, 7);
      Assert.AreEqual(expected, start.PlusDays(-8));
    },

    'PlusDays_MonthBoundary': (args) {
      LocalDate start = LocalDate(2011, 1, 26);
      LocalDate expected = LocalDate(2011, 2, 3);
      Assert.AreEqual(expected, start.PlusDays(8));

      // Round-trip back across the boundary
      Assert.AreEqual(start, start.PlusDays(8).PlusDays(-8));
    },

    'PlusDays_YearBoundary': (args) {
      LocalDate start = LocalDate(2011, 12, 26);
      LocalDate expected = LocalDate(2012, 1, 3);
      Assert.AreEqual(expected, start.PlusDays(8));

      // Round-trip back across the boundary
      Assert.AreEqual(start, start.PlusDays(8).PlusDays(-8));
    },

    'PlusDays_EndOfFebruary_InLeapYear': (args) {
      LocalDate start = LocalDate(2012, 2, 26);
      LocalDate expected = LocalDate(2012, 3, 5);
      Assert.AreEqual(expected, start.PlusDays(8));
      // Round-trip back across the boundary
      Assert.AreEqual(start, start.PlusDays(8).PlusDays(-8));
    },

    'PlusDays_EndOfFebruary_NotInLeapYear': (args) {
      LocalDate start = LocalDate(2011, 2, 26);
      LocalDate expected = LocalDate(2011, 3, 6);
      Assert.AreEqual(expected, start.PlusDays(8));

      // Round-trip back across the boundary
      Assert.AreEqual(start, start.PlusDays(8).PlusDays(-8));
    },

    'PlusDays_LargeValue': (args) {
      LocalDate start = LocalDate(2013, 2, 26);
      LocalDate expected = LocalDate(2015, 2, 26);
      Assert.AreEqual(expected, start.PlusDays(365 * 2));
    },

    'PlusWeeks_Simple': (args) {
      LocalDate start = LocalDate(2011, 4, 2);
      LocalDate expectedForward = LocalDate(2011, 4, 23);
      LocalDate expectedBackward = LocalDate(2011, 3, 12);
      Assert.AreEqual(expectedForward, start.PlusWeeks(3));
      Assert.AreEqual(expectedBackward, start.PlusWeeks(-3));
    },

    'PlusDays_OutOfRange': (args) {
      final [int year, int month, int day, int days] = args;
      var start = LocalDate(year, month, day);
      TestHelper.AssertOverflow(start.PlusDays, days);
    },

    // Each test case gives a day-of-month in November 2011 and a target "next day of week";
    // the result is the next day-of-month in November 2011 with that target day.
    // The tests are picked somewhat arbitrarily...
    'Next': (args) {
      final [int dayOfMonth, IsoDayOfWeek targetDayOfWeek] = args;
      LocalDate start = LocalDate(2011, 11, dayOfMonth);
      LocalDate target = start.Next(targetDayOfWeek);
      Assert.AreEqual(2011, target.Year);
      Assert.AreEqual(11, target.Month);
      return target.Day;
    },

    'Next_InvalidArgument': (args) {
      final [IsoDayOfWeek targetDayOfWeek] = args;
      LocalDate start = LocalDate(2011, 1, 1);
      Assert.Throws<RangeError>(() => start.Next(targetDayOfWeek));
    },

    // Each test case gives a day-of-month in November 2011 and a target "next day of week";
    // the result is the next day-of-month in November 2011 with that target day.
    'Previous': (args) {
      final [int dayOfMonth, IsoDayOfWeek targetDayOfWeek] = args;
      LocalDate start = LocalDate(2011, 11, dayOfMonth);
      LocalDate target = start.Previous(targetDayOfWeek);
      Assert.AreEqual(2011, target.Year);
      Assert.AreEqual(11, target.Month);
      return target.Day;
    },

    'Previous_InvalidArgument': (args) {
      final [IsoDayOfWeek targetDayOfWeek] = args;
      LocalDate start = LocalDate(2011, 1, 1);
      Assert.Throws<RangeError>(() => start.Previous(targetDayOfWeek));
    },

    // No tests for non-ISO-day-of-week calendars as we don't have any yet.

    'With': (args) {
      LocalDate start = LocalDate(2014, 6, 27);
      LocalDate expected = LocalDate(2014, 6, 30);
      Assert.AreEqual(expected, start.With(DateAdjusters.EndOfMonth));
    },
    // #endregion
  }, skip: {
    'ToDateOnly_Gregorian': SkipReasons.DateOnlyTimeOnly,
    'ToDateOnly_NonGregorian': SkipReasons.DateOnlyTimeOnly,
    'ToDateOnly_OutOfRange': SkipReasons.DateOnlyTimeOnly,
    'FromDateOnly': SkipReasons.DateOnlyTimeOnly,
    'DefaultConstructor': SkipReasons.DefaultConstructor,
    'XmlSerialization_Iso': SkipReasons.Xml,
    'XmlSerialization_NonIso': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
    'Construction_NullCalendar_Throws': "null safety: the calendar parameter is optional in Dart (null means ISO)",
    'Addition_WithNullPeriod_ThrowsArgumentNullException': SkipReasons.NullSafety,
    'Subtraction_WithNullPeriod_ThrowsArgumentNullException': SkipReasons.NullSafety,
  });
}
