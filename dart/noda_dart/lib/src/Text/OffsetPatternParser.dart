// Ported from NodaTime 6e024dde: src/NodaTime/Text/OffsetPatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaFormatInfo.dart';
import '../NodaConstants.dart';
import '../Offset.dart';
import 'CompositePatternBuilder.dart';
import 'Delegates.dart';
import 'IPartialPattern.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternCursor.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'TextErrorMessages.generated.dart';
import 'ValueCursor.dart';

@internal
final class OffsetPatternParser implements IPatternParser<Offset> {
  static final Map<String, CharacterHandler<Offset, _OffsetPatternParserOffsetParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<Offset, _OffsetPatternParserOffsetParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    ':': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch<Offset>),
    'h': (pattern, builder) { throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.Hour12PatternNotSupported, [ParseResult.TypeName(Offset)]); },
    'H': SteppedPatternBuilder.HandlePaddedField<Offset, _OffsetPatternParserOffsetParseBucket>
        (2, PatternFields.Hours24, 0, 23, _GetPositiveHours, (bucket, value) => bucket.Hours = value),
    'm': SteppedPatternBuilder.HandlePaddedField<Offset, _OffsetPatternParserOffsetParseBucket>
        (2, PatternFields.Minutes, 0, 59, _GetPositiveMinutes, (bucket, value) => bucket.Minutes = value),
    's': SteppedPatternBuilder.HandlePaddedField<Offset, _OffsetPatternParserOffsetParseBucket>
        (2, PatternFields.Seconds, 0, 59, _GetPositiveSeconds, (bucket, value) => bucket.Seconds = value),
    '+': _HandlePlus,
    '-': _HandleMinus,
    'Z': (ignored1, ignored2) { throw InvalidPatternException(TextErrorMessages.ZPrefixNotAtStartOfPattern); }
  };

  // Dart: no declared constructor in C#, so the default (unnamed) one is used: `OffsetPatternParser()`.

  // These are used to compute the individual (always-positive) components of an offset.
  // For example, an offset of "three and a half hours behind UTC" would have a "positive hours" value
  // of 3, and a "positive minutes" value of 30. The sign is computed elsewhere.
  static int _GetPositiveHours(Offset offset) => offset.Milliseconds.abs() ~/ NodaConstants.MillisecondsPerHour;

  static int _GetPositiveMinutes(Offset offset) => (offset.Milliseconds.abs().remainder(NodaConstants.MillisecondsPerHour)) ~/ NodaConstants.MillisecondsPerMinute;

  static int _GetPositiveSeconds(Offset offset) => (offset.Milliseconds.abs().remainder(NodaConstants.MillisecondsPerMinute)) ~/ NodaConstants.MillisecondsPerSecond;

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<Offset> ParsePattern(String patternText, NodaFormatInfo formatInfo) => _ParsePartialPattern(patternText, formatInfo);

  IPartialPattern<Offset> _ParsePartialPattern(String patternText, NodaFormatInfo formatInfo) {
    // Nullity check is performed in OffsetPattern.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length == 1) {
      switch (patternText[0]) {
        case 'g':
          return (CompositePatternBuilder<Offset>()
                ..Add(_ParsePartialPattern(formatInfo.OffsetPatternLong, formatInfo), (offset) => true)
                ..Add(_ParsePartialPattern(formatInfo.OffsetPatternMedium, formatInfo), _HasZeroSeconds)
                ..Add(_ParsePartialPattern(formatInfo.OffsetPatternShort, formatInfo), _HasZeroSecondsAndMinutes))
              .BuildAsPartial();
        case 'G':
          return _OffsetPatternParserZPrefixPattern.NewFullPattern(_ParsePartialPattern("g", formatInfo));
        case 'i':
          return (CompositePatternBuilder<Offset>()
                ..Add(_ParsePartialPattern(formatInfo.OffsetPatternLongNoPunctuation, formatInfo), (offset) => true)
                ..Add(_ParsePartialPattern(formatInfo.OffsetPatternMediumNoPunctuation, formatInfo), _HasZeroSeconds)
                ..Add(_ParsePartialPattern(formatInfo.OffsetPatternShortNoPunctuation, formatInfo), _HasZeroSecondsAndMinutes))
              .BuildAsPartial();
        case 'I':
          return _OffsetPatternParserZPrefixPattern.NewFullPattern(_ParsePartialPattern("i", formatInfo));
        case 'l':
          patternText = formatInfo.OffsetPatternLong;
          break;
        case 'm':
          patternText = formatInfo.OffsetPatternMedium;
          break;
        case 's':
          patternText = formatInfo.OffsetPatternShort;
          break;
        case 'L':
          patternText = formatInfo.OffsetPatternLongNoPunctuation;
          break;
        case 'M':
          patternText = formatInfo.OffsetPatternMediumNoPunctuation;
          break;
        case 'S':
          patternText = formatInfo.OffsetPatternShortNoPunctuation;
          break;
        default:
          throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(Offset)]);
      }
    }
    // This is the only way we'd normally end up in custom parsing land for Z on its own.
    if (patternText == "%Z") {
      throw InvalidPatternException(TextErrorMessages.EmptyZPrefixedOffsetPattern);
    }

    // Handle Z-prefix by stripping it, parsing the rest as a normal pattern, then building a special pattern
    // which decides whether or not to delegate.
    // Note that patternText is guaranteed not to be empty due to the check at the start.
    // (And assuming we don't add any standard => custom pattern expansions that result in an empty pattern.)
    bool zPrefix = patternText[0] == 'Z';

    var patternBuilder = SteppedPatternBuilder<Offset, _OffsetPatternParserOffsetParseBucket>.NewFormatInfoBucketProvider(formatInfo, () => _OffsetPatternParserOffsetParseBucket());
    patternBuilder.ParseCustomPattern(zPrefix ? patternText.substring(1) : patternText, _PatternCharacterHandlers);
    // No need to validate field combinations here, but we do need to do something a bit special
    // for Z-handling.
    IPartialPattern<Offset> pattern = patternBuilder.Build(Offset.FromHoursAndMinutes(5, 30));
    return zPrefix ? _OffsetPatternParserZPrefixPattern.NewFullPattern(pattern) : pattern;
  }

  /// Returns true if the offset is representable just in hours and minutes (no seconds).
  static bool _HasZeroSeconds(Offset offset) => (offset.Seconds.remainder(NodaConstants.SecondsPerMinute)) == 0;
  /// Returns true if the offset is representable just in hours (no minutes or seconds).
  static bool _HasZeroSecondsAndMinutes(Offset offset) => (offset.Seconds.remainder(NodaConstants.SecondsPerHour)) == 0;

  // #region Character handlers
  static void _HandlePlus(PatternCursor pattern, SteppedPatternBuilder<Offset, _OffsetPatternParserOffsetParseBucket> builder) {
    builder.AddField(PatternFields.Sign, pattern.Current);
    builder.AddRequiredSign((bucket, positive) => bucket.IsNegative = !positive, (offset) => offset.Milliseconds >= 0);
  }

  static void _HandleMinus(PatternCursor pattern, SteppedPatternBuilder<Offset, _OffsetPatternParserOffsetParseBucket> builder) {
    builder.AddField(PatternFields.Sign, pattern.Current);
    builder.AddNegativeOnlySign((bucket, positive) => bucket.IsNegative = !positive, (offset) => offset.Milliseconds >= 0);
  }
  // #endregion
}

/// Pattern which optionally delegates to another, but both parses and formats Offset.Zero as "Z".
final class _OffsetPatternParserZPrefixPattern implements IPartialPattern<Offset> {
  final IPartialPattern<Offset> _fullPattern;

  _OffsetPatternParserZPrefixPattern.NewFullPattern(IPartialPattern<Offset> fullPattern) : _fullPattern = fullPattern;

  @override
  ParseResult<Offset> Parse(String text) => text == "Z" ? ParseResult.ForValue<Offset>(Offset.Zero) : _fullPattern.Parse(text);

  @override
  String Format(Offset value) => value == Offset.Zero ? "Z" : _fullPattern.Format(value);

  @override
  ParseResult<Offset> ParsePartial(ValueCursor cursor) {
    if (cursor.Current == 'Z') {
      cursor.MoveNext();
      return ParseResult.ForValue<Offset>(Offset.Zero);
    }
    return _fullPattern.ParsePartial(cursor);
  }

  @override
  StringBuffer AppendFormat(Offset value, StringBuffer builder) {
    // Dart: null safety checks builder.
    return value == Offset.Zero ? (builder..write('Z')) : _fullPattern.AppendFormat(value, builder);
  }
}

/// Provides a container for the interim parsed pieces of an [Offset] value.
// [DebuggerStepThrough]
final class _OffsetPatternParserOffsetParseBucket extends ParseBucket<Offset> {
  /// The hours in the range [0, 23].
  int Hours = 0;

  /// The minutes in the range [0, 59].
  int Minutes = 0;

  /// The seconds in the range [0, 59].
  int Seconds = 0;

  /// Gets a value indicating whether this instance is negative.
  ///
  /// Returns `true` if this instance is negative; otherwise, `false`.
  bool IsNegative = false;

  /// Calculates the value from the parsed pieces.
  @override
  ParseResult<Offset> CalculateValue(PatternFields usedFields, String text) {
    int seconds = Hours * NodaConstants.SecondsPerHour +
        Minutes * NodaConstants.SecondsPerMinute +
        Seconds;
    if (IsNegative) {
      seconds = -seconds;
    }
    if (seconds > Offset.MaxSeconds || seconds < Offset.MinSeconds) {
      return ParseResult.ForInvalidValuePostParse<Offset>(text, TextErrorMessages.OverallValueOutOfRange,
          [ParseResult.TypeName(Offset)]);
    }
    return ParseResult.ForValue<Offset>(Offset.FromSeconds(seconds));
  }
}
