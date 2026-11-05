// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler.Test/Tzdb/TzdbZoneInfoParserTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the internal ZoneYearOffset constructors are the static factories
// NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(AddDay); ParseLink returns an [existing, alias] array
// rather than a Tuple; Parse takes the text itself rather than a StringReader. The month names C# gets from
// DateTime.ToString("MMM"/"MMMM", CultureInfo.InvariantCulture) come from LocalDatePattern with the invariant culture.

import { expect } from "vitest";
import {
  Int32,
  IsoDayOfWeek,
  LocalDate,
  LocalDatePattern,
  LocalDateTime,
  LocalTime,
  Offset,
  TransitionMode,
  ZoneYearOffset,
} from "../../../../src/noda-js/internal.ts";
import {
  Tokens,
  TzdbDatabase,
  TzdbZoneInfoParser,
  ZoneLine,
} from "../../../../src/noda-js/TzdbCompiler/internal.ts";
import { assertNodaEqual, assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TzdbCompiler/Tzdb/TzdbZoneInfoParserTest.generated.ts";

/** C# `new ZoneYearOffset(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay[, addDay])`. */
function newZoneYearOffset(
  mode: TransitionMode,
  monthOfYear: number,
  dayOfMonth: number,
  dayOfWeek: number,
  advance: boolean,
  timeOfDay: LocalTime,
  addDay?: boolean,
): ZoneYearOffset {
  return addDay === undefined
    ? ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay)
    : ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay, addDay);
}

function ToOffset(hours: number, minutes: number): Offset {
  return Offset.FromHoursAndMinutes(hours, minutes);
}

function ValidateCounts(database: TzdbDatabase, ruleSets: number, zoneLists: number, links: number): void {
  expect(database.Rules.size, "Rules").toBe(ruleSets);
  expect(database.Zones.size, "Zones").toBe(zoneLists);
  expect(database.Aliases.size, "Links").toBe(links);
}

/** LINQ's Single(): the only element of the sequence. */
function Single<T>(values: Iterable<T>): T {
  const array = [...values];
  expect(array.length, "Single()").toBe(1);
  return array[0]!;
}

/**
 * Helper method to create a database and call Parse with the given text.
 */
function ParseText(line: string): TzdbDatabase {
  const parser = new TzdbZoneInfoParser();
  const database = new TzdbDatabase("version");
  parser.Parse(line, database);
  return database;
}

/** The ZoneLines for the given zone ID (C#: `database.Zones[id]`). */
function ZoneLines(database: TzdbDatabase, id: string): ZoneLine[] {
  const lines = database.Zones.get(id);
  expect(lines, `Zones[${id}]`).toBeDefined();
  return lines!;
}

port(fixture, {
  ParseDateTimeOfYear_emptyString() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("");
    assertThrows("InvalidDataException", () => parser.ParseDateTimeOfYear(tokens, true));
  },

  ParseDateTimeOfYear_missingAt_invalidForRule() {
    const parser = new TzdbZoneInfoParser();
    const text = "Mar lastSun";
    const tokens = Tokens.Tokenize(text);
    assertThrows("InvalidDataException", () => parser.ParseDateTimeOfYear(tokens, true));
  },

  ParseDateTimeOfYear_missingOn_invalidForRule() {
    const parser = new TzdbZoneInfoParser();
    const text = "Mar";
    const tokens = Tokens.Tokenize(text);
    assertThrows("InvalidDataException", () => parser.ParseDateTimeOfYear(tokens, true));
  },

  ParseDateTimeOfYear_missingAt_validForZone() {
    const parser = new TzdbZoneInfoParser();
    const text = "Mar lastSun";
    const tokens = Tokens.Tokenize(text);
    const actual = parser.ParseDateTimeOfYear(tokens, false);
    const expected = newZoneYearOffset(TransitionMode.Wall, 3, -1, IsoDayOfWeek.Sunday, false, LocalTime.Midnight);
    assertNodaEqual(actual, expected);
  },

  ParseDateTimeOfYear_missingOn_validForZone() {
    const parser = new TzdbZoneInfoParser();
    const text = "Mar";
    const tokens = Tokens.Tokenize(text);
    const actual = parser.ParseDateTimeOfYear(tokens, false);
    const expected = newZoneYearOffset(TransitionMode.Wall, 3, 1, 0, false, LocalTime.Midnight);
    assertNodaEqual(actual, expected);
  },

  ParseDateTimeOfYear_onAfter() {
    const parser = new TzdbZoneInfoParser();
    const text = "Mar Tue>=14 2:00";
    const tokens = Tokens.Tokenize(text);
    const actual = parser.ParseDateTimeOfYear(tokens, true);
    const expected = newZoneYearOffset(TransitionMode.Wall, 3, 14, IsoDayOfWeek.Tuesday, true, new LocalTime(2, 0));
    assertNodaEqual(actual, expected);
  },

  ParseDateTimeOfYear_onBefore() {
    const parser = new TzdbZoneInfoParser();
    const text = "Mar Tue<=14 2:00";
    const tokens = Tokens.Tokenize(text);
    const actual = parser.ParseDateTimeOfYear(tokens, true);
    const expected = newZoneYearOffset(TransitionMode.Wall, 3, 14, IsoDayOfWeek.Tuesday, false, new LocalTime(2, 0));
    assertNodaEqual(actual, expected);
  },

  ParseDateTimeOfYear_onLast() {
    const parser = new TzdbZoneInfoParser();
    const text = "Mar lastTue 2:00";
    const tokens = Tokens.Tokenize(text);
    const actual = parser.ParseDateTimeOfYear(tokens, true);
    const expected = newZoneYearOffset(TransitionMode.Wall, 3, -1, IsoDayOfWeek.Tuesday, false, new LocalTime(2, 0));
    assertNodaEqual(actual, expected);
  },

  ParseLine_comment() {
    const line = "# Comment";
    const database = ParseText(line);
    ValidateCounts(database, 0, 0, 0);
  },

  ParseLine_commentWithLeadingWhitespace() {
    const line = "   # Comment";
    const database = ParseText(line);
    ValidateCounts(database, 0, 0, 0);
  },

  ParseLine_emptyString() {
    const database = ParseText("");
    ValidateCounts(database, 0, 0, 0);
  },

  // Assume that all lines work the same way - it's comment handling
  // that's important here.
  ParseLine_commentAtEndOfLine() {
    const line = "Link from to#Comment";
    const database = ParseText(line);
    ValidateCounts(database, 0, 0, 1);
    assertNodaEqual(database.Aliases.get("to"), "from");
  },

  ParseLine_link() {
    const line = "Link from to";
    const database = ParseText(line);
    ValidateCounts(database, 0, 0, 1);
  },

  ParseLine_whiteSpace() {
    const line = "    \t\t\n";
    const database = ParseText(line);
    ValidateCounts(database, 0, 0, 0);
  },

  ParseLine_zone() {
    const line = "Zone PST 2:00 US P%sT";
    const database = ParseText(line);
    ValidateCounts(database, 0, 1, 0);
    assertNodaEqual(Single(database.Zones.values()).length, 1);
  },

  ParseLine_zonePlus() {
    const lines =
      "Zone PST 2:00 US P%sT\n" +
      "  3:00 US P%sT";
    const database = ParseText(lines);
    ValidateCounts(database, 0, 1, 0);
    assertNodaEqual(ZoneLines(database, "PST").length, 2);
  },

  ParseLink_emptyString_exception() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("");
    assertThrows("InvalidDataException", () => parser.ParseLink(tokens));
  },

  ParseLink_simple() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("from to");
    const actual = parser.ParseLink(tokens);
    const expected = ["from", "to"];
    assertNodaEqual(actual, expected);
  },

  ParseLink_tooFewWords_exception() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("from");
    assertThrows("InvalidDataException", () => parser.ParseLink(tokens));
  },

  ParseMonth_nullOrEmpty() {
    assertThrows("ArgumentException", () => TzdbZoneInfoParser.ParseMonth(""));
    assertThrows("ArgumentException", () => TzdbZoneInfoParser.ParseMonth(null!));
  },

  ParseMonth_invalidMonth_default() {
    assertThrows("InvalidDataException", () => TzdbZoneInfoParser.ParseMonth("Able"));
  },

  ParseMonth_shortMonthNames() {
    const pattern = LocalDatePattern.CreateWithInvariantCulture("MMM");
    for (let i = 1; i < 12; i++) {
      const month = pattern.Format(new LocalDate(2000, i, 1));
      assertNodaEqual(TzdbZoneInfoParser.ParseMonth(month), i);
    }
  },

  ParseMonth_longMonthNames() {
    const pattern = LocalDatePattern.CreateWithInvariantCulture("MMMM");
    for (let i = 1; i < 12; i++) {
      const month = pattern.Format(new LocalDate(2000, i, 1));
      assertNodaEqual(TzdbZoneInfoParser.ParseMonth(month), i);
    }
  },

  ParseZone_badOffset_exception() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("asd US P%sT 1969 Mar 23 14:53:27.856s");
    assertThrows("FormatException", () => parser.ParseZone("", tokens));
  },

  ParseZone_emptyString_exception() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("");
    assertThrows("InvalidDataException", () => parser.ParseZone("", tokens));
  },

  ParseZone_optionalRule() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("2:00 - P%sT");
    const expected = new ZoneLine("", ToOffset(2, 0), null, "P%sT", Int32.MaxValue, TzdbZoneInfoParser.StartOfYearZoneOffset);
    assertNodaEqual(parser.ParseZone("", tokens), expected);
  },

  ParseZone_simple() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("2:00 US P%sT");
    const expected = new ZoneLine("", ToOffset(2, 0), "US", "P%sT", Int32.MaxValue, TzdbZoneInfoParser.StartOfYearZoneOffset);
    assertNodaEqual(parser.ParseZone("", tokens), expected);
  },

  ParseZone_tooFewWords1_exception() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("2:00 US");
    assertThrows("InvalidDataException", () => parser.ParseZone("", tokens));
  },

  ParseZone_tooFewWords2_exception() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("2:00");
    assertThrows("InvalidDataException", () => parser.ParseZone("", tokens));
  },

  ParseZone_withYear() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("2:00 US P%sT 1969");
    const expected = new ZoneLine("", ToOffset(2, 0), "US", "P%sT", 1969, newZoneYearOffset(TransitionMode.Wall, 1, 1, 0, false, LocalTime.Midnight));
    assertNodaEqual(parser.ParseZone("", tokens), expected);
  },

  ParseZone_withYearMonthDay() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("2:00 US P%sT 1969 Mar 23");
    const expected = new ZoneLine("", ToOffset(2, 0), "US", "P%sT", 1969, newZoneYearOffset(TransitionMode.Wall, 3, 23, 0, false, LocalTime.Midnight));
    assertNodaEqual(parser.ParseZone("", tokens), expected);
  },

  ParseZone_withYearMonthDayTime() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("2:00 US P%sT 1969 Mar 23 14:53:27.856");
    const expected = new ZoneLine("", ToOffset(2, 0), "US", "P%sT", 1969,
      newZoneYearOffset(TransitionMode.Wall, 3, 23, 0, false, new LocalTime(14, 53, 27, 856)));
    assertNodaEqual(parser.ParseZone("", tokens), expected);
  },

  ParseZone_withYearMonthDayTimeZone() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("2:00 US P%sT 1969 Mar 23 14:53:27.856s");
    const expected = new ZoneLine("", ToOffset(2, 0), "US", "P%sT", 1969,
      newZoneYearOffset(TransitionMode.Standard, 3, 23, 0, false, new LocalTime(14, 53, 27, 856)));
    assertNodaEqual(parser.ParseZone("", tokens), expected);
  },

  ParseZone_withDayOfWeek() {
    const parser = new TzdbZoneInfoParser();
    const tokens = Tokens.Tokenize("2:00 US P%sT 1969 Mar lastSun");
    const expected = new ZoneLine("", ToOffset(2, 0), "US", "P%sT", 1969,
      newZoneYearOffset(TransitionMode.Wall, 3, -1, IsoDayOfWeek.Sunday, false, LocalTime.Midnight));
    assertNodaEqual(parser.ParseZone("", tokens), expected);
  },

  Parse_threeLines() {
    const text =
      "# A comment\n" +
      "Zone PST 2:00 US P%sT\n" +
      "         3:00 -  P%sT\n";
    const database = ParseText(text);
    ValidateCounts(database, 0, 1, 0);
    assertNodaEqual(Single(database.Zones.values()).length, 2);
  },

  Parse_threeLinesWithComment() {
    const text =
      "# A comment\n" +
      "Zone PST 2:00 US P%sT # An end of line comment\n" +
      "         3:00 -  P%sT\n";
    const database = ParseText(text);
    ValidateCounts(database, 0, 1, 0);
    assertNodaEqual(Single(database.Zones.values()).length, 2);
  },

  Parse_twoLines() {
    const text =
      "# A comment\n" +
      "Zone PST 2:00 US P%sT\n";
    const database = ParseText(text);
    ValidateCounts(database, 0, 1, 0);
    assertNodaEqual(Single(database.Zones.values()).length, 1);
  },

  Parse_twoLinks() {
    const text =
      "# First line must be a comment\n" +
      "Link from to\n" + "Link target source\n";
    const database = ParseText(text);
    ValidateCounts(database, 0, 0, 2);
  },

  Parse_twoZones() {
    const text =
      "# A comment\n" +
      "Zone PST 2:00 US P%sT # An end of line comment\n" +
      "         3:00 -  P%sT\n" +
      "         4:00 -  P%sT\n" +
      "Zone EST 2:00 US E%sT # An end of line comment\n" +
      "         3:00 -  E%sT\n";
    const database = ParseText(text);
    ValidateCounts(database, 0, 2, 0);
    assertNodaEqual(ZoneLines(database, "PST").length, 3);
    assertNodaEqual(ZoneLines(database, "EST").length, 2);
  },

  Parse_twoZonesTwoRule() {
    const text =
      "# A comment\n" +
      "Rule US 1987 2006 - Apr Sun>=1 2:00 1:00 D\n" +
      "Rule US 2007 max  - Mar Sun>=8 2:00 1:00 D\n" +
      "Zone PST 2:00 US P%sT # An end of line comment\n" +
      "         3:00 -  P%sT\n" + "         4:00 -  P%sT\n" +
      "Zone EST 2:00 US E%sT # An end of line comment\n" +
      "         3:00 -  E%sT\n";
    const database = ParseText(text);
    ValidateCounts(database, 1, 2, 0);
    assertNodaEqual(ZoneLines(database, "PST").length, 3);
    assertNodaEqual(ZoneLines(database, "EST").length, 2);
  },

  // 2018f uses 25:00 for Japan's fallback transitions 1948-1951
  Parse_2500_FromDay_AtLeast_Sunday() {
    const parser = new TzdbZoneInfoParser();
    const text = "Apr Sun>=1  25:00";
    const tokens = Tokens.Tokenize(text);
    const rule = parser.ParseDateTimeOfYear(tokens, true);
    const actual = rule.GetOccurrenceForYear(2012);
    const expected = new LocalDateTime(2012, 4, 2, 1, 0).ToLocalInstant();
    assertNodaEqual(actual, expected);
  },

  Parse_2400_FromDay_AtLeast_Sunday() {
    const parser = new TzdbZoneInfoParser();
    const text = "Apr Sun>=1  24:00";
    const tokens = Tokens.Tokenize(text);
    const rule = parser.ParseDateTimeOfYear(tokens, true);
    const actual = rule.GetOccurrenceForYear(2012);
    const expected = new LocalDateTime(2012, 4, 2, 0, 0).ToLocalInstant();
    assertNodaEqual(actual, expected);
  },

  Parse_2400_FromDay_AtMost_Sunday() {
    const parser = new TzdbZoneInfoParser();
    const text = "Apr Sun<=7  24:00";
    const tokens = Tokens.Tokenize(text);
    const rule = parser.ParseDateTimeOfYear(tokens, true);
    const actual = rule.GetOccurrenceForYear(2012);
    const expected = new LocalDateTime(2012, 4, 2, 0, 0).ToLocalInstant();
    assertNodaEqual(actual, expected);
  },

  Parse_2400_FromDay_AtLeast_Wednesday() {
    const parser = new TzdbZoneInfoParser();
    const text = "Apr Wed>=1  24:00";
    const tokens = Tokens.Tokenize(text);
    const rule = parser.ParseDateTimeOfYear(tokens, true);
    const actual = rule.GetOccurrenceForYear(2012);
    const expected = new LocalDateTime(2012, 4, 5, 0, 0).ToLocalInstant();
    assertNodaEqual(actual, expected);
  },

  Parse_2400_FromDay_AtMost_Wednesday() {
    const parser = new TzdbZoneInfoParser();
    const text = "Apr Wed<=14  24:00";
    const tokens = Tokens.Tokenize(text);
    const rule = parser.ParseDateTimeOfYear(tokens, true);
    const actual = rule.GetOccurrenceForYear(2012);
    const expected = new LocalDateTime(2012, 4, 12, 0, 0).ToLocalInstant();
    assertNodaEqual(actual, expected);
  },

  Parse_2400_FromDay() {
    const parser = new TzdbZoneInfoParser();
    const text = "Apr Sun>=1  24:00";
    const tokens = Tokens.Tokenize(text);
    const actual = parser.ParseDateTimeOfYear(tokens, true);
    const expected = newZoneYearOffset(TransitionMode.Wall, 4, 1, IsoDayOfWeek.Sunday, true, LocalTime.Midnight, true);
    assertNodaEqual(actual, expected);
  },

  Parse_2400_Last() {
    const parser = new TzdbZoneInfoParser();
    const text = "Mar lastSun 24:00";
    const tokens = Tokens.Tokenize(text);
    const actual = parser.ParseDateTimeOfYear(tokens, true);
    const expected = newZoneYearOffset(TransitionMode.Wall, 3, -1, IsoDayOfWeek.Sunday, false, LocalTime.Midnight, true);
    assertNodaEqual(actual, expected);
  },

  Parse_Fixed_Eastern() {
    const text =
      "# A comment\n" +
      "Zone\tEtc/GMT-9\t9\t-\tGMT-9\n";
    const database = ParseText(text);

    ValidateCounts(database, 0, 1, 0);
    const zone = Single(ZoneLines(database, "Etc/GMT-9"));
    assertNodaEqual(zone.StandardOffset, Offset.FromHours(9));
    expect(zone.Rules).toBeNull();
    assertNodaEqual(zone.UntilYear, Int32.MaxValue);
  },

  Parse_Fixed_Western() {
    const text =
      "# A comment\n" +
      "Zone\tEtc/GMT+9\t-9\t-\tGMT+9\n";
    const database = ParseText(text);

    ValidateCounts(database, 0, 1, 0);
    const zone = Single(ZoneLines(database, "Etc/GMT+9"));
    assertNodaEqual(zone.StandardOffset, Offset.FromHours(-9));
    expect(zone.Rules).toBeNull();
    assertNodaEqual(zone.UntilYear, Int32.MaxValue);
  },

  Parse_RuleWithType() {
    const line = "Rule BrokenRule 2010 2020 odd Apr Sun>=1 2:00 1:00 D\n";
    const exception = assertThrows("NotImplementedException", () => ParseText(line));
    expect(exception.message).toContain("'BrokenRule'");
    expect(exception.message).toContain("'odd'");
  },
});
