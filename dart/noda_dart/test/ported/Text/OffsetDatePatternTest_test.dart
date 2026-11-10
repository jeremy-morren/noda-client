// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/OffsetDatePatternTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Globalization/NodaFormatInfo.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/OffsetDate.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/OffsetDatePattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/OffsetDatePatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'Cultures.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

// Not ported: the data arrays and the fields only they use (from the scenarios).

void main() {
  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<OffsetDate>((fields) => Data(fields['value'] as OffsetDate)),

    'CreateWithInvariantCulture': (args) {
      var pattern = OffsetDatePattern.CreateWithInvariantCulture('uuuu-MM-ddo<g>');
      Assert.AreSame(NodaFormatInfo.InvariantInfo, pattern.FormatInfo);
      var od = LocalDate(2017, 8, 23).WithOffset(Offset.FromHours(2));
      Assert.AreEqual('2017-08-23+02', pattern.Format(od));
    },

    'WithCulture': (args) {
      var pattern = OffsetDatePattern.CreateWithInvariantCulture('uuuu/MM/dd o<G>').WithCulture(Cultures.FrCa);
      var text = pattern.Format(LocalDate(2000, 1, 1).WithOffset(Offset.FromHours(1)));
      Assert.AreEqual('2000-01-01 +01', text);
    },

    'WithPatternText': (args) {
      var pattern = OffsetDatePattern.CreateWithInvariantCulture('uuuu-MM-dd').WithPatternText('dd MM uuuu o<g>');
      var value = LocalDate(1970, 1, 1).WithOffset(Offset.FromHours(2));
      var text = pattern.Format(value);
      Assert.AreEqual('01 01 1970 +02', text);
    },

    'WithTemplateValue': (args) {
      var pattern = OffsetDatePattern.CreateWithInvariantCulture('MM-dd')
          .WithTemplateValue(LocalDate(1970, 1, 1).WithOffset(Offset.FromHours(2)));
      var parsed = pattern.Parse('08-23').Value;
      Assert.AreEqual(LocalDate(1970, 8, 23), parsed.Date);
      Assert.AreEqual(Offset.FromHours(2), parsed.Offset);
    },

    'WithCalendar': (args) {
      var pattern = OffsetDatePattern.CreateWithInvariantCulture('uuuu-MM-dd').WithCalendar(CalendarSystem.Coptic);
      var parsed = pattern.Parse('0284-08-29').Value;
      Assert.AreEqual(LocalDate(284, 8, 29, CalendarSystem.Coptic), parsed.Date);
    },

    'WithTwoDigitYearMax': (args) {
      final [int twoDigitYearMax, String text, int expectedYear] = args;
      var pattern = OffsetDatePattern.CreateWithInvariantCulture('yy-MM-dd o<g>').WithTwoDigitYearMax(twoDigitYearMax);
      var value = pattern.Parse(text).Value;
      Assert.AreEqual(expectedYear, value.Year);
    },

    'WithTwoDigitYearMax_Invalid': (args) {
      final [int twoDigitYearMax] = args;
      Assert.Throws<RangeError>(() => OffsetDatePattern.GeneralIso.WithTwoDigitYearMax(twoDigitYearMax));
    },
  }, skip: {
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
    'ParseNull': SkipReasons.NullSafety,
  }, cultures: scenarioCultures);
}

final class Data extends PatternTestData<OffsetDate> {
  @override
  OffsetDate get DefaultTemplate => OffsetDatePattern.DefaultTemplateValue;

  Data(super.value);

  // Not ported: the other constructors (only the data arrays use them).

  @override
  IPattern<OffsetDate> CreatePattern() => OffsetDatePattern.Create(this.Pattern!, Culture, Template);
}
