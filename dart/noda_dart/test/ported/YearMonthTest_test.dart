// Ported from NodaTime 6e024dde: src/NodaTime.Test/YearMonthTest.cs (+ YearMonthTest.BasicProperties.cs,
// YearMonthTest.Comparison.cs, YearMonthTest.Construction.cs, YearMonthTest.Misc.cs, YearMonthTest.XmlSerialization.cs)
// Copyright 2019 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarOrdinal.generated.dart';
import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/Calendars/IslamicEpoch.generated.dart';
import 'package:noda_dart/src/Calendars/IslamicLeapYearPattern.generated.dart';
import 'package:noda_dart/src/DateInterval.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/YearMonth.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/YearMonthTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    // #region YearMonthTest.BasicProperties.cs
    'Properties': (args) {
      // Some of these are covered in other tests too, but it doesn't hurt
      // to repeat ourselves here.
      var yearMonth = YearMonth(2000, 1);
      Assert.AreEqual(2000, yearMonth.Year);
      Assert.AreEqual(1, yearMonth.Month);
      Assert.AreEqual(CalendarSystem.Iso, yearMonth.Calendar);
      Assert.AreEqual(2000, yearMonth.YearOfEra);
      Assert.AreEqual(Era.Common, yearMonth.Era);

      Assert.AreEqual(LocalDate(2000, 1, 1), yearMonth.StartDate);
      Assert.AreEqual(LocalDate(2000, 1, 31), yearMonth.EndDate);
    },

    'ToDateInterval': (args) {
      var yearMonth = YearMonth(2000, 1);

      var interval = DateInterval(LocalDate(2000, 1, 1), LocalDate(2000, 1, 31));
      Assert.AreEqual(interval, yearMonth.ToDateInterval());
    },
    // #endregion

    // #region YearMonthTest.Comparison.cs
    // These tests were copied from LocalDateTest and then modified for YearMonth.

    'Equals_EqualValues': (args) {
      CalendarSystem calendar = CalendarSystem.Julian;
      YearMonth yearMonth1 = YearMonth(2011, 1, calendar);
      YearMonth yearMonth2 = YearMonth(2011, 1, calendar);
      Assert.AreEqual(yearMonth1, yearMonth2);
      Assert.AreEqual(yearMonth1.hashCode, yearMonth2.hashCode);
      Assert.IsTrue(yearMonth1 == yearMonth2);
      Assert.IsFalse(yearMonth1 != yearMonth2);
      Assert.IsTrue(yearMonth1.Equals(yearMonth2)); // IEquatable implementation
    },

    'Equals_DifferentMonths': (args) {
      CalendarSystem calendar = CalendarSystem.Julian;
      YearMonth yearMonth1 = YearMonth(2011, 1, calendar);
      YearMonth yearMonth2 = YearMonth(2011, 2, calendar);
      Assert.AreNotEqual(yearMonth1, yearMonth2);
      Assert.AreNotEqual(yearMonth1.hashCode, yearMonth2.hashCode);
      Assert.IsFalse(yearMonth1 == yearMonth2);
      Assert.IsTrue(yearMonth1 != yearMonth2);
      Assert.IsFalse(yearMonth1.Equals(yearMonth2)); // IEquatable implementation
    },

    'Equals_DifferentCalendars': (args) {
      CalendarSystem calendar = CalendarSystem.Julian;
      YearMonth yearMonth1 = YearMonth(2011, 1, calendar);
      YearMonth yearMonth2 = YearMonth(2011, 1, CalendarSystem.Iso);
      Assert.AreNotEqual(yearMonth1, yearMonth2);
      Assert.AreNotEqual(yearMonth1.hashCode, yearMonth2.hashCode);
      Assert.IsFalse(yearMonth1 == yearMonth2);
      Assert.IsTrue(yearMonth1 != yearMonth2);
      Assert.IsFalse(yearMonth1.Equals(yearMonth2)); // IEquatable implementation
    },

    'Equals_DifferentToNull': (args) {
      YearMonth date = YearMonth(2011, 1);
      // noda_dart: C#'s Equals(object) with null is Dart's == with null.
      Object? other;
      Assert.IsFalse(date == other);
    },

    'Equals_DifferentToOtherType': (args) {
      YearMonth date = YearMonth(2011, 1);
      // noda_dart: C#'s Equals(object) is Dart's ==.
      // ignore: unrelated_type_equality_checks
      Assert.IsFalse(date == Instant.FromUnixTimeTicks(0));
    },

    'CompareTo_SameCalendar': (args) {
      YearMonth yearMonth1 = YearMonth(2011, 1);
      YearMonth yearMonth2 = YearMonth(2011, 1);
      YearMonth yearMonth3 = YearMonth(2011, 2);

      TestHelper.TestOperatorComparisonEquality(yearMonth1, yearMonth2, [yearMonth3]);
    },

    'CompareTo_DifferentCalendars_Throws': (args) {
      CalendarSystem islamic = CalendarSystem.GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical);
      YearMonth yearMonth1 = YearMonth(2011, 1);
      YearMonth yearMonth2 = YearMonth(1500, 1, islamic);

      Assert.Throws<ArgumentError>(() => yearMonth1.compareTo(yearMonth2));
      Assert.Throws<ArgumentError>(() => yearMonth1.CompareTo(yearMonth2));
      Assert.Throws<ArgumentError>(() => (yearMonth1 > yearMonth2).toString());
    },

    /// IComparable.CompareTo works properly with YearMonth inputs with same calendar.
    'IComparableCompareTo_SameCalendar': (args) {
      var instance = YearMonth(2012, 3);
      var i_instance = instance;

      var later = YearMonth(2012, 6);
      var earlier = YearMonth(2012, 1);
      var same = YearMonth(2012, 3);

      Assert.That(i_instance.CompareTo(later), Is.LessThan(0));
      Assert.That(i_instance.CompareTo(earlier), Is.GreaterThan(0));
      Assert.That(i_instance.CompareTo(same), Is.EqualTo(0));
    },

    /// IComparable.CompareTo returns a positive number for a null input.
    'IComparableCompareTo_Null_Positive': (args) {
      var instance = YearMonth(2012, 3);
      var comparable = instance;
      var result = comparable.CompareTo(null);
      Assert.Greater(result, 0);
    },

    /// IComparable.CompareTo throws an ArgumentException for non-null arguments
    /// that are not a YearMonth.
    'IComparableCompareTo_WrongType_ArgumentException': (args) {
      var instance = YearMonth(2012, 3);
      var i_instance = instance;
      var arg = LocalDateTime(2012, 3, 6, 15, 42);
      Assert.Throws<ArgumentError>(() {
        i_instance.CompareTo(arg);
      });
    },
    // #endregion

    // #region YearMonthTest.Construction.cs
    'ValidConstruction': (args) {
      final [int year, int month] = args;
      var yearMonth = YearMonth(year, month);
      Assert.AreEqual(year, yearMonth.Year);
      Assert.AreEqual(month, yearMonth.Month);
      Assert.AreEqual(CalendarSystem.Iso, yearMonth.Calendar);
    },

    'InvalidConstruction': (args) {
      final [int year, int month] = args;
      Assert.Throws<RangeError>(() => YearMonth(year, month));
    },

    'ValidConstruction_WithCalendar': (args) {
      final [int year, int month, int ordinal] = args;
      CalendarSystem calendar = CalendarSystem.ForOrdinal(CalendarOrdinal(ordinal));
      var yearMonth = YearMonth(year, month, calendar);
      Assert.AreEqual(year, yearMonth.Year);
      Assert.AreEqual(month, yearMonth.Month);
      Assert.AreEqual(calendar, yearMonth.Calendar);
    },

    'InvalidConstruction_WithCalendar': (args) {
      final [int year, int month, int ordinal] = args;
      CalendarSystem calendar = CalendarSystem.ForOrdinal(CalendarOrdinal(ordinal));
      Assert.Throws<RangeError>(() => YearMonth(year, month, calendar));
    },

    'ValidConstruction_WithIsoEra': (args) {
      final [int yearOfEra, int month, String eraName] = args;
      Era era = GetEra(eraName);
      var yearMonth = YearMonth.EraYearOfEraMonth(era, yearOfEra, month);
      Assert.AreEqual(era, yearMonth.Era);
      Assert.AreEqual(yearOfEra, yearMonth.YearOfEra);
      Assert.AreEqual(month, yearMonth.Month);
      Assert.AreEqual(CalendarSystem.Iso, yearMonth.Calendar);
    },

    'InvalidConstruction_WithIsoEra': (args) {
      final [int yearOfEra, int month, String eraName] = args;
      Era era = GetEra(eraName);
      // We'll assume it throws the correct exact exception type. It varies by test case.
      Assert.That(() => YearMonth.EraYearOfEraMonth(era, yearOfEra, month), Throws.InstanceOf<ArgumentError>());
    },

    'ValidConstruction_WithEraAndCalendar': (args) {
      final [int yearOfEra, int month, String eraName, int calendarOrdinal] = args;
      Era era = GetEra(eraName);
      CalendarSystem calendar = CalendarSystem.ForOrdinal(CalendarOrdinal(calendarOrdinal));
      var yearMonth = YearMonth.EraYearOfEraMonth(era, yearOfEra, month, calendar);
      Assert.AreEqual(era, yearMonth.Era);
      Assert.AreEqual(yearOfEra, yearMonth.YearOfEra);
      Assert.AreEqual(month, yearMonth.Month);
      Assert.AreEqual(calendar, yearMonth.Calendar);
    },

    'InvalidConstruction_WithEraAndCalendar': (args) {
      final [int yearOfEra, int month, String eraName, int calendarOrdinal] = args;
      Era era = GetEra(eraName);
      CalendarSystem calendar = CalendarSystem.ForOrdinal(CalendarOrdinal(calendarOrdinal));
      // We'll assume it throws the correct exact exception type. It varies by test case.
      Assert.That(() => YearMonth.EraYearOfEraMonth(era, yearOfEra, month, calendar), Throws.InstanceOf<ArgumentError>());
    },
    // #endregion

    // #region YearMonthTest.Misc.cs
    'OnDayOfMonth_Valid': (args) {
      final [int calendarOrdinal, int year, int month, int day] = args;
      var calendar = CalendarSystem.ForOrdinal(CalendarOrdinal(calendarOrdinal));
      var yearMonth = YearMonth(year, month, calendar);
      var actualDate = yearMonth.OnDayOfMonth(day);
      var expectedDate = LocalDate(year, month, day, calendar);
      Assert.AreEqual(expectedDate, actualDate);
    },

    'OnDayOfMonth_Invalid': (args) {
      final [int calendarOrdinal, int year, int month, int day] = args;
      var calendar = CalendarSystem.ForOrdinal(CalendarOrdinal(calendarOrdinal));
      var yearMonth = YearMonth(year, month, calendar);
      Assert.Throws<RangeError>(() => yearMonth.OnDayOfMonth(day));
    },

    'PlusMonths': (args) {
      final [int year, int month, int monthsToAdd, int expectedYear, int expectedMonth] = args;
      var yearMonth = YearMonth(year, month);
      var expected = YearMonth(expectedYear, expectedMonth);
      Assert.AreEqual(expected, yearMonth.PlusMonths(monthsToAdd));
    },
    // #endregion
  }, skip: {
    // YearMonthTest.Misc.cs
    'ToStringTest_Iso': SkipReasons.CurrentCulture,
    'ToStringBclEquality': SkipReasons.BclFormatting,
    // YearMonthTest.XmlSerialization.cs
    'XmlSerialization_Iso': SkipReasons.Xml,
    'XmlSerialization_NonIso': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
  });
}

// We may want to put this somewhere in the production code; I'm surprised we
// haven't needed it before.
// noda_dart: C# looks the era up by reflection over Era's public static properties; Dart lists them.
Era GetEra(String eraName) {
  return switch (eraName) {
    'Common' => Era.Common,
    'BeforeCommon' => Era.BeforeCommon,
    'AnnoMartyrum' => Era.AnnoMartyrum,
    'AnnoHegirae' => Era.AnnoHegirae,
    'AnnoMundi' => Era.AnnoMundi,
    'AnnoPersico' => Era.AnnoPersico,
    'Bahai' => Era.Bahai,
    _ => throw ArgumentError.value(eraName, 'eraName'),
  };
}
