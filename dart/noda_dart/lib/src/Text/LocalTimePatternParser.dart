// Ported from NodaTime 6e024dde: src/NodaTime/Text/LocalTimePatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaFormatInfo.dart';
import '../LocalTime.dart';
import 'Delegates.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'LocalTimePattern.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'Patterns/TimePatternHelper.dart';
import 'TextErrorMessages.generated.dart';

/// Pattern parser for [LocalTime] values.
@internal
final class LocalTimePatternParser implements IPatternParser<LocalTime> {
  final LocalTime _templateValue;

  static final Map<String, CharacterHandler<LocalTime, LocalTimePatternParserLocalTimeParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<LocalTime, LocalTimePatternParserLocalTimeParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    '.': TimePatternHelper.CreatePeriodHandler<LocalTime, LocalTimePatternParserLocalTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.FractionalSeconds = value),
    ';': TimePatternHelper.CreateCommaDotHandler<LocalTime, LocalTimePatternParserLocalTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.FractionalSeconds = value),
    ':': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch<LocalTime>),
    'h': SteppedPatternBuilder.HandlePaddedField<LocalTime, LocalTimePatternParserLocalTimeParseBucket>
        (2, PatternFields.Hours12, 1, 12, (value) => value.ClockHourOfHalfDay, (bucket, value) => bucket.Hours12 = value),
    'H': SteppedPatternBuilder.HandlePaddedField<LocalTime, LocalTimePatternParserLocalTimeParseBucket>
        (2, PatternFields.Hours24, 0, 23, (value) => value.Hour, (bucket, value) => bucket.Hours24 = value),
    'm': SteppedPatternBuilder.HandlePaddedField<LocalTime, LocalTimePatternParserLocalTimeParseBucket>
        (2, PatternFields.Minutes, 0, 59, (value) => value.Minute, (bucket, value) => bucket.Minutes = value),
    's': SteppedPatternBuilder.HandlePaddedField<LocalTime, LocalTimePatternParserLocalTimeParseBucket>
        (2, PatternFields.Seconds, 0, 59, (value) => value.Second, (bucket, value) => bucket.Seconds = value),
    'f': TimePatternHelper.CreateFractionHandler<LocalTime, LocalTimePatternParserLocalTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.FractionalSeconds = value),
    'F': TimePatternHelper.CreateFractionHandler<LocalTime, LocalTimePatternParserLocalTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.FractionalSeconds = value),
    't': TimePatternHelper.CreateAmPmHandler<LocalTime, LocalTimePatternParserLocalTimeParseBucket>((time) => time.Hour, (bucket, value) => bucket.AmPm = value)
  };

  // Dart: a public constructor in C# (of an internal class), so the unnamed constructor.
  LocalTimePatternParser(LocalTime templateValue) : _templateValue = templateValue;

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<LocalTime> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Dart: a local function must be declared before it's used.
    IPattern<LocalTime> ParseNoStandardExpansion(String patternTextLocal) {
      var patternBuilder = SteppedPatternBuilder<LocalTime, LocalTimePatternParserLocalTimeParseBucket>.NewFormatInfoBucketProvider(formatInfo,
          () => LocalTimePatternParserLocalTimeParseBucket.NewTemplateValue(_templateValue));
      patternBuilder.ParseCustomPattern(patternTextLocal, _PatternCharacterHandlers);
      patternBuilder.ValidateUsedFields();
      return patternBuilder.Build(_templateValue);
    }

    // Nullity check is performed in LocalTimePattern.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length == 1) {
      return switch (patternText[0]) {
        // Invariant standard patterns return cached implementations.
        'o' => LocalTimePatternPatterns.ExtendedIsoPatternImpl,
        'O' => LocalTimePatternPatterns.LongExtendedIsoPatternImpl,
        // Other standard patterns expand the pattern text to the appropriate custom pattern.
        // Note: we don't just recurse, as otherwise a ShortTimePattern of 't' (for example) would cause a stack overflow.
        't' => ParseNoStandardExpansion(formatInfo.DateTimeFormat.ShortTimePattern),
        'T' => ParseNoStandardExpansion(formatInfo.DateTimeFormat.LongTimePattern),
        'r' => ParseNoStandardExpansion("HH:mm:ss.FFFFFFFFF"),
        // Unknown standard patterns fail.
        _ => throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(LocalTime)])
      };
    }
    return ParseNoStandardExpansion(patternText);
  }
}

// Dart: LocalTimeParseBucket's private consts; final, as `|` and `^` on PatternFields aren't const.
final PatternFields _Hour24MinuteSecond = PatternFields.Hours24 | PatternFields.Minutes | PatternFields.Seconds;
final PatternFields _AllTimeFieldsExceptFractionalSeconds =
    PatternFields(PatternFields.AllTimeFields.value ^ PatternFields.FractionalSeconds.value);

/// Bucket to put parsed values in, ready for later result calculation. This type is also used
/// by LocalDateTimePattern to store and calculate values.
@internal
final class LocalTimePatternParserLocalTimeParseBucket extends ParseBucket<LocalTime> {
  final LocalTime TemplateValue;

  /// The fractions of a second in nanoseconds, in the range [0, 999999999]
  int FractionalSeconds;

  /// The hours in the range [0, 23].
  int Hours24 = 0;

  /// The hours in the range [1, 12].
  int Hours12 = 0;

  /// The minutes in the range [0, 59].
  int Minutes;

  /// The seconds in the range [0, 59].
  int Seconds;

  /// AM (0) or PM (1) - or "take from the template" (2). The latter is used in situations
  /// where we're parsing but there is no AM or PM designator.
  int AmPm = 0;

  LocalTimePatternParserLocalTimeParseBucket.NewTemplateValue(LocalTime templateValue)
      : TemplateValue = templateValue,
        // By copying these out of the template value now, we don't have to use any conditional
        // logic later on.
        Minutes = templateValue.Minute,
        Seconds = templateValue.Second,
        FractionalSeconds = templateValue.NanosecondOfSecond;

  /// Calculates the value from the parsed pieces.
  ///
  /// (Dart: C#'s two CalculateValue overloads.)
  @override
  ParseResult<LocalTime> CalculateValue(PatternFields usedFields, String text, [Type eventualResultType = LocalTime]) {
    // Optimize common situation for ISO values.
    if ((usedFields & _AllTimeFieldsExceptFractionalSeconds) == _Hour24MinuteSecond) {
      return ParseResult.ForValue<LocalTime>(LocalTime.FromHourMinuteSecondNanosecondTrusted(Hours24, Minutes, Seconds, FractionalSeconds));
    }

    // If this bucket was created from an embedded pattern, it's already been computed.
    if (usedFields.HasAny(PatternFields.EmbeddedTime)) {
      return ParseResult.ForValue<LocalTime>(LocalTime.FromHourMinuteSecondNanosecondTrusted(Hours24, Minutes, Seconds, FractionalSeconds));
    }

    if (AmPm == 2) {
      AmPm = TemplateValue.Hour ~/ 12;
    }
    final (ParseResult<LocalTime>? failure, int hour) = _DetermineHour(usedFields, text, eventualResultType);
    if (failure != null) {
      return failure;
    }
    return ParseResult.ForValue<LocalTime>(LocalTime.FromHourMinuteSecondNanosecondTrusted(hour, Minutes, Seconds, FractionalSeconds));
  }

  // Dart: C#'s `out int hour` is the second element of the returned record.
  (ParseResult<LocalTime>?, int) _DetermineHour(PatternFields usedFields, String text, Type eventualResultType) {
    int hour = 0;
    if (usedFields.HasAny(PatternFields.Hours24)) {
      if (usedFields.HasAll(PatternFields.Hours12 | PatternFields.Hours24)) {
        if (Hours12.remainder(12) != Hours24.remainder(12)) {
          return (ParseResult.InconsistentValues<LocalTime>(text, 'H', 'h', eventualResultType), hour);
        }
      }
      if (usedFields.HasAny(PatternFields.AmPm)) {
        if (Hours24 ~/ 12 != AmPm) {
          return (ParseResult.InconsistentValues<LocalTime>(text, 'H', 't', eventualResultType), hour);
        }
      }
      hour = Hours24;
      return (null, hour);
    }
    // Okay, it's definitely valid - but we've still got 8 possibilities for what's been specified.
    // Dart: a C# switch on combined flags isn't a constant pattern in Dart, so this is an if/else chain.
    final hourFields = usedFields & (PatternFields.Hours12 | PatternFields.AmPm);
    if (hourFields == (PatternFields.Hours12 | PatternFields.AmPm)) {
      hour = (Hours12.remainder(12)) + AmPm * 12;
    } else if (hourFields == PatternFields.Hours12) {
      // Preserve AM/PM from template value
      hour = (Hours12.remainder(12)) + (TemplateValue.Hour ~/ 12) * 12;
    } else if (hourFields == PatternFields.AmPm) {
      // Preserve 12-hour hour of day from template value, use specified AM/PM
      hour = (TemplateValue.Hour.remainder(12)) + AmPm * 12;
    } else if (hourFields == PatternFields.None) {
      hour = TemplateValue.Hour;
    }
    return (null, hour);
  }
}
