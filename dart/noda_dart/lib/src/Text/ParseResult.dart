// Ported from NodaTime 6e024dde: src/NodaTime/Text/ParseResult.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../AnnualDate.dart';
import '../CalendarSystem.dart';
import '../Calendars/Era.dart';
import '../Duration.dart';
import '../Instant.dart';
import '../LocalDate.dart';
import '../LocalDateTime.dart';
import '../LocalTime.dart';
import '../Offset.dart';
import '../OffsetDate.dart';
import '../OffsetDateTime.dart';
import '../OffsetTime.dart';
import '../Period.dart';
import '../Utility/StringFormat.dart';
import '../YearMonth.dart';
import '../ZonedDateTime.dart';
import 'TextErrorMessages.generated.dart';
import 'UnparsableValueException.dart';
import 'ValueCursor.dart';

// noda_dart: Dart statics can't use the class's type parameter, so the factories are generic methods:
// ParseResult<LocalDate>.ForValue(x) is ParseResult.ForValue<LocalDate>(x).

/// The result of a parse operation.
///
/// [T]: The type which was parsed, such as a [LocalDateTime].
final class ParseResult<T> {
  // Invariant: exactly one of value or exceptionProvider is null.
  final T? _value;
  final Object Function()? _exceptionProvider;

  @internal
  final bool ContinueAfterErrorWithMultipleFormats;

  ParseResult._NewExceptionProviderContinueWithMultiple(
      Object Function() exceptionProvider, bool continueWithMultiple)
      : _exceptionProvider = exceptionProvider,
        ContinueAfterErrorWithMultipleFormats = continueWithMultiple,
        // Satisfy the compiler around the invariant.
        _value = null;

  ParseResult._NewValue(T value)
      : _value = value,
        _exceptionProvider = null,
        ContinueAfterErrorWithMultipleFormats = false;

  /// Gets the value from the parse operation if it was successful, or throws an exception indicating the parse failure
  /// otherwise.
  ///
  /// This method is exactly equivalent to calling the [GetValueOrThrow] method, but is terser if the code is
  /// already clear that it will throw if the parse failed.
  ///
  /// The result of the parsing operation if it was successful.
  T get Value => GetValueOrThrow();

  /// Gets an exception indicating the cause of the parse failure.
  ///
  /// This property is typically used to wrap parse failures in higher level exceptions.
  ///
  /// The exception indicating the cause of the parse failure.
  ///
  /// Throws [StateError]: The parse operation succeeded.
  Object get Exception {
    if (_exceptionProvider == null) {
      throw StateError('Parse operation succeeded, so no exception is available');
    }
    return _exceptionProvider();
  }

  /// Gets the value from the parse operation if it was successful, or throws an exception indicating the parse failure
  /// otherwise.
  ///
  /// This method is exactly equivalent to fetching the [Value] property, but more explicit in terms of throwing
  /// an exception on failure.
  ///
  /// Returns the result of the parsing operation if it was successful.
  T GetValueOrThrow() {
    if (_exceptionProvider == null) {
      return _value as T;
    }
    throw _exceptionProvider();
  }

  /// Returns the success value, and either the specified failure value of T or the successful parse result value.
  ///
  /// noda_dart: the C# `out` parameter is the second element of the returned record.
  ///
  /// [failureValue]: The "default" value to return as the result if parsing failed.
  ///
  /// Returns true if this parse result was successful, or false otherwise; and the parsed value on success, or
  /// [failureValue] on failure.
  (bool, T) TryGetValue(T failureValue) {
    bool success = _exceptionProvider == null;
    T result = success ? _value as T : failureValue;
    return (success, result);
  }

  /// Indicates whether the parse operation was successful.
  ///
  /// This returns True if and only if fetching the value with the [Value] property will return with no exception.
  ///
  /// true if the parse operation was successful; otherwise false.
  bool get Success => _exceptionProvider == null;

  /// Converts this result to a new target type, either by executing the given projection
  /// for a success result, or propagating the exception provider for failure.
  ///
  /// [TTarget]: The target type of the conversion.
  /// [projection]: The projection to apply for the value of this result,
  /// if it's a success result.
  ///
  /// Returns a ParseResult for the target type, either with a value obtained by applying the specified
  /// projection to the value in this result, or with the same error as this result.
  ParseResult<TTarget> Convert<TTarget>(TTarget Function(T) projection) {
    // Dart: null safety checks projection.
    return Success
        ? ParseResult.ForValue<TTarget>(projection(Value))
        : ParseResult<TTarget>._NewExceptionProviderContinueWithMultiple(
            _exceptionProvider!, ContinueAfterErrorWithMultipleFormats);
  }

  /// Converts this result to a new target type by propagating the exception provider.
  /// This parse result must already be an error result.
  ///
  /// Returns a ParseResult for the target type, with the same error as this result.
  ParseResult<TTarget> ConvertError<TTarget>() {
    if (Success) {
      throw StateError('ConvertError should not be called on a successful parse result');
    }
    return ParseResult<TTarget>._NewExceptionProviderContinueWithMultiple(
        _exceptionProvider!, ContinueAfterErrorWithMultipleFormats);
  }

  // #region Factory methods and readonly static fields

  // Changing this would be a breaking change, and I'm comfortable with it anyway.
  /// Produces a ParseResult which represents a successful parse operation.
  ///
  /// When T is a reference type, [value] should not be null,
  /// but this isn't currently checked.
  ///
  /// [value]: The successfully parsed value.
  ///
  /// Returns a ParseResult representing a successful parsing operation.
  static ParseResult<T> ForValue<T>(T value) => ParseResult<T>._NewValue(value);

  /// Produces a ParseResult which represents a failed parsing operation.
  ///
  /// This method accepts a delegate rather than the exception itself, as creating an
  /// exception can be relatively slow: if the client doesn't need the actual exception, just the information
  /// that the parse failed, there's no point in creating the exception.
  ///
  /// [exceptionProvider]: A delegate that produces the exception representing the error that
  /// caused the parse to fail.
  ///
  /// Returns a ParseResult representing a failed parsing operation.
  static ParseResult<T> ForException<T>(Object Function() exceptionProvider) =>
      // Dart: null safety checks exceptionProvider.
      ParseResult<T>._NewExceptionProviderContinueWithMultiple(exceptionProvider, false);

  @internal
  static ParseResult<T> ForInvalidValue<T>(ValueCursor cursor, String formatString,
          [List<Object?> parameters = const []]) =>
      _ForInvalidValueExceptionProvider<T>(() {
        // Format the message which is specific to the kind of parse error.
        String detailMessage = StringFormat.Format(formatString, parameters);
        // Format the overall message, containing the parse error and the value itself.
        String overallMessage = StringFormat.Format(TextErrorMessages.UnparsableValue, [detailMessage, cursor]);
        return UnparsableValueException(overallMessage, cursor.Value, cursor.Index);
      });

  @internal
  static ParseResult<T> ForInvalidValuePostParse<T>(String text, String formatString,
          [List<Object?> parameters = const []]) =>
      _ForInvalidValueExceptionProvider<T>(() {
        // Format the message which is specific to the kind of parse error.
        String detailMessage = StringFormat.Format(formatString, parameters);
        // Format the overall message, containing the parse error and the value itself.
        String overallMessage = StringFormat.Format(TextErrorMessages.UnparsableValuePostParse, [detailMessage, text]);
        return UnparsableValueException(overallMessage, text, -1);
      });

  // noda_dart: C#'s private overload ForInvalidValue(Func<Exception>), renamed as Dart has no overloads.
  static ParseResult<T> _ForInvalidValueExceptionProvider<T>(Object Function() exceptionProvider) =>
      ParseResult<T>._NewExceptionProviderContinueWithMultiple(exceptionProvider, true);

  @internal
  static ParseResult<T> ArgumentNull<T>(String parameter) =>
      ParseResult<T>._NewExceptionProviderContinueWithMultiple(() => ArgumentError.notNull(parameter), false);

  @internal
  static ParseResult<T> PositiveSignInvalid<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.PositiveSignInvalid);

  // Special case: it's a fault with the value, but we still don't want to continue with multiple patterns.
  // (noda_dart: C#'s static property, one per T; a method here, as Dart has no generic getters.)
  @internal
  static ParseResult<T> ValueStringEmpty<T>() => ParseResult<T>._NewExceptionProviderContinueWithMultiple(
      () => UnparsableValueException(StringFormat.Format(TextErrorMessages.ValueStringEmpty, const []), '', -1), false);

  @internal
  static ParseResult<T> ExtraValueCharacters<T>(ValueCursor cursor, String remainder) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.ExtraValueCharacters, [remainder]);

  @internal
  static ParseResult<T> QuotedStringMismatch<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.QuotedStringMismatch);

  @internal
  static ParseResult<T> EscapedCharacterMismatch<T>(ValueCursor cursor, String patternCharacter) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.EscapedCharacterMismatch, [patternCharacter]);

  @internal
  static ParseResult<T> EndOfString<T>(ValueCursor cursor) => ForInvalidValue<T>(cursor, TextErrorMessages.EndOfString);

  @internal
  static ParseResult<T> TimeSeparatorMismatch<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.TimeSeparatorMismatch);

  @internal
  static ParseResult<T> DateSeparatorMismatch<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.DateSeparatorMismatch);

  @internal
  static ParseResult<T> MissingNumber<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.MissingNumber);

  @internal
  static ParseResult<T> UnexpectedNegative<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.UnexpectedNegative);

  /// This isn't really an issue with the value so much as the pattern... but the result is the same.
  @internal
  static ParseResult<T> FormatOnlyPattern<T>(ValueCursor cursor) =>
      ParseResult<T>._NewExceptionProviderContinueWithMultiple(
          () => UnparsableValueException(StringFormat.Format(TextErrorMessages.FormatOnlyPattern, const []), cursor.Value, cursor.Index),
          true);

  @internal
  static ParseResult<T> MismatchedNumber<T>(ValueCursor cursor, String pattern) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.MismatchedNumber, [pattern]);

  @internal
  static ParseResult<T> MismatchedCharacter<T>(ValueCursor cursor, String patternCharacter) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.MismatchedCharacter, [patternCharacter]);

  @internal
  static ParseResult<T> MismatchedText<T>(ValueCursor cursor, String field) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.MismatchedText, [field]);

  @internal
  static ParseResult<T> NoMatchingFormat<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.NoMatchingFormat);

  @internal
  static ParseResult<T> ValueOutOfRange<T>(ValueCursor cursor, Object value) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.ValueOutOfRange, [value, TypeName(T)]);

  @internal
  static ParseResult<T> MissingSign<T>(ValueCursor cursor) => ForInvalidValue<T>(cursor, TextErrorMessages.MissingSign);

  @internal
  static ParseResult<T> MissingAmPmDesignator<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.MissingAmPmDesignator);

  @internal
  static ParseResult<T> NoMatchingCalendarSystem<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.NoMatchingCalendarSystem);

  @internal
  static ParseResult<T> NoMatchingZoneId<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.NoMatchingZoneId);

  @internal
  static ParseResult<T> InvalidHour24<T>(String text) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.InvalidHour24);

  /// (noda_dart: covers both the C# `int` and `long` overloads.)
  @internal
  static ParseResult<T> FieldValueOutOfRange<T>(ValueCursor cursor, int value, String field) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.FieldValueOutOfRange, [value, field, TypeName(T)]);

  @internal
  static ParseResult<T> FieldValueOutOfRangePostParse<T>(String text, int value, String field, Type eventualResultType) =>
      ForInvalidValuePostParse<T>(
          text, TextErrorMessages.FieldValueOutOfRange, [value, field, TypeName(eventualResultType)]);

  /// Two fields (e.g. "hour of day" and "hour of half day") were mutually inconsistent.
  @internal
  static ParseResult<T> InconsistentValues<T>(String text, String field1, String field2, Type eventualResultType) =>
      ForInvalidValuePostParse<T>(
          text, TextErrorMessages.InconsistentValues2, [field1, field2, TypeName(eventualResultType)]);

  /// The month of year is inconsistent between the text and numeric specifications.
  /// We can't use InconsistentValues for this as the pattern character is the same in both cases.
  @internal
  static ParseResult<T> InconsistentMonthValues<T>(String text) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.InconsistentMonthTextValue);

  /// The day of month is inconsistent with the day of week value.
  /// We can't use InconsistentValues for this as the pattern character is the same in both cases.
  @internal
  static ParseResult<T> InconsistentDayOfWeekTextValue<T>(String text) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.InconsistentDayOfWeekTextValue);

  /// We'd expected to get to the end of the string now, but we haven't.
  @internal
  static ParseResult<T> ExpectedEndOfString<T>(ValueCursor cursor) =>
      ForInvalidValue<T>(cursor, TextErrorMessages.ExpectedEndOfString);

  @internal
  static ParseResult<T> YearOfEraOutOfRange<T>(String text, int value, Era era, CalendarSystem calendar) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.YearOfEraOutOfRange, [value, era.Name, calendar.Name]);

  @internal
  static ParseResult<T> MonthOutOfRange<T>(String text, int month, int year) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.MonthOutOfRange, [month, year]);

  @internal
  static ParseResult<T> IsoMonthOutOfRange<T>(String text, int month) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.IsoMonthOutOfRange, [month]);

  @internal
  static ParseResult<T> DayOfMonthOutOfRange<T>(String text, int day, int month, int year) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.DayOfMonthOutOfRange, [day, month, year]);

  @internal
  static ParseResult<T> DayOfMonthOutOfRangeNoYear<T>(String text, int day, int month) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.DayOfMonthOutOfRangeNoYear, [day, month]);

  @internal
  static ParseResult<T> InvalidOffset<T>(String text) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.InvalidOffset);

  @internal
  static ParseResult<T> SkippedLocalTime<T>(String text) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.SkippedLocalTime);

  @internal
  static ParseResult<T> AmbiguousLocalTime<T>(String text) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.AmbiguousLocalTime);

  @internal
  static ParseResult<T> TemplateYearOutOfRangeForCalendar<T>(String text, int value, CalendarSystem calendar) =>
      ForInvalidValuePostParse<T>(text, TextErrorMessages.TemplateYearOutOfRange, [value, calendar.Name]);

  // #endregion

  /// noda_dart: C#'s `typeof(T)` full name (Dart's `Type.toString()` is the simple name, minified by dart2js).
  @internal
  static String TypeName(Type type) => switch (type) {
        const (AnnualDate) => 'NodaTime.AnnualDate',
        const (Duration) => 'NodaTime.Duration',
        const (Instant) => 'NodaTime.Instant',
        const (LocalDate) => 'NodaTime.LocalDate',
        const (LocalDateTime) => 'NodaTime.LocalDateTime',
        const (LocalTime) => 'NodaTime.LocalTime',
        const (Offset) => 'NodaTime.Offset',
        const (OffsetDate) => 'NodaTime.OffsetDate',
        const (OffsetDateTime) => 'NodaTime.OffsetDateTime',
        const (OffsetTime) => 'NodaTime.OffsetTime',
        const (Period) => 'NodaTime.Period',
        const (YearMonth) => 'NodaTime.YearMonth',
        const (ZonedDateTime) => 'NodaTime.ZonedDateTime',
        _ => type.toString(),
      };
}
