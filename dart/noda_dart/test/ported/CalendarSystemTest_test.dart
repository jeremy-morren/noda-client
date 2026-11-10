// Ported from NodaTime 6e024dde: src/NodaTime.Test/CalendarSystemTest.cs
// (+ CalendarSystemTest.Era.cs, CalendarSystemTest.Ids.cs, CalendarSystemTest.Validation.cs)
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarOrdinal.generated.dart';
import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/LocalDate.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/CalendarSystemTest.generated.dart' as scenarios;

// #region CalendarSystemTest.cs
final Iterable<String> SupportedIds = CalendarSystem.Ids.toList();
final List<CalendarSystem> SupportedCalendars = SupportedIds.map(CalendarSystem.ForId).toList();
// #endregion

// #region CalendarSystemTest.Era.cs
final CalendarSystem CopticCalendar = CalendarSystem.Coptic;
// #endregion

// #region CalendarSystemTest.Validation.cs
final CalendarSystem Iso = CalendarSystem.Iso;
// #endregion

void main() {
  port(scenarios.fixture, {
    // #region CalendarSystemTest.cs
    'MaxDate': (args) {
      final [CalendarSystem calendar] = args;
      // Construct the largest LocalDate we can, and validate that all the properties can be fetched without
      // issues.
      ValidateProperties(calendar, calendar.MaxDays, calendar.MaxYear);
    },

    'MinDate': (args) {
      final [CalendarSystem calendar] = args;
      // Construct the smallest LocalDate we can, and validate that all the properties can be fetched without
      // issues.
      ValidateProperties(calendar, calendar.MinDays, calendar.MinYear);
    },
    // #endregion

    // #region CalendarSystemTest.Era.cs
    // Tests using CopticCalendar as a simple example which doesn't override anything.
    'GetAbsoluteYear': (args) {
      Assert.AreEqual(5, CopticCalendar.GetAbsoluteYear(5, Era.AnnoMartyrum));
      // Prove it's right...
      LocalDate localDate = LocalDate(5, 1, 1, CopticCalendar);
      Assert.AreEqual(5, localDate.Year);
      Assert.AreEqual(5, localDate.YearOfEra);
      Assert.AreEqual(Era.AnnoMartyrum, localDate.Era);
    },

    'GetMinYearOfEra': (args) {
      Assert.AreEqual(1, CopticCalendar.GetMinYearOfEra(Era.AnnoMartyrum));
    },

    'GetMaxYearOfEra': (args) {
      Assert.AreEqual(CopticCalendar.MaxYear, CopticCalendar.GetMaxYearOfEra(Era.AnnoMartyrum));
    },
    // #endregion

    // #region CalendarSystemTest.Ids.cs
    'ValidId': (args) {
      final [String id] = args;
      Assert.IsInstanceOf<CalendarSystem>(CalendarSystem.ForId(id));
    },

    'IdsAreCaseSensitive': (args) {
      final [String id] = args;
      Assert.Throws<ArgumentError>(() => CalendarSystem.ForId(id.toLowerCase()));
    },

    'AllIdsGiveDifferentCalendars': (args) {
      var allCalendars = SupportedIds.map(CalendarSystem.ForId);
      Assert.AreEqual(SupportedIds.length, allCalendars.toSet().length);
    },

    'BadId': (args) {
      Assert.Throws<ArgumentError>(() => CalendarSystem.ForId('bad'));
    },

    'NoSubstrings': (args) {
          // noda_dart: CompareOptions.IgnoreCase on ASCII IDs: upper-cased prefixes.
      int Compare(String first, String second, int length) =>
          first.substring(0, length).toUpperCase().compareTo(second.substring(0, length).toUpperCase());
      for (var firstId in CalendarSystem.Ids) {
        for (var secondId in CalendarSystem.Ids) {
          // We're looking for firstId being a substring of secondId, which can only
          // happen if firstId is shorter...
          if (firstId.length >= secondId.length) {
            continue;
          }
          Assert.AreNotEqual(0, Compare(firstId, secondId, firstId.length), '$firstId is a leading substring of $secondId');
        }
      }
    },

    // Ordinals are similar enough to IDs to keep the tests in this file too...

    'ForOrdinal_Roundtrip': (args) {
      final [CalendarSystem calendar] = args;
      Assert.AreSame(calendar, CalendarSystem.ForOrdinal(calendar.Ordinal));
    },

    'ForOrdinalUncached_Roundtrip': (args) {
      final [CalendarSystem calendar] = args;
      Assert.AreSame(calendar, CalendarSystem.ForOrdinalUncached(calendar.Ordinal));
    },

    'ForOrdinalUncached_Invalid': (args) {
      Assert.Throws<StateError>(() => CalendarSystem.ForOrdinalUncached(CalendarOrdinal(9999)));
    },
    // #endregion

    // #region CalendarSystemTest.Validation.cs
    'GetMonthsInYear_Valid': (args) {
      final [int year] = args;
      TestHelper.AssertValid(Iso.GetMonthsInYear, year);
    },

    'GetMonthsInYear_Invalid': (args) {
      final [int year] = args;
      TestHelper.AssertOutOfRange(Iso.GetMonthsInYear, year);
    },

    'GetDaysInMonth_Valid': (args) {
      final [int year, int month] = args;
      TestHelper.AssertValid(Iso.GetDaysInMonth, year, month);
    },

    'GetDaysInMonth_Invalid': (args) {
      final [int year, int month] = args;
      TestHelper.AssertOutOfRange(Iso.GetDaysInMonth, year, month);
    },

    'GetDaysInMonth_Hebrew': (args) {
      TestHelper.AssertValid(CalendarSystem.HebrewCivil.GetDaysInMonth, 5402, 13); // Leap year
      TestHelper.AssertOutOfRange(CalendarSystem.HebrewCivil.GetDaysInMonth, 5401, 13); // Not a leap year
    },

    'IsLeapYear_Valid': (args) {
      final [int year] = args;
      TestHelper.AssertValid(Iso.IsLeapYear, year);
    },

    'IsLeapYear_Invalid': (args) {
      final [int year] = args;
      TestHelper.AssertOutOfRange(Iso.IsLeapYear, year);
    },

    'GetAbsoluteYear_ValidCe': (args) {
      final [int year] = args;
      TestHelper.AssertValid(Iso.GetAbsoluteYear, year, Era.Common);
    },

    'GetAbsoluteYear_ValidBce': (args) {
      final [int year] = args;
      TestHelper.AssertValid(Iso.GetAbsoluteYear, year, Era.BeforeCommon);
    },

    'GetAbsoluteYear_InvalidCe': (args) {
      final [int year] = args;
      TestHelper.AssertOutOfRange(Iso.GetAbsoluteYear, year, Era.Common);
    },

    'GetAbsoluteYear_InvalidBce': (args) {
      final [int year] = args;
      TestHelper.AssertOutOfRange(Iso.GetAbsoluteYear, year, Era.BeforeCommon);
    },

    'GetAbsoluteYear_InvalidEra': (args) {
      TestHelper.AssertInvalid(Iso.GetAbsoluteYear, 1, Era.AnnoPersico);
    },

    'GetMinYearOfEra_InvalidEra': (args) {
      TestHelper.AssertInvalid(Iso.GetMinYearOfEra, Era.AnnoPersico);
    },

    'GetMaxYearOfEra_InvalidEra': (args) {
      TestHelper.AssertInvalid(Iso.GetMaxYearOfEra, Era.AnnoPersico);
    },
    // #endregion
  }, skip: {
    'GetAbsoluteYear_NullEra': SkipReasons.NullSafety,
    'GetMinYearOfEra_NullEra': SkipReasons.NullSafety,
    'GetMaxYearOfEra_NullEra': SkipReasons.NullSafety,
  });
}

// #region CalendarSystemTest.cs
void ValidateProperties(CalendarSystem calendar, int daysSinceEpoch, int expectedYear) {
  var localDate = LocalDate.NewDaysSinceEpochCalendar(daysSinceEpoch, calendar);
  Assert.AreEqual(expectedYear, localDate.Year);

  // noda_dart: C# fetches every property LocalDate declares by reflection; they're listed here.
  for (var property in <Object? Function()>[
    () => LocalDate.MaxIsoValue,
    () => LocalDate.MinIsoValue,
    () => localDate.Calendar,
    () => localDate.Year,
    () => localDate.Month,
    () => localDate.Day,
    () => localDate.DaysSinceEpoch,
    () => localDate.DayOfWeek,
    () => localDate.YearOfEra,
    () => localDate.Era,
    () => localDate.DayOfYear,
    () => localDate.YearMonthDay,
  ]) {
    property();
  }
}
// #endregion
