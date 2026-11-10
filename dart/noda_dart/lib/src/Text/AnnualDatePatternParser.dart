// Ported from NodaTime 6e024dde: src/NodaTime/Text/AnnualDatePatternParser.cs
// Copyright 2018 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../AnnualDate.dart';
import '../CalendarSystem.dart';
import '../Globalization/NodaFormatInfo.dart';
import 'AnnualDatePattern.dart';
import 'Delegates.dart';
import 'IPattern.dart';
import 'InvalidPatternException.dart';
import 'ParseBucket.dart';
import 'ParseResult.dart';
import 'Patterns/DatePatternHelper.dart';
import 'Patterns/IPatternParser.dart';
import 'Patterns/PatternCursor.dart';
import 'Patterns/PatternFields.dart';
import 'Patterns/SteppedPatternBuilder.dart';
import 'TextErrorMessages.generated.dart';

/// Parser for patterns of [AnnualDate] values.
@internal
final class AnnualDatePatternParser implements IPatternParser<AnnualDate> {
  final AnnualDate _templateValue;

  static final Map<String, CharacterHandler<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket>> _PatternCharacterHandlers =
      <String, CharacterHandler<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket>>{
    '%': SteppedPatternBuilder.HandlePercent,
    '\'': SteppedPatternBuilder.HandleQuote,
    '"': SteppedPatternBuilder.HandleQuote,
    '\\': SteppedPatternBuilder.HandleBackslash,
    '/': (pattern, builder) => builder.AddLiteral(builder.FormatInfo.DateSeparator, ParseResult.DateSeparatorMismatch<AnnualDate>),
    'M': DatePatternHelper.CreateMonthOfYearHandler<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket>
        ((value) => value.Month, (bucket, value) => bucket.MonthOfYearText = value, (bucket, value) => bucket.MonthOfYearNumeric = value),
    'd': _HandleDayOfMonth,
  };

  AnnualDatePatternParser.NewTemplateValue(AnnualDate templateValue) : _templateValue = templateValue;

  // Note: public to implement the interface. It does no harm, and it's simpler than using explicit
  // interface implementation.
  @override
  IPattern<AnnualDate> ParsePattern(String patternText, NodaFormatInfo formatInfo) {
    // Nullity check is performed in AnnualDatePattern.
    if (patternText.isEmpty) {
      throw InvalidPatternException(TextErrorMessages.FormatStringEmpty);
    }

    if (patternText.length == 1) {
      switch (patternText[0]) {
        case 'G':
          return AnnualDatePattern.Iso;
        default:
          throw InvalidPatternException.NewFormatStringParameters(TextErrorMessages.UnknownStandardFormat, [patternText, ParseResult.TypeName(AnnualDate)]);
      }
    }

    var patternBuilder = SteppedPatternBuilder<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket>.NewFormatInfoBucketProvider(formatInfo,
        () => AnnualDatePatternParserAnnualDateParseBucket.NewTemplateValue(_templateValue));
    patternBuilder.ParseCustomPattern(patternText, _PatternCharacterHandlers);
    patternBuilder.ValidateUsedFields();
    return patternBuilder.Build(_templateValue);
  }

  static void _HandleDayOfMonth(PatternCursor pattern, SteppedPatternBuilder<AnnualDate, AnnualDatePatternParserAnnualDateParseBucket> builder) {
    int count = pattern.GetRepeatCount(2);
    PatternFields field;
    switch (count) {
      case 1:
      case 2:
        field = PatternFields.DayOfMonth;
        // Handle real maximum value in the bucket
        builder.AddParseValueAction(count, 2, pattern.Current, 1, 99, (bucket, value) => bucket.DayOfMonth = value);
        builder.AddFormatLeftPad(count, (value) => value.Day, /* assumeNonNegative: */ true, /* assumeFitsInCount: */ count == 2);
        break;
      default:
        throw StateError("Invalid count!");
    }
    builder.AddField(field, pattern.Current);
  }
}

/// Bucket to put parsed values in, ready for later result calculation. This type is also used
/// by AnnualDateTimePattern to store and calculate values.
@internal
final class AnnualDatePatternParserAnnualDateParseBucket extends ParseBucket<AnnualDate> {
  final AnnualDate TemplateValue;
  int MonthOfYearNumeric = 0;
  int MonthOfYearText = 0;
  int DayOfMonth = 0;

  AnnualDatePatternParserAnnualDateParseBucket.NewTemplateValue(AnnualDate templateValue) : TemplateValue = templateValue;

  @override
  ParseResult<AnnualDate> CalculateValue(PatternFields usedFields, String text) {
    // This will set MonthOfYearNumeric if necessary
    var failure = _DetermineMonth(usedFields, text);
    if (failure != null) {
      return failure;
    }

    int day = usedFields.HasAny(PatternFields.DayOfMonth) ? DayOfMonth : TemplateValue.Day;
    // Validate for the year 2000, just like the AnnualDate constructor does.
    if (day > CalendarSystem.Iso.GetDaysInMonth(2000, MonthOfYearNumeric)) {
      return ParseResult.DayOfMonthOutOfRangeNoYear<AnnualDate>(text, day, MonthOfYearNumeric);
    }

    return ParseResult.ForValue<AnnualDate>(AnnualDate(MonthOfYearNumeric, day));
  }

  ParseResult<AnnualDate>? _DetermineMonth(PatternFields usedFields, String text) {
    // Dart: a C# switch on combined flags isn't a constant pattern in Dart, so this is an if/else chain.
    final monthFields = usedFields & (PatternFields.MonthOfYearNumeric | PatternFields.MonthOfYearText);
    if (monthFields == PatternFields.MonthOfYearNumeric) {
      // No-op
    } else if (monthFields == PatternFields.MonthOfYearText) {
      MonthOfYearNumeric = MonthOfYearText;
    } else if (monthFields == (PatternFields.MonthOfYearNumeric | PatternFields.MonthOfYearText)) {
      if (MonthOfYearNumeric != MonthOfYearText) {
        return ParseResult.InconsistentMonthValues<AnnualDate>(text);
      }
      // No need to change MonthOfYearNumeric - this was just a check
    } else if (monthFields == PatternFields.None) {
      MonthOfYearNumeric = TemplateValue.Month;
    }
    if (MonthOfYearNumeric > CalendarSystem.Iso.GetMonthsInYear(2000)) {
      return ParseResult.IsoMonthOutOfRange<AnnualDate>(text, MonthOfYearNumeric);
    }
    return null;
  }
}
