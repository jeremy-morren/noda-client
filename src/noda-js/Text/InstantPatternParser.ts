// Ported from NodaTime 3.3.7: src/NodaTime/Text/InstantPatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Instant, InvalidPatternException, LocalDateTimePattern, Preconditions, TextErrorMessages } from "../internal.ts";
import type { IPattern, IPatternParser, LocalDateTime, NodaFormatInfo, ParseResult, StringBuilder } from "../internal.ts";

const GeneralPatternText = "uuuu'-'MM'-'dd'T'HH':'mm':'ss'Z'";

// This not only converts between LocalDateTime and Instant; it also handles infinity.
class InstantPatternParserLocalDateTimePatternAdapter implements IPattern<Instant> {
  private readonly _pattern: IPattern<LocalDateTime>;

  constructor(pattern: IPattern<LocalDateTime>) {
    this._pattern = pattern;
  }

  /** @inheritDoc */
  Format(value: Instant): string {
    // We don't need to be able to parse before-min/after-max values, but it's convenient to be
    // able to format them - mostly for the sake of testing (but also for ZoneInterval).
    return value.IsValid ? this._pattern.Format(value.InUtc().LocalDateTime)
      : value.Equals(Instant.BeforeMinValue) ? InstantPatternParser.BeforeMinValueText
      : InstantPatternParser.AfterMaxValueText;
  }

  /** @inheritDoc */
  AppendFormat(value: Instant, builder: StringBuilder): StringBuilder {
    return this._pattern.AppendFormat(value.InUtc().LocalDateTime, builder);
  }

  /** @inheritDoc */
  Parse(text: string): ParseResult<Instant> {
    return this._pattern.Parse(text).Convert(local => Instant.NewDaysNanoOfDay(local.Date.DaysSinceEpoch, local.NanosecondOfDay));
  }
}

/**
 * Pattern parsing support for {@link Instant}.
 *
 * Supported standard patterns:
 * - g: general; the UTC ISO-8601 instant in the style uuuu-MM-ddTHH:mm:ssZ
 * @internal
 */
export class InstantPatternParser implements IPatternParser<Instant> {
  static readonly BeforeMinValueText = "StartOfTime";
  static readonly AfterMaxValueText = "EndOfTime";

  private readonly _localTemplateValue: LocalDateTime;
  private readonly _twoDigitYearMax: number;

  constructor(templateValue: Instant, twoDigitYearMax: number) {
    this._localTemplateValue = templateValue.InUtc().LocalDateTime;
    this._twoDigitYearMax = twoDigitYearMax;
  }

  static NewTemplateValueTwoDigitYearMax(templateValue: Instant, twoDigitYearMax: number): InstantPatternParser {
    return new InstantPatternParser(templateValue, twoDigitYearMax);
  }

  ParsePattern(patternText: string, formatInfo: NodaFormatInfo): IPattern<Instant> {
    Preconditions.CheckNotNull(patternText, "patternText");
    if (patternText.length === 0) {
      throw new InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }
    if (patternText.length === 1) {
      switch (patternText[0]) {
        // Simplest way of handling the general pattern...
        case "g":
          patternText = GeneralPatternText;
          break;
        default:
          throw new InvalidPatternException(TextErrorMessages.UnknownStandardFormat, patternText, "NodaTime.Instant");
      }
    }

    // We unwrap the LocalDateTimePattern to avoid unnecessary levels of indirection.
    const localPattern: IPattern<LocalDateTime> =
      LocalDateTimePattern.Create(patternText, formatInfo, this._localTemplateValue, this._twoDigitYearMax).UnderlyingPattern;
    return new InstantPatternParserLocalDateTimePatternAdapter(localPattern);
  }
}
