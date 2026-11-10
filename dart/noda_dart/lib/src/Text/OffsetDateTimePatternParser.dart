// Ported from NodaTime 6e024dde: src/NodaTime/Text/OffsetDateTimePatternParser.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaFormatInfo.dart';
import '../Offset.dart';
import '../Offset.dart' as nt show Offset;
import '../OffsetDateTime.dart';
import '../Utility/Preconditions.dart';
import 'Delegates.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'LocalDatePatternParser.dart';
import 'LocalDateTimePatternParser.dart';
import 'LocalTimePatternParser.dart';
import 'OffsetDateTimePattern.dart';
import 'OffsetPattern.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/DatePatternHelper.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternCursor.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'Patterns/TimePatternHelper.dart';
import 'TextErrorMessages.generated.dart';

@internal
final class OffsetDateTimePatternParser implements IPatternParser<OffsetDateTime> {
  final OffsetDateTime _templateValue;
  final int _twoDigitYearMax;

  static final Map<String, CharacterHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    '/': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch<OffsetDateTime>),
    'T': (pattern, builder) => builder.AddLiteralChar('T', ParseResult.MismatchedCharacter<OffsetDateTime>),
    'y': DatePatternHelper.CreateYearOfEraHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>((value) => value.YearOfEra, (bucket, value) => bucket.Date.YearOfEra = value),
    'u': SteppedPatternBuilder.HandlePaddedField<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>
        (4, PatternFields.Year, -9998, 9999, (value) => value.Year, (bucket, value) => bucket.Date.Year = value),
    'M': DatePatternHelper.CreateMonthOfYearHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>
        ((value) => value.Month, (bucket, value) => bucket.Date.MonthOfYearText = value, (bucket, value) => bucket.Date.MonthOfYearNumeric = value),
    'd': DatePatternHelper.CreateDayHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>
        ((value) => value.Day, (value) => value.DayOfWeek.value, (bucket, value) => bucket.Date.DayOfMonth = value, (bucket, value) => bucket.Date.DayOfWeek = value),
    '.': TimePatternHelper.CreatePeriodHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ';': TimePatternHelper.CreateCommaDotHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ':': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch<OffsetDateTime>),
    'h': SteppedPatternBuilder.HandlePaddedField<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>
        (2, PatternFields.Hours12, 1, 12, (value) => value.ClockHourOfHalfDay, (bucket, value) => bucket.Time.Hours12 = value),
    'H': SteppedPatternBuilder.HandlePaddedField<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>
        (2, PatternFields.Hours24, 0, 24, (value) => value.Hour, (bucket, value) => bucket.Time.Hours24 = value),
    'm': SteppedPatternBuilder.HandlePaddedField<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>
        (2, PatternFields.Minutes, 0, 59, (value) => value.Minute, (bucket, value) => bucket.Time.Minutes = value),
    's': SteppedPatternBuilder.HandlePaddedField<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>
        (2, PatternFields.Seconds, 0, 59, (value) => value.Second, (bucket, value) => bucket.Time.Seconds = value),
    'f': TimePatternHelper.CreateFractionHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    'F': TimePatternHelper.CreateFractionHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    't': TimePatternHelper.CreateAmPmHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>((time) => time.Hour, (bucket, value) => bucket.Time.AmPm = value),
    'c': DatePatternHelper.CreateCalendarHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>((value) => value.LocalDateTime.Calendar, (bucket, value) => bucket.Date.Calendar = value),
    'g': DatePatternHelper.CreateEraHandler<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>((value) => value.Era, (bucket) => bucket.Date),
    'o': _HandleOffset,
    'l': (cursor, builder) => builder.AddEmbeddedLocalPartial(cursor, (bucket) => bucket.Date, (bucket) => bucket.Time, (value) => value.Date, (value) => value.TimeOfDay, (value) => value.LocalDateTime),
  };

  OffsetDateTimePatternParser.NewTemplateValueTwoDigitYearMax(OffsetDateTime templateValue, int twoDigitYearMax)
      : _templateValue = templateValue,
        _twoDigitYearMax = twoDigitYearMax {
    Preconditions.CheckArgumentRange('twoDigitYearMax', twoDigitYearMax, 0, 99);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<OffsetDateTime> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Nullity check is performed in OffsetDateTimePattern.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    // Handle standard patterns
    if (patternText.length == 1) {
      return switch (patternText[0]) {
        'G' => OffsetDateTimePatternPatterns.GeneralIsoPatternImpl,
        'o' => OffsetDateTimePatternPatterns.ExtendedIsoPatternImpl,
        'r' => OffsetDateTimePatternPatterns.FullRoundtripPatternImpl,
        _ => throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(OffsetDateTime)])
      };
    }

    var patternBuilder = SteppedPatternBuilder<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket>.NewFormatInfoBucketProvider(formatInfo,
        () => _OffsetDateTimePatternParserOffsetDateTimeParseBucket.NewTemplateValueTwoDigitYearMax(_templateValue, _twoDigitYearMax));
    patternBuilder.ParseCustomPattern(patternText, _PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    // Need to reconstruct the template value from the bits...
    return patternBuilder.Build(_templateValue);
  }

  static void _HandleOffset(PatternCursor pattern,
      SteppedPatternBuilder<OffsetDateTime, _OffsetDateTimePatternParserOffsetDateTimeParseBucket> builder) {
    builder.AddField(PatternFields.EmbeddedOffset, pattern.Current);
    String embeddedPattern = pattern.GetEmbeddedPattern();
    var offsetPattern = OffsetPattern.CreateNodaFormatInfo(embeddedPattern, builder.FormatInfo).UnderlyingPattern;
    builder.AddEmbeddedPattern<Offset>(offsetPattern, (bucket, offset) => bucket.Offset = offset, (zdt) => zdt.Offset);
  }
}

final class _OffsetDateTimePatternParserOffsetDateTimeParseBucket extends ParseBucket<OffsetDateTime> {
  final LocalDatePatternParserLocalDateParseBucket Date;
  final LocalTimePatternParserLocalTimeParseBucket Time;
  nt.Offset Offset;

  _OffsetDateTimePatternParserOffsetDateTimeParseBucket.NewTemplateValueTwoDigitYearMax(OffsetDateTime templateValue, int twoDigitYearMax)
      : Date = LocalDatePatternParserLocalDateParseBucket.NewTemplateValueTwoDigitYearMax(templateValue.Date, twoDigitYearMax),
        Time = LocalTimePatternParserLocalTimeParseBucket.NewTemplateValue(templateValue.TimeOfDay),
        Offset = templateValue.Offset;

  @override
  ParseResult<OffsetDateTime> CalculateValue(PatternFields usedFields, String text) {
    var localResult = LocalDateTimePatternParserLocalDateTimeParseBucket.CombineBuckets(usedFields, Date, Time, text);
    if (!localResult.Success) {
      return localResult.ConvertError<OffsetDateTime>();
    }

    var localDateTime = localResult.Value;
    return ParseResult.ForValue<OffsetDateTime>(localDateTime.WithOffset(Offset));
  }
}
