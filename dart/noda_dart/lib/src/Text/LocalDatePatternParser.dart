// Ported from NodaTime 6e024dde: src/NodaTime/Text/LocalDatePatternParser.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../CalendarSystem.dart';
import '../CalendarOrdinal.generated.dart';
import '../Calendars/Era.dart';
import '../Globalization/NodaFormatInfo.dart';
import '../LocalDate.dart';
import '../Utility/Preconditions.dart';
import '../YearMonthDayCalendar.dart';
import 'Delegates.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'LocalDatePattern.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/DatePatternHelper.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'TextErrorMessages.generated.dart';
import 'ValueCursor.dart';

/// Parser for patterns of [LocalDate] values.
@internal
final class LocalDatePatternParser implements IPatternParser<LocalDate> {
  final LocalDate _templateValue;
  final int _twoDigitYearMax;

  static final Map<String, CharacterHandler<LocalDate, LocalDatePatternParserLocalDateParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<LocalDate, LocalDatePatternParserLocalDateParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    '/': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch<LocalDate>),
    'y': DatePatternHelper.CreateYearOfEraHandler<LocalDate, LocalDatePatternParserLocalDateParseBucket>((value) => value.YearOfEra, (bucket, value) => bucket.YearOfEra = value),
    'u': SteppedPatternBuilder.HandlePaddedField<LocalDate, LocalDatePatternParserLocalDateParseBucket>
        (4, PatternFields.Year, -9998, 9999, (value) => value.Year, (bucket, value) => bucket.Year = value),
    'M': DatePatternHelper.CreateMonthOfYearHandler<LocalDate, LocalDatePatternParserLocalDateParseBucket>
        ((value) => value.Month, (bucket, value) => bucket.MonthOfYearText = value, (bucket, value) => bucket.MonthOfYearNumeric = value),
    'd': DatePatternHelper.CreateDayHandler<LocalDate, LocalDatePatternParserLocalDateParseBucket>
        ((value) => value.Day, (value) => value.DayOfWeek.value, (bucket, value) => bucket.DayOfMonth = value, (bucket, value) => bucket.DayOfWeek = value),
    'c': DatePatternHelper.CreateCalendarHandler<LocalDate, LocalDatePatternParserLocalDateParseBucket>((value) => value.Calendar, (bucket, value) => bucket.Calendar = value),
    'g': DatePatternHelper.CreateEraHandler<LocalDate, LocalDatePatternParserLocalDateParseBucket>((date) => date.Era, (bucket) => bucket),
  };

  LocalDatePatternParser.NewTemplateValueTwoDigitYearMax(LocalDate templateValue, int twoDigitYearMax)
      : _templateValue = templateValue,
        _twoDigitYearMax = twoDigitYearMax {
    Preconditions.CheckArgumentRange('twoDigitYearMax', twoDigitYearMax, 0, 99);
  }

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<LocalDate> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Dart: a local function must be declared before it's used.
    IPattern<LocalDate> ParseNoStandardExpansion(String patternTextLocal) {
      var patternBuilder = SteppedPatternBuilder<LocalDate, LocalDatePatternParserLocalDateParseBucket>.NewFormatInfoBucketProvider(formatInfo,
          () => LocalDatePatternParserLocalDateParseBucket.NewTemplateValueTwoDigitYearMax(_templateValue, _twoDigitYearMax));
      patternBuilder.ParseCustomPattern(patternTextLocal, _PatternCharacterHandlers);
      patternBuilder.ValidateUsedFields();
      return patternBuilder.Build(_templateValue);
    }

    // Nullity check is performed in LocalDatePattern.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length == 1) {
      return switch (patternText[0]) {
        // Invariant standard patterns return cached implementations.
        'R' => LocalDatePatternPatterns.IsoPatternImpl,
        'r' => LocalDatePatternPatterns.FullRoundtripPatternImpl,
        // Other standard patterns expand the pattern text to the appropriate custom pattern.
        // Note: we don't just recurse, as otherwise a ShortDatePattern of 'd' (for example) would cause a stack overflow.
        'd' => ParseNoStandardExpansion(formatInfo.DateTimeFormat.ShortDatePattern),
        'D' => ParseNoStandardExpansion(formatInfo.DateTimeFormat.LongDatePattern),
        'M' => ParseNoStandardExpansion(formatInfo.DateTimeFormat.MonthDayPattern),
        // Unknown standard patterns fail.
        _ => throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(LocalDate)])
      };
    }
    return ParseNoStandardExpansion(patternText);
  }
}

/// Bucket to put parsed values in, ready for later result calculation. This type is also used
/// by LocalDateTimePattern to store and calculate values.
@internal
final class LocalDatePatternParserLocalDateParseBucket extends ParseBucket<LocalDate> {
  final LocalDate TemplateValue;
  int TwoDigitYearMax;

  CalendarSystem Calendar;
  int Year = 0;
  Era? _Era;
  int YearOfEra = 0;
  int MonthOfYearNumeric = 0;
  int MonthOfYearText = 0;
  int DayOfMonth = 0;
  int DayOfWeek = 0;

  LocalDatePatternParserLocalDateParseBucket.NewTemplateValueTwoDigitYearMax(LocalDate templateValue, int twoDigitYearMax)
      : TemplateValue = templateValue,
        // Only fetch this once.
        Calendar = templateValue.Calendar,
        TwoDigitYearMax = twoDigitYearMax;

  ParseResult<TResult>? ParseEra<TResult>(NodaFormatInfo formatInfo, ValueCursor cursor) {
    var compareInfo = formatInfo.CompareInfo;
    for (var era in Calendar.Eras) {
      for (String eraName in formatInfo.GetEraNames(era)) {
        if (cursor.MatchCaseInsensitive(eraName, compareInfo, true)) {
          _Era = era;
          return null;
        }
      }
    }
    return ParseResult.MismatchedText<TResult>(cursor, 'g');
  }

  // Dart: C#'s two CalculateValue overloads.
  @override
  ParseResult<LocalDate> CalculateValue(PatternFields usedFields, String text, [Type eventualResultType = LocalDate]) {
    // Optimization for very, very common case.
    if (usedFields == (PatternFields.Year | PatternFields.MonthOfYearNumeric | PatternFields.DayOfMonth) &&
        Calendar == CalendarSystem.Iso) {
      return _CalculateSimpleIsoValue(text);
    }

    if (usedFields.HasAny(PatternFields.EmbeddedDate)) {
      return ParseResult.ForValue<LocalDate>(LocalDate(Year, MonthOfYearNumeric, DayOfMonth, Calendar));
    }
    // This will set Year if necessary
    ParseResult<LocalDate>? failure = _DetermineYear(usedFields, text, eventualResultType);
    if (failure != null) {
      return failure;
    }
    // This will set MonthOfYearNumeric if necessary
    failure = _DetermineMonth(usedFields, text);
    if (failure != null) {
      return failure;
    }

    int day = usedFields.HasAny(PatternFields.DayOfMonth) ? DayOfMonth : TemplateValue.Day;
    if (day > Calendar.GetDaysInMonth(Year, MonthOfYearNumeric)) {
      return ParseResult.DayOfMonthOutOfRange<LocalDate>(text, day, MonthOfYearNumeric, Year);
    }

    // Avoid further revalidation.
    LocalDate value = LocalDate.NewYearMonthDayCalendar(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(Year, MonthOfYearNumeric, day, Calendar.Ordinal));

    if (usedFields.HasAny(PatternFields.DayOfWeek) && DayOfWeek != value.DayOfWeek.value) {
      return ParseResult.InconsistentDayOfWeekTextValue<LocalDate>(text);
    }

    return ParseResult.ForValue<LocalDate>(value);
  }

  /// Optimized computation for a pattern with an ISO calendar template value,
  /// and year/month/day fields.
  ParseResult<LocalDate> _CalculateSimpleIsoValue(String text) {
    int day = DayOfMonth;
    int month = MonthOfYearNumeric;
    // Note: year is always valid, as it's already validated to be in the range -9998 to 9999.

    if (month > 12) {
      return ParseResult.MonthOutOfRange<LocalDate>(text, MonthOfYearNumeric, Year);
    }
    // If we've been asked for day 1-28, we're definitely okay regardless of month.
    // If it's 29-31, we need to check.
    // If it's over 31, it's definitely wrong.
    if (day > 31 || (day > 28 && day > Calendar.GetDaysInMonth(Year, MonthOfYearNumeric))) {
      return ParseResult.DayOfMonthOutOfRange<LocalDate>(text, day, MonthOfYearNumeric, Year);
    }

    var value = LocalDate.NewYearMonthDayCalendar(YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(Year, month, day, CalendarOrdinal.Iso));
    return ParseResult.ForValue<LocalDate>(value);
  }

  /// Work out the year, based on fields of:
  /// - Year
  /// - YearOfEra
  /// - YearTwoDigits (implies YearOfEra)
  /// - Era
  ///
  /// If the year is specified, that trumps everything else - any other fields
  /// are just used for checking.
  ///
  /// If nothing is specified, the year of the template value is used.
  ///
  /// If just the era is specified, the year of the template value is used,
  /// and the specified era is checked against it. (Hopefully no-one will
  /// expect to get useful information from a format string with era but no year...)
  ///
  /// Otherwise, we have the year of era (possibly only two digits) and possibly the
  /// era. If the era isn't specified, take it from the template value.
  /// Finally, if we only have two digits, then use either the century of the template
  /// value or the previous century if the year-of-era is greater than TwoDigitYearMax...
  /// and if the template value isn't in the first century already.
  ///
  /// Phew.
  ParseResult<LocalDate>? _DetermineYear(PatternFields usedFields, String text, Type eventualResultType) {
    if (usedFields.HasAny(PatternFields.Year)) {
      if (Year > Calendar.MaxYear || Year < Calendar.MinYear) {
        return ParseResult.FieldValueOutOfRangePostParse<LocalDate>(text, Year, 'u', eventualResultType);
      }

      if (usedFields.HasAny(PatternFields.Era) && _Era != Calendar.GetEra(Year)) {
        return ParseResult.InconsistentValues<LocalDate>(text, 'g', 'u', eventualResultType);
      }

      if (usedFields.HasAny(PatternFields.YearOfEra)) {
        int yearOfEraFromYear = Calendar.GetYearOfEra(Year);
        if (usedFields.HasAny(PatternFields.YearTwoDigits)) {
          // We're only checking the last two digits
          yearOfEraFromYear = yearOfEraFromYear.remainder(100);
        }
        if (yearOfEraFromYear != YearOfEra) {
          return ParseResult.InconsistentValues<LocalDate>(text, 'y', 'u', eventualResultType);
        }
      }
      return null;
    }

    // Use the year from the template value, checking validity in the target calendar, and possibly checking the era.
    if (!usedFields.HasAny(PatternFields.YearOfEra)) {
      Year = TemplateValue.Year;
      if (Year > Calendar.MaxYear || Year < Calendar.MinYear) {
        return ParseResult.TemplateYearOutOfRangeForCalendar<LocalDate>(text, Year, Calendar);
      }
      return usedFields.HasAny(PatternFields.Era) && _Era != Calendar.GetEra(Year)
          ? ParseResult.InconsistentValues<LocalDate>(text, 'g', 'u', eventualResultType) : null;
    }

    // If the era hasn't been specified explicitly, use the template era if it's valid for the
    // target calendar, or the target calendar's default era otherwise.
    if (!usedFields.HasAny(PatternFields.Era)) {
      _Era = Calendar.Eras.contains(TemplateValue.Era) ? TemplateValue.Era : Calendar.DefaultEra;
    }

    // After this point, Era is definitely non-null.

    if (usedFields.HasAny(PatternFields.YearTwoDigits)) {
      int century = TemplateValue.YearOfEra ~/ 100;
      if (YearOfEra > TwoDigitYearMax && century > 1) {
        century--;
      }
      YearOfEra += century * 100;
    }

    if (YearOfEra < Calendar.GetMinYearOfEra(_Era!) ||
        YearOfEra > Calendar.GetMaxYearOfEra(_Era!)) {
      return ParseResult.YearOfEraOutOfRange<LocalDate>(text, YearOfEra, _Era!, Calendar);
    }
    Year = Calendar.GetAbsoluteYear(YearOfEra, _Era!);
    return null;
  }

  ParseResult<LocalDate>? _DetermineMonth(PatternFields usedFields, String text) {
    // Dart: a C# switch on combined flags isn't a constant pattern in Dart, so this is an if/else chain.
    final monthFields = usedFields & (PatternFields.MonthOfYearNumeric | PatternFields.MonthOfYearText);
    if (monthFields == PatternFields.MonthOfYearNumeric) {
      // No-op
    } else if (monthFields == PatternFields.MonthOfYearText) {
      MonthOfYearNumeric = MonthOfYearText;
    } else if (monthFields == (PatternFields.MonthOfYearNumeric | PatternFields.MonthOfYearText)) {
      if (MonthOfYearNumeric != MonthOfYearText) {
        return ParseResult.InconsistentMonthValues<LocalDate>(text);
      }
      // No need to change MonthOfYearNumeric - this was just a check
    } else if (monthFields == PatternFields.None) {
      MonthOfYearNumeric = TemplateValue.Month;
    }
    if (MonthOfYearNumeric > Calendar.GetMonthsInYear(Year)) {
      return ParseResult.MonthOutOfRange<LocalDate>(text, MonthOfYearNumeric, Year);
    }
    return null;
  }
}
