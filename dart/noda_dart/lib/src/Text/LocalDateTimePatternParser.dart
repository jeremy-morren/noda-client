// Ported from NodaTime 6e024dde: src/NodaTime/Text/LocalDateTimePatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../Globalization/NodaFormatInfo.dart';
import '../LocalDate.dart';
import '../LocalDateTime.dart';
import '../LocalTime.dart';
import '../Utility/Preconditions.dart';
import 'Delegates.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'LocalDatePatternParser.dart';
import 'LocalDateTimePattern.dart';
import 'LocalTimePatternParser.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/DatePatternHelper.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'Patterns/TimePatternHelper.dart';
import 'TextErrorMessages.generated.dart';

/// Parser for patterns of [LocalDateTime] values.
@internal
final class LocalDateTimePatternParser implements IPatternParser<LocalDateTime> {
  // Split the template value into date and time once, to avoid doing it every time we parse.
  final LocalDate _templateValueDate;
  final LocalTime _templateValueTime;
  final int _twoDigitYearMax;

  static final Map<String, CharacterHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    '/': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch<LocalDateTime>),
    'T': (pattern, builder) => builder.AddLiteralChar('T', ParseResult.MismatchedCharacter<LocalDateTime>),
    'y': DatePatternHelper.CreateYearOfEraHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>((value) => value.YearOfEra, (bucket, value) => bucket.Date.YearOfEra = value),
    'u': SteppedPatternBuilder.HandlePaddedField<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>
        (4, PatternFields.Year, -9998, 9999, (value) => value.Year, (bucket, value) => bucket.Date.Year = value),
    'M': DatePatternHelper.CreateMonthOfYearHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>
        ((value) => value.Month, (bucket, value) => bucket.Date.MonthOfYearText = value, (bucket, value) => bucket.Date.MonthOfYearNumeric = value),
    'd': DatePatternHelper.CreateDayHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>
        ((value) => value.Day, (value) => value.DayOfWeek.value, (bucket, value) => bucket.Date.DayOfMonth = value, (bucket, value) => bucket.Date.DayOfWeek = value),
    '.': TimePatternHelper.CreatePeriodHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ';': TimePatternHelper.CreateCommaDotHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    ':': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.TimeSeparator, ParseResult.TimeSeparatorMismatch<LocalDateTime>),
    'h': SteppedPatternBuilder.HandlePaddedField<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>
        (2, PatternFields.Hours12, 1, 12, (value) => value.ClockHourOfHalfDay, (bucket, value) => bucket.Time.Hours12 = value),
    'H': SteppedPatternBuilder.HandlePaddedField<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>
        (2, PatternFields.Hours24, 0, 24, (value) => value.Hour, (bucket, value) => bucket.Time.Hours24 = value),
    'm': SteppedPatternBuilder.HandlePaddedField<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>
        (2, PatternFields.Minutes, 0, 59, (value) => value.Minute, (bucket, value) => bucket.Time.Minutes = value),
    's': SteppedPatternBuilder.HandlePaddedField<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>
        (2, PatternFields.Seconds, 0, 59, (value) => value.Second, (bucket, value) => bucket.Time.Seconds = value),
    'f': TimePatternHelper.CreateFractionHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    'F': TimePatternHelper.CreateFractionHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>(9, (value) => value.NanosecondOfSecond, (bucket, value) => bucket.Time.FractionalSeconds = value),
    't': TimePatternHelper.CreateAmPmHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>((time) => time.Hour, (bucket, value) => bucket.Time.AmPm = value),
    'c': DatePatternHelper.CreateCalendarHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>((value) => value.Calendar, (bucket, value) => bucket.Date.Calendar = value),
    'g': DatePatternHelper.CreateEraHandler<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>((value) => value.Era, (bucket) => bucket.Date),
    'l': (cursor, builder) => builder.AddEmbeddedLocalPartial(cursor, (bucket) => bucket.Date, (bucket) => bucket.Time, (value) => value.Date, (value) => value.TimeOfDay, null),
  };

  LocalDateTimePatternParser.NewTemplateValueTwoDigitYearMax(LocalDateTime templateValue, int twoDigitYearMax)
      : _templateValueDate = templateValue.Date,
        _templateValueTime = templateValue.TimeOfDay,
        _twoDigitYearMax = twoDigitYearMax {
    Preconditions.CheckArgumentRange('twoDigitYearMax', twoDigitYearMax, 0, 99);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<LocalDateTime> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Dart: a local function must be declared before it's used.
    IPattern<LocalDateTime> ParseNoStandardExpansion(String patternTextLocal) {
      var patternBuilder = SteppedPatternBuilder<LocalDateTime, LocalDateTimePatternParserLocalDateTimeParseBucket>.NewFormatInfoBucketProvider(formatInfo,
          () => LocalDateTimePatternParserLocalDateTimeParseBucket.NewTemplateValueDateTemplateValueTimeTwoDigitYearMax(_templateValueDate, _templateValueTime, _twoDigitYearMax));
      patternBuilder.ParseCustomPattern(patternTextLocal, _PatternCharacterHandlers);
      patternBuilder.ValidateUsedFields();
      return patternBuilder.Build(_templateValueDate.At(_templateValueTime));
    }

    // Nullity check is performed in LocalDateTimePattern.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length == 1) {
      return switch (patternText[0]) {
        // Invariant standard patterns return cached implementations.
        'o' => LocalDateTimePatternPatterns.BclRoundtripPatternImpl,
        'O' => LocalDateTimePatternPatterns.BclRoundtripPatternImpl,
        'r' => LocalDateTimePatternPatterns.FullRoundtripPatternImpl,
        'R' => LocalDateTimePatternPatterns.FullRoundtripWithoutCalendarImpl,
        's' => LocalDateTimePatternPatterns.GeneralIsoPatternImpl,
        'S' => LocalDateTimePatternPatterns.ExtendedIsoPatternImpl,
        // Other standard patterns expand the pattern text to the appropriate custom pattern.
        // Note: we don't just recurse, as otherwise a FullDateTimePattern of 'F' would cause a stack overflow.
        'f' => ParseNoStandardExpansion("${formatInfo.DateTimeFormat.LongDatePattern} ${formatInfo.DateTimeFormat.ShortTimePattern}"),
        'F' => ParseNoStandardExpansion(formatInfo.DateTimeFormat.FullDateTimePattern),
        'g' => ParseNoStandardExpansion("${formatInfo.DateTimeFormat.ShortDatePattern} ${formatInfo.DateTimeFormat.ShortTimePattern}"),
        'G' => ParseNoStandardExpansion("${formatInfo.DateTimeFormat.ShortDatePattern} ${formatInfo.DateTimeFormat.LongTimePattern}"),
        // Unknown standard patterns fail.
        _ => throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(LocalDateTime)])
      };
    }
    return ParseNoStandardExpansion(patternText);
  }
}

@internal
final class LocalDateTimePatternParserLocalDateTimeParseBucket extends ParseBucket<LocalDateTime> {
  final LocalDatePatternParserLocalDateParseBucket Date;
  final LocalTimePatternParserLocalTimeParseBucket Time;

  LocalDateTimePatternParserLocalDateTimeParseBucket.NewTemplateValueDateTemplateValueTimeTwoDigitYearMax(
      LocalDate templateValueDate, LocalTime templateValueTime, int twoDigitYearMax)
      : Date = LocalDatePatternParserLocalDateParseBucket.NewTemplateValueTwoDigitYearMax(templateValueDate, twoDigitYearMax),
        Time = LocalTimePatternParserLocalTimeParseBucket.NewTemplateValue(templateValueTime);

  /// Combines the values in a date bucket with the values in a time bucket.
  ///
  /// This would normally be the [CalculateValue] method, but we want
  /// to be able to use the same logic when parsing an [OffsetDateTime]
  /// and [ZonedDateTime].
  static ParseResult<LocalDateTime> CombineBuckets(
      PatternFields usedFields,
      LocalDatePatternParserLocalDateParseBucket dateBucket,
      LocalTimePatternParserLocalTimeParseBucket timeBucket,
      String text) {
    // Handle special case of hour = 24
    bool hour24 = false;
    if (timeBucket.Hours24 == 24) {
      timeBucket.Hours24 = 0;
      hour24 = true;
    }

    ParseResult<LocalDate> dateResult = dateBucket.CalculateValue(usedFields & PatternFields.AllDateFields, text, LocalDateTime);
    if (!dateResult.Success) {
      return dateResult.ConvertError<LocalDateTime>();
    }
    ParseResult<LocalTime> timeResult = timeBucket.CalculateValue(usedFields & PatternFields.AllTimeFields, text, LocalDateTime);
    if (!timeResult.Success) {
      return timeResult.ConvertError<LocalDateTime>();
    }

    LocalDate date = dateResult.Value;
    LocalTime time = timeResult.Value;

    if (hour24) {
      if (time != LocalTime.Midnight) {
        return ParseResult.InvalidHour24<LocalDateTime>(text);
      }
      // If we're already on the last valid day of the calendar, we can't apply the 24:00.
      // We first check the year as that's much cheaper than computing DaysSinceEpoch.
      if (date.Year == date.Calendar.MaxYear && date.DaysSinceEpoch == date.Calendar.MaxDays) {
        return ParseResult.ForInvalidValuePostParse<LocalDateTime>(text, TextErrorMessages.OverallValueOutOfRange,
            [ParseResult.TypeName(LocalDateTime)]);
      }
      date = date.PlusDays(1);
    }
    return ParseResult.ForValue<LocalDateTime>(date.At(time)); // Dart: date + time (LocalDate's + operator takes a Period)
  }

  @override
  ParseResult<LocalDateTime> CalculateValue(PatternFields usedFields, String text) =>
      CombineBuckets(usedFields, Date, Time, text);
}
