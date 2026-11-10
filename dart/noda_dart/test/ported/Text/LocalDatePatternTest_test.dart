// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/LocalDatePatternTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/LocalDatePattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/LocalDatePatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

// Not ported: the data arrays (their values come from the scenarios).

void main() {
  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<LocalDate>((fields) => Data(fields['value'] as LocalDate)),

    'WithCalendar': (args) {
      var pattern = LocalDatePattern.Iso.WithCalendar(CalendarSystem.Coptic);
      var value = pattern.Parse('0284-08-29').Value;
      Assert.AreEqual(LocalDate(284, 8, 29, CalendarSystem.Coptic), value);
    },

    'WithTwoDigitYearMax': (args) {
      final [int twoDigitYearMax, String text, int expectedYear] = args;
      var pattern = LocalDatePattern.CreateWithInvariantCulture('yy-MM-dd').WithTwoDigitYearMax(twoDigitYearMax);
      var value = pattern.Parse(text).Value;
      Assert.AreEqual(expectedYear, value.Year);
    },

    'WithTwoDigitYearMax_Invalid': (args) {
      final [int twoDigitYearMax] = args;
      Assert.Throws<RangeError>(() => LocalDatePattern.Iso.WithTwoDigitYearMax(twoDigitYearMax));
    },
  }, skip: {
    'BclLongDatePatternGivesSameResultsInNoda': SkipReasons.BclFormatting,
    'BclShortDatePatternGivesSameResultsInNoda': SkipReasons.BclFormatting,
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
    'ParseNull': SkipReasons.NullSafety,
  }, cultures: scenarioCultures);
}

// Not ported: AssertBclNodaEquality (it compares with .NET's DateTime.ToString(pattern, culture)).

final class Data extends PatternTestData<LocalDate> {
  // Default to the start of the year 2000.
  @override
  LocalDate get DefaultTemplate => LocalDatePattern.DefaultTemplateValue;

  /// Initializes a new instance of the [Data] class.
  ///
  /// [value]: The value.
  Data(super.value);

  // Not ported: the Data constructors only the data arrays use.

  @override
  IPattern<LocalDate> CreatePattern() =>
      LocalDatePattern.CreateWithInvariantCulture(this.Pattern!) // noda_dart: this. (dart:core has a Pattern type)
          .WithTemplateValue(Template)
          .WithCulture(Culture);
}
