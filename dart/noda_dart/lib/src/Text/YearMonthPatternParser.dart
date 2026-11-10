// Ported from NodaTime 6e024dde: src/NodaTime/Text/YearMonthPatternParser.cs
// Copyright 2019 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaFormatInfo.dart';
import '../Utility/Preconditions.dart';
import '../YearMonth.dart';
import 'Delegates.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'LocalDatePatternParser.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/DatePatternHelper.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'TextErrorMessages.generated.dart';
import 'YearMonthPattern.dart';

/// Parser for patterns of [YearMonth] values.
@internal
final class YearMonthPatternParser implements IPatternParser<YearMonth> {
  final YearMonth _templateValue;
  final int _twoDigitYearMax;

  static final Map<String, CharacterHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    '/': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch<YearMonth>),
    'y': DatePatternHelper.CreateYearOfEraHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>((value) => value.YearOfEra, (bucket, value) => bucket.DateBucket.YearOfEra = value),
    'u': SteppedPatternBuilder.HandlePaddedField<YearMonth, YearMonthPatternParserYearMonthParseBucket>
        (4, PatternFields.Year, -9998, 9999, (value) => value.Year, (bucket, value) => bucket.DateBucket.Year = value),
    'M': DatePatternHelper.CreateMonthOfYearHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>
        ((value) => value.Month, (bucket, value) => bucket.DateBucket.MonthOfYearText = value, (bucket, value) => bucket.DateBucket.MonthOfYearNumeric = value),
    'c': DatePatternHelper.CreateCalendarHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>((value) => value.Calendar, (bucket, value) => bucket.DateBucket.Calendar = value),
    'g': DatePatternHelper.CreateEraHandler<YearMonth, YearMonthPatternParserYearMonthParseBucket>((date) => date.Era, (bucket) => bucket.DateBucket),
  };

  YearMonthPatternParser.NewTemplateValueTwoDigitYearMax(YearMonth templateValue, int twoDigitYearMax)
      : _templateValue = templateValue,
        _twoDigitYearMax = twoDigitYearMax {
    Preconditions.CheckArgumentRange('twoDigitYearMax', twoDigitYearMax, 0, 99);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<YearMonth> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Dart: a local function must be declared before it's used.
    IPattern<YearMonth> ParseNoStandardExpansion(String patternTextLocal) {
      var patternBuilder = SteppedPatternBuilder<YearMonth, YearMonthPatternParserYearMonthParseBucket>.NewFormatInfoBucketProvider(formatInfo,
          () => YearMonthPatternParserYearMonthParseBucket.NewTemplateValueTwoDigitYearMax(_templateValue, _twoDigitYearMax));
      patternBuilder.ParseCustomPattern(patternTextLocal, _PatternCharacterHandlers);
      patternBuilder.ValidateUsedFields();
      return patternBuilder.Build(_templateValue);
    }

    // Nullity check is performed in YearMonthPattern.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length == 1) {
      return switch (patternText[0]) {
        // Invariant standard patterns return cached implementations.
        'g' => YearMonthPatternPatterns.IsoPatternImpl,
        // Culture-specific default pattern
        'G' => ParseNoStandardExpansion(formatInfo.DateTimeFormat.YearMonthPattern),
        // Unknown standard patterns fail.
        _ => throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(YearMonth)])
      };
    }

    return ParseNoStandardExpansion(patternText);
  }
}

/// Bucket to put parsed values in, ready for later result calculation.
/// Actually just delegates to a LocalDateParseBucket.
@internal
final class YearMonthPatternParserYearMonthParseBucket extends ParseBucket<YearMonth> {
  final LocalDatePatternParserLocalDateParseBucket DateBucket;

  YearMonthPatternParserYearMonthParseBucket.NewTemplateValueTwoDigitYearMax(YearMonth templateValue, int twoDigitYearMax)
      : DateBucket = LocalDatePatternParserLocalDateParseBucket.NewTemplateValueTwoDigitYearMax(templateValue.StartDate, twoDigitYearMax);

  @override
  ParseResult<YearMonth> CalculateValue(PatternFields usedFields, String text) {
    var result = DateBucket.CalculateValue(usedFields, text, YearMonth);
    if (!result.Success) {
      return result.ConvertError<YearMonth>();
    }
    return ParseResult.ForValue<YearMonth>(result.Value.ToYearMonth());
  }
}
