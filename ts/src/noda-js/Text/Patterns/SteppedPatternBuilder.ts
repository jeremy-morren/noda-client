// Ported from NodaTime 3.3.7: src/NodaTime/Text/Patterns/SteppedPatternBuilder.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  AnnualDate,
  Duration,
  FormatHelper,
  Instant,
  InvalidPatternException,
  LocalDate,
  LocalDatePattern,
  LocalDateTime,
  LocalDateTimePattern,
  LocalTime,
  LocalTimePattern,
  Offset,
  OffsetDate,
  OffsetDateTime,
  OffsetTime,
  ParseResult,
  PatternCursor,
  PatternFields,
  Period,
  Preconditions,
  StringBuilder,
  TextCursor,
  TextErrorMessages,
  ValueCursor,
  YearMonth,
  ZonedDateTime,
} from "../../internal.ts";
import type {
  CharacterHandler,
  CompareInfo,
  IPartialPattern,
  LocalDatePatternParserLocalDateParseBucket,
  LocalTimePatternParserLocalTimeParseBucket,
  NodaFormatInfo,
  ParseBucket,
} from "../../internal.ts";
import { NewInvalidOperationException } from "../../internal.ts";

/**
 * C#: SteppedPatternBuilder&lt;TResult, TBucket&gt;.ParseAction
 * @internal
 */
export type SteppedPatternBuilderParseAction<TResult, TBucket> = (cursor: ValueCursor, bucket: TBucket) => ParseResult<TResult> | null;

/**
 * Hack to handle genitive month names - we only know what we need to do *after* we've parsed the whole pattern.
 * (C#: SteppedPatternBuilder&lt;TResult, TBucket&gt;.IPostPatternParseFormatAction)
 * @internal
 */
export interface SteppedPatternBuilderIPostPatternParseFormatAction<TResult> {
  BuildFormatAction(finalFields: PatternFields): (value: TResult, builder: StringBuilder) => void;
}

/**
 * A format action. noda-js: the function carries C#'s delegate target as a property.
 * @internal
 */
export type SteppedPatternBuilderFormatAction<TResult> = ((value: TResult, builder: StringBuilder) => void) & {
  readonly target?: SteppedPatternBuilderIPostPatternParseFormatAction<TResult>;
};

// noda-js: PatternFieldsExtensions (in PatternFields.cs in NodaTime) lives here, as PatternFields is a generated enum.

/**
 * Returns true if the given set of fields contains any of the target fields.
 * (C#: PatternFieldsExtensions.HasAny)
 * @internal
 */
export function HasAny(fields: PatternFields, target: PatternFields): boolean {
  return (fields & target) !== 0;
}

/**
 * Returns true if the given set of fields contains all of the target fields.
 * (C#: PatternFieldsExtensions.HasAll)
 * @internal
 */
export function HasAll(fields: PatternFields, target: PatternFields): boolean {
  return (fields & target) === target;
}

/**
 * noda-js: C#'s typeof(TResult), for error messages, from the sample passed to {@link SteppedPatternBuilder.Build}.
 */
function ResultTypeName(sample: unknown): string {
  // (Function rather than a constructor type, as some of these classes have private constructors.)
  const types: readonly [Function, string][] = [
    [LocalDate, "NodaTime.LocalDate"],
    [LocalTime, "NodaTime.LocalTime"],
    [LocalDateTime, "NodaTime.LocalDateTime"],
    [Offset, "NodaTime.Offset"],
    [Instant, "NodaTime.Instant"],
    [Duration, "NodaTime.Duration"],
    [Period, "NodaTime.Period"],
    [OffsetDate, "NodaTime.OffsetDate"],
    [OffsetTime, "NodaTime.OffsetTime"],
    [OffsetDateTime, "NodaTime.OffsetDateTime"],
    [ZonedDateTime, "NodaTime.ZonedDateTime"],
    [AnnualDate, "NodaTime.AnnualDate"],
    [YearMonth, "NodaTime.YearMonth"],
  ];
  for (const [type, name] of types) {
    if (sample instanceof type) {
      return name;
    }
  }
  return `NodaTime.${(sample as object | null)?.constructor?.name ?? "Unknown"}`;
}

/**
 * Builder for a pattern which implements parsing and formatting as a sequence of steps applied
 * in turn.
 * @internal
 */
export class SteppedPatternBuilder<TResult, TBucket extends ParseBucket<TResult>> {
  private readonly _formatActions: SteppedPatternBuilderFormatAction<TResult>[];
  private readonly _parseActions: SteppedPatternBuilderParseAction<TResult, TBucket>[];
  private readonly _bucketProvider: () => TBucket;
  private _usedFieldsField: PatternFields = PatternFields.None;
  private _formatOnly = false;
  // noda-js: typeof(TResult); set by Build(), and only read when parsing (i.e. after Build()).
  private _resultTypeName = "";

  readonly FormatInfo: NodaFormatInfo;

  get UsedFields(): PatternFields {
    return this._usedFieldsField;
  }

  constructor(formatInfo: NodaFormatInfo, bucketProvider: () => TBucket) {
    this.FormatInfo = formatInfo;
    this._formatActions = [];
    this._parseActions = [];
    this._bucketProvider = bucketProvider;
  }

  /** @internal */
  static NewFormatInfoBucketProvider<TResult, TBucket extends ParseBucket<TResult>>(
    formatInfo: NodaFormatInfo,
    bucketProvider: () => TBucket,
  ): SteppedPatternBuilder<TResult, TBucket> {
    return new SteppedPatternBuilder<TResult, TBucket>(formatInfo, bucketProvider);
  }

  /**
   * Calls the bucket provider and returns a sample bucket. This means that any values
   * normally propagated via the bucket can also be used when building the pattern.
   */
  CreateSampleBucket(): TBucket {
    return this._bucketProvider();
  }

  /**
   * Sets this pattern to only be capable of formatting; any attempt to parse using the
   * built pattern will fail immediately.
   */
  SetFormatOnly(): void {
    this._formatOnly = true;
  }

  /**
   * Performs common parsing operations: start with a parse action to move the
   * value cursor onto the first character, then call a character handler for each
   * character in the pattern to build up the steps. If any handler fails,
   * that failure is returned - otherwise the return value is null.
   */
  ParseCustomPattern(patternText: string, characterHandlers: ReadonlyMap<string, CharacterHandler<TResult, TBucket>>): void {
    const patternCursor = new PatternCursor(patternText);

    // Now iterate over the pattern.
    while (patternCursor.MoveNext()) {
      const handler = characterHandlers.get(patternCursor.Current);
      if (handler !== undefined) {
        handler(patternCursor, this);
      } else {
        const current = patternCursor.Current;
        if (
          (current >= "A" && current <= "Z") ||
          (current >= "a" && current <= "z") ||
          current === PatternCursor.EmbeddedPatternStart ||
          current === PatternCursor.EmbeddedPatternEnd
        ) {
          throw new InvalidPatternException(TextErrorMessages.UnquotedLiteral, current);
        }
        this.AddLiteral(patternCursor.Current, ParseResult.MismatchedCharacter<TResult>);
      }
    }
  }

  /** Validates the combination of fields used. */
  ValidateUsedFields(): void {
    // We assume invalid combinations are global across all parsers. The way that
    // the patterns are parsed ensures we never end up with any invalid individual fields
    // (e.g. time fields within a date pattern).

    if ((this._usedFieldsField & (PatternFields.Era | PatternFields.YearOfEra)) === PatternFields.Era) {
      throw new InvalidPatternException(TextErrorMessages.EraWithoutYearOfEra);
    }
    const calendarAndEra = PatternFields.Era | PatternFields.Calendar;
    if ((this._usedFieldsField & calendarAndEra) === calendarAndEra) {
      throw new InvalidPatternException(TextErrorMessages.CalendarAndEra);
    }
  }

  /**
   * Returns a built pattern. This is mostly to keep the API for the builder separate from that of the pattern,
   * and for thread safety (publishing a new object, thus leading to a memory barrier).
   * Note that this builder *must not* be used after the result has been built.
   */
  Build(sample: TResult): IPartialPattern<TResult> {
    // If we've got an embedded date and any *other* date fields, throw.
    if (
      HasAny(this._usedFieldsField, PatternFields.EmbeddedDate) &&
      HasAny(this._usedFieldsField, PatternFields.AllDateFields & ~PatternFields.EmbeddedDate)
    ) {
      throw new InvalidPatternException(TextErrorMessages.DateFieldAndEmbeddedDate);
    }
    // Ditto for time
    if (
      HasAny(this._usedFieldsField, PatternFields.EmbeddedTime) &&
      HasAny(this._usedFieldsField, PatternFields.AllTimeFields & ~PatternFields.EmbeddedTime)
    ) {
      throw new InvalidPatternException(TextErrorMessages.TimeFieldAndEmbeddedTime);
    }

    this._resultTypeName = ResultTypeName(sample);

    // noda-js: C# combines the actions into a multicast delegate; here they're kept as an array.
    const formatDelegate: ((value: TResult, builder: StringBuilder) => void)[] = [];
    for (const formatAction of this._formatActions) {
      const postAction = formatAction.target;
      formatDelegate.push(postAction !== undefined ? postAction.BuildFormatAction(this._usedFieldsField) : formatAction);
    }
    return new SteppedPattern<TResult, TBucket>(
      formatDelegate,
      this._formatOnly ? null : [...this._parseActions],
      this._bucketProvider,
      this._usedFieldsField,
      sample,
    );
  }

  /**
   * Registers that a pattern field has been used in this pattern, and throws a suitable error
   * result if it's already been used.
   */
  AddField(field: PatternFields, characterInPattern: string): void {
    const newUsedFields = this._usedFieldsField | field;
    if (newUsedFields === this._usedFieldsField) {
      throw new InvalidPatternException(TextErrorMessages.RepeatedFieldInPattern, characterInPattern);
    }
    this._usedFieldsField = newUsedFields;
  }

  AddParseAction(parseAction: SteppedPatternBuilderParseAction<TResult, TBucket>): void {
    this._parseActions.push(parseAction);
  }

  AddFormatAction(formatAction: SteppedPatternBuilderFormatAction<TResult>): void {
    this._formatActions.push(formatAction);
  }

  /**
   * Equivalent of {@link AddParseValueAction} but for 64-bit integers. Currently only
   * positive values are supported.
   */
  AddParseInt64ValueAction(
    minimumDigits: number,
    maximumDigits: number,
    patternChar: string,
    minimumValue: number,
    maximumValue: number,
    valueSetter: (bucket: TBucket, value: number) => void,
  ): void {
    // (noda-js: the values are at most 13 digits, so they are safe integers.)
    Preconditions.DebugCheckArgumentRange("minimumValue", minimumValue, 0, Number.MAX_SAFE_INTEGER);
    this.AddParseAction((cursor, bucket) => {
      const startingIndex = cursor.Index;
      const [success, value] = cursor.ParseInt64Digits(minimumDigits, maximumDigits);
      if (!success) {
        cursor.Move(startingIndex);
        return ParseResult.MismatchedNumber<TResult>(cursor, patternChar.repeat(minimumDigits));
      }
      if (value < minimumValue || value > maximumValue) {
        cursor.Move(startingIndex);
        return ParseResult.FieldValueOutOfRange<TResult>(cursor, value, patternChar, this._resultTypeName);
      }

      valueSetter(bucket, value);
      return null;
    });
  }

  AddParseValueAction(
    minimumDigits: number,
    maximumDigits: number,
    patternChar: string,
    minimumValue: number,
    maximumValue: number,
    valueSetter: (bucket: TBucket, value: number) => void,
  ): void {
    this.AddParseAction((cursor, bucket) => {
      const startingIndex = cursor.Index;
      const negative = cursor.Match("-");
      if (negative && minimumValue >= 0) {
        cursor.Move(startingIndex);
        return ParseResult.UnexpectedNegative<TResult>(cursor);
      }
      let [success, value] = cursor.ParseDigits(minimumDigits, maximumDigits);
      if (!success) {
        cursor.Move(startingIndex);
        return ParseResult.MismatchedNumber<TResult>(cursor, patternChar.repeat(minimumDigits));
      }
      if (negative) {
        value = -value;
      }
      if (value < minimumValue || value > maximumValue) {
        cursor.Move(startingIndex);
        return ParseResult.FieldValueOutOfRange<TResult>(cursor, value, patternChar, this._resultTypeName);
      }

      valueSetter(bucket, value);
      return null;
    });
  }

  /**
   * Adds text which must be matched exactly when parsing, and appended directly when formatting.
   *
   * noda-js: also the AddLiteral(char, failureSelector) overload, told apart by the failure function's parameter count.
   */
  AddLiteral(expectedText: string, failure: (cursor: ValueCursor) => ParseResult<TResult>): void;
  /** Adds a character which must be matched exactly when parsing, and appended directly when formatting. */
  AddLiteral(expectedChar: string, failureSelector: (cursor: ValueCursor, expectedChar: string) => ParseResult<TResult>): void;
  AddLiteral(
    expectedText: string,
    failure: ((cursor: ValueCursor) => ParseResult<TResult>) | ((cursor: ValueCursor, expectedChar: string) => ParseResult<TResult>),
  ): void {
    if (failure.length >= 2) {
      // C#: AddLiteral(char expectedChar, Func<ValueCursor, char, ParseResult<TResult>> failureSelector)
      const expectedChar = expectedText;
      const failureSelector = failure as (cursor: ValueCursor, expectedChar: string) => ParseResult<TResult>;
      this.AddParseAction((str, bucket) => (str.Match(expectedChar) ? null : failureSelector(str, expectedChar)));
      this.AddFormatAction((value, builder) => builder.Append(expectedChar));
      return;
    }
    const failure1 = failure as (cursor: ValueCursor) => ParseResult<TResult>;
    // Common case - single character literal, often a date or time separator.
    if (expectedText.length === 1) {
      const expectedChar = expectedText[0]!;
      this.AddParseAction((str, bucket) => (str.Match(expectedChar) ? null : failure1(str)));
      this.AddFormatAction((value, builder) => builder.Append(expectedChar));
      return;
    }
    this.AddParseAction((str, bucket) => (str.Match(expectedText) ? null : failure1(str)));
    this.AddFormatAction((value, builder) => builder.Append(expectedText));
  }

  static HandleQuote<TResult, TBucket extends ParseBucket<TResult>>(pattern: PatternCursor, builder: SteppedPatternBuilder<TResult, TBucket>): void {
    const quoted = pattern.GetQuotedString(pattern.Current);
    builder.AddLiteral(quoted, ParseResult.QuotedStringMismatch<TResult>);
  }

  static HandleBackslash<TResult, TBucket extends ParseBucket<TResult>>(pattern: PatternCursor, builder: SteppedPatternBuilder<TResult, TBucket>): void {
    if (!pattern.MoveNext()) {
      throw new InvalidPatternException(TextErrorMessages.EscapeAtEndOfString);
    }
    builder.AddLiteral(pattern.Current, ParseResult.EscapedCharacterMismatch<TResult>);
  }

  // Note: the builder parameter is unused, but required so that the method fits the delegate signature.

  /**
   * Handle a leading "%" which acts as a pseudo-escape - it's mostly used to allow format strings such as "%H" to mean
   * "use a custom format string consisting of H instead of a standard pattern H".
   */
  static HandlePercent<TResult, TBucket extends ParseBucket<TResult>>(pattern: PatternCursor, builder: SteppedPatternBuilder<TResult, TBucket>): void {
    if (pattern.HasMoreCharacters) {
      if (pattern.PeekNext() !== "%") {
        // Handle the next character as normal
        return;
      }
      throw new InvalidPatternException(TextErrorMessages.PercentDoubled);
    }
    throw new InvalidPatternException(TextErrorMessages.PercentAtEndOfString);
  }

  /**
   * Returns a handler for a zero-padded purely-numeric field specifier, such as "seconds", "minutes", "24-hour", "12-hour" etc.
   * @param maxCount Maximum permissible count (usually two)
   * @param field Field to remember that we've seen
   * @param minValue Minimum valid value for the field (inclusive)
   * @param maxValue Maximum value value for the field (inclusive)
   * @param getter Delegate to retrieve the field value when formatting
   * @param setter Delegate to set the field value into a bucket when parsing
   * @returns The pattern parsing failure, or null on success.
   */
  static HandlePaddedField<TResult, TBucket extends ParseBucket<TResult>>(
    maxCount: number,
    field: PatternFields,
    minValue: number,
    maxValue: number,
    getter: (value: TResult) => number,
    setter: (bucket: TBucket, value: number) => void,
  ): CharacterHandler<TResult, TBucket> {
    return (pattern, builder) => {
      const count = pattern.GetRepeatCount(maxCount);
      builder.AddField(field, pattern.Current);
      builder.AddParseValueAction(count, maxCount, pattern.Current, minValue, maxValue, setter);
      builder.AddFormatLeftPad(count, getter, minValue >= 0, count === maxCount);
    };
  }

  /**
   * Adds parse actions for a list of strings, such as days of the week or month names.
   * The parsing is performed case-insensitively. All candidates are tested, and only the longest
   * match is used.
   * (noda-js: also the overload taking two lists, e.g. non-genitive and genitive month names.)
   */
  AddParseLongestTextAction(
    field: string,
    setter: (bucket: TBucket, value: number) => void,
    compareInfo: CompareInfo,
    textValues1: readonly string[],
    textValues2?: readonly string[],
  ): void {
    this.AddParseAction((str, bucket) => {
      const best = { bestIndex: -1, longestMatch: 0 };
      SteppedPatternBuilder.FindLongestMatch(compareInfo, str, textValues1, best);
      if (textValues2 !== undefined) {
        SteppedPatternBuilder.FindLongestMatch(compareInfo, str, textValues2, best);
      }
      if (best.bestIndex !== -1) {
        setter(bucket, best.bestIndex);
        str.Move(str.Index + best.longestMatch);
        return null;
      }
      return ParseResult.MismatchedText<TResult>(str, field);
    });
  }

  /**
   * Find the longest match from a given set of candidate strings, updating the index/length of the best value
   * accordingly. (noda-js: the C# ref parameters are fields of `best`.)
   */
  private static FindLongestMatch(
    compareInfo: CompareInfo,
    cursor: ValueCursor,
    values: readonly string[],
    best: { bestIndex: number; longestMatch: number },
  ): void {
    for (let i = 0; i < values.length; i++) {
      const candidate = values[i];
      if (candidate === null || candidate === undefined || candidate.length <= best.longestMatch) {
        continue;
      }
      if (cursor.MatchCaseInsensitive(candidate, compareInfo, false)) {
        best.bestIndex = i;
        best.longestMatch = candidate.length;
      }
    }
  }

  /**
   * Adds parse and format actions for a mandatory positive/negative sign.
   * @param signSetter Action to take when to set the given sign within the bucket
   * @param nonNegativePredicate Predicate to detect whether the value being formatted is non-negative
   */
  AddRequiredSign(signSetter: (bucket: TBucket, positive: boolean) => void, nonNegativePredicate: (value: TResult) => boolean): void {
    this.AddParseAction((str, bucket) => {
      if (str.Match("-")) {
        signSetter(bucket, false);
        return null;
      }
      if (str.Match("+")) {
        signSetter(bucket, true);
        return null;
      }
      return ParseResult.MissingSign<TResult>(str);
    });
    this.AddFormatAction((value, sb) => sb.Append(nonNegativePredicate(value) ? "+" : "-"));
  }

  /**
   * Adds parse and format actions for an "negative only" sign.
   * @param signSetter Action to take when to set the given sign within the bucket
   * @param nonNegativePredicate Predicate to detect whether the value being formatted is non-negative
   */
  AddNegativeOnlySign(signSetter: (bucket: TBucket, positive: boolean) => void, nonNegativePredicate: (value: TResult) => boolean): void {
    this.AddParseAction((str, bucket) => {
      if (str.Match("-")) {
        signSetter(bucket, false);
        return null;
      }
      if (str.Match("+")) {
        return ParseResult.PositiveSignInvalid<TResult>(str);
      }
      signSetter(bucket, true);
      return null;
    });
    this.AddFormatAction((value, builder) => {
      if (!nonNegativePredicate(value)) {
        builder.Append("-");
      }
    });
  }

  /**
   * Adds an action to pad a selected value to a given minimum length.
   * @param count The minimum length to pad to
   * @param selector The selector function to apply to obtain a value to format
   * @param assumeNonNegative Whether it is safe to assume the value will be non-negative
   * @param assumeFitsInCount Whether it is safe to assume the value will not exceed the specified length
   */
  AddFormatLeftPad(count: number, selector: (value: TResult) => number, assumeNonNegative: boolean, assumeFitsInCount: boolean): void {
    if (count === 2 && assumeNonNegative && assumeFitsInCount) {
      this.AddFormatAction((value, sb) => FormatHelper.Format2DigitsNonNegative(selector(value), sb));
    } else if (count === 4 && assumeFitsInCount) {
      this.AddFormatAction((value, sb) => FormatHelper.Format4DigitsValueFits(selector(value), sb));
    } else if (assumeNonNegative) {
      this.AddFormatAction((value, sb) => FormatHelper.LeftPadNonNegative(selector(value), count, sb));
    } else {
      this.AddFormatAction((value, sb) => FormatHelper.LeftPad(selector(value), count, sb));
    }
  }

  AddFormatFraction(width: number, scale: number, selector: (value: TResult) => number): void {
    this.AddFormatAction((value, sb) => FormatHelper.AppendFraction(selector(value), width, scale, sb));
  }

  AddFormatFractionTruncate(width: number, scale: number, selector: (value: TResult) => number): void {
    this.AddFormatAction((value, sb) => FormatHelper.AppendFractionTruncate(selector(value), width, scale, sb));
  }

  /** Handles date, time and date/time embedded patterns. */
  AddEmbeddedLocalPartial(
    pattern: PatternCursor,
    dateBucketExtractor: (bucket: TBucket) => LocalDatePatternParserLocalDateParseBucket,
    timeBucketExtractor: (bucket: TBucket) => LocalTimePatternParserLocalTimeParseBucket,
    dateExtractor: (value: TResult) => LocalDate,
    timeExtractor: (value: TResult) => LocalTime,
    // null if date/time embedded patterns are invalid
    dateTimeExtractor: ((value: TResult) => LocalDateTime) | null,
  ): void {
    // This will be d (date-only), t (time-only), or < (date and time)
    // If it's anything else, we'll see the problem when we try to get the pattern.
    const patternType = pattern.PeekNext();
    if (patternType === "d" || patternType === "t") {
      pattern.MoveNext();
    }
    const embeddedPatternText = pattern.GetEmbeddedPattern();
    switch (patternType) {
      case "<": {
        const sampleBucket = this.CreateSampleBucket();
        const twoDigitYearMax = dateBucketExtractor(sampleBucket).TwoDigitYearMax;
        const templateTime = timeBucketExtractor(sampleBucket).TemplateValue;
        const templateDate = dateBucketExtractor(sampleBucket).TemplateValue;
        if (dateTimeExtractor === null) {
          throw new InvalidPatternException(TextErrorMessages.InvalidEmbeddedPatternType);
        }
        this.AddField(PatternFields.EmbeddedDate, "l");
        this.AddField(PatternFields.EmbeddedTime, "l");
        this.AddEmbeddedPattern(
          // C#: templateDate + templateTime
          LocalDateTimePattern.Create(embeddedPatternText, this.FormatInfo, templateDate.At(templateTime), twoDigitYearMax).UnderlyingPattern,
          (bucket, value) => {
            const dateBucket = dateBucketExtractor(bucket);
            const timeBucket = timeBucketExtractor(bucket);
            dateBucket.Calendar = value.Calendar;
            dateBucket.Year = value.Year;
            dateBucket.MonthOfYearNumeric = value.Month;
            dateBucket.DayOfMonth = value.Day;
            timeBucket.Hours24 = value.Hour;
            timeBucket.Minutes = value.Minute;
            timeBucket.Seconds = value.Second;
            timeBucket.FractionalSeconds = value.NanosecondOfSecond;
          },
          dateTimeExtractor,
        );
        break;
      }
      case "d":
        this.AddEmbeddedDatePattern("l", embeddedPatternText, dateBucketExtractor, dateExtractor);
        break;
      case "t":
        this.AddEmbeddedTimePattern("l", embeddedPatternText, timeBucketExtractor, timeExtractor);
        break;
      default:
        throw NewInvalidOperationException("Bug in Noda Time: embedded pattern type wasn't date, time, or date+time");
    }
  }

  AddEmbeddedDatePattern(
    characterInPattern: string,
    embeddedPatternText: string,
    dateBucketExtractor: (bucket: TBucket) => LocalDatePatternParserLocalDateParseBucket,
    dateExtractor: (value: TResult) => LocalDate,
  ): void {
    const templateDate = dateBucketExtractor(this.CreateSampleBucket()).TemplateValue;
    this.AddField(PatternFields.EmbeddedDate, characterInPattern);
    this.AddEmbeddedPattern(
      LocalDatePattern.Create(embeddedPatternText, this.FormatInfo, templateDate, LocalDatePattern.DefaultTwoDigitYearMax).UnderlyingPattern,
      (bucket, value) => {
        const dateBucket = dateBucketExtractor(bucket);
        dateBucket.Calendar = value.Calendar;
        dateBucket.Year = value.Year;
        dateBucket.MonthOfYearNumeric = value.Month;
        dateBucket.DayOfMonth = value.Day;
      },
      dateExtractor,
    );
  }

  AddEmbeddedTimePattern(
    characterInPattern: string,
    embeddedPatternText: string,
    timeBucketExtractor: (bucket: TBucket) => LocalTimePatternParserLocalTimeParseBucket,
    timeExtractor: (value: TResult) => LocalTime,
  ): void {
    const templateTime = timeBucketExtractor(this.CreateSampleBucket()).TemplateValue;
    this.AddField(PatternFields.EmbeddedTime, characterInPattern);
    this.AddEmbeddedPattern(
      LocalTimePattern.Create(embeddedPatternText, this.FormatInfo, templateTime).UnderlyingPattern,
      (bucket, value) => {
        const timeBucket = timeBucketExtractor(bucket);
        timeBucket.Hours24 = value.Hour;
        timeBucket.Minutes = value.Minute;
        timeBucket.Seconds = value.Second;
        timeBucket.FractionalSeconds = value.NanosecondOfSecond;
      },
      timeExtractor,
    );
  }

  /** Adds parsing/formatting of an embedded pattern, e.g. an offset within a ZonedDateTime/OffsetDateTime. */
  AddEmbeddedPattern<TEmbedded>(
    embeddedPattern: IPartialPattern<TEmbedded>,
    parseAction: (bucket: TBucket, value: TEmbedded) => void,
    valueExtractor: (value: TResult) => TEmbedded,
  ): void {
    this.AddParseAction((value, bucket) => {
      const result = embeddedPattern.ParsePartial(value);
      if (!result.Success) {
        return result.ConvertError<TResult>();
      }
      parseAction(bucket, result.Value);
      return null;
    });
    this.AddFormatAction((value, sb) => embeddedPattern.AppendFormat(valueExtractor(value), sb));
  }
}

class SteppedPattern<TResult, TBucket extends ParseBucket<TResult>> implements IPartialPattern<TResult> {
  private readonly _formatActions: readonly ((value: TResult, builder: StringBuilder) => void)[];
  // This will be null if the pattern is only capable of formatting.
  private readonly _parseActions: readonly SteppedPatternBuilderParseAction<TResult, TBucket>[] | null;
  private readonly _bucketProvider: () => TBucket;
  private readonly _usedFields: PatternFields;
  private readonly _expectedLength: number;

  constructor(
    formatActions: readonly ((value: TResult, builder: StringBuilder) => void)[],
    parseActions: readonly SteppedPatternBuilderParseAction<TResult, TBucket>[] | null,
    bucketProvider: () => TBucket,
    usedFields: PatternFields,
    sample: TResult,
  ) {
    this._formatActions = formatActions;
    this._parseActions = parseActions;
    this._bucketProvider = bucketProvider;
    this._usedFields = usedFields;

    // Format the sample value to work out the expected length, so we
    // can use that when creating a StringBuilder. This will definitely not always
    // be appropriate, but it's a start.
    const builder = new StringBuilder();
    this.FormatAll(sample, builder);
    this._expectedLength = builder.Length;
  }

  // noda-js: invokes the "multicast delegate".
  private FormatAll(value: TResult, builder: StringBuilder): void {
    for (const action of this._formatActions) {
      action(value, builder);
    }
  }

  /** @inheritDoc */
  Parse(text: string): ParseResult<TResult> {
    if (this._parseActions === null) {
      return ParseResult.FormatOnlyPattern<TResult>(new ValueCursor(text));
    }
    if (text === null || text === undefined) {
      return ParseResult.ArgumentNull<TResult>("text");
    }
    if (text.length === 0) {
      return ParseResult.ValueStringEmpty;
    }

    const valueCursor = new ValueCursor(text);
    // Prime the pump... the value cursor ends up *before* the first character, but
    // our steps always assume it's *on* the right character.
    valueCursor.MoveNext();
    const result = this.ParsePartial(valueCursor);
    if (!result.Success) {
      return result;
    }
    // Check that we've used up all the text
    if (valueCursor.Current !== TextCursor.Nul) {
      return ParseResult.ExtraValueCharacters<TResult>(valueCursor, valueCursor.Remainder);
    }
    return result;
  }

  /** @inheritDoc */
  Format(value: TResult): string {
    // noda-js: there's no capacity to set, so expectedLength is unused.
    void this._expectedLength;
    const builder = new StringBuilder();
    // This will call all the actions in the multicast delegate.
    this.FormatAll(value, builder);
    return builder.toString();
  }

  /** @inheritDoc */
  ParsePartial(cursor: ValueCursor): ParseResult<TResult> {
    // At the moment we shouldn't get a partial parse for a format-only pattern, but
    // let's guard against it for the future.
    if (this._parseActions === null) {
      return ParseResult.FormatOnlyPattern<TResult>(cursor);
    }

    const bucket = this._bucketProvider();

    for (const action of this._parseActions) {
      const failure = action(cursor, bucket);
      if (failure !== null) {
        return failure;
      }
    }
    return bucket.CalculateValue(this._usedFields, cursor.Value);
  }

  /** @inheritDoc */
  AppendFormat(value: TResult, builder: StringBuilder): StringBuilder {
    Preconditions.CheckNotNull(builder, "builder");
    this.FormatAll(value, builder);
    return builder;
  }
}
