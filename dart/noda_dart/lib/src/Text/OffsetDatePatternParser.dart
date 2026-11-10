// Ported from NodaTime 6e024dde: src/NodaTime/Text/OffsetDatePatternParser.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaFormatInfo.dart';
import '../LocalDate.dart';
import '../Offset.dart';
import '../Offset.dart' as nt show Offset;
import '../OffsetDate.dart';
import '../Utility/Preconditions.dart';
import 'Delegates.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'LocalDatePatternParser.dart';
import 'OffsetDatePattern.dart';
import 'OffsetPattern.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/DatePatternHelper.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternCursor.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'TextErrorMessages.generated.dart';

@internal
final class OffsetDatePatternParser implements IPatternParser<OffsetDate> {
  final OffsetDate _templateValue;
  final int _twoDigitYearMax;

  static final Map<String, CharacterHandler<OffsetDate, _OffsetDatePatternParserOffsetDateParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<OffsetDate, _OffsetDatePatternParserOffsetDateParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    '/': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch<OffsetDate>),
    'y': DatePatternHelper.CreateYearOfEraHandler<OffsetDate, _OffsetDatePatternParserOffsetDateParseBucket>((value) => value.YearOfEra, (bucket, value) => bucket.Date.YearOfEra = value),
    'u': SteppedPatternBuilder.HandlePaddedField<OffsetDate, _OffsetDatePatternParserOffsetDateParseBucket>
        (4, PatternFields.Year, -9998, 9999, (value) => value.Year, (bucket, value) => bucket.Date.Year = value),
    'M': DatePatternHelper.CreateMonthOfYearHandler<OffsetDate, _OffsetDatePatternParserOffsetDateParseBucket>
        ((value) => value.Month, (bucket, value) => bucket.Date.MonthOfYearText = value, (bucket, value) => bucket.Date.MonthOfYearNumeric = value),
    'd': DatePatternHelper.CreateDayHandler<OffsetDate, _OffsetDatePatternParserOffsetDateParseBucket>
        ((value) => value.Day, (value) => value.DayOfWeek.value, (bucket, value) => bucket.Date.DayOfMonth = value, (bucket, value) => bucket.Date.DayOfWeek = value),
    'c': DatePatternHelper.CreateCalendarHandler<OffsetDate, _OffsetDatePatternParserOffsetDateParseBucket>((value) => value.Date.Calendar, (bucket, value) => bucket.Date.Calendar = value),
    'g': DatePatternHelper.CreateEraHandler<OffsetDate, _OffsetDatePatternParserOffsetDateParseBucket>((value) => value.Era, (bucket) => bucket.Date),
    'o': _HandleOffset,
    'l': (cursor, builder) => builder.AddEmbeddedDatePattern(cursor.Current, cursor.GetEmbeddedPattern(), (bucket) => bucket.Date, (value) => value.Date),
  };

  OffsetDatePatternParser.NewTemplateValueTwoDigitYearMax(OffsetDate templateValue, int twoDigitYearMax)
      : _templateValue = templateValue,
        _twoDigitYearMax = twoDigitYearMax {
    Preconditions.CheckArgumentRange('twoDigitYearMax', twoDigitYearMax, 0, 99);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<OffsetDate> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Nullity check is performed in OffsetDatePattern.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    // Handle standard patterns
    if (patternText.length == 1) {
      return switch (patternText[0]) {
        'G' => OffsetDatePatternPatterns.GeneralIsoPatternImpl,
        'r' => OffsetDatePatternPatterns.FullRoundtripPatternImpl,
        _ => throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(OffsetDate)])
      };
    }

    var patternBuilder = SteppedPatternBuilder<OffsetDate, _OffsetDatePatternParserOffsetDateParseBucket>.NewFormatInfoBucketProvider(formatInfo,
        () => _OffsetDatePatternParserOffsetDateParseBucket.NewTemplateValueTwoDigitYearMax(_templateValue, _twoDigitYearMax));
    patternBuilder.ParseCustomPattern(patternText, _PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    // Need to reconstruct the template value from the bits...
    return patternBuilder.Build(_templateValue);
  }

  static void _HandleOffset(PatternCursor pattern,
      SteppedPatternBuilder<OffsetDate, _OffsetDatePatternParserOffsetDateParseBucket> builder) {
    builder.AddField(PatternFields.EmbeddedOffset, pattern.Current);
    String embeddedPattern = pattern.GetEmbeddedPattern();
    var offsetPattern = OffsetPattern.CreateNodaFormatInfo(embeddedPattern, builder.FormatInfo).UnderlyingPattern;
    builder.AddEmbeddedPattern<Offset>(offsetPattern, (bucket, offset) => bucket.Offset = offset, (zdt) => zdt.Offset);
  }
}

final class _OffsetDatePatternParserOffsetDateParseBucket extends ParseBucket<OffsetDate> {
  final LocalDatePatternParserLocalDateParseBucket Date;
  nt.Offset Offset;

  _OffsetDatePatternParserOffsetDateParseBucket.NewTemplateValueTwoDigitYearMax(OffsetDate templateValue, int twoDigitYearMax)
      : Date = LocalDatePatternParserLocalDateParseBucket.NewTemplateValueTwoDigitYearMax(templateValue.Date, twoDigitYearMax),
        Offset = templateValue.Offset;

  @override
  ParseResult<OffsetDate> CalculateValue(PatternFields usedFields, String text) {
    ParseResult<LocalDate> dateResult = Date.CalculateValue(usedFields & PatternFields.AllDateFields, text, OffsetDate);
    if (!dateResult.Success) {
      return dateResult.ConvertError<OffsetDate>();
    }
    LocalDate date = dateResult.Value;
    return ParseResult.ForValue<OffsetDate>(date.WithOffset(Offset));
  }
}
