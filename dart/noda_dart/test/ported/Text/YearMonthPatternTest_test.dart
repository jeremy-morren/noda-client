// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/YearMonthPatternTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/YearMonthPattern.dart';
import 'package:noda_dart/src/YearMonth.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/YearMonthPatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'Cultures.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

// Not ported: the data arrays (their values come from the scenarios).

void main() {
  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<YearMonth>((fields) => Data(fields['value'] as YearMonth)),

    'CreateWithSpecificCulture': (args) {
      var pattern = YearMonthPattern.Create('uuuu/MM', Cultures.FrCa);
      Assert.AreEqual('2017-08', pattern.Format(YearMonth(2017, 8)));
    },

    'CreateWithTemplateValue': (args) {
      var template = YearMonth(2000, 6);
      var pattern = YearMonthPattern.Create('uuuu', NodaCultureInfo.InvariantCulture, template);
      Assert.AreEqual(template, pattern.TemplateValue);
      var parseResult = pattern.Parse('1990');
      Assert.True(parseResult.Success);
      Assert.AreEqual(YearMonth(1990, 6), parseResult.Value);
    },

    'WithTwoDigitYearMax': (args) {
      final [int twoDigitYearMax, String text, int expectedYear] = args;
      var pattern = YearMonthPattern.CreateWithInvariantCulture('yy-MM').WithTwoDigitYearMax(twoDigitYearMax);
      var value = pattern.Parse(text).Value;
      Assert.AreEqual(expectedYear, value.Year);
    },

    'WithTwoDigitYearMax_Invalid': (args) {
      final [int twoDigitYearMax] = args;
      Assert.Throws<RangeError>(() => YearMonthPattern.Iso.WithTwoDigitYearMax(twoDigitYearMax));
    },
  }, skip: {
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
    'ParseNull': SkipReasons.NullSafety,
  }, cultures: scenarioCultures);
}

final class Data extends PatternTestData<YearMonth> {
  @override
  YearMonth get DefaultTemplate => YearMonthPattern.DefaultTemplateValue;

  Data(super.value);

  // Not ported: the Data constructors only the data arrays use.

  @override
  IPattern<YearMonth> CreatePattern() =>
      YearMonthPattern.CreateWithInvariantCulture(this.Pattern!).WithTemplateValue(Template).WithCulture(Culture);
}
