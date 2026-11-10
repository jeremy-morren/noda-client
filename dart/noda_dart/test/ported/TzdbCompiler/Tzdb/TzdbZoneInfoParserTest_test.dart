// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/Tzdb/TzdbZoneInfoParserTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: month names come from LocalDatePattern with the invariant culture.

import 'package:noda_dart/src/IsoDayOfWeek.generated.dart';
import 'package:noda_dart/src/LocalDate.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/LocalTime.dart';
import 'package:noda_dart/src/Offset.dart';
import 'package:noda_dart/src/Text/LocalDatePattern.dart';
import 'package:noda_dart/src/TimeZones/TransitionMode.generated.dart';
import 'package:noda_dart/src/TimeZones/ZoneYearOffset.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/Tokens.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/TzdbDatabase.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/TzdbZoneInfoParser.dart';
import 'package:noda_dart/src/TzdbCompiler/Tzdb/ZoneLine.dart';
import 'package:noda_dart/src/Utility/Int64.dart';
import 'package:noda_dart/src/Utility/SystemExceptions.dart';

import '../../../helpers/Assertions.dart';
import '../../../helpers/Scenarios.dart';
import '../../../scenarios/TzdbCompiler/Tzdb/TzdbZoneInfoParserTest.generated.dart' as scenarios;

/// Tests for TzdbZoneInfoParser.
void main() {
  port(scenarios.fixture, {
    'ParseDateTimeOfYear_emptyString': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('');
      Assert.Throws<InvalidDataException>(() => parser.ParseDateTimeOfYear(tokens, true));
    },

    'ParseDateTimeOfYear_missingAt_invalidForRule': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Mar lastSun';
      var tokens = Tokens.Tokenize(text);
      Assert.Throws<InvalidDataException>(() => parser.ParseDateTimeOfYear(tokens, true));
    },

    'ParseDateTimeOfYear_missingOn_invalidForRule': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Mar';
      var tokens = Tokens.Tokenize(text);
      Assert.Throws<InvalidDataException>(() => parser.ParseDateTimeOfYear(tokens, true));
    },

    'ParseDateTimeOfYear_missingAt_validForZone': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Mar lastSun';
      var tokens = Tokens.Tokenize(text);
      var actual = parser.ParseDateTimeOfYear(tokens, false);
      var expected = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
          TransitionMode.Wall, 3, -1, IsoDayOfWeek.Sunday.value, false, LocalTime.Midnight);
      Assert.AreEqual(expected, actual);
    },

    'ParseDateTimeOfYear_missingOn_validForZone': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Mar';
      var tokens = Tokens.Tokenize(text);
      var actual = parser.ParseDateTimeOfYear(tokens, false);
      var expected = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
          TransitionMode.Wall, 3, 1, 0, false, LocalTime.Midnight);
      Assert.AreEqual(expected, actual);
    },

    'ParseDateTimeOfYear_onAfter': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Mar Tue>=14 2:00';
      var tokens = Tokens.Tokenize(text);
      var actual = parser.ParseDateTimeOfYear(tokens, true);
      var expected = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
          TransitionMode.Wall, 3, 14, IsoDayOfWeek.Tuesday.value, true, LocalTime(2, 0));
      Assert.AreEqual(expected, actual);
    },

    'ParseDateTimeOfYear_onBefore': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Mar Tue<=14 2:00';
      var tokens = Tokens.Tokenize(text);
      var actual = parser.ParseDateTimeOfYear(tokens, true);
      var expected = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
          TransitionMode.Wall, 3, 14, IsoDayOfWeek.Tuesday.value, false, LocalTime(2, 0));
      Assert.AreEqual(expected, actual);
    },

    'ParseDateTimeOfYear_onLast': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Mar lastTue 2:00';
      var tokens = Tokens.Tokenize(text);
      var actual = parser.ParseDateTimeOfYear(tokens, true);
      var expected = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
          TransitionMode.Wall, 3, -1, IsoDayOfWeek.Tuesday.value, false, LocalTime(2, 0));
      Assert.AreEqual(expected, actual);
    },

    'ParseLine_comment': (args) {
      const String line = '# Comment';
      var database = ParseText(line);
      ValidateCounts(database, 0, 0, 0);
    },

    'ParseLine_commentWithLeadingWhitespace': (args) {
      const String line = '   # Comment';
      var database = ParseText(line);
      ValidateCounts(database, 0, 0, 0);
    },

    'ParseLine_emptyString': (args) {
      var database = ParseText('');
      ValidateCounts(database, 0, 0, 0);
    },

    // Assume that all lines work the same way - it's comment handling
    // that's important here.
    'ParseLine_commentAtEndOfLine': (args) {
      String line = 'Link from to#Comment';
      var database = ParseText(line);
      ValidateCounts(database, 0, 0, 1);
      Assert.AreEqual('from', database.Aliases['to']);
    },

    'ParseLine_link': (args) {
      const String line = 'Link from to';
      var database = ParseText(line);
      ValidateCounts(database, 0, 0, 1);
    },

    'ParseLine_whiteSpace': (args) {
      const String line = '    \t\t\n';
      var database = ParseText(line);
      ValidateCounts(database, 0, 0, 0);
    },

    'ParseLine_zone': (args) {
      const String line = 'Zone PST 2:00 US P%sT';
      var database = ParseText(line);
      ValidateCounts(database, 0, 1, 0);
      Assert.AreEqual(1, database.Zones.values.single.length);
    },

    'ParseLine_zonePlus': (args) {
      String lines = 'Zone PST 2:00 US P%sT\n'
          '  3:00 US P%sT';
      var database = ParseText(lines);
      ValidateCounts(database, 0, 1, 0);
      Assert.AreEqual(2, database.Zones['PST']!.length);
    },

    'ParseLink_emptyString_exception': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('');
      Assert.Throws<InvalidDataException>(() => parser.ParseLink(tokens));
    },

    'ParseLink_simple': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('from to');
      var actual = parser.ParseLink(tokens);
      var expected = ('from', 'to');
      Assert.AreEqual(expected, actual);
    },

    'ParseLink_tooFewWords_exception': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('from');
      Assert.Throws<InvalidDataException>(() => parser.ParseLink(tokens));
    },

    'ParseMonth_nullOrEmpty': (args) {
      Assert.Throws<ArgumentError>(() => TzdbZoneInfoParser.ParseMonth(''));
      // Not ported: ParseMonth(null!) (null safety).
    },

    'ParseMonth_invalidMonth_default': (args) {
      Assert.Throws<InvalidDataException>(() => TzdbZoneInfoParser.ParseMonth('Able'));
    },

    'ParseMonth_shortMonthNames': (args) {
      for (int i = 1; i < 12; i++) {
        var month = LocalDatePattern.CreateWithInvariantCulture('MMM').Format(LocalDate(2000, i, 1));
        Assert.AreEqual(i, TzdbZoneInfoParser.ParseMonth(month));
      }
    },

    'ParseMonth_longMonthNames': (args) {
      for (int i = 1; i < 12; i++) {
        var month = LocalDatePattern.CreateWithInvariantCulture('MMMM').Format(LocalDate(2000, i, 1));
        Assert.AreEqual(i, TzdbZoneInfoParser.ParseMonth(month));
      }
    },

    'ParseMonth_unambiguousPrefix': (args) {
      Assert.AreEqual(8, TzdbZoneInfoParser.ParseMonth('Au')); // No other month starts with "Au"
      Assert.AreEqual(9, TzdbZoneInfoParser.ParseMonth('Septe')); // Prefix of the long form "September"
    },

    'ParseMonth_ambiguousPrefix_exception': (args) {
      // "Ju" matches both June and July.
      Assert.Throws<InvalidDataException>(() => TzdbZoneInfoParser.ParseMonth('Ju'));
    },

    'ParseMonth_caseInsensitive': (args) {
      Assert.AreEqual(1, TzdbZoneInfoParser.ParseMonth('jan'));
      Assert.AreEqual(1, TzdbZoneInfoParser.ParseMonth('JANUARY'));
      Assert.AreEqual(8, TzdbZoneInfoParser.ParseMonth('au'));
    },

    'ParseDayOfWeek_nullOrEmpty': (args) {
      Assert.Throws<ArgumentError>(() => TzdbZoneInfoParser.ParseDayOfWeek(''));
      // Not ported: ParseDayOfWeek(null!) (null safety).
    },

    'ParseDayOfWeek_invalidDay_exception': (args) {
      Assert.Throws<InvalidDataException>(() => TzdbZoneInfoParser.ParseDayOfWeek('Able'));
    },

    'ParseDayOfWeek_shortNames': (args) {
      Assert.AreEqual(1, TzdbZoneInfoParser.ParseDayOfWeek('Mon'));
      Assert.AreEqual(7, TzdbZoneInfoParser.ParseDayOfWeek('Sun'));
    },

    'ParseDayOfWeek_unambiguousPrefix': (args) {
      Assert.AreEqual(1, TzdbZoneInfoParser.ParseDayOfWeek('Mo')); // No other day starts with "Mo"
      Assert.AreEqual(4, TzdbZoneInfoParser.ParseDayOfWeek('Th')); // No other day starts with "Th"
    },

    'ParseDayOfWeek_ambiguousPrefix_exception': (args) {
      // "S" matches both Saturday and Sunday.
      Assert.Throws<InvalidDataException>(() => TzdbZoneInfoParser.ParseDayOfWeek('S'));
    },

    'ParseDayOfWeek_caseInsensitive': (args) {
      Assert.AreEqual(1, TzdbZoneInfoParser.ParseDayOfWeek('mon'));
      Assert.AreEqual(7, TzdbZoneInfoParser.ParseDayOfWeek('SUN'));
    },

    'ParseZone_badOffset_exception': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('asd US P%sT 1969 Mar 23 14:53:27.856s');
      Assert.Throws<FormatException>(() => parser.ParseZone('', tokens));
    },

    'ParseZone_emptyString_exception': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('');
      Assert.Throws<InvalidDataException>(() => parser.ParseZone('', tokens));
    },

    'ParseZone_optionalRule': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('2:00 - P%sT');
      var expected =
          ZoneLine('', ToOffset(2, 0), null, 'P%sT', Int64.Int32MaxValue, TzdbZoneInfoParser.StartOfYearZoneOffset);
      Assert.AreEqual(expected, parser.ParseZone('', tokens));
    },

    'ParseZone_simple': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('2:00 US P%sT');
      var expected =
          ZoneLine('', ToOffset(2, 0), 'US', 'P%sT', Int64.Int32MaxValue, TzdbZoneInfoParser.StartOfYearZoneOffset);
      Assert.AreEqual(expected, parser.ParseZone('', tokens));
    },

    'ParseZone_tooFewWords1_exception': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('2:00 US');
      Assert.Throws<InvalidDataException>(() => parser.ParseZone('', tokens));
    },

    'ParseZone_tooFewWords2_exception': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('2:00');
      Assert.Throws<InvalidDataException>(() => parser.ParseZone('', tokens));
    },

    'ParseZone_withYear': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('2:00 US P%sT 1969');
      var expected = ZoneLine('', ToOffset(2, 0), 'US', 'P%sT', 1969,
          ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 1, 1, 0, false, LocalTime.Midnight));
      Assert.AreEqual(expected, parser.ParseZone('', tokens));
    },

    'ParseZone_withYearMonthDay': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('2:00 US P%sT 1969 Mar 23');
      var expected = ZoneLine('', ToOffset(2, 0), 'US', 'P%sT', 1969,
          ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(TransitionMode.Wall, 3, 23, 0, false, LocalTime.Midnight));
      Assert.AreEqual(expected, parser.ParseZone('', tokens));
    },

    'ParseZone_withYearMonthDayTime': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('2:00 US P%sT 1969 Mar 23 14:53:27.856');
      var expected = ZoneLine('', ToOffset(2, 0), 'US', 'P%sT', 1969,
          ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
              TransitionMode.Wall, 3, 23, 0, false, LocalTime(14, 53, 27, 856)));
      Assert.AreEqual(expected, parser.ParseZone('', tokens));
    },

    'ParseZone_withYearMonthDayTimeZone': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('2:00 US P%sT 1969 Mar 23 14:53:27.856s');
      var expected = ZoneLine('', ToOffset(2, 0), 'US', 'P%sT', 1969,
          ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
              TransitionMode.Standard, 3, 23, 0, false, LocalTime(14, 53, 27, 856)));
      Assert.AreEqual(expected, parser.ParseZone('', tokens));
    },

    'ParseZone_withDayOfWeek': (args) {
      var parser = TzdbZoneInfoParser();
      var tokens = Tokens.Tokenize('2:00 US P%sT 1969 Mar lastSun');
      var expected = ZoneLine('', ToOffset(2, 0), 'US', 'P%sT', 1969,
          ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
              TransitionMode.Wall, 3, -1, IsoDayOfWeek.Sunday.value, false, LocalTime.Midnight));
      Assert.AreEqual(expected, parser.ParseZone('', tokens));
    },

    'Parse_threeLines': (args) {
      const String text = '# A comment\n'
          'Zone PST 2:00 US P%sT\n'
          '         3:00 -  P%sT\n';
      var database = ParseText(text);
      ValidateCounts(database, 0, 1, 0);
      Assert.AreEqual(2, database.Zones.values.single.length);
    },

    'Parse_threeLinesWithComment': (args) {
      const String text = '# A comment\n'
          'Zone PST 2:00 US P%sT # An end of line comment\n'
          '         3:00 -  P%sT\n';
      var database = ParseText(text);
      ValidateCounts(database, 0, 1, 0);
      Assert.AreEqual(2, database.Zones.values.single.length);
    },

    'Parse_twoLines': (args) {
      const String text = '# A comment\n'
          'Zone PST 2:00 US P%sT\n';
      var database = ParseText(text);
      ValidateCounts(database, 0, 1, 0);
      Assert.AreEqual(1, database.Zones.values.single.length);
    },

    'Parse_twoLinks': (args) {
      const String text = '# First line must be a comment\n'
          'Link from to\n' 'Link target source\n';
      var database = ParseText(text);
      ValidateCounts(database, 0, 0, 2);
    },

    'Parse_twoZones': (args) {
      const String text = '# A comment\n'
          'Zone PST 2:00 US P%sT # An end of line comment\n'
          '         3:00 -  P%sT\n'
          '         4:00 -  P%sT\n'
          'Zone EST 2:00 US E%sT # An end of line comment\n'
          '         3:00 -  E%sT\n';
      var database = ParseText(text);
      ValidateCounts(database, 0, 2, 0);
      Assert.AreEqual(3, database.Zones['PST']!.length);
      Assert.AreEqual(2, database.Zones['EST']!.length);
    },

    'Parse_twoZonesTwoRule': (args) {
      const String text = '# A comment\n'
          'Rule US 1987 2006 - Apr Sun>=1 2:00 1:00 D\n'
          'Rule US 2007 max  - Mar Sun>=8 2:00 1:00 D\n'
          'Zone PST 2:00 US P%sT # An end of line comment\n'
          '         3:00 -  P%sT\n' '         4:00 -  P%sT\n'
          'Zone EST 2:00 US E%sT # An end of line comment\n'
          '         3:00 -  E%sT\n';
      var database = ParseText(text);
      ValidateCounts(database, 1, 2, 0);
      Assert.AreEqual(3, database.Zones['PST']!.length);
      Assert.AreEqual(2, database.Zones['EST']!.length);
    },

    // 2018f uses 25:00 for Japan's fallback transitions 1948-1951
    'Parse_2500_FromDay_AtLeast_Sunday': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Apr Sun>=1  25:00';
      var tokens = Tokens.Tokenize(text);
      var rule = parser.ParseDateTimeOfYear(tokens, true);
      var actual = rule.GetOccurrenceForYear(2012);
      var expected = LocalDateTime(2012, 4, 2, 1, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'Parse_2400_FromDay_AtLeast_Sunday': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Apr Sun>=1  24:00';
      var tokens = Tokens.Tokenize(text);
      var rule = parser.ParseDateTimeOfYear(tokens, true);
      var actual = rule.GetOccurrenceForYear(2012);
      var expected = LocalDateTime(2012, 4, 2, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'Parse_2400_FromDay_AtMost_Sunday': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Apr Sun<=7  24:00';
      var tokens = Tokens.Tokenize(text);
      var rule = parser.ParseDateTimeOfYear(tokens, true);
      var actual = rule.GetOccurrenceForYear(2012);
      var expected = LocalDateTime(2012, 4, 2, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'Parse_2400_FromDay_AtLeast_Wednesday': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Apr Wed>=1  24:00';
      var tokens = Tokens.Tokenize(text);
      var rule = parser.ParseDateTimeOfYear(tokens, true);
      var actual = rule.GetOccurrenceForYear(2012);
      var expected = LocalDateTime(2012, 4, 5, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'Parse_2400_FromDay_AtMost_Wednesday': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Apr Wed<=14  24:00';
      var tokens = Tokens.Tokenize(text);
      var rule = parser.ParseDateTimeOfYear(tokens, true);
      var actual = rule.GetOccurrenceForYear(2012);
      var expected = LocalDateTime(2012, 4, 12, 0, 0).ToLocalInstant();
      Assert.AreEqual(expected, actual);
    },

    'Parse_2400_FromDay': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Apr Sun>=1  24:00';
      var tokens = Tokens.Tokenize(text);
      var actual = parser.ParseDateTimeOfYear(tokens, true);
      var expected = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(
          TransitionMode.Wall, 4, 1, IsoDayOfWeek.Sunday.value, true, LocalTime.Midnight, true);
      Assert.AreEqual(expected, actual);
    },

    'Parse_2400_Last': (args) {
      var parser = TzdbZoneInfoParser();
      const String text = 'Mar lastSun 24:00';
      var tokens = Tokens.Tokenize(text);
      var actual = parser.ParseDateTimeOfYear(tokens, true);
      var expected = ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(
          TransitionMode.Wall, 3, -1, IsoDayOfWeek.Sunday.value, false, LocalTime.Midnight, true);
      Assert.AreEqual(expected, actual);
    },

    'Parse_Fixed_Eastern': (args) {
      const String text = '# A comment\n'
          'Zone\tEtc/GMT-9\t9\t-\tGMT-9\n';
      var database = ParseText(text);

      ValidateCounts(database, 0, 1, 0);
      var zone = database.Zones['Etc/GMT-9']!.single;
      Assert.AreEqual(Offset.FromHours(9), zone.StandardOffset);
      Assert.IsNull(zone.Rules);
      Assert.AreEqual(Int64.Int32MaxValue, zone.UntilYear);
    },

    'Parse_Fixed_Western': (args) {
      const String text = '# A comment\n'
          'Zone\tEtc/GMT+9\t-9\t-\tGMT+9\n';
      var database = ParseText(text);

      ValidateCounts(database, 0, 1, 0);
      var zone = database.Zones['Etc/GMT+9']!.single;
      Assert.AreEqual(Offset.FromHours(-9), zone.StandardOffset);
      Assert.IsNull(zone.Rules);
      Assert.AreEqual(Int64.Int32MaxValue, zone.UntilYear);
    },

    'Parse_RuleWithType': (args) {
      String line = 'Rule BrokenRule 2010 2020 odd Apr Sun>=1 2:00 1:00 D\n';
      var exception = Assert.Throws<UnimplementedError>(() => ParseText(line));
      StringAssert.Contains("'BrokenRule'", exception.message!);
      StringAssert.Contains("'odd'", exception.message!);
    },
  });
}

Offset ToOffset(int hours, int minutes) {
  return Offset.FromHoursAndMinutes(hours, minutes);
}

void ValidateCounts(TzdbDatabase database, int ruleSets, int zoneLists, int links) {
  Assert.AreEqual(ruleSets, database.Rules.length, 'Rules');
  Assert.AreEqual(zoneLists, database.Zones.length, 'Zones');
  Assert.AreEqual(links, database.Aliases.length, 'Links');
}

/// Helper method to create a database and call Parse with the given text.
TzdbDatabase ParseText(String line) {
  var parser = TzdbZoneInfoParser();
  var database = TzdbDatabase('version');
  parser.ParseTextReader(line, database);
  return database;
}
