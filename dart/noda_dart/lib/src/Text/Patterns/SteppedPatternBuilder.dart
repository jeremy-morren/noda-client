// Ported from NodaTime 6e024dde: src/NodaTime/Text/Patterns/SteppedPatternBuilder.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Globalization/NodaCultureInfo.dart';
import '../../Globalization/NodaFormatInfo.dart';
import '../../LocalDate.dart';
import '../../LocalDateTime.dart';
import '../../LocalTime.dart';
import '../../Utility/Int64.dart';
import '../../Utility/Preconditions.dart';
import '../Delegates.dart';
import '../FormatHelper.dart';
import '../IPartialPattern.dart';
import '../InvalidPatternException.dart';
import '../LocalDatePattern.dart';
import '../LocalDatePatternParser.dart';
import '../LocalDateTimePattern.dart';
import '../LocalTimePattern.dart';
import '../LocalTimePatternParser.dart';
import '../ParseBucket.dart';
import '../ParseResult.dart';
import '../TextCursor.dart';
import '../TextErrorMessages.generated.dart';
import '../ValueCursor.dart';
import 'PatternCursor.dart';
import 'PatternFields.dart';

/// C#: `SteppedPatternBuilder<TResult, TBucket>.ParseAction`.
@internal
typedef SteppedPatternBuilderParseAction<TResult, TBucket> = ParseResult<TResult>? Function(
    ValueCursor cursor, TBucket bucket);

/// C#'s `Action<TResult, StringBuilder>`, the type of a format action.
@internal
typedef SteppedPatternBuilderFormatAction<TResult> = void Function(TResult value, StringBuffer builder);

/// Builder for a pattern which implements parsing and formatting as a sequence of steps applied
/// in turn.
@internal
final class SteppedPatternBuilder<TResult, TBucket extends ParseBucket<TResult>> {
  // noda_dart: each action is kept with its target, as a Dart closure doesn't expose C#'s delegate `Target`.
  final List<(SteppedPatternBuilderFormatAction<TResult>, SteppedPatternBuilderIPostPatternParseFormatAction<TResult>?)>
      _formatActions;
  final List<SteppedPatternBuilderParseAction<TResult, TBucket>> _parseActions;
  final TBucket Function() _bucketProvider;
  PatternFields _usedFields = PatternFields.None;
  bool _formatOnly = false;

  final NodaFormatInfo FormatInfo;

  PatternFields get UsedFields => _usedFields;

  @internal
  SteppedPatternBuilder.NewFormatInfoBucketProvider(NodaFormatInfo formatInfo, TBucket Function() bucketProvider)
      : FormatInfo = formatInfo,
        _formatActions = [],
        _parseActions = [],
        _bucketProvider = bucketProvider;

  /// Calls the bucket provider and returns a sample bucket. This means that any values
  /// normally propagated via the bucket can also be used when building the pattern.
  TBucket CreateSampleBucket() {
    return _bucketProvider();
  }

  /// Sets this pattern to only be capable of formatting; any attempt to parse using the
  /// built pattern will fail immediately.
  void SetFormatOnly() {
    _formatOnly = true;
  }

  /// Performs common parsing operations: start with a parse action to move the
  /// value cursor onto the first character, then call a character handler for each
  /// character in the pattern to build up the steps. If any handler fails,
  /// that failure is returned - otherwise the return value is null.
  void ParseCustomPattern(String patternText, Map<String, CharacterHandler<TResult, TBucket>> characterHandlers) {
    var patternCursor = PatternCursor.NewPattern(patternText);

    // Now iterate over the pattern.
    while (patternCursor.MoveNext()) {
      CharacterHandler<TResult, TBucket>? handler = characterHandlers[patternCursor.Current];
      if (handler != null) {
        handler(patternCursor, this);
      } else {
        String current = patternCursor.Current;
        int code = current.codeUnitAt(0);
        if ((code >= 0x41 && code <= 0x5A) || // 'A'..'Z'
            (code >= 0x61 && code <= 0x7A) || // 'a'..'z'
            current == PatternCursor.EmbeddedPatternStart ||
            current == PatternCursor.EmbeddedPatternEnd) {
          throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnquotedLiteral, [current]);
        }
        AddLiteralChar(patternCursor.Current, ParseResult.MismatchedCharacter<TResult>);
      }
    }
  }

  /// Validates the combination of fields used.
  void ValidateUsedFields() {
    // We assume invalid combinations are global across all parsers. The way that
    // the patterns are parsed ensures we never end up with any invalid individual fields
    // (e.g. time fields within a date pattern).

    if ((_usedFields & (PatternFields.Era | PatternFields.YearOfEra)) == PatternFields.Era) {
      throw InvalidPatternException(TextErrorMessages.EraWithoutYearOfEra);
    }
    final PatternFields calendarAndEra = PatternFields.Era | PatternFields.Calendar;
    if ((_usedFields & calendarAndEra) == calendarAndEra) {
      throw InvalidPatternException(TextErrorMessages.CalendarAndEra);
    }
  }

  /// Returns a built pattern. This is mostly to keep the API for the builder separate from that of the pattern,
  /// and for thread safety (publishing a new object, thus leading to a memory barrier).
  /// Note that this builder *must not* be used after the result has been built.
  IPartialPattern<TResult> Build(TResult sample) {
    // If we've got an embedded date and any *other* date fields, throw.
    if (_usedFields.HasAny(PatternFields.EmbeddedDate) &&
        _usedFields.HasAny(PatternFields.AllDateFields & ~PatternFields.EmbeddedDate)) {
      throw InvalidPatternException(TextErrorMessages.DateFieldAndEmbeddedDate);
    }
    // Ditto for time
    if (_usedFields.HasAny(PatternFields.EmbeddedTime) &&
        _usedFields.HasAny(PatternFields.AllTimeFields & ~PatternFields.EmbeddedTime)) {
      throw InvalidPatternException(TextErrorMessages.TimeFieldAndEmbeddedTime);
    }

    // (noda_dart: C# combines the actions into a multicast delegate; here they're kept in a list.)
    final List<SteppedPatternBuilderFormatAction<TResult>> formatDelegate = [];
    for (final (formatAction, postAction) in _formatActions) {
      formatDelegate.add(postAction != null ? postAction.BuildFormatAction(_usedFields) : formatAction);
    }
    return _SteppedPattern<TResult, TBucket>(
        formatDelegate, _formatOnly ? null : List.of(_parseActions, growable: false), _bucketProvider, _usedFields, sample);
  }

  /// Registers that a pattern field has been used in this pattern, and throws a suitable error
  /// result if it's already been used.
  void AddField(PatternFields field, String characterInPattern) {
    PatternFields newUsedFields = _usedFields | field;
    if (newUsedFields == _usedFields) {
      throw InvalidPatternException.NewFormatStringParameters(
          TextErrorMessages.RepeatedFieldInPattern, [characterInPattern]);
    }
    _usedFields = newUsedFields;
  }

  void AddParseAction(SteppedPatternBuilderParseAction<TResult, TBucket> parseAction) => _parseActions.add(parseAction);

  /// (noda_dart: [target] is C#'s delegate `Target`; see [_formatActions].)
  void AddFormatAction(SteppedPatternBuilderFormatAction<TResult> formatAction,
          [SteppedPatternBuilderIPostPatternParseFormatAction<TResult>? target]) =>
      _formatActions.add((formatAction, target));

  /// Equivalent of [AddParseValueAction] but for 64-bit integers. Currently only
  /// positive values are supported.
  void AddParseInt64ValueAction(int minimumDigits, int maximumDigits, String patternChar, int minimumValue,
      int maximumValue, void Function(TBucket, int) valueSetter) {
    Preconditions.DebugCheckArgumentRange('minimumValue', minimumValue, 0, Int64.MaxValue);
    AddParseAction((cursor, bucket) {
      int startingIndex = cursor.Index;
      final (bool success, int value) = cursor.ParseInt64Digits(minimumDigits, maximumDigits);
      if (!success) {
        cursor.Move(startingIndex);
        return ParseResult.MismatchedNumber<TResult>(cursor, patternChar * minimumDigits);
      }
      if (value < minimumValue || value > maximumValue) {
        cursor.Move(startingIndex);
        return ParseResult.FieldValueOutOfRange<TResult>(cursor, value, patternChar);
      }

      valueSetter(bucket, value);
      return null;
    });
  }

  void AddParseValueAction(int minimumDigits, int maximumDigits, String patternChar, int minimumValue,
      int maximumValue, void Function(TBucket, int) valueSetter) {
    AddParseAction((cursor, bucket) {
      int startingIndex = cursor.Index;
      bool negative = cursor.Match('-');
      if (negative && minimumValue >= 0) {
        cursor.Move(startingIndex);
        return ParseResult.UnexpectedNegative<TResult>(cursor);
      }
      var (bool success, int value) = cursor.ParseDigits(minimumDigits, maximumDigits);
      if (!success) {
        cursor.Move(startingIndex);
        return ParseResult.MismatchedNumber<TResult>(cursor, patternChar * minimumDigits);
      }
      if (negative) {
        value = -value;
      }
      if (value < minimumValue || value > maximumValue) {
        cursor.Move(startingIndex);
        return ParseResult.FieldValueOutOfRange<TResult>(cursor, value, patternChar);
      }

      valueSetter(bucket, value);
      return null;
    });
  }

  /// Adds text which must be matched exactly when parsing, and appended directly when formatting.
  void AddLiteral(String expectedText, ParseResult<TResult> Function(ValueCursor) failure) {
    // Common case - single character literal, often a date or time separator.
    if (expectedText.length == 1) {
      String expectedChar = expectedText[0];
      AddParseAction((str, bucket) => str.Match(expectedChar) ? null : failure(str));
      AddFormatAction((value, builder) => builder.write(expectedChar));
      return;
    }
    AddParseAction((str, bucket) => str.Match(expectedText) ? null : failure(str));
    AddFormatAction((value, builder) => builder.write(expectedText));
  }

  static void HandleQuote<TResult, TBucket extends ParseBucket<TResult>>(
      PatternCursor pattern, SteppedPatternBuilder<TResult, TBucket> builder) {
    String quoted = pattern.GetQuotedString(pattern.Current);
    builder.AddLiteral(quoted, ParseResult.QuotedStringMismatch<TResult>);
  }

  static void HandleBackslash<TResult, TBucket extends ParseBucket<TResult>>(
      PatternCursor pattern, SteppedPatternBuilder<TResult, TBucket> builder) {
    if (!pattern.MoveNext()) {
      throw InvalidPatternException(TextErrorMessages.EscapeAtEndOfString);
    }
    builder.AddLiteralChar(pattern.Current, ParseResult.EscapedCharacterMismatch<TResult>);
  }

  // Note: the builder parameter is unused, but required so that the method fits the delegate signature.

  /// Handle a leading "%" which acts as a pseudo-escape - it's mostly used to allow format strings such as "%H" to mean
  /// "use a custom format string consisting of H instead of a standard pattern H".
  static void HandlePercent<TResult, TBucket extends ParseBucket<TResult>>(
      PatternCursor pattern, SteppedPatternBuilder<TResult, TBucket> builder) {
    if (pattern.HasMoreCharacters) {
      if (pattern.PeekNext() != '%') {
        // Handle the next character as normal
        return;
      }
      throw InvalidPatternException(TextErrorMessages.PercentDoubled);
    }
    throw InvalidPatternException(TextErrorMessages.PercentAtEndOfString);
  }

  /// Returns a handler for a zero-padded purely-numeric field specifier, such as "seconds", "minutes", "24-hour", "12-hour" etc.
  ///
  /// [maxCount]: Maximum permissible count (usually two)
  /// [field]: Field to remember that we've seen
  /// [minValue]: Minimum valid value for the field (inclusive)
  /// [maxValue]: Maximum value value for the field (inclusive)
  /// [getter]: Delegate to retrieve the field value when formatting
  /// [setter]: Delegate to set the field value into a bucket when parsing
  ///
  /// Returns the pattern parsing failure, or null on success.
  static CharacterHandler<TResult, TBucket> HandlePaddedField<TResult, TBucket extends ParseBucket<TResult>>(
      int maxCount,
      PatternFields field,
      int minValue,
      int maxValue,
      int Function(TResult) getter,
      void Function(TBucket, int) setter) {
    return (pattern, builder) {
      int count = pattern.GetRepeatCount(maxCount);
      builder.AddField(field, pattern.Current);
      builder.AddParseValueAction(count, maxCount, pattern.Current, minValue, maxValue, setter);
      builder.AddFormatLeftPad(count, getter, minValue >= 0, count == maxCount);
    };
  }

  /// Adds a character which must be matched exactly when parsing, and appended directly when formatting.
  ///
  /// (noda_dart: C#'s `AddLiteral(char, Func<ValueCursor, char, ParseResult<TResult>>)` overload.)
  void AddLiteralChar(String expectedChar, ParseResult<TResult> Function(ValueCursor, String) failureSelector) {
    AddParseAction((str, bucket) => str.Match(expectedChar) ? null : failureSelector(str, expectedChar));
    AddFormatAction((value, builder) => builder.write(expectedChar));
  }

  /// Adds parse actions for a list of strings, such as days of the week or month names.
  /// The parsing is performed case-insensitively. All candidates are tested, and only the longest
  /// match is used.
  ///
  /// With [textValues2], adds parse actions for two list of strings, such as non-genitive and genitive month names.
  /// (noda_dart: the two C# overloads form a prefix chain, so they're one method.)
  void AddParseLongestTextAction(String field, void Function(TBucket, int) setter, CompareInfo compareInfo,
      List<String> textValues1, [List<String>? textValues2]) {
    AddParseAction((str, bucket) {
      final best = _LongestMatch();
      _FindLongestMatch(compareInfo, str, textValues1, best);
      if (textValues2 != null) {
        _FindLongestMatch(compareInfo, str, textValues2, best);
      }
      if (best.bestIndex != -1) {
        setter(bucket, best.bestIndex);
        str.Move(str.Index + best.longestMatch);
        return null;
      }
      return ParseResult.MismatchedText<TResult>(str, field);
    });
  }

  /// Find the longest match from a given set of candidate strings, updating the index/length of the best value
  /// accordingly.
  ///
  /// (noda_dart: the C# `ref` parameters bestIndex and longestMatch are the fields of [best].)
  static void _FindLongestMatch(CompareInfo compareInfo, ValueCursor cursor, List<String?> values, _LongestMatch best) {
    for (int i = 0; i < values.length; i++) {
      String? candidate = values[i];
      if (candidate == null || candidate.length <= best.longestMatch) {
        continue;
      }
      if (cursor.MatchCaseInsensitive(candidate, compareInfo, false)) {
        best.bestIndex = i;
        best.longestMatch = candidate.length;
      }
    }
  }

  /// Adds parse and format actions for a mandatory positive/negative sign.
  ///
  /// [signSetter]: Action to take when to set the given sign within the bucket
  /// [nonNegativePredicate]: Predicate to detect whether the value being formatted is non-negative
  void AddRequiredSign(void Function(TBucket, bool) signSetter, bool Function(TResult) nonNegativePredicate) {
    AddParseAction((str, bucket) {
      if (str.Match('-')) {
        signSetter(bucket, false);
        return null;
      }
      if (str.Match('+')) {
        signSetter(bucket, true);
        return null;
      }
      return ParseResult.MissingSign<TResult>(str);
    });
    AddFormatAction((value, sb) => sb.write(nonNegativePredicate(value) ? '+' : '-'));
  }

  /// Adds parse and format actions for an "negative only" sign.
  ///
  /// [signSetter]: Action to take when to set the given sign within the bucket
  /// [nonNegativePredicate]: Predicate to detect whether the value being formatted is non-negative
  void AddNegativeOnlySign(void Function(TBucket, bool) signSetter, bool Function(TResult) nonNegativePredicate) {
    AddParseAction((str, bucket) {
      if (str.Match('-')) {
        signSetter(bucket, false);
        return null;
      }
      if (str.Match('+')) {
        return ParseResult.PositiveSignInvalid<TResult>(str);
      }
      signSetter(bucket, true);
      return null;
    });
    AddFormatAction((value, builder) {
      if (!nonNegativePredicate(value)) {
        builder.write('-');
      }
    });
  }

  /// Adds an action to pad a selected value to a given minimum length.
  ///
  /// [count]: The minimum length to pad to
  /// [selector]: The selector function to apply to obtain a value to format
  /// [assumeNonNegative]: Whether it is safe to assume the value will be non-negative
  /// [assumeFitsInCount]: Whether it is safe to assume the value will not exceed the specified length
  void AddFormatLeftPad(int count, int Function(TResult) selector, bool assumeNonNegative, bool assumeFitsInCount) {
    if (count == 2 && assumeNonNegative && assumeFitsInCount) {
      AddFormatAction((value, sb) => FormatHelper.Format2DigitsNonNegative(selector(value), sb));
    } else if (count == 4 && assumeFitsInCount) {
      AddFormatAction((value, sb) => FormatHelper.Format4DigitsValueFits(selector(value), sb));
    } else if (assumeNonNegative) {
      AddFormatAction((value, sb) => FormatHelper.LeftPadNonNegative(selector(value), count, sb));
    } else {
      AddFormatAction((value, sb) => FormatHelper.LeftPad(selector(value), count, sb));
    }
  }

  void AddFormatFraction(int width, int scale, int Function(TResult) selector) =>
      AddFormatAction((value, sb) => FormatHelper.AppendFraction(selector(value), width, scale, sb));

  void AddFormatFractionTruncate(int width, int scale, int Function(TResult) selector) =>
      AddFormatAction((value, sb) => FormatHelper.AppendFractionTruncate(selector(value), width, scale, sb));

  /// Handles date, time and date/time embedded patterns.
  void AddEmbeddedLocalPartial(
      PatternCursor pattern,
      LocalDatePatternParserLocalDateParseBucket Function(TBucket) dateBucketExtractor,
      LocalTimePatternParserLocalTimeParseBucket Function(TBucket) timeBucketExtractor,
      LocalDate Function(TResult) dateExtractor,
      LocalTime Function(TResult) timeExtractor,
      // null if date/time embedded patterns are invalid
      LocalDateTime Function(TResult)? dateTimeExtractor) {
    // This will be d (date-only), t (time-only), or < (date and time)
    // If it's anything else, we'll see the problem when we try to get the pattern.
    var patternType = pattern.PeekNext();
    if (patternType == 'd' || patternType == 't') {
      pattern.MoveNext();
    }
    String embeddedPatternText = pattern.GetEmbeddedPattern();
    switch (patternType) {
      case '<':
        {
          var sampleBucket = CreateSampleBucket();
          var twoDigitYearMax = dateBucketExtractor(sampleBucket).TwoDigitYearMax;
          var templateTime = timeBucketExtractor(sampleBucket).TemplateValue;
          var templateDate = dateBucketExtractor(sampleBucket).TemplateValue;
          if (dateTimeExtractor == null) {
            throw InvalidPatternException(TextErrorMessages.InvalidEmbeddedPatternType);
          }
          AddField(PatternFields.EmbeddedDate, 'l');
          AddField(PatternFields.EmbeddedTime, 'l');
          AddEmbeddedPattern<LocalDateTime>(
              // (C#: templateDate + templateTime.)
              LocalDateTimePattern.CreateNodaFormatInfo(embeddedPatternText, FormatInfo, templateDate.At(templateTime), twoDigitYearMax)
                  .UnderlyingPattern, (bucket, value) {
            var dateBucket = dateBucketExtractor(bucket);
            var timeBucket = timeBucketExtractor(bucket);
            dateBucket.Calendar = value.Calendar;
            dateBucket.Year = value.Year;
            dateBucket.MonthOfYearNumeric = value.Month;
            dateBucket.DayOfMonth = value.Day;
            timeBucket.Hours24 = value.Hour;
            timeBucket.Minutes = value.Minute;
            timeBucket.Seconds = value.Second;
            timeBucket.FractionalSeconds = value.NanosecondOfSecond;
          }, dateTimeExtractor);
          break;
        }
      case 'd':
        AddEmbeddedDatePattern('l', embeddedPatternText, dateBucketExtractor, dateExtractor);
        break;
      case 't':
        AddEmbeddedTimePattern('l', embeddedPatternText, timeBucketExtractor, timeExtractor);
        break;
      default:
        throw StateError("Bug in Noda Time: embedded pattern type wasn't date, time, or date+time");
    }
  }

  void AddEmbeddedDatePattern(
      String characterInPattern,
      String embeddedPatternText,
      LocalDatePatternParserLocalDateParseBucket Function(TBucket) dateBucketExtractor,
      LocalDate Function(TResult) dateExtractor) {
    var templateDate = dateBucketExtractor(CreateSampleBucket()).TemplateValue;
    AddField(PatternFields.EmbeddedDate, characterInPattern);
    AddEmbeddedPattern<LocalDate>(
        LocalDatePattern.CreateNodaFormatInfo(embeddedPatternText, FormatInfo, templateDate, LocalDatePattern.DefaultTwoDigitYearMax)
            .UnderlyingPattern, (bucket, value) {
      var dateBucket = dateBucketExtractor(bucket);
      dateBucket.Calendar = value.Calendar;
      dateBucket.Year = value.Year;
      dateBucket.MonthOfYearNumeric = value.Month;
      dateBucket.DayOfMonth = value.Day;
    }, dateExtractor);
  }

  void AddEmbeddedTimePattern(
      String characterInPattern,
      String embeddedPatternText,
      LocalTimePatternParserLocalTimeParseBucket Function(TBucket) timeBucketExtractor,
      LocalTime Function(TResult) timeExtractor) {
    var templateTime = timeBucketExtractor(CreateSampleBucket()).TemplateValue;
    AddField(PatternFields.EmbeddedTime, characterInPattern);
    AddEmbeddedPattern<LocalTime>(
        LocalTimePattern.CreateNodaFormatInfo(embeddedPatternText, FormatInfo, templateTime).UnderlyingPattern, (bucket, value) {
      var timeBucket = timeBucketExtractor(bucket);
      timeBucket.Hours24 = value.Hour;
      timeBucket.Minutes = value.Minute;
      timeBucket.Seconds = value.Second;
      timeBucket.FractionalSeconds = value.NanosecondOfSecond;
    }, timeExtractor);
  }

  /// Adds parsing/formatting of an embedded pattern, e.g. an offset within a ZonedDateTime/OffsetDateTime.
  void AddEmbeddedPattern<TEmbedded>(IPartialPattern<TEmbedded> embeddedPattern,
      void Function(TBucket, TEmbedded) parseAction, TEmbedded Function(TResult) valueExtractor) {
    AddParseAction((value, bucket) {
      var result = embeddedPattern.ParsePartial(value);
      if (!result.Success) {
        return result.ConvertError<TResult>();
      }
      parseAction(bucket, result.Value);
      return null;
    });
    AddFormatAction((value, sb) => embeddedPattern.AppendFormat(valueExtractor(value), sb));
  }
}

/// Hack to handle genitive month names - we only know what we need to do *after* we've parsed the whole pattern.
///
/// (C#: `SteppedPatternBuilder<TResult, TBucket>.IPostPatternParseFormatAction`.)
@internal
abstract interface class SteppedPatternBuilderIPostPatternParseFormatAction<TResult> {
  SteppedPatternBuilderFormatAction<TResult> BuildFormatAction(PatternFields finalFields);
}

/// noda_dart: the C# `ref int bestIndex, ref int longestMatch` parameters of FindLongestMatch.
final class _LongestMatch {
  int bestIndex = -1;
  int longestMatch = 0;
}

final class _SteppedPattern<TResult, TBucket extends ParseBucket<TResult>> implements IPartialPattern<TResult> {
  final List<SteppedPatternBuilderFormatAction<TResult>> _formatActions;
  // This will be null if the pattern is only capable of formatting.
  final List<SteppedPatternBuilderParseAction<TResult, TBucket>>? _parseActions;
  final TBucket Function() _bucketProvider;
  final PatternFields _usedFields;
  // ignore: unused_field
  late final int _expectedLength;

  _SteppedPattern(List<SteppedPatternBuilderFormatAction<TResult>> formatActions,
      List<SteppedPatternBuilderParseAction<TResult, TBucket>>? parseActions, TBucket Function() bucketProvider,
      PatternFields usedFields, TResult sample)
      : _formatActions = formatActions,
        _parseActions = parseActions,
        _bucketProvider = bucketProvider,
        _usedFields = usedFields {
    // Format the sample value to work out the expected length, so we
    // can use that when creating a StringBuilder. This will definitely not always
    // be appropriate, but it's a start.
    // (noda_dart: the length is unused, but formatting the sample can throw, as in C#.)
    StringBuffer builder = StringBuffer();
    _FormatActions(sample, builder);
    _expectedLength = builder.length;
  }

  // noda_dart: invokes the "multicast delegate".
  void _FormatActions(TResult value, StringBuffer builder) {
    for (final action in _formatActions) {
      action(value, builder);
    }
  }

  @override
  ParseResult<TResult> Parse(String text) {
    if (_parseActions == null) {
      return ParseResult.FormatOnlyPattern<TResult>(ValueCursor.NewValue(text));
    }
    // Dart: null safety checks text (C#: ParseResult<TResult>.ArgumentNull(nameof(text)) for null).
    if (text.isEmpty) {
      return ParseResult.ValueStringEmpty<TResult>();
    }

    var valueCursor = ValueCursor.NewValue(text);
    // Prime the pump... the value cursor ends up *before* the first character, but
    // our steps always assume it's *on* the right character.
    valueCursor.MoveNext();
    var result = ParsePartial(valueCursor);
    if (!result.Success) {
      return result;
    }
    // Check that we've used up all the text
    if (valueCursor.Current != TextCursor.Nul) {
      return ParseResult.ExtraValueCharacters<TResult>(valueCursor, valueCursor.Remainder);
    }
    return result;
  }

  @override
  String Format(TResult value) {
    StringBuffer builder = StringBuffer();
    // This will call all the actions in the multicast delegate.
    _FormatActions(value, builder);
    return builder.toString();
  }

  @override
  ParseResult<TResult> ParsePartial(ValueCursor cursor) {
    // At the moment we shouldn't get a partial parse for a format-only pattern, but
    // let's guard against it for the future.
    final parseActions = _parseActions;
    if (parseActions == null) {
      return ParseResult.FormatOnlyPattern<TResult>(cursor);
    }

    TBucket bucket = _bucketProvider();

    for (var action in parseActions) {
      ParseResult<TResult>? failure = action(cursor, bucket);
      if (failure != null) {
        return failure;
      }
    }
    return bucket.CalculateValue(_usedFields, cursor.Value);
  }

  @override
  StringBuffer AppendFormat(TResult value, StringBuffer builder) {
    // Dart: null safety checks builder.
    _FormatActions(value, builder);
    return builder;
  }
}
