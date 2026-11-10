// Ported from NodaTime 6e024dde: src/NodaTime.Test/Text/ZonedDateTimePatternTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: the test zones and TestProvider are registered with the decoder (zone equality is by reference).

import 'package:noda_dart/src/CalendarSystem.dart';
import 'package:noda_dart/src/DateTimeZone.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Globalization/NodaCultureInfo.dart';
import 'package:noda_dart/src/IDateTimeZoneProvider.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Testing/TimeZones/FakeDateTimeZoneSource.dart';
import 'package:noda_dart/src/Testing/TimeZones/SingleTransitionDateTimeZone.dart';
import 'package:noda_dart/src/Text/IPattern.dart';
import 'package:noda_dart/src/Text/ZonedDateTimePattern.dart';
import 'package:noda_dart/src/TimeZones/DateTimeZoneCache.dart';
import 'package:noda_dart/src/TimeZones/Delegates.dart';
import 'package:noda_dart/src/TimeZones/Resolvers.dart';
import 'package:noda_dart/src/ZonedDateTime.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Decode.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/Text/ZonedDateTimePatternTest.generated.dart' as scenarios;
import '../../scenarios/cultures.generated.dart';
import 'Cultures.dart';
import 'PatternTestBase.dart';
import 'PatternTestData.dart';

// Three zones with a deliberately leading-substring-matching set of names.
// Transition is at 1am local time, going forward an hour.
final SingleTransitionDateTimeZone TestZone1 = SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
    Instant.FromUtc(2010, 1, 1, 0, 0), Offset.FromHours(1), Offset.FromHours(2), 'ab');
// Transition is at 2am local time, going back an hour.
final SingleTransitionDateTimeZone TestZone2 = SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
    Instant.FromUtc(2010, 1, 1, 0, 0), Offset.FromHours(2), Offset.FromHours(1), 'abc');
final SingleTransitionDateTimeZone TestZone3 = SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
    Instant.FromUtc(2010, 1, 1, 0, 0), Offset.FromHours(1), Offset.FromHours(2), 'abcd');

final IDateTimeZoneProvider TestProvider = (FakeDateTimeZoneSourceBuilder()
      ..Add(TestZone1)
      ..Add(TestZone2)
      ..Add(TestZone3))
    .Build()
    .ToProvider();

// Not ported: the data arrays and the fields only they use (from the scenarios).

void main() {
  testStatics['ZonedDateTimePatternTest.TestProvider'] = () => TestProvider;
  for (final zone in [TestZone1, TestZone2, TestZone3]) {
    testZones[zone.Id] = zone;
  }

  port(scenarios.fixture, {
    ...PatternTestBase.Bodies<ZonedDateTime>((fields) => Data(fields['value'] as ZonedDateTime)
      ..Resolver = fields['resolver'] as ZoneLocalMappingResolver?
      ..ZoneProvider = fields['zoneProvider'] as IDateTimeZoneProvider?),

    'WithTemplateValue': (args) {
      var pattern = ZonedDateTimePattern.CreateWithInvariantCulture('uuuu-MM-dd', TestProvider)
          .WithTemplateValue(Instant.FromUtc(1970, 1, 1, 11, 30).InZone(TestZone3));
      var parsed = pattern.Parse('2017-08-23').Value;
      Assert.AreSame(TestZone3, parsed.Zone);
      // TestZone3 is at UTC+1 in 1970, so the template value's *local* time is 12pm.
      // Even though we're parsing a date in 2017, it's the local time from the template value that's used.
      Assert.AreEqual(LocalDateTime(2017, 8, 23, 12, 30, 0), parsed.LocalDateTime);
      Assert.AreEqual(Offset.FromHours(2), parsed.Offset);
    },

    'WithCalendar': (args) {
      var pattern = ZonedDateTimePattern.CreateWithInvariantCulture('uuuu-MM-dd', TestProvider)
          .WithCalendar(CalendarSystem.Coptic);
      var parsed = pattern.Parse('0284-08-29').Value;
      Assert.AreEqual(
          LocalDateTime.YearMonthDayHourMinuteCalendar(284, 8, 29, 0, 0, CalendarSystem.Coptic), parsed.LocalDateTime);
    },

    'WithPatternText': (args) {
      var pattern = ZonedDateTimePattern.CreateWithInvariantCulture('uuuu', TestProvider).WithPatternText('uuuu-MM-dd');
      var text = pattern.Format(NodaConstants.UnixEpoch.InUtc());
      Assert.AreEqual('1970-01-01', text);
    },

    'WithCulture': (args) {
      var pattern = ZonedDateTimePattern.CreateWithInvariantCulture('HH:mm', null).WithCulture(Cultures.DotTimeSeparator);
      var text = pattern.Format(Instant.FromUtc(2000, 1, 1, 19, 30).InUtc());
      Assert.AreEqual('19.30', text);
    },

    // Test to hit each exit condition in the time zone ID parsing part of ZonedDateTimePatternParser
    'FindLongestZoneId': (args) {
      DateTimeZone CreateZone(String id) => SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(
          NodaConstants.UnixEpoch.MinusDuration(Duration.FromDays(1)), Offset.FromHours(-1), Offset.FromHours(0), id);

      var source = (FakeDateTimeZoneSourceBuilder()
            ..Add(CreateZone('ABC'))
            ..Add(CreateZone('ABCA'))
            ..Add(CreateZone('ABCB'))
            ..Add(CreateZone('ABCBX'))
            ..Add(CreateZone('ABCD')))
          .Build();
      var provider = DateTimeZoneCache(source);
      var pattern = ZonedDateTimePattern.Create("z 'x'", NodaCultureInfo.InvariantCulture, Resolvers.StrictResolver,
          provider, NodaConstants.UnixEpoch.InUtc());
      for (var id in provider.Ids) {
        var value = pattern.Parse('$id x').Value;
        Assert.AreEqual(id, value.Zone.Id);
      }
    },

    'WithTwoDigitYearMax': (args) {
      final [int twoDigitYearMax, String text, int expectedYear] = args;
      var pattern = ZonedDateTimePattern.CreateWithInvariantCulture("yy-MM-dd'T'HH:mm:ss z", TestProvider)
          .WithTwoDigitYearMax(twoDigitYearMax);
      var value = pattern.Parse(text).Value;
      Assert.AreEqual(expectedYear, value.Year);
    },

    'WithTwoDigitYearMax_Invalid': (args) {
      final [int twoDigitYearMax] = args;
      Assert.Throws<RangeError>(() => ZonedDateTimePattern.GeneralFormatOnlyIso.WithTwoDigitYearMax(twoDigitYearMax));
    },
  }, skip: {
    'CreateWithCurrentCulture': SkipReasons.CurrentCulture,
    'ParseNull': SkipReasons.NullSafety,
  }, cultures: scenarioCultures);
}

final class Data extends PatternTestData<ZonedDateTime> {
  // Default to the start of the year 2000 UTC
  @override
  ZonedDateTime get DefaultTemplate => ZonedDateTimePattern.DefaultTemplateValue;

  ZoneLocalMappingResolver? Resolver;
  IDateTimeZoneProvider? ZoneProvider;

  /// Initializes a new instance of the [Data] class.
  ///
  /// [value]: The value.
  Data(super.value);

  // Not ported: the other constructors (only the data arrays use them).

  @override
  IPattern<ZonedDateTime> CreatePattern() =>
      ZonedDateTimePattern.Create(this.Pattern!, Culture, Resolver, ZoneProvider, Template);

  @override
  String toString() => '${super.toString()};Resolver? ${Resolver == null ? 'N' : 'Y'}; Provider: ${ZoneProvider?.VersionId}';
}
