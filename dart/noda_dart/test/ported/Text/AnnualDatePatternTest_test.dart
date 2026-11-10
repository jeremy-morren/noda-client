// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/AnnualDatePatternTest.cs
// Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: C#'s `new CultureInfo(cultureId)` is the scenario culture of that name (Decode.dart's scenarioCulture).

import 'package:noda_dart/src/AnnualDate.dart';
import 'package:noda_dart/src/Text/AnnualDatePattern.dart';
import 'package:noda_dart/src/Text/IPattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Decode.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/AnnualDatePatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

// Not ported: the data arrays (their values come from the scenarios).

void main() {
  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<AnnualDate>((fields) => Data(fields['value'] as AnnualDate)),

    'CreateWithCulture': (args) {
      final [String cultureId, String expected] = args;
      var date = AnnualDate(8, 23);
      var culture = scenarioCulture(cultureId);
      var pattern = AnnualDatePattern.Create('MM/dd', culture);
      Assert.AreEqual(expected, pattern.Format(date));
    },

    'CreateWithCultureAndTemplateValue': (args) {
      final [String cultureId, String expected] = args;
      var date = AnnualDate(8, 23);
      var template = AnnualDate(5, 3);
      var culture = scenarioCulture(cultureId);
      // Check the culture is still used
      var pattern1 = AnnualDatePattern.Create('MM/dd', culture, template);
      Assert.AreEqual(expected, pattern1.Format(date));
      // And the template value
      var pattern2 = AnnualDatePattern.Create('MM', culture, template);
      var parsed = pattern2.Parse('08').Value;
      Assert.AreEqual(AnnualDate(8, 3), parsed);
    },
  }, skip: {
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
    'ParseNull': SkipReasons.NullSafety,
  }, cultures: scenarioCultures);
}

final class Data extends PatternTestData<AnnualDate> {
  // Default to January 1st
  @override
  AnnualDate get DefaultTemplate => AnnualDatePattern.DefaultTemplateValue;

  /// Initializes a new instance of the [Data] class.
  ///
  /// [value]: The value.
  Data(super.value);

  // Not ported: Data(int month, int day) and Data() (only the data arrays use them).

  @override
  IPattern<AnnualDate> CreatePattern() =>
      AnnualDatePattern.CreateWithInvariantCulture(this.Pattern!) // noda_dart: this. (dart:core has a Pattern type)
          .WithTemplateValue(Template)
          .WithCulture(Culture);
}
