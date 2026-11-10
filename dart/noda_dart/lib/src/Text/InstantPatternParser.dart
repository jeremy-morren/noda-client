// Ported from NodaTime 6e024dde: src/NodaTime/Text/InstantPatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaFormatInfo.dart';
import '../Instant.dart';
import '../LocalDateTime.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'LocalDateTimePattern.dart';
import 'ParseResult.dart';
import 'Patterns/IPatternParser.dart';
import 'TextErrorMessages.generated.dart';

const String _GeneralPatternText = "uuuu'-'MM'-'dd'T'HH':'mm':'ss'Z'";

/// Pattern parsing support for [Instant].
///
/// Supported standard patterns:
/// - g: general; the UTC ISO-8601 instant in the style uuuu-MM-ddTHH:mm:ssZ
@internal
final class InstantPatternParser implements IPatternParser<Instant> {
  static const String BeforeMinValueText = "StartOfTime";
  static const String AfterMaxValueText = "EndOfTime";

  final LocalDateTime _localTemplateValue;
  final int _twoDigitYearMax;

  InstantPatternParser.NewTemplateValueTwoDigitYearMax(Instant templateValue, int twoDigitYearMax)
      : _localTemplateValue = templateValue.InUtc().LocalDateTime,
        _twoDigitYearMax = twoDigitYearMax;

  @override
  IPattern<Instant> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Dart: null safety checks patternText.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }
    if (patternText.length == 1) {
      patternText = switch (patternText[0]) {
        // Simplest way of handling the general pattern...
        'g' => _GeneralPatternText,
        _ => throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(Instant)])
      };
    }

    // We unwrap the LocalDateTimePattern to avoid unnecessary levels of indirection.
    IPattern<LocalDateTime> localPattern =
        LocalDateTimePattern.CreateNodaFormatInfo(patternText, formatInfo, _localTemplateValue, _twoDigitYearMax).UnderlyingPattern;
    return _InstantPatternParserLocalDateTimePatternAdapter.NewPattern(localPattern);
  }
}

// This not only converts between LocalDateTime and Instant; it also handles infinity.
final class _InstantPatternParserLocalDateTimePatternAdapter implements IPattern<Instant> {
  final IPattern<LocalDateTime> _pattern;

  _InstantPatternParserLocalDateTimePatternAdapter.NewPattern(IPattern<LocalDateTime> pattern) : _pattern = pattern;

  @override
  String Format(Instant value) =>
      // We don't need to be able to parse before-min/after-max values, but it's convenient to be
      // able to format them - mostly for the sake of testing (but also for ZoneInterval).
      value.IsValid ? _pattern.Format(value.InUtc().LocalDateTime)
          : value == Instant.BeforeMinValue ? InstantPatternParser.BeforeMinValueText
          : InstantPatternParser.AfterMaxValueText;

  @override
  StringBuffer AppendFormat(Instant value, StringBuffer builder) =>
      _pattern.AppendFormat(value.InUtc().LocalDateTime, builder);

  @override
  ParseResult<Instant> Parse(String text) =>
      _pattern.Parse(text).Convert((local) => Instant.NewDaysNanoOfDay(local.Date.DaysSinceEpoch, local.NanosecondOfDay));
}
