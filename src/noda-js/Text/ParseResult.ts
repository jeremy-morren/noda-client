// Ported from NodaTime 3.3.0: src/NodaTime/Text/ParseResult.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  ArgumentNullError,
  InvalidOperationError,
  Preconditions,
  TextErrorMessages,
  UnparsableValueError,
  FormatString as formatStringImpl,
} from "../internal.ts";
import type { CalendarSystem, Era, ValueCursor } from "../internal.ts";
import type { LocalDateTime } from "../internal.ts";

// noda-js: the C# factory methods are static members of the generic class ParseResult<T>; here they're
// generic static methods (ParseResult<LocalDate>.ForValue(x) becomes ParseResult.forValue<LocalDate>(x), and
// usually the type argument is inferred). They never use `this`, so they can be passed around unbound
// (e.g. `builder.addLiteral(separator, ParseResult.dateSeparatorMismatch)`).
// Where the C# uses typeof(T) in a message, the type name (e.g. "NodaTime.LocalDate") is an extra parameter.
// (formatString is imported as formatStringImpl, as several methods have a parameter named formatString.)

let valueStringEmpty: ParseResult<any> | undefined;

/**
 * The result of a parse operation.
 * @typeParam T The type which was parsed, such as a {@link LocalDateTime}.
 */
export class ParseResult<T> {
  // Invariant: exactly one of value or exceptionProvider is null.
  private readonly _valueField: T;
  private readonly _exceptionProvider: (() => Error) | null;
  /** @internal */
  readonly ContinueAfterErrorWithMultipleFormats: boolean;

  private constructor(value: T, exceptionProvider: (() => Error) | null, continueWithMultiple: boolean) {
    this._valueField = value;
    this._exceptionProvider = exceptionProvider;
    this.ContinueAfterErrorWithMultipleFormats = continueWithMultiple;
  }

  /**
   * Gets the value from the parse operation if it was successful, or throws an exception indicating the parse failure
   * otherwise.
   *
   * This method is exactly equivalent to calling the {@link GetValueOrThrow} method, but is terser if the code is
   * already clear that it will throw if the parse failed.
   */
  get Value(): T {
    return this.GetValueOrThrow();
  }

  /**
   * Gets an exception indicating the cause of the parse failure.
   *
   * This property is typically used to wrap parse failures in higher level exceptions.
   * @throws {InvalidOperationError} The parse operation succeeded.
   */
  get Exception(): Error {
    if (this._exceptionProvider === null) {
      throw new InvalidOperationError("Parse operation succeeded, so no exception is available");
    }
    return this._exceptionProvider();
  }

  /**
   * Gets the value from the parse operation if it was successful, or throws an exception indicating the parse failure
   * otherwise.
   *
   * This method is exactly equivalent to fetching the {@link Value} property, but more explicit in terms of throwing
   * an exception on failure.
   * @returns The result of the parsing operation if it was successful.
   */
  GetValueOrThrow(): T {
    if (this._exceptionProvider === null) {
      return this._valueField;
    }
    throw this._exceptionProvider();
  }

  /**
   * Returns the success value, and either the specified failure value of T or the successful parse result value.
   * (noda-js: the C# out parameter is the second element of the returned tuple.)
   * @param failureValue The "default" value to return as the result if parsing failed.
   * @returns A tuple of: true if this parse result was successful, or false otherwise; and the parsed value
   * on success, or `failureValue` on failure.
   */
  TryGetValue(failureValue: T): [success: boolean, result: T] {
    const success = this._exceptionProvider === null;
    return [success, success ? this._valueField : failureValue];
  }

  /**
   * Indicates whether the parse operation was successful.
   *
   * This returns True if and only if fetching the value with the {@link Value} property will return with no exception.
   */
  get Success(): boolean {
    return this._exceptionProvider === null;
  }

  /**
   * Converts this result to a new target type, either by executing the given projection
   * for a success result, or propagating the exception provider for failure.
   * @typeParam TTarget The target type of the conversion.
   * @param projection The projection to apply for the value of this result,
   * if it's a success result.
   * @returns A ParseResult for the target type, either with a value obtained by applying the specified
   * projection to the value in this result, or with the same error as this result.
   */
  Convert<TTarget>(projection: (value: T) => TTarget): ParseResult<TTarget> {
    Preconditions.CheckNotNull(projection, "projection");
    return this.Success
      ? ParseResult.ForValue<TTarget>(projection(this.Value))
      : new ParseResult<TTarget>(undefined as TTarget, this._exceptionProvider!, this.ContinueAfterErrorWithMultipleFormats);
  }

  /**
   * Converts this result to a new target type by propagating the exception provider.
   * This parse result must already be an error result.
   * @returns A ParseResult for the target type, with the same error as this result.
   */
  ConvertError<TTarget>(): ParseResult<TTarget> {
    if (this.Success) {
      throw new InvalidOperationError("ConvertError should not be called on a successful parse result");
    }
    return new ParseResult<TTarget>(undefined as TTarget, this._exceptionProvider!, this.ContinueAfterErrorWithMultipleFormats);
  }

  // #region Factory methods and readonly static fields

  // Changing this would be a breaking change, and I'm comfortable with it anyway.
  /**
   * Produces a ParseResult which represents a successful parse operation.
   *
   * When T is a reference type, `value` should not be null,
   * but this isn't currently checked.
   * @param value The successfully parsed value.
   * @returns A ParseResult representing a successful parsing operation.
   */
  static ForValue<T>(value: T): ParseResult<T> {
    return new ParseResult<T>(value, null, false);
  }

  /**
   * Produces a ParseResult which represents a failed parsing operation.
   *
   * This method accepts a delegate rather than the exception itself, as creating an
   * exception can be relatively slow: if the client doesn't need the actual exception, just the information
   * that the parse failed, there's no point in creating the exception.
   * @param exceptionProvider A delegate that produces the exception representing the error that
   * caused the parse to fail.
   * @returns A ParseResult representing a failed parsing operation.
   */
  static ForException<T>(exceptionProvider: () => Error): ParseResult<T> {
    return new ParseResult<T>(undefined as T, Preconditions.CheckNotNull(exceptionProvider, "exceptionProvider"), false);
  }

  /** @internal */
  static ForInvalidValue<T>(cursor: ValueCursor, formatString: string, ...parameters: unknown[]): ParseResult<T> {
    return ParseResult.ForInvalidValueProvider<T>(() => {
      // Format the message which is specific to the kind of parse error.
      const detailMessage = formatStringImpl(formatString, ...parameters);
      // Format the overall message, containing the parse error and the value itself.
      const overallMessage = formatStringImpl(TextErrorMessages.UnparsableValue, detailMessage, cursor);
      return new UnparsableValueError(overallMessage, cursor.Value, cursor.Index);
    });
  }

  /** @internal */
  static ForInvalidValuePostParse<T>(text: string, formatString: string, ...parameters: unknown[]): ParseResult<T> {
    return ParseResult.ForInvalidValueProvider<T>(() => {
      // Format the message which is specific to the kind of parse error.
      const detailMessage = formatStringImpl(formatString, ...parameters);
      // Format the overall message, containing the parse error and the value itself.
      const overallMessage = formatStringImpl(TextErrorMessages.UnparsableValuePostParse, detailMessage, text);
      return new UnparsableValueError(overallMessage, text, -1);
    });
  }

  // noda-js: C#'s private overload ForInvalidValue(Func<Exception>), renamed as it can't be told apart at runtime.
  private static ForInvalidValueProvider<T>(exceptionProvider: () => Error): ParseResult<T> {
    return new ParseResult<T>(undefined as T, exceptionProvider, true);
  }

  /** @internal */
  static ArgumentNull<T>(parameter: string): ParseResult<T> {
    return new ParseResult<T>(undefined as T, () => new ArgumentNullError(parameter), false);
  }

  /** @internal */
  static PositiveSignInvalid<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.PositiveSignInvalid);
  }

  // Special case: it's a fault with the value, but we still don't want to continue with multiple patterns.
  /** @internal */
  static get ValueStringEmpty(): ParseResult<any> {
    return (valueStringEmpty ??= new ParseResult<any>(
      undefined,
      () => new UnparsableValueError(formatStringImpl(TextErrorMessages.ValueStringEmpty), "", -1),
      false,
    ));
  }

  /** @internal */
  static ExtraValueCharacters<T>(cursor: ValueCursor, remainder: string): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.ExtraValueCharacters, remainder);
  }

  /** @internal */
  static QuotedStringMismatch<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.QuotedStringMismatch);
  }

  /** @internal */
  static EscapedCharacterMismatch<T>(cursor: ValueCursor, patternCharacter: string): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.EscapedCharacterMismatch, patternCharacter);
  }

  /** @internal */
  static EndOfString<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.EndOfString);
  }

  /** @internal */
  static TimeSeparatorMismatch<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.TimeSeparatorMismatch);
  }

  /** @internal */
  static DateSeparatorMismatch<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.DateSeparatorMismatch);
  }

  /** @internal */
  static MissingNumber<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.MissingNumber);
  }

  /** @internal */
  static UnexpectedNegative<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.UnexpectedNegative);
  }

  /**
   * This isn't really an issue with the value so much as the pattern... but the result is the same.
   * @internal
   */
  static FormatOnlyPattern<T>(cursor: ValueCursor): ParseResult<T> {
    return new ParseResult<T>(
      undefined as T,
      () => new UnparsableValueError(formatStringImpl(TextErrorMessages.FormatOnlyPattern), cursor.Value, cursor.Index),
      true,
    );
  }

  /** @internal */
  static MismatchedNumber<T>(cursor: ValueCursor, pattern: string): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.MismatchedNumber, pattern);
  }

  /** @internal */
  static MismatchedCharacter<T>(cursor: ValueCursor, patternCharacter: string): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.MismatchedCharacter, patternCharacter);
  }

  /** @internal */
  static MismatchedText<T>(cursor: ValueCursor, field: string): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.MismatchedText, field);
  }

  /** @internal */
  static NoMatchingFormat<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.NoMatchingFormat);
  }

  /**
   * @param typeName noda-js: the name of the C# type argument T, e.g. "NodaTime.Period".
   * @internal
   */
  static ValueOutOfRange<T>(cursor: ValueCursor, value: unknown, typeName: string): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.ValueOutOfRange, value, typeName);
  }

  /** @internal */
  static MissingSign<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.MissingSign);
  }

  /** @internal */
  static MissingAmPmDesignator<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.MissingAmPmDesignator);
  }

  /** @internal */
  static NoMatchingCalendarSystem<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.NoMatchingCalendarSystem);
  }

  /** @internal */
  static NoMatchingZoneId<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.NoMatchingZoneId);
  }

  /** @internal */
  static InvalidHour24<T>(text: string): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.InvalidHour24);
  }

  /**
   * (noda-js: covers both the int and long overloads.)
   * @param typeName noda-js: the name of the C# type argument T, e.g. "NodaTime.LocalTime".
   * @internal
   */
  static FieldValueOutOfRange<T>(cursor: ValueCursor, value: number, field: string, typeName: string): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.FieldValueOutOfRange, value, field, typeName);
  }

  /**
   * @param eventualResultType The name of the eventual result type, e.g. "NodaTime.LocalDate".
   * @internal
   */
  static FieldValueOutOfRangePostParse<T>(text: string, value: number, field: string, eventualResultType: string): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.FieldValueOutOfRange, value, field, eventualResultType);
  }

  /**
   * Two fields (e.g. "hour of day" and "hour of half day") were mutually inconsistent.
   * @param eventualResultType The name of the eventual result type, e.g. "NodaTime.LocalDate".
   * @internal
   */
  static InconsistentValues<T>(text: string, field1: string, field2: string, eventualResultType: string): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.InconsistentValues2, field1, field2, eventualResultType);
  }

  /**
   * The month of year is inconsistent between the text and numeric specifications.
   * We can't use InconsistentValues for this as the pattern character is the same in both cases.
   * @internal
   */
  static InconsistentMonthValues<T>(text: string): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.InconsistentMonthTextValue);
  }

  /**
   * The day of month is inconsistent with the day of week value.
   * We can't use InconsistentValues for this as the pattern character is the same in both cases.
   * @internal
   */
  static InconsistentDayOfWeekTextValue<T>(text: string): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.InconsistentDayOfWeekTextValue);
  }

  /**
   * We'd expected to get to the end of the string now, but we haven't.
   * @internal
   */
  static ExpectedEndOfString<T>(cursor: ValueCursor): ParseResult<T> {
    return ParseResult.ForInvalidValue<T>(cursor, TextErrorMessages.ExpectedEndOfString);
  }

  /** @internal */
  static YearOfEraOutOfRange<T>(text: string, value: number, era: Era, calendar: CalendarSystem): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.YearOfEraOutOfRange, value, era.Name, calendar.Name);
  }

  /** @internal */
  static MonthOutOfRange<T>(text: string, month: number, year: number): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.MonthOutOfRange, month, year);
  }

  /** @internal */
  static IsoMonthOutOfRange<T>(text: string, month: number): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.IsoMonthOutOfRange, month);
  }

  /** @internal */
  static DayOfMonthOutOfRange<T>(text: string, day: number, month: number, year: number): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.DayOfMonthOutOfRange, day, month, year);
  }

  /** @internal */
  static DayOfMonthOutOfRangeNoYear<T>(text: string, day: number, month: number): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.DayOfMonthOutOfRangeNoYear, day, month);
  }

  /** @internal */
  static InvalidOffset<T>(text: string): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.InvalidOffset);
  }

  /** @internal */
  static SkippedLocalTime<T>(text: string): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.SkippedLocalTime);
  }

  /** @internal */
  static AmbiguousLocalTime<T>(text: string): ParseResult<T> {
    return ParseResult.ForInvalidValuePostParse<T>(text, TextErrorMessages.AmbiguousLocalTime);
  }

  // #endregion
}
