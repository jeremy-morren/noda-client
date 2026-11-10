// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/OffsetDateTimePatternTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/Globalization/NodaFormatInfo.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/OffsetDateTime.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/OffsetDateTimePattern.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/OffsetDateTimePatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'Cultures.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

// Not ported: the data arrays and the fields only they use (from the scenarios).

void main() {
  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<OffsetDateTime>((fields) => Data(fields['value'] as OffsetDateTime)),

    'CreateWithInvariantCulture': (args) {
      var pattern = OffsetDateTimePattern.CreateWithInvariantCulture("uuuu-MM-dd'T'HH:mm:sso<g>");
      Assert.AreSame(NodaFormatInfo.InvariantInfo, pattern.FormatInfo);
      var odt = LocalDateTime(2017, 8, 23, 12, 34, 56).WithOffset(Offset.FromHours(2));
      Assert.AreEqual('2017-08-23T12:34:56+02', pattern.Format(odt));
    },

    'WithCulture': (args) {
      var pattern = OffsetDateTimePattern.CreateWithInvariantCulture('HH:mm').WithCulture(Cultures.DotTimeSeparator);
      var text = pattern.Format(Instant.FromUtc(2000, 1, 1, 19, 30).WithOffset(Offset.Zero));
      Assert.AreEqual('19.30', text);
    },

    'WithPatternText': (args) {
      var pattern = OffsetDateTimePattern.CreateWithInvariantCulture('uuuu-MM-dd').WithPatternText('HH:mm');
      var value = Instant.FromUtc(1970, 1, 1, 11, 30).WithOffset(Offset.FromHours(2));
      var text = pattern.Format(value);
      Assert.AreEqual('13:30', text);
    },

    'WithTemplateValue': (args) {
      var pattern = OffsetDateTimePattern.CreateWithInvariantCulture('uuuu-MM-dd')
          .WithTemplateValue(Instant.FromUtc(1970, 1, 1, 11, 30).WithOffset(Offset.FromHours(2)));
      var parsed = pattern.Parse('2017-08-23').Value;
      Assert.AreEqual(LocalDateTime(2017, 8, 23, 13, 30, 0), parsed.LocalDateTime);
      Assert.AreEqual(Offset.FromHours(2), parsed.Offset);
    },

    'WithCalendar': (args) {
      var pattern =
          OffsetDateTimePattern.CreateWithInvariantCulture('uuuu-MM-dd').WithCalendar(CalendarSystem.Coptic);
      var parsed = pattern.Parse('0284-08-29').Value;
      Assert.AreEqual(
          LocalDateTime.YearMonthDayHourMinuteCalendar(284, 8, 29, 0, 0, CalendarSystem.Coptic), parsed.LocalDateTime);
    },

    'WithTwoDigitYearMax': (args) {
      final [int twoDigitYearMax, String text, int expectedYear] = args;
      var pattern = OffsetDateTimePattern.CreateWithInvariantCulture("yy-MM-dd'T'HH:mm:ss o<g>")
          .WithTwoDigitYearMax(twoDigitYearMax);
      var value = pattern.Parse(text).Value;
      Assert.AreEqual(expectedYear, value.Year);
    },

    'WithTwoDigitYearMax_Invalid': (args) {
      final [int twoDigitYearMax] = args;
      Assert.Throws<RangeError>(() => OffsetDateTimePattern.GeneralIso.WithTwoDigitYearMax(twoDigitYearMax));
    },
  }, skip: {
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
    'ParseNull': SkipReasons.NullSafety,
  }, cultures: scenarioCultures);
}

final class Data extends PatternTestData<OffsetDateTime> {
  @override
  OffsetDateTime get DefaultTemplate => OffsetDateTimePattern.DefaultTemplateValue;

  Data(super.value);

  // Not ported: the other constructors (only the data arrays use them).

  @override
  IPattern<OffsetDateTime> CreatePattern() => OffsetDateTimePattern.Create(this.Pattern!, Culture, Template);
}
