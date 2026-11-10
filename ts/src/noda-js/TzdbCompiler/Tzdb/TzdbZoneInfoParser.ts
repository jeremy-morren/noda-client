// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/TzdbZoneInfoParser.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  Int32,
  LocalTime,
  Preconditions,
  TransitionMode,
  ZoneRecurrence,
  ZoneYearOffset,
} from "../../internal.ts";
import type { Offset } from "../../internal.ts";
import {
  IsLetter,
  ParseInt32,
  ParserHelper,
  ReadLines,
  RuleLine,
  StartsWithOrdinalIgnoreCase,
  Tokens,
  TrimEnd,
  ZoneLine,
} from "../internal.ts";
import type { TzdbDatabase } from "../internal.ts";
import { IsNodaError, NewArgumentException, NewInvalidDataException, NewNotImplementedException, type InvalidDataException } from "../../internal.ts";

let startOfYearZoneOffset: ZoneYearOffset | undefined;

/**
 * The keyword that specifies the line defines an alias link.
 */
const KeywordLink = "Link";

/**
 * The keyword that specifies the line defines a daylight savings rule.
 */
const KeywordRule = "Rule";

/**
 * The keyword that specifies the line defines a time zone.
 */
const KeywordZone = "Zone";

/**
 * The days of the week names as they appear in the TZDB zone files. They are
 * always the short name in US English.
 */
const DaysOfWeek: readonly string[] = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

/**
 * The months of the year names as they appear in the TZDB zone files. Entries are usually
 * abbreviated to (an unambiguous prefix of) the first three letters, e.g. "Jan", but older
 * files sometimes spell them out in full, e.g. "January" in Greece's 96d rule. As the short
 * form is always a prefix of the long form, matching against the long form alone covers both.
 */
const LongMonths: readonly string[] =
  ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

/**
 * Provides a parser for TZDB time zone description files.
 * @internal
 */
export class TzdbZoneInfoParser {
  /**
   * An offset that specifies the beginning of the year.
   */
  static get StartOfYearZoneOffset(): ZoneYearOffset {
    return (startOfYearZoneOffset ??= ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
      TransitionMode.Wall, 1, 1, 0, false, LocalTime.Midnight));
  }

  /**
   * Parses the next token as a month number (1-12).
   * @param tokens The tokens.
   * @param name The name of the expected value, for use in the exception if no value is available.
   */
  private NextMonth(tokens: Tokens, name: string): number {
    const value = this.NextString(tokens, name);
    return TzdbZoneInfoParser.ParseMonth(value);
  }

  /**
   * Parses the next token as an offset.
   * @param tokens The tokens.
   * @param name The name of the expected value, for use in the exception if no value is available.
   */
  private NextOffset(tokens: Tokens, name: string): Offset {
    return ParserHelper.ParseOffset(this.NextString(tokens, name));
  }

  /**
   * Returns the next token, which is optional, converting "-" to null.
   * @param tokens The tokens.
   * @param name The name of the expected value, for use in the exception if no value is available.
   */
  private NextOptional(tokens: Tokens, name: string): string | null {
    return ParserHelper.ParseOptional(this.NextString(tokens, name));
  }

  /**
   * Returns the next string from the token stream.
   * @param tokens The tokens to parse from.
   * @param name The name of the expected value, for use in the exception if no value is available.
   */
  private NextString(tokens: Tokens, name: string): string {
    if (!tokens.HasNextToken) {
      throw NewInvalidDataException(`Missing zone info token: ${name}`);
    }
    return tokens.NextToken(name);
  }

  /**
   * Parses the next string from the token stream as a year.
   * @param tokens The tokens.
   * @param defaultValue The default value to return if the year isn't specified.
   */
  private static NextYear(tokens: Tokens, defaultValue: number): number {
    let result = defaultValue;
    const [success, text] = tokens.TryNextToken();
    if (success) {
      result = ParserHelper.ParseYear(text, defaultValue);
    }
    return result;
  }

  /**
   * Parses the TZDB time zone info file from the given stream (bytes) or reader (text) and merges its information
   * with the given database.
   *
   * noda-js: merges Parse(Stream, ...) and Parse(TextReader, ...): bytes are UTF-8 (skipping a BOM); a string is the text.
   * @param input The stream input (bytes) or text to parse.
   * @param database The database to fill.
   */
  Parse(input: Uint8Array | string, database: TzdbDatabase): void {
    let currentZone: string | null = null;
    for (const line of ReadLines(input)) {
      currentZone = this.ParseLine(line, currentZone, database);
    }
  }

  /**
   * Parses the ZoneYearOffset for a rule or zone. This is something like "3rd Sunday of October at 2am".
   *
   * IN ON AT
   * @param tokens The tokens to parse.
   * @param forRule True if this is for a Rule line, in which case ON/AT are mandatory;
   * false for a Zone line, in which case it's part of "until" and they're optional
   * @returns The ZoneYearOffset object.
   */
  ParseDateTimeOfYear(tokens: Tokens, forRule: boolean): ZoneYearOffset {
    let mode = TzdbZoneInfoParser.StartOfYearZoneOffset.Mode;
    let timeOfDay = TzdbZoneInfoParser.StartOfYearZoneOffset.TimeOfDay;

    const monthOfYear = this.NextMonth(tokens, "MonthOfYear");

    let dayOfMonth = 1;
    let dayOfWeek = 0;
    let advanceDayOfWeek = false;
    let addDay = false;

    if (tokens.HasNextToken || forRule) {
      const on = this.NextString(tokens, "On");
      if (on.startsWith("last")) {
        dayOfMonth = -1;
        dayOfWeek = TzdbZoneInfoParser.ParseDayOfWeek(on.substring(4));
      } else {
        let index = on.indexOf(">=");
        if (index > 0) {
          dayOfMonth = ParseInt32(on.substring(index + 2));
          dayOfWeek = TzdbZoneInfoParser.ParseDayOfWeek(on.substring(0, index));
          advanceDayOfWeek = true;
        } else {
          index = on.indexOf("<=");
          if (index > 0) {
            dayOfMonth = ParseInt32(on.substring(index + 2));
            dayOfWeek = TzdbZoneInfoParser.ParseDayOfWeek(on.substring(0, index));
          } else {
            try {
              dayOfMonth = ParseInt32(on);
              dayOfWeek = 0;
            } catch (e) {
              if (IsNodaError(e, "FormatException")) {
                throw NewArgumentException(`Unparsable ON token: ${on}`, null, { cause: e });
              }
              throw e;
            }
          }
        }
      }

      if (tokens.HasNextToken || forRule) {
        let atTime = this.NextString(tokens, "AT");
        if (atTime !== "") {
          if (IsLetter(atTime.charAt(atTime.length - 1))) {
            const zoneCharacter = atTime.charAt(atTime.length - 1);
            mode = TzdbZoneInfoParser.ConvertModeCharacter(zoneCharacter);
            atTime = atTime.substring(0, atTime.length - 1);
          }
          if (atTime === "24:00") {
            timeOfDay = LocalTime.Midnight;
            addDay = true;
          }
          // As of TZDB 2018f, Japan's fallback transitions occur at 25:00. We can't
          // represent this entirely accurately, but this is as close as we can approximate it.
          else if (atTime === "25:00") {
            timeOfDay = new LocalTime(1, 0);
            addDay = true;
          } else {
            timeOfDay = ParserHelper.ParseTime(atTime);
          }
        }
      }
    }
    return ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(
      mode, monthOfYear, dayOfMonth, dayOfWeek, advanceDayOfWeek, timeOfDay, addDay);
  }

  /**
   * Parses the day of week, which may be any case-insensitive, unambiguous prefix of a day
   * name (matching the behavior of zic itself).
   * @param text The text.
   */
  static ParseDayOfWeek(text: string): number {
    return TzdbZoneInfoParser.ParseUnambiguousNamePrefix(text, "day of week", DaysOfWeek);
  }

  /**
   * Parses a single line of an TZDB zone info file.
   *
   * TZDB files have a simple line based structure. Each line defines one item. Comments
   * start with a hash or pound sign (#) and continue to the end of the line. Blank lines are
   * ignored. Of the remaining there are four line types which are determined by the first
   * keyword on the line.
   *
   * A line beginning with the keyword `Link` defines an alias between one time zone and
   * another. Both time zones use the same definition but have different names.
   *
   * A line beginning with the keyword `Rule` defines a daylight savings time
   * calculation rule.
   *
   * A line beginning with the keyword `Zone` defines a time zone.
   *
   * A line beginning with leading whitespace (an empty keyword) defines another part of the
   * preceding time zone. As many lines as necessary to define the time zone can be listed,
   * but they must all be together and only the first line can have a name.
   * @param line The line to parse.
   * @param previousZone The previous zone ID, or null if we don't have one.
   * @param database The database to fill.
   * @returns The zone name just parsed, if any - so that it can be passed into the next call.
   */
  private ParseLine(line: string, previousZone: string | null, database: TzdbDatabase): string | null {
    // Trim end-of-line comments
    const index = line.indexOf("#");
    if (index >= 0) {
      line = line.substring(0, index);
    }
    line = TrimEnd(line);
    if (line.length === 0) {
      // We can still continue with the previous zone
      return previousZone;
    }

    // Okay, everything left in the line should be "real" now.
    const tokens = Tokens.Tokenize(line);
    const keyword = this.NextString(tokens, "Keyword");
    switch (keyword) {
      case KeywordRule:
        database.AddRule(this.ParseRule(tokens));
        return null;
      case KeywordLink: {
        const alias = this.ParseLink(tokens);
        database.AddAlias(alias[0], alias[1]);
        return null;
      }
      case KeywordZone: {
        const name = this.NextString(tokens, "GetName");
        database.AddZone(this.ParseZone(name, tokens));
        return name;
      }
      default:
        if (keyword === "") {
          if (previousZone === null) {
            throw NewInvalidDataException("Zone continuation provided with no previous zone line");
          }
          database.AddZone(this.ParseZone(previousZone, tokens));
          return previousZone;
        } else {
          throw NewInvalidDataException(`Unexpected zone database keyword: ${keyword}`);
        }
    }
  }

  /**
   * Parses an alias link and returns the ZoneAlias object.
   * @param tokens The tokens to parse.
   * @returns The ZoneAlias object: a tuple of the existing zone ID and the alias.
   */
  ParseLink(tokens: Tokens): [string, string] {
    const existing = this.NextString(tokens, "Existing");
    const alias = this.NextString(tokens, "Alias");
    return [existing, alias];
  }

  /**
   * Parses the month, which may be any case-insensitive, unambiguous prefix of a month name
   * (matching the behavior of zic itself).
   * @param text The text.
   * @returns The month number in the range 1 to 12.
   * @throws {InvalidDataException} The month name can't be parsed, or is ambiguous.
   */
  static ParseMonth(text: string): number {
    return TzdbZoneInfoParser.ParseUnambiguousNamePrefix(text, "month", LongMonths);
  }

  /**
   * Finds the index of the single entry in `names` (which has an unused entry
   * at index 0) for which `text` is a case-insensitive prefix. Throws
   * {@link InvalidDataException} if no entry matches, or if more than one does.
   */
  private static ParseUnambiguousNamePrefix(text: string, what: string, names: readonly string[]): number {
    Preconditions.CheckArgument(text !== null && text !== "", "text", "Value must not be empty or null");
    let match = 0;
    for (let i = 1; i < names.length; i++) {
      if (StartsWithOrdinalIgnoreCase(names[i]!, text)) {
        if (match !== 0) {
          throw NewInvalidDataException(`Ambiguous ${what}: ${text}`);
        }
        match = i;
      }
    }
    if (match === 0) {
      throw NewInvalidDataException(`Invalid ${what}: ${text}`);
    }
    return match;
  }

  /**
   * Parses a daylight savings rule and returns the Rule object.
   *
   * # Rule    NAME    FROM    TO    TYPE    IN    ON    AT    SAVE    LETTER/S
   * @param tokens The tokens to parse.
   * @returns The Rule object.
   */
  ParseRule(tokens: Tokens): RuleLine {
    const name = this.NextString(tokens, "GetName");
    let fromYear = TzdbZoneInfoParser.NextYear(tokens, 0);

    // This basically doesn't happen these days, but if we have any recurrent rules
    // which start at the dawn of time, make them effective from 1900. This matches
    // zic behaviour in the only cases of this that we've seen, e.g. the systemv rules
    // prior to 2001a.
    if (fromYear === Int32.MinValue) {
      fromYear = 1900;
    }

    const toYear = TzdbZoneInfoParser.NextYear(tokens, fromYear);
    if (toYear < fromYear) {
      throw NewArgumentException(`To year cannot be before the from year in a Rule: ${toYear} < ${fromYear}`);
    }

    // We don't support types any more, but rather than just ignoring the value, we check that it's not specified.
    const type = this.NextOptional(tokens, "Type");
    if (type !== null) {
      throw NewNotImplementedException(`Zone rules with types are no longer supported. Recurrence '${name}' has type '${type}'`);
    }

    const yearOffset = this.ParseDateTimeOfYear(tokens, true);
    const savings = this.NextOffset(tokens, "SaveMillis");
    const daylightSavingsIndicator = this.NextOptional(tokens, "LetterS");
    // The name of the zone recurrence is currently the name of the rule. Later (in ZoneRule.GetRecurrences)
    // it will be replaced with the formatted name. It's not ideal, but it avoids a lot of duplication.
    const recurrence = new ZoneRecurrence(name, savings, yearOffset, fromYear, toYear);
    return new RuleLine(recurrence, daylightSavingsIndicator);
  }

  /**
   * Parses a time zone definition and returns the Zone object.
   *
   * # GMTOFF RULES FORMAT [ UntilYear [ UntilMonth [ UntilDay [ UntilTime [ ZoneCharacter ] ] ] ] ]
   * @param name The name of the zone being parsed.
   * @param tokens The tokens to parse.
   * @returns The Zone object.
   */
  ParseZone(name: string, tokens: Tokens): ZoneLine {
    const offset = this.NextOffset(tokens, "Gmt Offset");
    const rules = this.NextOptional(tokens, "Rules");
    const format = this.NextString(tokens, "Format");
    const year = TzdbZoneInfoParser.NextYear(tokens, Int32.MaxValue);

    if (tokens.HasNextToken) {
      const until = this.ParseDateTimeOfYear(tokens, false);
      return new ZoneLine(name, offset, rules, format, year, until);
    }

    return new ZoneLine(name, offset, rules, format, year, TzdbZoneInfoParser.StartOfYearZoneOffset);
  }

  /**
   * Normalizes the transition mode character.
   * @param modeCharacter The character to normalize.
   * @returns The {@link TransitionMode}.
   */
  private static ConvertModeCharacter(modeCharacter: string): TransitionMode {
    switch (modeCharacter) {
      case "s":
      case "S":
        return TransitionMode.Standard;
      case "u":
      case "U":
      case "g":
      case "G":
      case "z":
      case "Z":
        return TransitionMode.Utc;
      default:
        return TransitionMode.Wall;
    }
  }
}
