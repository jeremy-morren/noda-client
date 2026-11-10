// Ported from NodaTime 6e024dde: src/NodaTime.Test/Calendars/IsoCalendarSystemTest.cs
// (+ IsoCalendarSystemTest.Era.cs, IsoCalendarSystemTest.FieldValidation.cs)
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: Dart's DateTime has microseconds, so TimeOfGreatAchievement's extra 8765 ticks are kept separately.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Calendars/Era.dart';
import 'package:noda_dart/src/Calendars/WeekYearRules.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalInstant.dart';
import 'package:noda_dart/src/NodaConstants.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Calendars/IsoCalendarSystemTest.generated.dart' as scenarios;

final core.DateTime UnixEpochDateTime = core.DateTime.utc(1970, 1, 1, 0, 0, 0);
// This was when I was writing the tests, having finally made everything work - several thousand lines
// of shockingly untested code.
// noda_dart: C#'s TimeOfGreatAchievement is this + TimeSpan.FromTicks(8765) (see TimeOfGreatAchievementTicks).
final core.DateTime TimeOfGreatAchievement = core.DateTime.utc(2009, 11, 27, 18, 38, 25, 345);
const int TimeOfGreatAchievementExtraTicks = 8765;

final CalendarSystem Iso = CalendarSystem.Iso;

void main() {
  port(scenarios.fixture, {
    // #region IsoCalendarSystemTest.cs
    'FieldsOf_UnixEpoch': (args) {
      // It's easiest to test this using a LocalDateTime in the ISO calendar system.
      // LocalDateTime just passes everything through anyway.
      LocalDateTime epoch = NodaConstants.UnixEpoch.InUtc().LocalDateTime;

      Assert.AreEqual(1970, epoch.Year);
      Assert.AreEqual(1970, epoch.YearOfEra);
      Assert.AreEqual(1970, WeekYearRules.Iso.GetWeekYear(epoch.Date));
      Assert.AreEqual(1, WeekYearRules.Iso.GetWeekOfWeekYear(epoch.Date));
      Assert.AreEqual(1, epoch.Month);
      Assert.AreEqual(1, epoch.Day);
      Assert.AreEqual(1, epoch.DayOfYear);
      Assert.AreEqual(IsoDayOfWeek.Thursday, epoch.DayOfWeek);
      Assert.AreEqual(Era.Common, epoch.Era);
      Assert.AreEqual(0, epoch.Hour);
      Assert.AreEqual(0, epoch.Minute);
      Assert.AreEqual(0, epoch.Second);
      Assert.AreEqual(0, epoch.Millisecond);
      Assert.AreEqual(0, epoch.TickOfDay);
      Assert.AreEqual(0, epoch.TickOfSecond);
    },

    'FieldsOf_GreatAchievement': (args) {
      LocalDateTime now = Instant.FromUnixTimeTicks(TimeOfGreatAchievementTicks()).InUtc().LocalDateTime;

      Assert.AreEqual(2009, now.Year);
      Assert.AreEqual(2009, now.YearOfEra);
      Assert.AreEqual(2009, WeekYearRules.Iso.GetWeekYear(now.Date));
      Assert.AreEqual(48, WeekYearRules.Iso.GetWeekOfWeekYear(now.Date));
      Assert.AreEqual(11, now.Month);
      Assert.AreEqual(27, now.Day);
      Assert.AreEqual(TimeOfGreatAchievementDayOfYear(), now.DayOfYear);
      Assert.AreEqual(IsoDayOfWeek.Friday, now.DayOfWeek);
      Assert.AreEqual(Era.Common, now.Era);
      Assert.AreEqual(18, now.Hour);
      Assert.AreEqual(38, now.Minute);
      Assert.AreEqual(25, now.Second);
      Assert.AreEqual(345, now.Millisecond);
      Assert.AreEqual(3458765, now.TickOfSecond);
      Assert.AreEqual(18 * NodaConstants.TicksPerHour +
                      38 * NodaConstants.TicksPerMinute +
                      25 * NodaConstants.TicksPerSecond +
                      3458765,
                      now.TickOfDay);
    },

    'ConstructLocalInstant_WithAllFields': (args) {
      LocalInstant localAchievement = LocalDateTime(2009, 11, 27, 18, 38, 25, 345).PlusTicks(8765).ToLocalInstant();
      int bclTicks = TimeOfGreatAchievementTicks();
      int bclDays = bclTicks ~/ NodaConstants.TicksPerDay;
      int bclTickOfDay = bclTicks.remainder(NodaConstants.TicksPerDay);
      Assert.AreEqual(bclDays, localAchievement.DaysSinceEpoch);
      Assert.AreEqual(bclTickOfDay, localAchievement.NanosecondOfDay ~/ NodaConstants.NanosecondsPerTick);
    },

    'IsLeapYear': (args) {
      Assert.IsTrue(CalendarSystem.Iso.IsLeapYear(2012)); // 4 year rule
      Assert.IsFalse(CalendarSystem.Iso.IsLeapYear(2011)); // 4 year rule
      Assert.IsFalse(CalendarSystem.Iso.IsLeapYear(2100)); // 100 year rule
      Assert.IsTrue(CalendarSystem.Iso.IsLeapYear(2000)); // 400 year rule
    },

    'GetDaysInMonth': (args) {
      Assert.AreEqual(30, CalendarSystem.Iso.GetDaysInMonth(2010, 9));
      Assert.AreEqual(31, CalendarSystem.Iso.GetDaysInMonth(2010, 1));
      Assert.AreEqual(28, CalendarSystem.Iso.GetDaysInMonth(2010, 2));
      Assert.AreEqual(29, CalendarSystem.Iso.GetDaysInMonth(2012, 2));
    },

    'BeforeCommonEra': (args) {
      // Year -1 in absolute terms is 2BCE
      LocalDate localDate = LocalDate(-1, 1, 1);
      Assert.AreEqual(Era.BeforeCommon, localDate.Era);
      Assert.AreEqual(-1, localDate.Year);
      Assert.AreEqual(2, localDate.YearOfEra);
    },

    'BeforeCommonEra_BySpecifyingEra': (args) {
      // Year -1 in absolute terms is 2BCE
      LocalDate localDate = LocalDate.EraYearOfEraMonthDay(Era.BeforeCommon, 2, 1, 1);
      Assert.AreEqual(Era.BeforeCommon, localDate.Era);
      Assert.AreEqual(-1, localDate.Year);
      Assert.AreEqual(2, localDate.YearOfEra);
    },
    // #endregion

    // #region IsoCalendarSystemTest.Era.cs
    'GetMaxYearOfEra': (args) {
      LocalDate date = LocalDate(Iso.MaxYear, 1, 1);
      Assert.AreEqual(date.YearOfEra, Iso.GetMaxYearOfEra(Era.Common));
      Assert.AreEqual(Era.Common, date.Era);
      date = LocalDate(Iso.MinYear, 1, 1);
      Assert.AreEqual(Iso.MinYear, date.Year);
      Assert.AreEqual(date.YearOfEra, Iso.GetMaxYearOfEra(Era.BeforeCommon));
      Assert.AreEqual(Era.BeforeCommon, date.Era);
    },

    'GetMinYearOfEra': (args) {
      LocalDate date = LocalDate(1, 1, 1);
      Assert.AreEqual(date.YearOfEra, Iso.GetMinYearOfEra(Era.Common));
      Assert.AreEqual(Era.Common, date.Era);
      date = LocalDate(0, 1, 1);
      Assert.AreEqual(date.YearOfEra, Iso.GetMinYearOfEra(Era.BeforeCommon));
      Assert.AreEqual(Era.BeforeCommon, date.Era);
    },

    'GetAbsoluteYear': (args) {
      Assert.AreEqual(1, Iso.GetAbsoluteYear(1, Era.Common));
      Assert.AreEqual(0, Iso.GetAbsoluteYear(1, Era.BeforeCommon));
      Assert.AreEqual(-1, Iso.GetAbsoluteYear(2, Era.BeforeCommon));
      Assert.AreEqual(Iso.MaxYear, Iso.GetAbsoluteYear(Iso.GetMaxYearOfEra(Era.Common), Era.Common));
      Assert.AreEqual(Iso.MinYear, Iso.GetAbsoluteYear(Iso.GetMaxYearOfEra(Era.BeforeCommon), Era.BeforeCommon));
    },
    // #endregion

    // #region IsoCalendarSystemTest.FieldValidation.cs
    // These tests assume that if the method doesn't throw, it's doing the right thing - this
    // is all tested elsewhere.
    'ValidateYearMonthDay_AllValues_ValidValuesDoesntThrow': (args) {
      Iso.ValidateYearMonthDay(20, 2, 20);
    },

    'ValidateYearMonthDay_InvalidYear_Throws': (args) {
      Assert.Throws<RangeError>(() => Iso.ValidateYearMonthDay(50000, 2, 20));
    },

    'GetLocalInstant_InvalidMonth_Throws': (args) {
      Assert.Throws<RangeError>(() => Iso.ValidateYearMonthDay(2010, 13, 20));
    },

    'GetLocalInstant_29thOfFebruaryInNonLeapYear_Throws': (args) {
      Assert.Throws<RangeError>(() => Iso.ValidateYearMonthDay(2010, 2, 29));
    },

    'GetLocalInstant_29thOfFebruaryInLeapYear_DoesntThrow': (args) {
      Iso.ValidateYearMonthDay(2012, 2, 29);
    },
    // #endregion
  }, skip: {
    // (TimeOfGreatAchievement - UnixEpochDateTime).Ticks is about 1.26e16, beyond 2^53.
    if (isDart2js) 'FieldsOf_GreatAchievement': SkipReasons.Dart2jsInt,
    if (isDart2js) 'ConstructLocalInstant_WithAllFields': SkipReasons.Dart2jsInt,
  });
}

/// noda_dart: C#'s (TimeOfGreatAchievement - UnixEpochDateTime).Ticks (a Dart Duration counts microseconds: 10 ticks).
int TimeOfGreatAchievementTicks() =>
    TimeOfGreatAchievement.difference(UnixEpochDateTime).inMicroseconds * 10 + TimeOfGreatAchievementExtraTicks;

/// noda_dart: C#'s TimeOfGreatAchievement.DayOfYear (Dart's DateTime has no day-of-year).
int TimeOfGreatAchievementDayOfYear() =>
    TimeOfGreatAchievement.difference(core.DateTime.utc(TimeOfGreatAchievement.year, 1, 1)).inDays + 1;
