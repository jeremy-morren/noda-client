// Ported from NodaTime 3.3.0: src/NodaTime/Text/Patterns/TimePatternHelper.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { ParseResult, PatternFields } from "../../internal.ts";
import type { CharacterHandler, CompareInfo, ParseBucket, SteppedPatternBuilder } from "../../internal.ts";

/**
 * Common methods used when parsing dates - these are used from LocalDateTimePatternParser,
 * OffsetPatternParser and LocalTimePatternParser.
 * @internal
 */
export class TimePatternHelper {
  private constructor() {}

  /**
   * Creates a character handler for a dot (period). This is *not* culture sensitive - it is
   * always treated as a literal, but with the additional behaviour that if it's followed by an 'F' pattern,
   * that makes the period optional.
   */
  static CreatePeriodHandler<TResult, TBucket extends ParseBucket<TResult>>(
    maxCount: number,
    getter: (value: TResult) => number,
    setter: (bucket: TBucket, value: number) => void,
  ): CharacterHandler<TResult, TBucket> {
    return (pattern, builder) => {
      // Note: Deliberately *not* using the decimal separator of the culture - see issue 21.

      // If the next part of the pattern is an F, then this decimal separator is effectively optional.
      // At parse time, we need to check whether we've matched the decimal separator. If we have, match the fractional
      // seconds part as normal. Otherwise, we continue on to the next parsing token.
      // At format time, we should always append the decimal separator, and then append using PadRightTruncate.
      if (pattern.PeekNext() === "F") {
        pattern.MoveNext();
        const count = pattern.GetRepeatCount(maxCount);
        builder.AddField(PatternFields.FractionalSeconds, pattern.Current);
        builder.AddParseAction((valueCursor, bucket) => {
          // If the next token isn't the decimal separator, we assume it's part of the next token in the pattern
          if (!valueCursor.Match(".")) {
            return null;
          }

          // If there *was* a decimal separator, we should definitely have a number.
          // Last argument is 1 because we need at least one digit after the decimal separator
          const [success, fractionalSeconds] = valueCursor.ParseFraction(count, maxCount, 1);
          if (!success) {
            return ParseResult.MismatchedNumber<TResult>(valueCursor, "F".repeat(count));
          }
          // No need to validate the value - we've got one to three digits, so the range 0-999 is guaranteed.
          setter(bucket, fractionalSeconds);
          return null;
        });
        builder.AddFormatAction((localTime, sb) => sb.Append("."));
        builder.AddFormatFractionTruncate(count, maxCount, getter);
      } else {
        builder.AddLiteral(".", ParseResult.MismatchedCharacter<TResult>);
      }
    };
  }

  /**
   * Creates a character handler for a dot (period) or comma, which have the same meaning.
   * Formatting always uses a dot, but parsing will allow a comma instead, to conform with
   * ISO-8601. This is *not* culture sensitive.
   */
  static CreateCommaDotHandler<TResult, TBucket extends ParseBucket<TResult>>(
    maxCount: number,
    getter: (value: TResult) => number,
    setter: (bucket: TBucket, value: number) => void,
  ): CharacterHandler<TResult, TBucket> {
    return (pattern, builder) => {
      // Note: Deliberately *not* using the decimal separator of the culture - see issue 21.

      // If the next part of the pattern is an F, then this decimal separator is effectively optional.
      // At parse time, we need to check whether we've matched the decimal separator. If we have, match the fractional
      // seconds part as normal. Otherwise, we continue on to the next parsing token.
      // At format time, we should always append the decimal separator, and then append using PadRightTruncate.
      if (pattern.PeekNext() === "F") {
        pattern.MoveNext();
        const count = pattern.GetRepeatCount(maxCount);
        builder.AddField(PatternFields.FractionalSeconds, pattern.Current);
        builder.AddParseAction((valueCursor, bucket) => {
          // If the next token isn't a dot or comma, we assume
          // it's part of the next token in the pattern
          if (!valueCursor.Match(".") && !valueCursor.Match(",")) {
            return null;
          }

          // If there *was* a decimal separator, we should definitely have a number.
          // Last argument is 1 because we need at least one digit to be present after a decimal separator
          const [success, fractionalSeconds] = valueCursor.ParseFraction(count, maxCount, 1);
          if (!success) {
            return ParseResult.MismatchedNumber<TResult>(valueCursor, "F".repeat(count));
          }
          // No need to validate the value - we've got an appropriate number of digits, so the range is guaranteed.
          setter(bucket, fractionalSeconds);
          return null;
        });
        builder.AddFormatAction((localTime, sb) => sb.Append("."));
        builder.AddFormatFractionTruncate(count, maxCount, getter);
      } else {
        builder.AddParseAction((str, bucket) =>
          str.Match(".") || str.Match(",") ? null : ParseResult.MismatchedCharacter<TResult>(str, ";"),
        );
        builder.AddFormatAction((value, sb) => sb.Append("."));
      }
    };
  }

  /** Creates a character handler to handle the "fraction of a second" specifier (f or F). */
  static CreateFractionHandler<TResult, TBucket extends ParseBucket<TResult>>(
    maxCount: number,
    getter: (value: TResult) => number,
    setter: (bucket: TBucket, value: number) => void,
  ): CharacterHandler<TResult, TBucket> {
    return (pattern, builder) => {
      const patternCharacter = pattern.Current;
      const count = pattern.GetRepeatCount(maxCount);
      builder.AddField(PatternFields.FractionalSeconds, pattern.Current);

      builder.AddParseAction((str, bucket) => {
        // If the pattern is 'f', we need exactly "count" digits. Otherwise ('F') we need
        // "up to count" digits.
        const [success, fractionalSeconds] = str.ParseFraction(count, maxCount, patternCharacter === "f" ? count : 0);
        if (!success) {
          return ParseResult.MismatchedNumber<TResult>(str, patternCharacter.repeat(count));
        }
        // No need to validate the value - we've got an appropriate number of digits, so the range is guaranteed.
        setter(bucket, fractionalSeconds);
        return null;
      });
      if (patternCharacter === "f") {
        builder.AddFormatFraction(count, maxCount, getter);
      } else {
        builder.AddFormatFractionTruncate(count, maxCount, getter);
      }
    };
  }

  static CreateAmPmHandler<TResult, TBucket extends ParseBucket<TResult>>(
    hourOfDayGetter: (value: TResult) => number,
    amPmSetter: (bucket: TBucket, value: number) => void,
  ): CharacterHandler<TResult, TBucket> {
    return (pattern, builder) => {
      const count = pattern.GetRepeatCount(2);
      builder.AddField(PatternFields.AmPm, pattern.Current);

      const amDesignator = builder.FormatInfo.AMDesignator;
      const pmDesignator = builder.FormatInfo.PMDesignator;

      // If we don't have an AM or PM designator, we're nearly done. Set the AM/PM designator
      // to the special value of 2, meaning "take it from the template".
      if (amDesignator.length === 0 && pmDesignator.length === 0) {
        builder.AddParseAction((str, bucket) => {
          amPmSetter(bucket, 2);
          return null;
        });
        return;
      }
      // Odd scenario (but present in af-ZA for .NET 2) - exactly one of the AM/PM designator is valid.
      // Delegate to a separate method to keep this clearer...
      if (amDesignator.length === 0 || pmDesignator.length === 0) {
        const specifiedDesignatorValue = amDesignator.length === 0 ? 1 : 0;
        const specifiedDesignator = specifiedDesignatorValue === 1 ? pmDesignator : amDesignator;
        TimePatternHelper.HandleHalfAmPmDesignator(count, specifiedDesignator, specifiedDesignatorValue, hourOfDayGetter, amPmSetter, builder);
        return;
      }
      const compareInfo: CompareInfo = builder.FormatInfo.CompareInfo;
      // Single character designator
      if (count === 1) {
        // It's not entirely clear whether this is the right thing to do... there's no nice
        // way of providing a single-character case-insensitive match.
        const amFirst = amDesignator.substring(0, 1);
        const pmFirst = pmDesignator.substring(0, 1);
        builder.AddParseAction((str, bucket) => {
          if (str.MatchCaseInsensitive(amFirst, compareInfo, true)) {
            amPmSetter(bucket, 0);
            return null;
          }
          if (str.MatchCaseInsensitive(pmFirst, compareInfo, true)) {
            amPmSetter(bucket, 1);
            return null;
          }
          return ParseResult.MissingAmPmDesignator<TResult>(str);
        });
        builder.AddFormatAction((value, sb) => sb.Append(hourOfDayGetter(value) > 11 ? pmDesignator[0]! : amDesignator[0]!));
        return;
      }
      // Full designator
      builder.AddParseAction((str, bucket) => {
        // Could use the "match longest" approach, but with only two it feels a bit silly to build a list...
        const pmLongerThanAm = pmDesignator.length > amDesignator.length;
        const longerDesignator = pmLongerThanAm ? pmDesignator : amDesignator;
        const shorterDesignator = pmLongerThanAm ? amDesignator : pmDesignator;
        const longerValue = pmLongerThanAm ? 1 : 0;
        if (str.MatchCaseInsensitive(longerDesignator, compareInfo, true)) {
          amPmSetter(bucket, longerValue);
          return null;
        }
        if (str.MatchCaseInsensitive(shorterDesignator, compareInfo, true)) {
          amPmSetter(bucket, 1 - longerValue);
          return null;
        }
        return ParseResult.MissingAmPmDesignator<TResult>(str);
      });
      builder.AddFormatAction((value, sb) => sb.Append(hourOfDayGetter(value) > 11 ? pmDesignator : amDesignator));
    };
  }

  private static HandleHalfAmPmDesignator<TResult, TBucket extends ParseBucket<TResult>>(
    count: number,
    specifiedDesignator: string,
    specifiedDesignatorValue: number,
    hourOfDayGetter: (value: TResult) => number,
    amPmSetter: (bucket: TBucket, value: number) => void,
    builder: SteppedPatternBuilder<TResult, TBucket>,
  ): void {
    const compareInfo: CompareInfo = builder.FormatInfo.CompareInfo;
    if (count === 1) {
      const abbreviation = specifiedDesignator.substring(0, 1);
      builder.AddParseAction((str, bucket) => {
        const value = str.MatchCaseInsensitive(abbreviation, compareInfo, true) ? specifiedDesignatorValue : 1 - specifiedDesignatorValue;
        amPmSetter(bucket, value);
        return null;
      });
      builder.AddFormatAction((value, sb) => {
        // Only append anything if it's the non-empty designator.
        if (Math.trunc(hourOfDayGetter(value) / 12) === specifiedDesignatorValue) {
          sb.Append(specifiedDesignator[0]!);
        }
      });
      return;
    }
    builder.AddParseAction((str, bucket) => {
      const value = str.MatchCaseInsensitive(specifiedDesignator, compareInfo, true) ? specifiedDesignatorValue : 1 - specifiedDesignatorValue;
      amPmSetter(bucket, value);
      return null;
    });
    builder.AddFormatAction((value, sb) => {
      // Only append anything if it's the non-empty designator.
      if (Math.trunc(hourOfDayGetter(value) / 12) === specifiedDesignatorValue) {
        sb.Append(specifiedDesignator);
      }
    });
  }
}
