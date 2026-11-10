// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/LocalDateTimePatternTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: NUnit's `Is.EqualTo(a) | Is.EqualTo(b)` is anyOf.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/InvalidPatternException.dart';
import 'package:noda_dart/src/Text/LocalDateTimePattern.dart';
import 'package:test/test.dart' show anyOf;

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/LocalDateTimePatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

final LocalDateTime SampleLocalDateTime = LocalDateTime(1976, 6, 19, 21, 13, 34).PlusNanoseconds(123456789);
final LocalDateTime SampleLocalDateTimeToTicks = LocalDateTime(1976, 6, 19, 21, 13, 34).PlusNanoseconds(123456700);
final LocalDateTime SampleLocalDateTimeToMillis = LocalDateTime(1976, 6, 19, 21, 13, 34, 123);
final LocalDateTime SampleLocalDateTimeToSeconds = LocalDateTime(1976, 6, 19, 21, 13, 34);
final LocalDateTime SampleLocalDateTimeToMinutes = LocalDateTime(1976, 6, 19, 21, 13);
final LocalDateTime SampleLocalDateTimeCoptic =
    LocalDateTime.YearMonthDayHourMinuteSecondCalendar(1976, 6, 19, 21, 13, 34, CalendarSystem.Coptic)
        .PlusNanoseconds(123456789);

// Not ported: AllStandardPatterns, AllCulturesStandardPatterns (from the scenarios).

// The standard example date/time used in all the MSDN samples, which means we can just cut and paste
// the expected results of the standard patterns.
final LocalDateTime MsdnStandardExample = LocalDateTime(2009, 06, 15, 13, 45, 30, 90);
final LocalDateTime MsdnStandardExampleNoMillis = LocalDateTime(2009, 06, 15, 13, 45, 30);
final LocalDateTime MsdnStandardExampleNoSeconds = LocalDateTime(2009, 06, 15, 13, 45);

// Not ported: the data arrays (their values come from the scenarios).

void main() {
  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<LocalDateTime>((fields) => Data(fields['value'] as LocalDateTime)),

    'WithCalendar': (args) {
      var pattern = LocalDateTimePattern.GeneralIso.WithCalendar(CalendarSystem.Coptic);
      var value = pattern.Parse('0284-08-29T12:34:56').Value;
      Assert.AreEqual(LocalDateTime.YearMonthDayHourMinuteSecondCalendar(284, 8, 29, 12, 34, 56, CalendarSystem.Coptic), value);
    },

    'WithTwoDigitYearMax': (args) {
      final [int twoDigitYearMax, String text, int expectedYear] = args;
      var pattern =
          LocalDateTimePattern.CreateWithInvariantCulture("yy-MM-dd'T'HH:mm:ss").WithTwoDigitYearMax(twoDigitYearMax);
      var value = pattern.Parse(text).Value;
      Assert.AreEqual(expectedYear, value.Year);
    },

    'WithTwoDigitYearMax_Invalid': (args) {
      final [int twoDigitYearMax] = args;
      Assert.Throws<RangeError>(() => LocalDateTimePattern.ExtendedIso.WithTwoDigitYearMax(twoDigitYearMax));
    },

    'ParseFormattedStandardPattern': (args) {
      final [NodaCultureInfo culture, String patternText] = args;
      var pattern = CreatePatternOrNull(patternText, culture, LocalDateTime(2000, 1, 1, 0, 0));
      if (pattern == null) {
        return;
      }

      // If the pattern really can't distinguish between AM and PM (e.g. it's 12 hour with an
      // abbreviated AM/PM designator) then let's let it go.
      if (pattern.Format(SampleLocalDateTime) == pattern.Format(SampleLocalDateTime.PlusHours(-12))) {
        return;
      }

      // If the culture doesn't have either AM or PM designators, we'll end up using the template value
      // AM/PM, so let's make sure that's right. (This happens on Mono for a few cultures.)
      if (culture.DateTimeFormat.AMDesignator == '' && culture.DateTimeFormat.PMDesignator == '') {
        pattern = pattern.WithTemplateValue(LocalDateTime(2000, 1, 1, 12, 0));
      }

      String formatted = pattern.Format(SampleLocalDateTime);
      var parseResult = pattern.Parse(formatted);
      Assert.IsTrue(parseResult.Success);
      var parsed = parseResult.Value;
      Assert.That(
          parsed,
          anyOf(
              Is.EqualTo(SampleLocalDateTime),
              Is.EqualTo(SampleLocalDateTimeToTicks),
              Is.EqualTo(SampleLocalDateTimeToMillis),
              Is.EqualTo(SampleLocalDateTimeToSeconds),
              Is.EqualTo(SampleLocalDateTimeToMinutes)));
    },

    'DateHourIso_Roundtrip': (args) {
      final [String text] = args;
      var result = LocalDateTimePattern.DateHourIso.Parse(text);
      Assert.True(result.Success);
      var time = result.Value;
      Assert.AreEqual(0, time.Minute);
      Assert.AreEqual(0, time.Second);
      Assert.AreEqual(0, time.NanosecondOfSecond);
      var formatted = LocalDateTimePattern.DateHourIso.Format(time);
      Assert.AreEqual(text, formatted);
    },

    'DateHourIso_2400': (args) {
      var result = LocalDateTimePattern.DateHourIso.Parse('1992-01-25T24');
      Assert.True(result.Success);
      Assert.AreEqual(LocalDateTime(1992, 1, 26, 0, 0), result.Value);
    },

    'DateHourIso_Invalid': (args) {
      final [String text] = args;
      var result = LocalDateTimePattern.DateHourIso.Parse(text);
      Assert.False(result.Success);
    },

    'DateHourMinuteIso_Roundtrip': (args) {
      final [String text] = args;
      var result = LocalDateTimePattern.DateHourMinuteIso.Parse(text);
      Assert.True(result.Success);
      var time = result.Value;
      Assert.AreEqual(0, time.Second);
      Assert.AreEqual(0, time.NanosecondOfSecond);
      var formatted = LocalDateTimePattern.DateHourMinuteIso.Format(time);
      Assert.AreEqual(text, formatted);
    },

    'DateHourMinuteIso_2400': (args) {
      var result = LocalDateTimePattern.DateHourMinuteIso.Parse('1992-01-25T24:00');
      Assert.True(result.Success);
      Assert.AreEqual(LocalDateTime(1992, 1, 26, 0, 0), result.Value);
    },

    'DateHourMinuteIso_Invalid': (args) {
      final [String text] = args;
      var result = LocalDateTimePattern.DateHourMinuteIso.Parse(text);
      Assert.False(result.Success);
    },

    'VariablePrecision_Valid': (args) {
      final [String canonical, List<dynamic> alternatives] = args;
      // Just use the same prefix for all values; it's only the time part that can vary in precision.
      String prefix = '1992-01-25T';
      String fullCanonical = prefix + canonical;

      var pattern = LocalDateTimePattern.VariablePrecisionIso;
      for (var text in [canonical, ...alternatives.cast<String>()]) {
        var result = pattern.Parse(prefix + text);
        Assert.True(result.Success);
        var time = result.Value;
        var formatted = pattern.Format(time);
        Assert.AreEqual(fullCanonical, formatted);
      }
    },

    'VarablePrecision_2400': (args) {
      final [String text] = args;
      var result = LocalDateTimePattern.VariablePrecisionIso.Parse(text);
      Assert.True(result.Success);
      Assert.AreEqual(LocalDateTime(1992, 1, 26, 0, 0), result.Value);
    },

    'VariablePrecision_Invalid': (args) {
      final [String text] = args;
      var result = LocalDateTimePattern.VariablePrecisionIso.Parse(text);
      Assert.False(result.Success);
    },
  }, skip: {
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
    'ParseNull': SkipReasons.NullSafety,
    'BclStandardPatternComparison': SkipReasons.BclFormatting,
  }, cultures: scenarioCultures);
}

// Not ported: AssertBclNodaEquality (compares with .NET's own formatting).

// Helper method to make it slightly easier for tests to skip "bad" cultures.
LocalDateTimePattern? CreatePatternOrNull(String patternText, NodaCultureInfo culture, LocalDateTime templateValue) {
  try {
    return LocalDateTimePattern.Create(patternText, culture);
  } on InvalidPatternException {
    // The Malta long date/time pattern in Mono 3.0 is invalid (not just wrong; invalid due to the wrong number of quotes).
    // Skip it :(
    // See https://bugzilla.xamarin.com/show_bug.cgi?id=11363
    return null;
  }
}

final class Data extends PatternTestData<LocalDateTime> {
  // Default to the start of the year 2000.
  @override
  LocalDateTime get DefaultTemplate => LocalDateTimePattern.DefaultTemplateValue;

  /// Initializes a new instance of the [Data] class.
  ///
  /// [value]: The value.
  Data(super.value);

  // Not ported: the other constructors (only the data arrays use them).

  @override
  IPattern<LocalDateTime> CreatePattern() =>
      LocalDateTimePattern.CreateWithInvariantCulture(this.Pattern!).WithTemplateValue(Template).WithCulture(Culture);
}
