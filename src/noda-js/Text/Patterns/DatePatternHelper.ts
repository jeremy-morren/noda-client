// Ported from NodaTime 3.3.0: src/NodaTime/Text/Patterns/DatePatternHelper.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { CalendarSystem, InvalidOperationError, InvalidPatternError, ParseResult, PatternFields, TextErrorMessages } from "../../internal.ts";
import type {
  CharacterHandler,
  Era,
  LocalDatePatternParserLocalDateParseBucket,
  NodaFormatInfo,
  ParseBucket,
  SteppedPatternBuilderFormatAction,
  SteppedPatternBuilderIPostPatternParseFormatAction,
  StringBuilder,
} from "../../internal.ts";

/**
 * Common methods used when parsing dates - these are used from both LocalDateTimePatternParser
 * and LocalDatePatternParser.
 * @internal
 */
export class DatePatternHelper {
  private constructor() {}

  /** Creates a character handler for the year-of-era specifier (y). */
  static CreateYearOfEraHandler<TResult, TBucket extends ParseBucket<TResult>>(
    yearGetter: (value: TResult) => number,
    setter: (bucket: TBucket, value: number) => void,
  ): CharacterHandler<TResult, TBucket> {
    return (pattern, builder) => {
      const count = pattern.GetRepeatCount(4);
      builder.AddField(PatternFields.YearOfEra, pattern.Current);
      switch (count) {
        case 2:
          builder.AddParseValueAction(2, 2, "y", 0, 99, setter);
          // Force the year into the range 0-99.
          builder.AddFormatLeftPad(2, (value) => ((yearGetter(value) % 100) + 100) % 100, true, true);
          // Just remember that we've set this particular field. We can't set it twice as we've already got the YearOfEra flag set.
          builder.AddField(PatternFields.YearTwoDigits, pattern.Current);
          break;
        case 4:
          // Left-pad to 4 digits when formatting; parse exactly 4 digits.
          builder.AddParseValueAction(4, 4, "y", 1, 9999, setter);
          builder.AddFormatLeftPad(4, yearGetter, false, true);
          break;
        default:
          throw new InvalidPatternError(TextErrorMessages.InvalidRepeatCount, pattern.Current, count);
      }
    };
  }

  /** Creates a character handler for the month-of-year specifier (M). */
  static CreateMonthOfYearHandler<TResult, TBucket extends ParseBucket<TResult>>(
    numberGetter: (value: TResult) => number,
    textSetter: (bucket: TBucket, value: number) => void,
    numberSetter: (bucket: TBucket, value: number) => void,
  ): CharacterHandler<TResult, TBucket> {
    return (pattern, builder) => {
      const count = pattern.GetRepeatCount(4);
      let field: PatternFields;
      switch (count) {
        case 1:
        case 2:
          field = PatternFields.MonthOfYearNumeric;
          // Handle real maximum value in the bucket
          builder.AddParseValueAction(count, 2, pattern.Current, 1, 99, numberSetter);
          builder.AddFormatLeftPad(count, numberGetter, true, count === 2);
          break;
        case 3:
        case 4: {
          field = PatternFields.MonthOfYearText;
          const format = builder.FormatInfo;
          const nonGenitiveTextValues: readonly string[] = count === 3 ? format.ShortMonthNames : format.LongMonthNames;
          const genitiveTextValues: readonly string[] = count === 3 ? format.ShortMonthGenitiveNames : format.LongMonthGenitiveNames;
          if (nonGenitiveTextValues === genitiveTextValues) {
            builder.AddParseLongestTextAction(pattern.Current, textSetter, format.CompareInfo, nonGenitiveTextValues);
          } else {
            builder.AddParseLongestTextAction(pattern.Current, textSetter, format.CompareInfo, genitiveTextValues, nonGenitiveTextValues);
          }

          // Hack: see below
          builder.AddFormatAction(new MonthFormatActionHolder<TResult>(format, count, numberGetter).DummyMethod);
          break;
        }
        default:
          throw new InvalidOperationError("Invalid count!");
      }
      builder.AddField(field, pattern.Current);
    };
  }

  /** Creates a character handler for the day specifier (d). */
  static CreateDayHandler<TResult, TBucket extends ParseBucket<TResult>>(
    dayOfMonthGetter: (value: TResult) => number,
    dayOfWeekGetter: (value: TResult) => number,
    dayOfMonthSetter: (bucket: TBucket, value: number) => void,
    dayOfWeekSetter: (bucket: TBucket, value: number) => void,
  ): CharacterHandler<TResult, TBucket> {
    return (pattern, builder) => {
      const count = pattern.GetRepeatCount(4);
      let field: PatternFields;
      switch (count) {
        case 1:
        case 2:
          field = PatternFields.DayOfMonth;
          // Handle real maximum value in the bucket
          builder.AddParseValueAction(count, 2, pattern.Current, 1, 99, dayOfMonthSetter);
          builder.AddFormatLeftPad(count, dayOfMonthGetter, true, count === 2);
          break;
        case 3:
        case 4: {
          field = PatternFields.DayOfWeek;
          const format = builder.FormatInfo;
          const textValues: readonly string[] = count === 3 ? format.ShortDayNames : format.LongDayNames;
          builder.AddParseLongestTextAction(pattern.Current, dayOfWeekSetter, format.CompareInfo, textValues);
          builder.AddFormatAction((value, sb) => sb.Append(textValues[dayOfWeekGetter(value)]!));
          break;
        }
        default:
          throw new InvalidOperationError("Invalid count!");
      }
      builder.AddField(field, pattern.Current);
    };
  }

  /** Creates a character handler for the era specifier (g). */
  static CreateEraHandler<TResult, TBucket extends ParseBucket<TResult>>(
    eraFromValue: (value: TResult) => Era,
    dateBucketFromBucket: (bucket: TBucket) => LocalDatePatternParserLocalDateParseBucket,
  ): CharacterHandler<TResult, TBucket> {
    return (pattern, builder) => {
      pattern.GetRepeatCount(2);
      builder.AddField(PatternFields.Era, pattern.Current);
      const formatInfo = builder.FormatInfo;
      // Note: currently the count is ignored. More work needed to determine whether abbreviated era names should be used for just "g".
      builder.AddParseAction((cursor, bucket) => {
        const dateBucket = dateBucketFromBucket(bucket);
        return dateBucket.ParseEra<TResult>(formatInfo, cursor);
      });
      builder.AddFormatAction((value, sb) => sb.Append(formatInfo.GetEraPrimaryName(eraFromValue(value))));
    };
  }

  /** Creates a character handler for the calendar specifier (c). */
  static CreateCalendarHandler<TResult, TBucket extends ParseBucket<TResult>>(
    getter: (value: TResult) => CalendarSystem,
    setter: (bucket: TBucket, value: CalendarSystem) => void,
  ): CharacterHandler<TResult, TBucket> {
    return (pattern, builder) => {
      builder.AddField(PatternFields.Calendar, pattern.Current);

      builder.AddParseAction((cursor, bucket) => {
        for (const id of CalendarSystem.Ids) {
          if (cursor.Match(id)) {
            setter(bucket, CalendarSystem.ForId(id));
            return null;
          }
        }
        return ParseResult.NoMatchingCalendarSystem<TResult>(cursor);
      });
      builder.AddFormatAction((value, sb) => sb.Append(getter(value).Id));
    };
  }
}

// Hacky way of building an action which depends on the final set of pattern fields to determine whether to format a month
// using the genitive form or not.
class MonthFormatActionHolder<TResult> implements SteppedPatternBuilderIPostPatternParseFormatAction<TResult> {
  private readonly _count: number;
  private readonly _formatInfo: NodaFormatInfo;
  private readonly _getter: (value: TResult) => number;

  /**
   * This function is never called. We use it to create a delegate with a target that implements
   * IPostPatternParseFormatAction. There's no test for this throwing.
   * (noda-js: the "target" is a property of the function; see SteppedPatternBuilderFormatAction.)
   */
  readonly DummyMethod: SteppedPatternBuilderFormatAction<TResult>;

  constructor(formatInfo: NodaFormatInfo, count: number, getter: (value: TResult) => number) {
    this._count = count;
    this._formatInfo = formatInfo;
    this._getter = getter;
    this.DummyMethod = Object.assign(
      (_value: TResult, _builder: StringBuilder): void => {
        throw new InvalidOperationError("This method should never be called");
      },
      { target: this },
    );
  }

  BuildFormatAction(finalFields: PatternFields): (value: TResult, builder: StringBuilder) => void {
    const genitive = (finalFields & PatternFields.DayOfMonth) !== 0;
    const textValues: readonly string[] =
      this._count === 3
        ? genitive
          ? this._formatInfo.ShortMonthGenitiveNames
          : this._formatInfo.ShortMonthNames
        : genitive
          ? this._formatInfo.LongMonthGenitiveNames
          : this._formatInfo.LongMonthNames;
    const getter = this._getter;
    return (value, sb) => {
      sb.Append(textValues[getter(value)]!);
    };
  }
}
