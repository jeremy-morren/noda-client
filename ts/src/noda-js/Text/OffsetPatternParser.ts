// Ported from NodaTime 3.3.7: src/NodaTime/Text/OffsetPatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CompositePatternBuilder,
  InvalidPatternException,
  NodaConstants,
  Offset,
  ParseBucket,
  ParseResult,
  PatternFields,
  Preconditions,
  SteppedPatternBuilder,
  TextErrorMessages,
} from "../internal.ts";
import type {
  CharacterHandler,
  IPartialPattern,
  IPattern,
  IPatternParser,
  NodaFormatInfo,
  PatternCursor,
  StringBuilder,
  ValueCursor,
} from "../internal.ts";

/** Provides a container for the interim parsed pieces of an {@link Offset} value. */
class OffsetParseBucket extends ParseBucket<Offset> {
  /** The hours in the range [0, 23]. */
  Hours = 0;

  /** The minutes in the range [0, 59]. */
  Minutes = 0;

  /** The seconds in the range [0, 59]. */
  Seconds = 0;

  /**
   * Gets a value indicating whether this instance is negative.
   * `true` if this instance is negative; otherwise, `false`.
   */
  IsNegative = false;

  /** Calculates the value from the parsed pieces. */
  override CalculateValue(usedFields: PatternFields, text: string): ParseResult<Offset> {
    let seconds = this.Hours * NodaConstants.SecondsPerHour + this.Minutes * NodaConstants.SecondsPerMinute + this.Seconds;
    if (this.IsNegative) {
      seconds = -seconds;
    }
    if (seconds > Offset.MaxSeconds || seconds < Offset.MinSeconds) {
      return ParseResult.ForInvalidValuePostParse<Offset>(text, TextErrorMessages.OverallValueOutOfRange,
        "NodaTime.Offset");
    }
    return ParseResult.ForValue(Offset.FromSeconds(seconds));
  }
}

/** Pattern which optionally delegates to another, but both parses and formats Offset.Zero as "Z". */
class ZPrefixPattern implements IPartialPattern<Offset> {
  private readonly _fullPattern: IPartialPattern<Offset>;

  constructor(fullPattern: IPartialPattern<Offset>) {
    this._fullPattern = fullPattern;
  }

  /** @inheritDoc */
  Parse(text: string): ParseResult<Offset> {
    return text === "Z" ? ParseResult.ForValue(Offset.Zero) : this._fullPattern.Parse(text);
  }

  /** @inheritDoc */
  Format(value: Offset): string {
    return value.Equals(Offset.Zero) ? "Z" : this._fullPattern.Format(value);
  }

  /** @inheritDoc */
  ParsePartial(cursor: ValueCursor): ParseResult<Offset> {
    if (cursor.Current === "Z") {
      cursor.MoveNext();
      return ParseResult.ForValue(Offset.Zero);
    }
    return this._fullPattern.ParsePartial(cursor);
  }

  /** @inheritDoc */
  AppendFormat(value: Offset, builder: StringBuilder): StringBuilder {
    Preconditions.CheckNotNull(builder, "builder");
    return value.Equals(Offset.Zero) ? builder.Append("Z") : this._fullPattern.AppendFormat(value, builder);
  }
}

let patternCharacterHandlers: ReadonlyMap<string, CharacterHandler<Offset, OffsetParseBucket>> | undefined;

function GetPatternCharacterHandlers(): ReadonlyMap<string, CharacterHandler<Offset, OffsetParseBucket>> {
  return (patternCharacterHandlers ??= new Map<string, CharacterHandler<Offset, OffsetParseBucket>>([
    ["%", SteppedPatternBuilder.HandlePercent],
    ["'", SteppedPatternBuilder.HandleQuote],
    ['"', SteppedPatternBuilder.HandleQuote],
    ["\\", SteppedPatternBuilder.HandleBackslash],
    [":", (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch<Offset>)],
    [
      "h",
      (pattern, builder) => {
        throw new InvalidPatternException(TextErrorMessages.Hour12PatternNotSupported, "NodaTime.Offset");
      },
    ],
    [
      "H",
      SteppedPatternBuilder.HandlePaddedField<Offset, OffsetParseBucket>(2, PatternFields.Hours24, 0, 23, OffsetPatternParser.GetPositiveHours, (bucket, value) => (bucket.Hours = value)),
    ],
    [
      "m",
      SteppedPatternBuilder.HandlePaddedField<Offset, OffsetParseBucket>(2, PatternFields.Minutes, 0, 59, OffsetPatternParser.GetPositiveMinutes, (bucket, value) => (bucket.Minutes = value)),
    ],
    [
      "s",
      SteppedPatternBuilder.HandlePaddedField<Offset, OffsetParseBucket>(2, PatternFields.Seconds, 0, 59, OffsetPatternParser.GetPositiveSeconds, (bucket, value) => (bucket.Seconds = value)),
    ],
    ["+", OffsetPatternParser.HandlePlus],
    ["-", OffsetPatternParser.HandleMinus],
    [
      "Z",
      (ignored1, ignored2) => {
        throw new InvalidPatternException(TextErrorMessages.ZPrefixNotAtStartOfPattern);
      },
    ],
  ]));
}

/** @internal */
export class OffsetPatternParser implements IPatternParser<Offset> {
  // These are used to compute the individual (always-positive) components of an offset.
  // For example, an offset of "three and a half hours behind UTC" would have a "positive hours" value
  // of 3, and a "positive minutes" value of 30. The sign is computed elsewhere.
  /** @internal */
  static GetPositiveHours(offset: Offset): number {
    return Math.trunc(Math.abs(offset.Milliseconds) / NodaConstants.MillisecondsPerHour);
  }

  /** @internal */
  static GetPositiveMinutes(offset: Offset): number {
    return Math.trunc((Math.abs(offset.Milliseconds) % NodaConstants.MillisecondsPerHour) / NodaConstants.MillisecondsPerMinute);
  }

  /** @internal */
  static GetPositiveSeconds(offset: Offset): number {
    return Math.trunc((Math.abs(offset.Milliseconds) % NodaConstants.MillisecondsPerMinute) / NodaConstants.MillisecondsPerSecond);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<Offset> {
    return this.ParsePartialPattern(patternText, formatInfo);
  }

  private ParsePartialPattern(patternText: string, formatInfo: NodaFormatInfo): IPartialPattern<Offset> {
    // Nullity check is performed in OffsetPattern.
    if (patternText.length === 0) {
      throw new InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length === 1) {
      switch (patternText[0]) {
        case "g": {
          const builder = new CompositePatternBuilder<Offset>();
          builder.Add(this.ParsePartialPattern(formatInfo.OffsetPatternLong, formatInfo), (offset) => true);
          builder.Add(this.ParsePartialPattern(formatInfo.OffsetPatternMedium, formatInfo), OffsetPatternParser.HasZeroSeconds);
          builder.Add(this.ParsePartialPattern(formatInfo.OffsetPatternShort, formatInfo), OffsetPatternParser.HasZeroSecondsAndMinutes);
          return builder.BuildAsPartial();
        }
        case "G":
          return new ZPrefixPattern(this.ParsePartialPattern("g", formatInfo));
        case "i": {
          const builder = new CompositePatternBuilder<Offset>();
          builder.Add(this.ParsePartialPattern(formatInfo.OffsetPatternLongNoPunctuation, formatInfo), (offset) => true);
          builder.Add(this.ParsePartialPattern(formatInfo.OffsetPatternMediumNoPunctuation, formatInfo), OffsetPatternParser.HasZeroSeconds);
          builder.Add(this.ParsePartialPattern(formatInfo.OffsetPatternShortNoPunctuation, formatInfo), OffsetPatternParser.HasZeroSecondsAndMinutes);
          return builder.BuildAsPartial();
        }
        case "I":
          return new ZPrefixPattern(this.ParsePartialPattern("i", formatInfo));
        case "l":
          patternText = formatInfo.OffsetPatternLong;
          break;
        case "m":
          patternText = formatInfo.OffsetPatternMedium;
          break;
        case "s":
          patternText = formatInfo.OffsetPatternShort;
          break;
        case "L":
          patternText = formatInfo.OffsetPatternLongNoPunctuation;
          break;
        case "M":
          patternText = formatInfo.OffsetPatternMediumNoPunctuation;
          break;
        case "S":
          patternText = formatInfo.OffsetPatternShortNoPunctuation;
          break;
        default:
          throw new InvalidPatternException(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.Offset");
      }
    }
    // This is the only way we'd normally end up in custom parsing land for Z on its own.
    if (patternText === "%Z") {
      throw new InvalidPatternException(TextErrorMessages.EmptyZPrefixedOffsetPattern);
    }

    // Handle Z-prefix by stripping it, parsing the rest as a normal pattern, then building a special pattern
    // which decides whether or not to delegate.
    // Note that patternText is guaranteed not to be empty due to the check at the start.
    // (And assuming we don't add any standard => custom pattern expansions that result in an empty pattern.)
    const zPrefix = patternText[0] === "Z";

    const patternBuilder = new SteppedPatternBuilder<Offset, OffsetParseBucket>(formatInfo, () => new OffsetParseBucket());
    patternBuilder.ParseCustomPattern(zPrefix ? patternText.substring(1) : patternText, GetPatternCharacterHandlers());
    // No need to validate field combinations here, but we do need to do something a bit special
    // for Z-handling.
    const pattern = patternBuilder.Build(Offset.FromHoursAndMinutes(5, 30));
    return zPrefix ? new ZPrefixPattern(pattern) : pattern;
  }

  /** Returns true if the offset is representable just in hours and minutes (no seconds). */
  private static HasZeroSeconds(offset: Offset): boolean {
    return offset.Seconds % NodaConstants.SecondsPerMinute === 0;
  }

  /** Returns true if the offset is representable just in hours (no minutes or seconds). */
  private static HasZeroSecondsAndMinutes(offset: Offset): boolean {
    return offset.Seconds % NodaConstants.SecondsPerHour === 0;
  }

  // #region Character handlers
  /** @internal */
  static HandlePlus(pattern: PatternCursor, builder: SteppedPatternBuilder<Offset, OffsetParseBucket>): void {
    builder.AddField(PatternFields.Sign, pattern.Current);
    builder.AddRequiredSign((bucket, positive) => (bucket.IsNegative = !positive), (offset) => offset.Milliseconds >= 0);
  }

  /** @internal */
  static HandleMinus(pattern: PatternCursor, builder: SteppedPatternBuilder<Offset, OffsetParseBucket>): void {
    builder.AddField(PatternFields.Sign, pattern.Current);
    builder.AddNegativeOnlySign((bucket, positive) => (bucket.IsNegative = !positive), (offset) => offset.Milliseconds >= 0);
  }
  // #endregion
}
