// Ported from NodaTime 6e024dde: src/NodaTime/Text/PeriodPattern.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import '../NodaConstants.generated.dart';
import '../Period.dart';
import '../PeriodBuilder.dart';
import '../PeriodUnits.generated.dart';
import '../Utility/Int64.dart';
import 'FormatHelper.dart';
import 'IPattern.dart';
import 'ParseResult.dart';
import 'TextErrorMessages.generated.dart';
import 'ValueCursor.dart';

/// Represents a pattern for parsing and formatting [Period] values.
///
/// Thread safety: This type is immutable reference type. See the thread safety section of the user guide for more information.
// [Immutable]
final class PeriodPattern implements IPattern<Period> {
  /// Pattern which uses the normal ISO format for all the supported ISO
  /// fields, but extends the time part with "s" for milliseconds, "t" for ticks and "n" for nanoseconds.
  /// No normalization is carried out, and a period may contain weeks as well as years, months and days.
  /// Each element may also be negative, independently of other elements. This pattern round-trips its
  /// values: a parse/format cycle will produce an identical period, including units.
  ///
  /// Returns pattern which uses the normal ISO format for all the supported ISO
  /// fields, but extends the time part with "s" for milliseconds, "t" for ticks and "n" for nanoseconds.
  static final PeriodPattern Roundtrip = PeriodPattern._NewPattern(_PeriodPatternRoundtripPatternImpl());

  /// A "normalizing" pattern which abides by the ISO-8601 duration format as far as possible.
  /// Weeks are added to the number of days (after multiplying by 7). Time units are normalized
  /// (extending into days where necessary), and fractions of seconds are represented within the
  /// seconds part. Unlike ISO-8601, which pattern allows for negative values within a period.
  ///
  /// Note that normalizing the period when formatting will cause an [OverflowException]
  /// if the period contains more than [Int64.MaxValue] nanoseconds when the
  /// combined weeks/days/time portions are considered.
  ///
  /// Normalization is performed on formatting, but not on parsing. Any value emitted by formatting should
  /// round-trip, but non-normal values (e.g. "PT25H") will not.
  ///
  /// Returns a "normalizing" pattern which abides by the ISO-8601 duration format as far as possible.
  static final PeriodPattern NormalizingIso = PeriodPattern._NewPattern(_PeriodPatternNormalizingIsoPatternImpl());

  final IPattern<Period> _pattern;

  PeriodPattern._NewPattern(IPattern<Period> pattern)
      // Dart: null safety checks pattern.
      : _pattern = pattern;

  /// Parses the given text value according to the rules of this pattern.
  ///
  /// This method never throws an exception (barring a bug in Noda Time itself). Even errors such as
  /// the argument being null are wrapped in a parse result.
  ///
  /// [text]: The text value to parse.
  ///
  /// Returns the result of parsing, which may be successful or unsuccessful.
  @override
  ParseResult<Period> Parse(String text) => _pattern.Parse(text);

  /// Formats the given period as text according to the rules of this pattern.
  ///
  /// [value]: The period to format.
  ///
  /// Returns the period formatted according to this pattern.
  @override
  String Format(Period value) => _pattern.Format(value);

  /// Formats the given value as text according to the rules of this pattern,
  /// appending to the given [StringBuffer].
  ///
  /// [value]: The value to format.
  /// [builder]: The `StringBuffer` to append to.
  ///
  /// Returns the builder passed in as [builder].
  @override
  StringBuffer AppendFormat(Period value, StringBuffer builder) => _pattern.AppendFormat(value, builder);

  static void _AppendValue(StringBuffer builder, int value, String suffix) {
    // Avoid having a load of conditions in the calling code by checking here
    if (value == 0) {
      return;
    }
    FormatHelper.FormatInvariant(value, builder);
    builder.write(suffix);
  }

  static ParseResult<Period> _InvalidUnit(ValueCursor cursor, String unitCharacter) => ParseResult.ForInvalidValue<Period>(cursor, TextErrorMessages.InvalidUnitSpecifier, [unitCharacter]);

  static ParseResult<Period> _RepeatedUnit(ValueCursor cursor, String unitCharacter) => ParseResult.ForInvalidValue<Period>(cursor, TextErrorMessages.RepeatedUnitSpecifier, [unitCharacter]);

  static ParseResult<Period> _MisplacedUnit(ValueCursor cursor, String unitCharacter) => ParseResult.ForInvalidValue<Period>(cursor, TextErrorMessages.MisplacedUnitSpecifier, [unitCharacter]);
}

final class _PeriodPatternRoundtripPatternImpl implements IPattern<Period> {
  @override
  ParseResult<Period> Parse(String text) {
    // Dart: null safety checks text (C#: if (text is null) return ParseResult<Period>.ArgumentNull(nameof(text));).
    if (text.isEmpty) {
      return ParseResult.ValueStringEmpty<Period>();
    }

    ValueCursor valueCursor = ValueCursor.NewValue(text);

    valueCursor.MoveNext();
    if (valueCursor.Current != 'P') {
      return ParseResult.MismatchedCharacter<Period>(valueCursor, 'P');
    }
    bool inDate = true;
    PeriodBuilder builder = PeriodBuilder();
    PeriodUnits unitsSoFar = PeriodUnits.None;
    while (valueCursor.MoveNext()) {
      if (inDate && valueCursor.Current == 'T') {
        inDate = false;
        continue;
      }
      final (failure, unitValue) = valueCursor.ParseInt64<Period>();
      if (failure != null) {
        return failure;
      }
      if (valueCursor.Length == valueCursor.Index) {
        return ParseResult.EndOfString<Period>(valueCursor);
      }
      // Various failure cases:
      // - Repeated unit (e.g. P1M2M)
      // - Time unit is in date part (e.g. P5M)
      // - Date unit is in time part (e.g. PT1D)
      // - Unit is in incorrect order (e.g. P5D1Y)
      // - Unit is invalid (e.g. P5J)
      // - Unit is missing (e.g. P5)
      PeriodUnits unit;
      switch (valueCursor.Current) {
        case 'Y': unit = PeriodUnits.Years; break;
        case 'M': unit = inDate ? PeriodUnits.Months : PeriodUnits.Minutes; break;
        case 'W': unit = PeriodUnits.Weeks; break;
        case 'D': unit = PeriodUnits.Days; break;
        case 'H': unit = PeriodUnits.Hours; break;
        case 'S': unit = PeriodUnits.Seconds; break;
        case 's': unit = PeriodUnits.Milliseconds; break;
        case 't': unit = PeriodUnits.Ticks; break;
        case 'n': unit = PeriodUnits.Nanoseconds; break;
        default: return PeriodPattern._InvalidUnit(valueCursor, valueCursor.Current);
      }
      if ((unit & unitsSoFar) != PeriodUnits.None) {
        return PeriodPattern._RepeatedUnit(valueCursor, valueCursor.Current);
      }

      // This handles putting months before years, for example. Less significant units
      // have higher integer representations.
      if (unit.value < unitsSoFar.value) {
        return PeriodPattern._MisplacedUnit(valueCursor, valueCursor.Current);
      }
      // The result of checking "there aren't any time units in this unit" should be
      // equal to "we're still in the date part".
      if (((unit & PeriodUnits.AllTimeUnits) == PeriodUnits.None) != inDate) {
        return PeriodPattern._MisplacedUnit(valueCursor, valueCursor.Current);
      }

      // Date units are limited to 32-bit values.
      if (inDate && (unitValue < Int64.Int32MinValue || unitValue > Int64.Int32MaxValue)) {
        return ParseResult.ValueOutOfRange<Period>(valueCursor, unitValue);
      }

      builder[unit] = unitValue;
      unitsSoFar |= unit;
    }
    return ParseResult.ForValue<Period>(builder.Build());
  }

  @override
  String Format(Period value) => AppendFormat(value, StringBuffer()).toString();

  @override
  StringBuffer AppendFormat(Period value, StringBuffer builder) {
    // Dart: null safety checks value and builder.
    // Always ensure we've got *some* unit to ensure the result is valid in ISO-8601; arbitrarily pick days.
    // Note: "P0S" might be nicer here, but NormalizingIsoPatternImpl picked "P0D" a
    // long time ago and we want to be consistent between the two.
    // We might want to make both pattern implementations configurable at some point.
    if (value.Equals(Period.Zero)) {
      builder.write("P0D");
      return builder;
    }
    builder.write('P');
    PeriodPattern._AppendValue(builder, value.Years, 'Y');
    PeriodPattern._AppendValue(builder, value.Months, 'M');
    PeriodPattern._AppendValue(builder, value.Weeks, 'W');
    PeriodPattern._AppendValue(builder, value.Days, 'D');
    if (value.HasTimeComponent) {
      builder.write('T');
      PeriodPattern._AppendValue(builder, value.Hours, 'H');
      PeriodPattern._AppendValue(builder, value.Minutes, 'M');
      PeriodPattern._AppendValue(builder, value.Seconds, 'S');
      PeriodPattern._AppendValue(builder, value.Milliseconds, 's');
      PeriodPattern._AppendValue(builder, value.Ticks, 't');
      PeriodPattern._AppendValue(builder, value.Nanoseconds, 'n');
    }
    return builder;
  }
}

final class _PeriodPatternNormalizingIsoPatternImpl implements IPattern<Period> {
  // TODO(misc): Tidy this up a *lot*.
  @override
  ParseResult<Period> Parse(String text) {
    // Dart: null safety checks text (C#: if (text is null) return ParseResult<Period>.ArgumentNull(nameof(text));).
    if (text.isEmpty) {
      return ParseResult.ValueStringEmpty<Period>();
    }

    ValueCursor valueCursor = ValueCursor.NewValue(text);

    valueCursor.MoveNext();
    if (valueCursor.Current != 'P') {
      return ParseResult.MismatchedCharacter<Period>(valueCursor, 'P');
    }
    bool inDate = true;
    PeriodBuilder builder = PeriodBuilder();
    PeriodUnits unitsSoFar = PeriodUnits.None;
    while (valueCursor.MoveNext()) {
      if (inDate && valueCursor.Current == 'T') {
        inDate = false;
        continue;
      }
      bool negative = valueCursor.Current == '-';
      final (failure, unitValue) = valueCursor.ParseInt64<Period>();
      if (failure != null) {
        return failure;
      }
      if (valueCursor.Length == valueCursor.Index) {
        return ParseResult.EndOfString<Period>(valueCursor);
      }
      // Various failure cases:
      // - Repeated unit (e.g. P1M2M)
      // - Time unit is in date part (e.g. P5M)
      // - Date unit is in time part (e.g. PT1D)
      // - Unit is in incorrect order (e.g. P5D1Y)
      // - Unit is invalid (e.g. P5J)
      // - Unit is missing (e.g. P5)
      PeriodUnits unit;
      switch (valueCursor.Current) {
        case 'Y': unit = PeriodUnits.Years; break;
        case 'M': unit = inDate ? PeriodUnits.Months : PeriodUnits.Minutes; break;
        case 'W': unit = PeriodUnits.Weeks; break;
        case 'D': unit = PeriodUnits.Days; break;
        case 'H': unit = PeriodUnits.Hours; break;
        case 'S': unit = PeriodUnits.Seconds; break;
        case ',':
        case '.': unit = PeriodUnits.Nanoseconds; break; // Special handling below
        default: return PeriodPattern._InvalidUnit(valueCursor, valueCursor.Current);
      }
      if ((unit & unitsSoFar) != PeriodUnits.None) {
        return PeriodPattern._RepeatedUnit(valueCursor, valueCursor.Current);
      }

      // This handles putting months before years, for example. Less significant units
      // have higher integer representations.
      if (unit.value < unitsSoFar.value) {
        return PeriodPattern._MisplacedUnit(valueCursor, valueCursor.Current);
      }

      // The result of checking "there aren't any time units in this unit" should be
      // equal to "we're still in the date part".
      if (((unit & PeriodUnits.AllTimeUnits) == PeriodUnits.None) != inDate) {
        return PeriodPattern._MisplacedUnit(valueCursor, valueCursor.Current);
      }

      // Date units are limited to 32-bit values.
      if (inDate && (unitValue < Int64.Int32MinValue || unitValue > Int64.Int32MaxValue)) {
        return ParseResult.ValueOutOfRange<Period>(valueCursor, unitValue);
      }

      // Seen a . or , which need special handling.
      if (unit == PeriodUnits.Nanoseconds) {
        // Check for already having seen seconds, e.g. PT5S0.5
        if ((unitsSoFar & PeriodUnits.Seconds) != PeriodUnits.None) {
          return PeriodPattern._MisplacedUnit(valueCursor, valueCursor.Current);
        }
        builder.Seconds = unitValue;

        if (!valueCursor.MoveNext()) {
          return ParseResult.MissingNumber<Period>(valueCursor);
        }
        // Can cope with at most 999999999 nanoseconds
        var (parsed, totalNanoseconds) = valueCursor.ParseFraction(9, 9, 1);
        if (!parsed) {
          return ParseResult.MissingNumber<Period>(valueCursor);
        }
        // Use whether or not the seconds value was negative (even if 0)
        // as the indication of whether this value is negative.
        if (negative) {
          totalNanoseconds = -totalNanoseconds;
        }
        builder.Milliseconds = (totalNanoseconds ~/ NanosecondsPerMillisecond).remainder(MillisecondsPerSecond);
        builder.Ticks = (totalNanoseconds ~/ NanosecondsPerTick).remainder(TicksPerMillisecond);
        builder.Nanoseconds = totalNanoseconds.remainder(NanosecondsPerTick);

        if (valueCursor.Current != 'S') {
          return ParseResult.MismatchedCharacter<Period>(valueCursor, 'S');
        }
        if (valueCursor.MoveNext()) {
          return ParseResult.ExpectedEndOfString<Period>(valueCursor);
        }
        return ParseResult.ForValue<Period>(builder.Build());
      }

      builder[unit] = unitValue;
      unitsSoFar |= unit;
    }
    if (unitsSoFar == PeriodUnits.None) {
      return ParseResult.ForInvalidValue<Period>(valueCursor, TextErrorMessages.EmptyPeriod);
    }
    return ParseResult.ForValue<Period>(builder.Build());
  }

  @override
  String Format(Period value) => AppendFormat(value, StringBuffer()).toString();

  @override
  StringBuffer AppendFormat(Period value, StringBuffer builder) {
    // Dart: null safety checks value and builder.
    value = value.Normalize();
    // Always ensure we've got *some* unit; arbitrarily pick days.
    if (value.Equals(Period.Zero)) {
      builder.write("P0D");
      return builder;
    }
    builder.write('P');
    PeriodPattern._AppendValue(builder, value.Years, 'Y');
    PeriodPattern._AppendValue(builder, value.Months, 'M');
    PeriodPattern._AppendValue(builder, value.Weeks, 'W');
    PeriodPattern._AppendValue(builder, value.Days, 'D');
    if (value.HasTimeComponent) {
      builder.write('T');
      PeriodPattern._AppendValue(builder, value.Hours, 'H');
      PeriodPattern._AppendValue(builder, value.Minutes, 'M');
      int nanoseconds = value.Milliseconds * NanosecondsPerMillisecond + value.Ticks * NanosecondsPerTick + value.Nanoseconds;
      int seconds = value.Seconds;
      if (nanoseconds != 0 || seconds != 0) {
        if (nanoseconds < 0 || seconds < 0) {
          builder.write('-');
          nanoseconds = -nanoseconds;
          seconds = -seconds;
        }
        FormatHelper.FormatInvariant(seconds, builder);
        if (nanoseconds != 0) {
          builder.write('.');
          FormatHelper.AppendFractionTruncate(nanoseconds, 9, 9, builder);
        }
        builder.write('S');
      }
    }
    return builder;
  }
}
