// Ported from NodaTime 6e024dde: src/NodaTime.Test/DateAdjustersTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/DateAdjusters.dart';
import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/Period.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/DateAdjustersTest.generated.dart' as scenarios;

void main() {
  port(scenarios.fixture, {
    'StartOfMonth': (args) {
      var start = LocalDate(2014, 6, 27);
      var end = LocalDate(2014, 6, 1);
      Assert.AreEqual(end, DateAdjusters.StartOfMonth(start));
    },

    'EndOfMonth': (args) {
      var start = LocalDate(2014, 6, 27);
      var end = LocalDate(2014, 6, 30);
      Assert.AreEqual(end, DateAdjusters.EndOfMonth(start));
    },

    'DayOfMonth': (args) {
      var start = LocalDate(2014, 6, 27);
      var end = LocalDate(2014, 6, 19);
      var adjuster = DateAdjusters.DayOfMonth(19);
      Assert.AreEqual(end, adjuster(start));
    },

    'NextOrSame': (args) {
      final [int year, int month, int day, IsoDayOfWeek dayOfWeek, int expectedYear, int expectedMonth, int expectedDay] =
          args;
      LocalDate start = LocalDate(year, month, day);
      LocalDate actual = start.With(DateAdjusters.NextOrSame(dayOfWeek));
      LocalDate expected = LocalDate(expectedYear, expectedMonth, expectedDay);
      Assert.AreEqual(expected, actual);
    },

    'PreviousOrSame': (args) {
      final [int year, int month, int day, IsoDayOfWeek dayOfWeek, int expectedYear, int expectedMonth, int expectedDay] =
          args;
      LocalDate start = LocalDate(year, month, day);
      LocalDate actual = start.With(DateAdjusters.PreviousOrSame(dayOfWeek));
      LocalDate expected = LocalDate(expectedYear, expectedMonth, expectedDay);
      Assert.AreEqual(expected, actual);
    },

    'Next': (args) {
      final [int year, int month, int day, IsoDayOfWeek dayOfWeek, int expectedYear, int expectedMonth, int expectedDay] =
          args;
      LocalDate start = LocalDate(year, month, day);
      LocalDate actual = start.With(DateAdjusters.Next(dayOfWeek));
      LocalDate expected = LocalDate(expectedYear, expectedMonth, expectedDay);
      Assert.AreEqual(expected, actual);
    },

    'Previous': (args) {
      final [int year, int month, int day, IsoDayOfWeek dayOfWeek, int expectedYear, int expectedMonth, int expectedDay] =
          args;
      LocalDate start = LocalDate(year, month, day);
      LocalDate actual = start.With(DateAdjusters.Previous(dayOfWeek));
      LocalDate expected = LocalDate(expectedYear, expectedMonth, expectedDay);
      Assert.AreEqual(expected, actual);
    },

    'Month_Valid': (args) {
      var adjuster = DateAdjusters.Month(2);
      var start = LocalDate(2017, 8, 21, CalendarSystem.Julian);
      var actual = start.With(adjuster);
      var expected = LocalDate(2017, 2, 21, CalendarSystem.Julian);
      Assert.AreEqual(expected, actual);
    },

    'Month_InvalidAdjustment': (args) {
      var adjuster = DateAdjusters.Month(2);
      var start = LocalDate(2017, 8, 30, CalendarSystem.Julian);
      Assert.Throws<RangeError>(() => start.With(adjuster));
    },

    'IsoDayOfWeekAdjusters_TooLarge': (args) {
      var invalid = IsoDayOfWeek(IsoDayOfWeek.Sunday.value + 1);
      Assert.Throws<RangeError>(() => DateAdjusters.Next(invalid));
      Assert.Throws<RangeError>(() => DateAdjusters.NextOrSame(invalid));
      Assert.Throws<RangeError>(() => DateAdjusters.Previous(invalid));
      Assert.Throws<RangeError>(() => DateAdjusters.PreviousOrSame(invalid));
    },

    'IsoDayOfWeekAdjusters_TooSmall': (args) {
      var invalid = IsoDayOfWeek(IsoDayOfWeek.Monday.value - 1);
      Assert.Throws<RangeError>(() => DateAdjusters.Next(invalid));
      Assert.Throws<RangeError>(() => DateAdjusters.NextOrSame(invalid));
      Assert.Throws<RangeError>(() => DateAdjusters.Previous(invalid));
      Assert.Throws<RangeError>(() => DateAdjusters.PreviousOrSame(invalid));
    },

    'AddPeriod_Valid': (args) {
      var period = Period.FromMonths(1) + Period.FromDays(3);
      var adjuster = DateAdjusters.AddPeriod(period);
      var start = LocalDate(2019, 5, 4);
      Assert.AreEqual(LocalDate(2019, 6, 7), start.With(adjuster));
    },

    'AddPeriod_IncludingTimeUnits': (args) =>
        Assert.Throws<ArgumentError>(() => DateAdjusters.AddPeriod(Period.FromDays(1) + Period.FromHours(1))),
  }, skip: {
    'AddPeriod_Null': SkipReasons.NullSafety,
  });
}
