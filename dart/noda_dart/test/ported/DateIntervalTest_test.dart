// Ported from NodaTime 6e024dde: src/NodaTime.Test/DateIntervalTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: C#'s Contains(DateInterval) overload is ContainsDateInterval; Deconstruct is a getter returning a record.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/DateInterval.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/Text/LocalDatePattern.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../scenarios/DateIntervalTest.generated.dart' as scenarios;

final CalendarSystem JulianCalendar = CalendarSystem.Julian;

void main() {
  port(scenarios.fixture, {
    'Construction_DifferentCalendars': (args) {
      LocalDate start = LocalDate(1600, 1, 1);
      LocalDate end = LocalDate(1800, 1, 1, JulianCalendar);
      Assert.Throws<ArgumentError>(() => DateInterval(start, end));
    },

    'Construction_EndBeforeStart': (args) {
      LocalDate start = LocalDate(1600, 1, 1);
      LocalDate end = LocalDate(1500, 1, 1);
      Assert.Throws<ArgumentError>(() => DateInterval(start, end));
    },

    'Construction_EqualStartAndEnd': (args) {
      LocalDate start = LocalDate(2000, 1, 1);
      Assert.DoesNotThrow(() => DateInterval(start, start));
    },

    'Construction_Properties': (args) {
      LocalDate start = LocalDate(2000, 1, 1);
      LocalDate end = LocalDate(2001, 6, 19);
      var interval = DateInterval(start, end);
      Assert.AreEqual(start, interval.Start);
      Assert.AreEqual(end, interval.End);
    },

    'Equals': (args) {
      LocalDate start = LocalDate(2000, 1, 1);
      LocalDate end = LocalDate(2001, 6, 19);
      var interval = DateInterval(start, end);
      var equalInterval = DateInterval(start, end);
      var unequalIntervals = [
        DateInterval(start.PlusDays(1), end),
        DateInterval(start, end.PlusDays(1)),
        // This is a really, really similar calendar to ISO, but we do distinguish.
        // (The calendar system has to be the same for the start and end, so we don't
        // need to perform start-different vs end-different equality tests.)
        DateInterval(start.WithCalendar(CalendarSystem.Gregorian), end.WithCalendar(CalendarSystem.Gregorian)),
      ];
      TestHelper.TestEqualsClass(interval, equalInterval, unequalIntervals);

      Assert.IsTrue(interval == equalInterval);
      Assert.IsFalse(interval != equalInterval);

      // noda_dart: a null of the nullable static type, so the analyzer doesn't fold the comparisons.
      DateInterval? nullInterval = NullInterval();
      Assert.IsFalse(interval == nullInterval);
      Assert.IsTrue(interval != nullInterval);
      Assert.IsFalse(nullInterval == interval);
      Assert.IsTrue(nullInterval != interval);

      for (var unequalInterval in unequalIntervals) {
        Assert.IsFalse(interval == unequalInterval);
        Assert.IsTrue(interval != unequalInterval);
      }
    },

    'StringRepresentation': (args) {
      LocalDate start = LocalDate(2000, 1, 1);
      LocalDate end = LocalDate(2001, 6, 19);
      var interval = DateInterval(start, end);
      Assert.AreEqual('[2000-01-01, 2001-06-19]', interval.toString());
    },

    'Length': (args) {
      LocalDate start = LocalDate(2000, 1, 1);
      LocalDate end = LocalDate(2000, 2, 10);
      var interval = DateInterval(start, end);
      Assert.AreEqual(41, interval.Length);
    },

    'Calendar': (args) {
      var calendar = CalendarSystem.Julian;
      LocalDate start = LocalDate(2000, 1, 1, calendar);
      LocalDate end = LocalDate(2000, 2, 10, calendar);
      var interval = DateInterval(start, end);
      Assert.AreEqual(calendar, interval.Calendar);
    },

    'Contains': (args) {
      final [String candidateText, bool expected] = args;
      var start = LocalDate(2000, 1, 1);
      var end = LocalDate(2014, 06, 30);
      var candidate = LocalDatePattern.Iso.Parse(candidateText).Value;
      var interval = DateInterval(start, end);
      Assert.AreEqual(expected, interval.Contains(candidate));
    },

    'Contains_DifferentCalendar': (args) {
      var start = LocalDate(2000, 1, 1);
      var end = LocalDate(2014, 06, 30);
      var interval = DateInterval(start, end);
      var candidate = LocalDate(2000, 1, 1, JulianCalendar);
      Assert.Throws<ArgumentError>(() => interval.Contains(candidate));
    },

    'Deconstruction': (args) {
      var start = LocalDate(2017, 11, 6);
      var end = LocalDate(2017, 11, 10);
      var value = DateInterval(start, end);

      var (actualStart, actualEnd) = value.Deconstruct;

      Assert.Multiple(() {
        Assert.AreEqual(start, actualStart);
        Assert.AreEqual(end, actualEnd);
      });
    },

    'Contains_IntervalWithinAnotherCalendar_Throws': (args) {
      var value = DateInterval(
          LocalDate(2017, 11, 6, CalendarSystem.Gregorian),
          LocalDate(2017, 11, 10, CalendarSystem.Gregorian));

      var other = DateInterval(
          LocalDate(2017, 11, 6, CalendarSystem.Coptic),
          LocalDate(2017, 11, 10, CalendarSystem.Coptic));

      Assert.Throws<ArgumentError>(() => value.ContainsDateInterval(other));
    },

    'Contains_IntervalOverload': (args) {
      final [String firstInterval, String secondInterval, bool expectedResult] = args;
      DateInterval value = ParseInterval(firstInterval);
      DateInterval other = ParseInterval(secondInterval);
      Assert.AreEqual(expectedResult, value.ContainsDateInterval(other));
    },

    'Intersection_IntervalInDifferentCalendar_Throws': (args) {
      var value = DateInterval(
          LocalDate(2017, 11, 6, CalendarSystem.Gregorian),
          LocalDate(2017, 11, 10, CalendarSystem.Gregorian));

      var other = DateInterval(
          LocalDate(2017, 11, 6, CalendarSystem.Coptic),
          LocalDate(2017, 11, 10, CalendarSystem.Coptic));

      Assert.Throws<ArgumentError>(() => value.Intersection(other));
    },

    'Intersection': (args) {
      final [String firstInterval, String secondInterval, String? expectedInterval] = args;
      var value = ParseInterval(firstInterval);
      var other = ParseInterval(secondInterval);
      var expectedResult = ParseIntervalOrNull(expectedInterval);
      Assert.AreEqual(expectedResult, value.Intersection(other));
    },

    'Union_DifferentCalendar_Throws': (args) {
      var value = DateInterval(
          LocalDate(2017, 11, 6, CalendarSystem.Gregorian),
          LocalDate(2017, 11, 10, CalendarSystem.Gregorian));

      var other = DateInterval(
          LocalDate(2017, 11, 6, CalendarSystem.Coptic),
          LocalDate(2017, 11, 10, CalendarSystem.Coptic));

      Assert.Throws<ArgumentError>(() => value.Union(other));
    },

    'Union': (args) {
      final [String first, String second, String? expected] = args;
      DateInterval firstInterval = ParseInterval(first);
      DateInterval secondInterval = ParseInterval(second);
      DateInterval? expectedResult = ParseIntervalOrNull(expected);

      Assert.Multiple(() {
        Assert.AreEqual(expectedResult, firstInterval.Union(secondInterval), 'First union failed.');
        Assert.AreEqual(expectedResult, secondInterval.Union(firstInterval), 'Second union failed.');
      });
    },

    'Iteration': (args) {
      final [String intervalText, List<dynamic> expectedDatesText] = args;
      var interval = ParseInterval(intervalText);
      var expected = expectedDatesText.cast<String>().map((x) => LocalDatePattern.Iso.Parse(x).Value).toList();
      var actual = interval.toList();
      Assert.AreEqual(expected, actual);

      // Test the non-generic version too. The double cast makes sure we use the right GetEnumerator call.
      actual = interval.cast<Object>().cast<LocalDate>().toList();
      Assert.AreEqual(expected, actual);
    },
  }, skip: {
    'Contains_NullInterval_Throws': SkipReasons.NullSafety,
    'Intersection_NullInterval_Throws': SkipReasons.NullSafety,
    'Union_NullInterval_Throws': SkipReasons.NullSafety,
  });
}

DateInterval? ParseIntervalOrNull(String? textualInterval) =>
    textualInterval == null ? null : ParseInterval(textualInterval);

DateInterval ParseInterval(String textualInterval) {
  var parts = textualInterval.split(',');
  var start = LocalDatePattern.Iso.Parse(parts[0]).Value;
  var end = LocalDatePattern.Iso.Parse(parts[1]).Value;

  return DateInterval(start, end);
}

// noda_dart: new code. A null DateInterval of the nullable static type (C#'s `interval == null`).
DateInterval? NullInterval() => null;
