// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/ParserHelper.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Int32, LocalTimePattern, NodaConstants, Offset, Preconditions } from "../../internal.ts";
import type { LocalTime } from "../../internal.ts";
import { ParseDecimalDouble, ParseInt32, TryParseInt32 } from "../internal.ts";
import { NewFormatException, type FormatException } from "../../internal.ts";

let timePatterns: readonly LocalTimePattern[] | undefined;

/**
 * Contains helper methods for parsing the TZDB files.
 * @internal
 */
export class ParserHelper {
  private static get TimePatterns(): readonly LocalTimePattern[] {
    return (timePatterns ??= [
      LocalTimePattern.CreateWithInvariantCulture("H:mm:ss.FFF"),
      LocalTimePattern.CreateWithInvariantCulture("H:mm"),
      LocalTimePattern.CreateWithInvariantCulture("%H"),
      // Handle "somewhat broken" data such as a DAVT rule in Antarctica 2009r, with a date/time of "2009 Oct 18 2:0"
      LocalTimePattern.CreateWithInvariantCulture("H:m"),
    ]);
  }

  /**
   * Converts an hour string to its long value.
   * @param text The text to convert.
   * @returns The hour in the range [-23, 23].
   * @throws {FormatException} If the text is not a valid integer in the range [-23, 23].
   */
  static ConvertHourToTicks(text: string): number {
    Preconditions.CheckNotNull(text, "text");
    const value = ParseInt32(text);
    if (value < -23 || value > 23) {
      throw NewFormatException(`hours out of valid range of [-23, 23]: ${value}`);
    }
    return value * NodaConstants.TicksPerHour;
  }

  /**
   * Converts a minute string to its long value.
   * @param text The text to convert.
   * @returns The minute in the range [0, 59].
   * @throws {FormatException} If the text is not a valid integer in the range [0, 59].
   */
  static ConvertMinuteToTicks(text: string): number {
    Preconditions.CheckNotNull(text, "text");
    const value = ParseInt32(text, false);
    if (value < 0 || value > 59) {
      throw NewFormatException(`minutes out of valid range of [0, 59]: ${value}`);
    }
    return value * NodaConstants.TicksPerMinute;
  }

  /**
   * Converts a second string to its double value.
   * @param text The text to convert.
   * @returns The second in the range [0, 60).
   * @throws {FormatException} If the text is not a valid integer in the range [0, 60).
   */
  static ConvertSecondsWithFractionalToTicks(text: string): number {
    Preconditions.CheckNotNull(text, "text");
    const number = ParseDecimalDouble(text);
    if (number < 0.0 || number >= 60.0) {
      throw NewFormatException(`seconds out of valid range of [0, 60): ${number}`);
    }
    const value = Math.trunc(number * NodaConstants.MillisecondsPerSecond) * NodaConstants.TicksPerMillisecond;
    return value;
  }

  /**
   * Formats an optional, converting null input to "-".
   * @param value The value.
   */
  static FormatOptional(value: string | null): string {
    return value ?? "-";
  }

  /**
   * Parses the given text for an integer. Leading and trailing white space is ignored.
   * @param text The text to parse.
   * @param defaultValue The default value to use if the number cannot be parsed.
   * @returns An integer.
   * @throws {FormatException} If the text is not a valid integer.
   */
  static ParseInteger(text: string | null, defaultValue: number): number {
    let value = defaultValue;
    if (text !== null) {
      const parsed = TryParseInt32(text);
      if (parsed === null) {
        value = defaultValue;
      } else {
        value = parsed;
      }
    }
    return value;
  }

  /**
   * Parses a time offset string into an integer number of ticks.
   * @param text The value to parse.
   * @returns an integer number of ticks
   */
  static ParseOffset(text: string): Offset {
    // Some old files use "-" for 0 in a few places.
    // Example: Tonga, 1999f.
    if (text === "-") {
      return Offset.Zero;
    }
    // TODO(2.0): Use normal parsers!
    Preconditions.CheckNotNull(text, "text");
    let sign = 1;
    if (text.startsWith("-")) {
      sign = -1;
      text = text.substring(1);
    }
    const parts = text.split(":");
    if (parts.length > 3) {
      throw NewFormatException(`Offset has too many colon separated parts (max of 3 allowed): ${text}`);
    }
    let ticks = ParserHelper.ConvertHourToTicks(parts[0]!);
    if (parts.length > 1) {
      ticks += ParserHelper.ConvertMinuteToTicks(parts[1]!);
      if (parts.length > 2) {
        ticks += ParserHelper.ConvertSecondsWithFractionalToTicks(parts[2]!);
      }
    }
    ticks = ticks * sign;
    return Offset.FromTicks(ticks);
  }

  static ParseTime(text: string): LocalTime {
    for (const pattern of ParserHelper.TimePatterns) {
      const result = pattern.Parse(text);
      if (result.Success) {
        return result.Value;
      }
    }
    throw NewFormatException(`Invalid time in rules: ${text}`);
  }

  /**
   * Parses an optional value. If the string value is "-" then null is returned otherwise the
   * input string is returned.
   * @param text The value to parse.
   * @returns The input string or null.
   */
  static ParseOptional(text: string): string | null {
    Preconditions.CheckNotNull(text, "text");
    return text === "-" ? null : text;
  }

  /**
   * Parses the year.
   * @param text The text to parse.
   * @param defaultValue The default value.
   * @returns The parsed year.
   */
  static ParseYear(text: string, defaultValue: number): number {
    text = text.toLowerCase();
    switch (text) {
      case "min":
      case "minimum":
        return Int32.MinValue;
      case "max":
      case "maximum":
        return Int32.MaxValue;
      case "only":
        return defaultValue;
      default:
        return ParseInt32(text);
    }
  }
}
