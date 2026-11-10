// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/OffsetTimePatternTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/Globalization/NodaFormatInfo.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/OffsetTime.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/OffsetTimePattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/OffsetTimePatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'Cultures.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

// Not ported: the data arrays and the fields only they use (from the scenarios).

void main() {
  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<OffsetTime>((fields) => Data(fields['value'] as OffsetTime)),

    'CreateWithInvariantCulture': (args) {
      var pattern = OffsetTimePattern.CreateWithInvariantCulture('HH:mm:sso<g>');
      Assert.AreSame(NodaFormatInfo.InvariantInfo, pattern.FormatInfo);
      var ot = LocalTime(12, 34, 56).WithOffset(Offset.FromHours(2));
      Assert.AreEqual('12:34:56+02', pattern.Format(ot));
    },

    'WithCulture': (args) {
      var pattern = OffsetTimePattern.CreateWithInvariantCulture('HH:mm').WithCulture(Cultures.DotTimeSeparator);
      var text = pattern.Format(LocalTime(19, 30).WithOffset(Offset.Zero));
      Assert.AreEqual('19.30', text);
    },

    'WithPatternText': (args) {
      var pattern = OffsetTimePattern.CreateWithInvariantCulture('HH:mm:ss').WithPatternText('HH:mm');
      var value = LocalTime(13, 30).WithOffset(Offset.FromHours(2));
      var text = pattern.Format(value);
      Assert.AreEqual('13:30', text);
    },

    'WithTemplateValue': (args) {
      var pattern = OffsetTimePattern.CreateWithInvariantCulture('o<G>')
          .WithTemplateValue(LocalTime(13, 30).WithOffset(Offset.Zero));
      var parsed = pattern.Parse('+02').Value;
      // Local time is taken from the template value; offset is from the text
      Assert.AreEqual(LocalTime(13, 30), parsed.TimeOfDay);
      Assert.AreEqual(Offset.FromHours(2), parsed.Offset);
    },
  }, skip: {
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
    'ParseNull': SkipReasons.NullSafety,
  }, cultures: scenarioCultures);
}

final class Data extends PatternTestData<OffsetTime> {
  // Default to the start of the year 2000 UTC
  @override
  OffsetTime get DefaultTemplate => OffsetTimePattern.DefaultTemplateValue;

  @override
  String? get ValuePatternText => 'HH:mm:ss.FFFFFFFFF o<G>';

  /// Initializes a new instance of the [Data] class.
  ///
  /// [value]: The value.
  Data(super.value);

  // Not ported: the other constructors (only the data arrays use them).

  @override
  IPattern<OffsetTime> CreatePattern() => OffsetTimePattern.Create(this.Pattern!, Culture, Template);
}
