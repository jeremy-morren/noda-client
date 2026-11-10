// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/LocalTimePatternTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/LocalTimePattern.dart';
import 'package:noda_dart/src/Text/Patterns/PatternCursor.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/LocalTimePatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

// Not ported: SampleDateTime, SampleLocalTime (only AssertBclNodaEquality uses them).

// Characters we expect to work the same in Noda Time as in the BCL.
const String ExpectedCharacters = 'hHms.:fFtT ';

// Not ported: the AM/PM test cultures and the data arrays (from the scenarios).

void main() {
  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<LocalTime>((fields) => Data(fields['value'] as LocalTime)),

    'BclLongTimePatternIsValidNodaPattern': (args) {
      final [NodaCultureInfo culture] = args;
      // Not ported: `if (culture is null) return;` (null safety: the culture can't be null).
      AssertValidNodaPattern(culture, culture.DateTimeFormat.LongTimePattern);
    },

    'BclShortTimePatternIsValidNodaPattern': (args) {
      final [NodaCultureInfo culture] = args;
      AssertValidNodaPattern(culture, culture.DateTimeFormat.ShortTimePattern);
    },

    'TemplateValue_DefaultsToMidnight': (args) {
      var pattern = LocalTimePattern.CreateWithInvariantCulture('HH');
      Assert.AreEqual(LocalTime.Midnight, pattern.TemplateValue);
    },

    'WithTemplateValue_PropertyFetch': (args) {
      LocalTime newValue = LocalTime(1, 23, 45);
      var pattern = LocalTimePattern.CreateWithInvariantCulture('HH').WithTemplateValue(newValue);
      Assert.AreEqual(newValue, pattern.TemplateValue);
    },

    'HourIso_Roundtrip': (args) {
      final [String text] = args;
      var result = LocalTimePattern.HourIso.Parse(text);
      Assert.True(result.Success);
      var time = result.Value;
      Assert.AreEqual(0, time.Minute);
      Assert.AreEqual(0, time.Second);
      Assert.AreEqual(0, time.NanosecondOfSecond);
      var formatted = LocalTimePattern.HourIso.Format(time);
      Assert.AreEqual(text, formatted);
    },

    'HourIso_Invalid': (args) {
      final [String text] = args;
      var result = LocalTimePattern.HourIso.Parse(text);
      Assert.False(result.Success);
    },

    'HourMinuteIso_Roundtrip': (args) {
      final [String text] = args;
      var result = LocalTimePattern.HourMinuteIso.Parse(text);
      Assert.True(result.Success);
      var time = result.Value;
      Assert.AreEqual(0, time.Second);
      Assert.AreEqual(0, time.NanosecondOfSecond);
      var formatted = LocalTimePattern.HourMinuteIso.Format(time);
      Assert.AreEqual(text, formatted);
    },

    'HourMinuteIso_Invalid': (args) {
      final [String text] = args;
      var result = LocalTimePattern.HourMinuteIso.Parse(text);
      Assert.False(result.Success);
    },

    'VariablePrecision_Valid': (args) {
      final [String canonical, List<dynamic> alternatives] = args;
      var pattern = LocalTimePattern.VariablePrecisionIso;
      for (var text in [canonical, ...alternatives.cast<String>()]) {
        var result = pattern.Parse(text);
        Assert.True(result.Success);
        var time = result.Value;
        var formatted = pattern.Format(time);
        Assert.AreEqual(canonical, formatted);
      }
    },

    'VariablePrecision_Invalid': (args) {
      final [String text] = args;
      var result = LocalTimePattern.VariablePrecisionIso.Parse(text);
      Assert.False(result.Success);
    },
  }, skip: {
    'ParseNull': SkipReasons.NullSafety,
    'BclLongTimePatternGivesSameResultsInNoda': SkipReasons.BclFormatting,
    'BclShortTimePatternGivesSameResultsInNoda': SkipReasons.BclFormatting,
    'CreateWithInvariantCulture_NullPatternText': SkipReasons.NullSafety,
    'Create_NullFormatInfo': SkipReasons.NullSafety,
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
  }, cultures: scenarioCultures);
}

// Not ported: AssertBclNodaEquality (it compares with .NET's DateTime.ToString(pattern, culture)).

void AssertValidNodaPattern(NodaCultureInfo culture, String pattern) {
  PatternCursor cursor = PatternCursor.NewPattern(pattern);
  while (cursor.MoveNext()) {
    if (cursor.Current == "'") {
      cursor.GetQuotedString("'");
    } else {
      // We'll never do anything "special" with non-ascii characters anyway,
      // so we don't mind if they're not quoted.
      if (cursor.Current.codeUnitAt(0) < 0x80) {
        Assert.IsTrue(ExpectedCharacters.contains(cursor.Current),
            "Pattern '$pattern' contains unquoted, unexpected characters");
      }
    }
  }
  // Check that the pattern parses
  LocalTimePattern.Create(pattern, culture);
}

/// A container for test data for formatting and parsing [LocalTime] objects.
final class Data extends PatternTestData<LocalTime> {
  // Default to midnight
  @override
  LocalTime get DefaultTemplate => LocalTime.Midnight;

  @override
  String? get ValuePatternText => 'HH:mm:ss.FFFFFFFFF';

  Data(super.value);

  // Not ported: the other constructors (only the data arrays use them).

  @override
  IPattern<LocalTime> CreatePattern() =>
      LocalTimePattern.CreateWithInvariantCulture(this.Pattern!).WithTemplateValue(Template).WithCulture(Culture);
}
