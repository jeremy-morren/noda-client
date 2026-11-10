// Ported from NodaTime 6e024dde: src/NodaTime/Text/DurationPatternParser.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Duration.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../NodaConstants.generated.dart';
import 'Delegates.dart';
import 'DurationPattern.dart';
import 'FormatHelper.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternCursor.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'Patterns/TimePatternHelper.dart';
import 'TextErrorMessages.generated.dart';

@internal
final class DurationPatternParser implements IPatternParser<Duration> {
  static final Map<String, CharacterHandler<Duration, _DurationPatternParserDurationParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<Duration, _DurationPatternParserDurationParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    '.': TimePatternHelper.CreatePeriodHandler<Duration, _DurationPatternParserDurationParseBucket>(9, _GetPositiveNanosecondOfSecond, (bucket, value) => bucket.AddNanoseconds(value)),
    ':': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch<Duration>),
    'D': _CreateDayHandler(),
    'H': _CreateTotalHandler(PatternFields.Hours24, NanosecondsPerHour, HoursPerDay, 402653184),
    'h': _CreatePartialHandler(PatternFields.Hours24, NanosecondsPerHour, HoursPerDay),
    'M': _CreateTotalHandler(PatternFields.Minutes, NanosecondsPerMinute, MinutesPerDay, 24159191040),
    'm': _CreatePartialHandler(PatternFields.Minutes, NanosecondsPerMinute, MinutesPerHour),
    'S': _CreateTotalHandler(PatternFields.Seconds, NanosecondsPerSecond, SecondsPerDay, 1449551462400),
    's': _CreatePartialHandler(PatternFields.Seconds, NanosecondsPerSecond, SecondsPerMinute),
    'f': TimePatternHelper.CreateFractionHandler<Duration, _DurationPatternParserDurationParseBucket>(9, _GetPositiveNanosecondOfSecond, (bucket, value) => bucket.AddNanoseconds(value)),
    'F': TimePatternHelper.CreateFractionHandler<Duration, _DurationPatternParserDurationParseBucket>(9, _GetPositiveNanosecondOfSecond, (bucket, value) => bucket.AddNanoseconds(value)),
    '+': _HandlePlus,
    '-': _HandleMinus,
  };

  // Dart: no declared constructor in C#, so the default (unnamed) one is used: `DurationPatternParser()`.

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<Duration> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Dart: null safety checks patternText.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length == 1) {
      return switch (patternText[0]) {
        'o' => DurationPatternPatterns.RoundtripPatternImpl,
        'j' => DurationPatternPatterns.JsonRoundtripPatternImpl,
        _ => throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(Duration)])
      };
    }

    var patternBuilder = SteppedPatternBuilder<Duration, _DurationPatternParserDurationParseBucket>.NewFormatInfoBucketProvider(formatInfo,
        () => _DurationPatternParserDurationParseBucket());
    patternBuilder.ParseCustomPattern(patternText, _PatternCharacterHandlers);
    // Somewhat random sample, admittedly...
    return patternBuilder.Build(Duration.FromHours(1) + Duration.FromMinutes(30) + Duration.FromSeconds(5) + Duration.FromMilliseconds(500));
  }

  static int _GetPositiveNanosecondOfSecond(Duration duration) {
    return duration.NanosecondOfDay.abs().remainder(NanosecondsPerSecond);
  }

  static CharacterHandler<Duration, _DurationPatternParserDurationParseBucket> _CreateTotalHandler
      (PatternFields field, int nanosecondsPerUnit, int unitsPerDay, int maxValue) {
    return (pattern, builder) {
      // Needs to be big enough for 1449551462400 seconds
      int count = pattern.GetRepeatCount(13);
      // AddField would throw an inappropriate exception here, so handle it specially.
      if ((builder.UsedFields & PatternFields.TotalDuration) != PatternFields.None) {
        throw InvalidPatternException(TextErrorMessages.MultipleCapitalDurationFields);
      }
      builder.AddField(field, pattern.Current);
      builder.AddField(PatternFields.TotalDuration, pattern.Current);
      builder.AddParseInt64ValueAction(count, 13, pattern.Current, 0, maxValue, (bucket, value) => bucket.AddUnits(value, nanosecondsPerUnit));
      builder.AddFormatAction((value, sb) => FormatHelper.LeftPadNonNegativeInt64(_GetPositiveNanosecondUnits(value, nanosecondsPerUnit, unitsPerDay), count, sb));
    };
  }

  static CharacterHandler<Duration, _DurationPatternParserDurationParseBucket> _CreateDayHandler() {
    return (pattern, builder) {
      int count = pattern.GetRepeatCount(8); // Enough for 16777216
      // AddField would throw an inappropriate exception here, so handle it specially.
      if ((builder.UsedFields & PatternFields.TotalDuration) != PatternFields.None) {
        throw InvalidPatternException(TextErrorMessages.MultipleCapitalDurationFields);
      }
      builder.AddField(PatternFields.DayOfMonth, pattern.Current);
      builder.AddField(PatternFields.TotalDuration, pattern.Current);
      builder.AddParseValueAction(count, 8, pattern.Current, 0, 16777216, (bucket, value) => bucket.AddDays(value));
      builder.AddFormatLeftPad(count, (duration) {
        int days = duration.FloorDays;
        if (days >= 0) {
          return days;
        }
        // Round towards 0.
        return duration.NanosecondOfFloorDay == 0 ? -days : -(days + 1);
      },
          /* assumeNonNegative: */ true,
          /* assumeFitsInCount: */ false);
    };
  }

  static CharacterHandler<Duration, _DurationPatternParserDurationParseBucket> _CreatePartialHandler
      (PatternFields field, int nanosecondsPerUnit, int unitsPerContainer) {
    return (pattern, builder) {
      int count = pattern.GetRepeatCount(2);
      builder.AddField(field, pattern.Current);
      builder.AddParseValueAction(count, 2, pattern.Current, 0, unitsPerContainer - 1,
          (bucket, value) => bucket.AddUnits(value, nanosecondsPerUnit));
      // This is never used for anything larger than a day, so the day part is irrelevant.
      builder.AddFormatLeftPad(count,
          (duration) => ((duration.NanosecondOfDay.abs() ~/ nanosecondsPerUnit)).remainder(unitsPerContainer),
          /* assumeNonNegative: */ true,
          /* assumeFitsInCount: */ count == 2);
    };
  }

  static void _HandlePlus(PatternCursor pattern, SteppedPatternBuilder<Duration, _DurationPatternParserDurationParseBucket> builder) {
    builder.AddField(PatternFields.Sign, pattern.Current);
    builder.AddRequiredSign((bucket, positive) => bucket.IsNegative = !positive, (duration) => duration.FloorDays >= 0);
  }

  static void _HandleMinus(PatternCursor pattern, SteppedPatternBuilder<Duration, _DurationPatternParserDurationParseBucket> builder) {
    builder.AddField(PatternFields.Sign, pattern.Current);
    builder.AddNegativeOnlySign((bucket, positive) => bucket.IsNegative = !positive, (duration) => duration.FloorDays >= 0);
  }

  static int _GetPositiveNanosecondUnits(Duration duration, int nanosecondsPerUnit, int unitsPerDay) {
    // The property is declared as an int, but we it as a long to force 64-bit arithmetic when multiplying.
    int floorDays = duration.FloorDays;
    if (floorDays >= 0) {
      return floorDays * unitsPerDay + duration.NanosecondOfFloorDay ~/ nanosecondsPerUnit;
    } else {
      int nanosecondOfDay = duration.NanosecondOfDay;
      // If it's not an exact number of days, FloorDays will overshoot (negatively) by 1.
      int negativeValue = nanosecondOfDay == 0
          ? floorDays * unitsPerDay
          : (floorDays + 1) * unitsPerDay + nanosecondOfDay ~/ nanosecondsPerUnit;
      return -negativeValue;
    }
  }
}

/// Provides a container for the interim parsed pieces of an [Offset] value.
// [DebuggerStepThrough]
final class _DurationPatternParserDurationParseBucket extends ParseBucket<Duration> {
  static final BigInt _BigIntegerNanosecondsPerDay = BigInt.from(NanosecondsPerDay);

  // Note: While we *could* try to optimize this to not use BigInteger, this approach is really simple.
  bool IsNegative = false;
  BigInt _currentNanos = BigInt.zero;

  void AddNanoseconds(int nanoseconds) {
    _currentNanos += BigInt.from(nanoseconds);
  }

  void AddDays(int days) {
    _currentNanos += BigInt.from(days) * _BigIntegerNanosecondsPerDay;
  }

  // Dart: C# converts nanosecondsPerUnit (a long) to a BigInteger implicitly; here the conversion is explicit.
  void AddUnits(int units, int nanosecondsPerUnit) {
    _currentNanos += BigInt.from(units) * BigInt.from(nanosecondsPerUnit);
  }

  /// Calculates the value from the parsed pieces.
  @override
  ParseResult<Duration> CalculateValue(PatternFields usedFields, String text) {
    if (IsNegative) {
      _currentNanos = -_currentNanos;
    }
    if (_currentNanos < Duration.MinNanoseconds || _currentNanos > Duration.MaxNanoseconds) {
      return ParseResult.ForInvalidValuePostParse<Duration>(text, TextErrorMessages.OverallValueOutOfRange,
          [ParseResult.TypeName(Duration)]);
    }
    return ParseResult.ForValue<Duration>(Duration.FromNanosecondsBigInteger(_currentNanos));
  }
}
