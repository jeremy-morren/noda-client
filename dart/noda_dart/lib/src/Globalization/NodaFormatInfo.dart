// Ported from NodaTime 6e024dde: src/NodaTime/Globalization/NodaFormatInfo.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../AnnualDate.dart';
import '../Calendars/Era.dart';
import '../Duration.dart';
import '../Instant.dart';
import '../LocalDate.dart';
import '../LocalDateTime.dart';
import '../LocalTime.dart';
import '../Offset.dart';
import '../OffsetDate.dart';
import '../OffsetDateTime.dart';
import '../OffsetTime.dart';
import '../Text/AnnualDatePattern.dart';
import '../Text/AnnualDatePatternParser.dart' as nt show AnnualDatePatternParser;
import '../Text/DurationPatternParser.dart' as nt show DurationPatternParser;
import '../Text/FixedFormatInfoPatternParser.dart';
import '../Text/InstantPattern.dart';
import '../Text/InstantPatternParser.dart' as nt show InstantPatternParser;
import '../Text/LocalDatePattern.dart';
import '../Text/LocalDatePatternParser.dart' as nt show LocalDatePatternParser;
import '../Text/LocalDateTimePattern.dart';
import '../Text/LocalDateTimePatternParser.dart' as nt show LocalDateTimePatternParser;
import '../Text/LocalTimePatternParser.dart' as nt show LocalTimePatternParser;
import '../Text/OffsetDatePattern.dart';
import '../Text/OffsetDatePatternParser.dart' as nt show OffsetDatePatternParser;
import '../Text/OffsetDateTimePattern.dart';
import '../Text/OffsetDateTimePatternParser.dart' as nt show OffsetDateTimePatternParser;
import '../Text/OffsetPatternParser.dart' as nt show OffsetPatternParser;
import '../Text/OffsetTimePattern.dart';
import '../Text/OffsetTimePatternParser.dart' as nt show OffsetTimePatternParser;
import '../Text/Patterns/IPatternParser.dart';
import '../Text/YearMonthPattern.dart';
import '../Text/YearMonthPatternParser.dart' as nt show YearMonthPatternParser;
import '../Text/ZonedDateTimePattern.dart';
import '../Text/ZonedDateTimePatternParser.dart' as nt show ZonedDateTimePatternParser;
import '../TimeZones/Resolvers.dart';
import '../Utility/Cache.dart';
import '../Utility/ReferenceEqualityComparer.dart';
import '../YearMonth.dart';
import '../ZonedDateTime.dart';
import 'NodaCultureInfo.dart';
import 'NodaCultureInfo.dart' as nt show CompareInfo;

// noda_dart: no lock (isolates don't share memory). Only the name lists initialize eagerly: eager pattern parsers
// would pull every pattern type into every app.

/// A [IFormatProvider] for Noda Time types, usually initialised from a [NodaCultureInfo].
/// This provides a single place defining how NodaTime values are formatted and displayed, depending on the culture.
///
/// Currently this is "shallow-immutable" - although none of these properties can be changed, the
/// CultureInfo itself may be mutable. If the CultureInfo is mutated after initialization, results are not
/// guaranteed: some aspects of the CultureInfo may be extracted at initialization time, others may be
/// extracted on first demand but cached, and others may be extracted on-demand each time.
@internal
final class NodaFormatInfo {
  // Names that we can use to check for broken Mono behaviour.
  // The cloning is *also* to work around a Mono bug, where even read-only cultures can change...
  // See https://xamarin.github.io/bugzilla-archives/32/3279/bug.html
  static final List<String> _ShortInvariantMonthNames =
      List<String>.of(NodaCultureInfo.InvariantCulture.DateTimeFormat.AbbreviatedMonthNames);
  static final List<String> _LongInvariantMonthNames =
      List<String>.of(NodaCultureInfo.InvariantCulture.DateTimeFormat.MonthNames);

  // #region Patterns
  FixedFormatInfoPatternParser<Duration>? _durationPatternParser;
  FixedFormatInfoPatternParser<Offset>? _offsetPatternParser;
  FixedFormatInfoPatternParser<Instant>? _instantPatternParser;
  FixedFormatInfoPatternParser<LocalTime>? _localTimePatternParser;
  FixedFormatInfoPatternParser<LocalDate>? _localDatePatternParser;
  FixedFormatInfoPatternParser<LocalDateTime>? _localDateTimePatternParser;
  FixedFormatInfoPatternParser<OffsetDateTime>? _offsetDateTimePatternParser;
  FixedFormatInfoPatternParser<OffsetDate>? _offsetDatePatternParser;
  FixedFormatInfoPatternParser<OffsetTime>? _offsetTimePatternParser;
  FixedFormatInfoPatternParser<ZonedDateTime>? _zonedDateTimePatternParser;
  FixedFormatInfoPatternParser<AnnualDate>? _annualDatePatternParser;
  FixedFormatInfoPatternParser<YearMonth>? _yearMonthPatternParser;
  // #endregion

  /// A NodaFormatInfo wrapping the invariant culture.
  // Note: this must occur below the pattern parsers, to make type initialization work...
  static final NodaFormatInfo InvariantInfo =
      NodaFormatInfo.NewCultureInfoInitializeEagerly(NodaCultureInfo.InvariantCulture, true);

  // Justification for max size: CultureInfo.GetCultures(CultureTypes.AllCultures) returned:
  // - 378 cultures on Windows 8 in mid-2013
  // - 832 cultures on Windows 10 in late-2016
  // - 869 or 888 on Windows 11 in early-2024 (net471 and net60/net80 respectively)
  // It's unlikely that they'll all be used by any particular application,
  // but the cost per entry is very small, so we might as well allow for all non-customized
  // cultures (and if fewer cultures are used, there's no cost anyway).
  static final Cache<NodaCultureInfo, NodaFormatInfo> _Cache = Cache<NodaCultureInfo, NodaFormatInfo>.NewSizeValueFactoryKeyComparer(
      1000, (culture) => NodaFormatInfo.NewCultureInfoInitializeEagerly(culture, true),
      const ReferenceEqualityComparer<NodaCultureInfo>());

  List<String>? _longMonthNames;
  List<String>? _longMonthGenitiveNames;
  List<String>? _longDayNames;
  List<String>? _shortMonthNames;
  List<String>? _shortMonthGenitiveNames;
  List<String>? _shortDayNames;

  final Map<Era, _EraDescription> _eraDescriptions;

  /// Initializes a new instance of the [NodaFormatInfo] class based solely
  /// on a [NodaCultureInfo].
  ///
  /// [cultureInfo]: The culture info to use.
  /// [initializeEagerly]: Whether or not to fully initialize eagerly. If this is true,
  /// more work is done on construction, but avoids locks during usage.
  @visibleForTesting
  @internal
  NodaFormatInfo.NewCultureInfoInitializeEagerly(NodaCultureInfo cultureInfo, bool initializeEagerly)
      // If cultureInfo is null, this will throw before we get to the DateTimeFormatInfo being null.
      : this.NewCultureInfoDateTimeFormatInitializeEagerly(cultureInfo, cultureInfo.DateTimeFormat, initializeEagerly);

  /// Initializes a new instance of the [NodaFormatInfo] class based on
  /// potentially disparate [NodaCultureInfo] and
  /// [DateTimeFormatInfo] instances.
  ///
  /// [cultureInfo]: The culture info to use for text comparisons and resource lookups.
  /// [dateTimeFormat]: The date/time format to use for format strings etc.
  /// [initializeEagerly]: Whether or not to fully initialize eagerly. If this is true,
  /// more work is done on construction, but avoids locks during usage.
  @visibleForTesting
  @internal
  NodaFormatInfo.NewCultureInfoDateTimeFormatInitializeEagerly(
      NodaCultureInfo cultureInfo, DateTimeFormatInfo dateTimeFormat, bool initializeEagerly)
      // Dart: null safety checks cultureInfo and dateTimeFormat.
      : CultureInfo = cultureInfo,
        DateTimeFormat = dateTimeFormat,
        _eraDescriptions = <Era, _EraDescription>{} {
    if (initializeEagerly) {
      // (noda_dart: only the name lists; see the comment at the top of this file.)
      _EnsureMonthsInitialized();
      _EnsureDaysInitialized();
    }
  }

  void _EnsureMonthsInitialized() {
    if (_longMonthNames != null) {
      return;
    }
    // Turn month names into 1-based read-only lists
    final longMonthNames = _ConvertMonthArray(DateTimeFormat.MonthNames);
    final shortMonthNames = _ConvertMonthArray(DateTimeFormat.AbbreviatedMonthNames);
    _longMonthNames = longMonthNames;
    _shortMonthNames = shortMonthNames;
    _longMonthGenitiveNames =
        _ConvertGenitiveMonthArray(longMonthNames, DateTimeFormat.MonthGenitiveNames, _LongInvariantMonthNames);
    _shortMonthGenitiveNames = _ConvertGenitiveMonthArray(
        shortMonthNames, DateTimeFormat.AbbreviatedMonthGenitiveNames, _ShortInvariantMonthNames);
  }

  /// The BCL returns arrays of month names starting at 0; we want a read-only list starting at 1 (with 0 as an empty string).
  static List<String> _ConvertMonthArray(List<String> monthNames) {
    List<String> list = List<String>.of(monthNames);
    list.insert(0, '');
    return List<String>.unmodifiable(list);
  }

  void _EnsureDaysInitialized() {
    if (_longDayNames != null) {
      return;
    }
    _longDayNames = _ConvertDayArray(DateTimeFormat.DayNames);
    _shortDayNames = _ConvertDayArray(DateTimeFormat.AbbreviatedDayNames);
  }

  /// The BCL returns arrays of week names starting at 0 as Sunday; we want a read-only list starting at 1 (with 0 as an empty string)
  /// and with 7 as Sunday.
  static List<String> _ConvertDayArray(List<String> dayNames) {
    List<String> list = List<String>.of(dayNames);
    list.add(dayNames[0]);
    list[0] = '';
    return List<String>.unmodifiable(list);
  }

  /// Checks whether any of the genitive names differ from the non-genitive names, and returns
  /// either a reference to the non-genitive names or a converted list as per ConvertMonthArray.
  ///
  /// Mono uses the invariant month names for the genitive month names by default, so we'll assume that
  /// if we see an invariant name, that *isn't* deliberately a genitive month name. A non-invariant culture
  /// which decided to have genitive month names exactly matching the invariant ones would be distinctly odd.
  /// See https://xamarin.github.io/bugzilla-archives/32/3278/bug.html for more details and progress.
  ///
  /// Mono 3.0.6 has an exciting and different bug, where all the abbreviated genitive month names are just numbers ("1" etc).
  /// So again, if we detect that, we'll go back to the non-genitive version.
  /// See https://xamarin.github.io/bugzilla-archives/11/11361/bug.html for more details and progress.
  static List<String> _ConvertGenitiveMonthArray(
      List<String> nonGenitiveNames, List<String> bclNames, List<String> invariantNames) {
    if (_TryParseInvariantInt32(bclNames[0])) {
      return nonGenitiveNames;
    }
    for (int i = 0; i < bclNames.length; i++) {
      if (bclNames[i] != nonGenitiveNames[i + 1] && bclNames[i] != invariantNames[i]) {
        return _ConvertMonthArray(bclNames);
      }
    }
    return nonGenitiveNames;
  }

  /// noda_dart: C#'s `int.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out _)`.
  static bool _TryParseInvariantInt32(String text) {
    final match = RegExp(r'^[\t\n\v\f\r ]*([+-]?[0-9]+)[\t\n\v\f\r ]*$').firstMatch(text);
    if (match == null) {
      return false;
    }
    final value = BigInt.parse(match.group(1)!);
    return value >= BigInt.from(-2147483648) && value <= BigInt.from(2147483647);
  }

  /// Gets the culture info associated with this format provider. This is used
  /// for resource lookups and text comparisons.
  final NodaCultureInfo CultureInfo;

  /// Gets the text comparison information associated with this format provider.
  nt.CompareInfo get CompareInfo => CultureInfo.CompareInfo;

  // Note: when adding a new property here, it *must* be initialized in the constructor in the "initializeEagerly" branch.
  // (noda_dart: C#'s EnsureFixedFormatInitialized(ref field, factory) assigns the field; here each getter does.)
  @internal
  FixedFormatInfoPatternParser<Duration> get DurationPatternParser =>
      _durationPatternParser ??= _EnsureFixedFormatInitialized(() => nt.DurationPatternParser());
  @internal
  FixedFormatInfoPatternParser<Offset> get OffsetPatternParser =>
      _offsetPatternParser ??= _EnsureFixedFormatInitialized(() => nt.OffsetPatternParser());
  @internal
  FixedFormatInfoPatternParser<Instant> get InstantPatternParser =>
      _instantPatternParser ??= _EnsureFixedFormatInitialized(() => nt.InstantPatternParser.NewTemplateValueTwoDigitYearMax(
          InstantPattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  @internal
  FixedFormatInfoPatternParser<LocalTime> get LocalTimePatternParser =>
      _localTimePatternParser ??= _EnsureFixedFormatInitialized(() => nt.LocalTimePatternParser(LocalTime.Midnight));
  @internal
  FixedFormatInfoPatternParser<LocalDate> get LocalDatePatternParser =>
      _localDatePatternParser ??= _EnsureFixedFormatInitialized(() => nt.LocalDatePatternParser.NewTemplateValueTwoDigitYearMax(
          LocalDatePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  @internal
  FixedFormatInfoPatternParser<LocalDateTime> get LocalDateTimePatternParser =>
      _localDateTimePatternParser ??= _EnsureFixedFormatInitialized(() =>
          nt.LocalDateTimePatternParser.NewTemplateValueTwoDigitYearMax(
              LocalDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  @internal
  FixedFormatInfoPatternParser<OffsetDateTime> get OffsetDateTimePatternParser =>
      _offsetDateTimePatternParser ??= _EnsureFixedFormatInitialized(() =>
          nt.OffsetDateTimePatternParser.NewTemplateValueTwoDigitYearMax(
              OffsetDateTimePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  @internal
  FixedFormatInfoPatternParser<OffsetDate> get OffsetDatePatternParser =>
      _offsetDatePatternParser ??= _EnsureFixedFormatInitialized(() => nt.OffsetDatePatternParser.NewTemplateValueTwoDigitYearMax(
          OffsetDatePattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));
  @internal
  FixedFormatInfoPatternParser<OffsetTime> get OffsetTimePatternParser =>
      _offsetTimePatternParser ??= _EnsureFixedFormatInitialized(
          () => nt.OffsetTimePatternParser.NewTemplateValue(OffsetTimePattern.DefaultTemplateValue));
  @internal
  FixedFormatInfoPatternParser<ZonedDateTime> get ZonedDateTimePatternParser =>
      _zonedDateTimePatternParser ??= _EnsureFixedFormatInitialized(() =>
          nt.ZonedDateTimePatternParser.NewTemplateValueResolverZoneProviderTwoDigitYearMax(
              ZonedDateTimePattern.DefaultTemplateValue, Resolvers.StrictResolver, null, LocalDatePattern.DefaultTwoDigitYearMax));
  @internal
  FixedFormatInfoPatternParser<AnnualDate> get AnnualDatePatternParser =>
      _annualDatePatternParser ??= _EnsureFixedFormatInitialized(
          () => nt.AnnualDatePatternParser.NewTemplateValue(AnnualDatePattern.DefaultTemplateValue));
  @internal
  FixedFormatInfoPatternParser<YearMonth> get YearMonthPatternParser =>
      _yearMonthPatternParser ??= _EnsureFixedFormatInitialized(() => nt.YearMonthPatternParser.NewTemplateValueTwoDigitYearMax(
          YearMonthPattern.DefaultTemplateValue, LocalDatePattern.DefaultTwoDigitYearMax));

  FixedFormatInfoPatternParser<T> _EnsureFixedFormatInitialized<T>(IPatternParser<T> Function() patternParserFactory) {
    return FixedFormatInfoPatternParser<T>.NewPatternParserFormatInfo(patternParserFactory(), this);
  }

  /// Returns a read-only list of the names of the months for the default calendar for this culture.
  /// See the usage guide for caveats around the use of these names for other calendars.
  /// Element 0 of the list is null, to allow a more natural mapping from (say) 1 to the string "January".
  List<String> get LongMonthNames {
    _EnsureMonthsInitialized();
    return _longMonthNames!;
  }

  /// Returns a read-only list of the abbreviated names of the months for the default calendar for this culture.
  /// See the usage guide for caveats around the use of these names for other calendars.
  /// Element 0 of the list is null, to allow a more natural mapping from (say) 1 to the string "Jan".
  List<String> get ShortMonthNames {
    _EnsureMonthsInitialized();
    return _shortMonthNames!;
  }

  /// Returns a read-only list of the names of the months for the default calendar for this culture.
  /// See the usage guide for caveats around the use of these names for other calendars.
  /// Element 0 of the list is null, to allow a more natural mapping from (say) 1 to the string "January".
  /// The genitive form is used for month text where the day of month also appears in the pattern.
  /// If the culture does not use genitive month names, this property will return the same reference as
  /// [LongMonthNames].
  List<String> get LongMonthGenitiveNames {
    _EnsureMonthsInitialized();
    return _longMonthGenitiveNames!;
  }

  /// Returns a read-only list of the abbreviated names of the months for the default calendar for this culture.
  /// See the usage guide for caveats around the use of these names for other calendars.
  /// Element 0 of the list is null, to allow a more natural mapping from (say) 1 to the string "Jan".
  /// The genitive form is used for month text where the day also appears in the pattern.
  /// If the culture does not use genitive month names, this property will return the same reference as
  /// [ShortMonthNames].
  List<String> get ShortMonthGenitiveNames {
    _EnsureMonthsInitialized();
    return _shortMonthGenitiveNames!;
  }

  /// Returns a read-only list of the names of the days of the week for the default calendar for this culture.
  /// See the usage guide for caveats around the use of these names for other calendars.
  /// Element 0 of the list is null, and the other elements correspond with the index values returned from
  /// [LocalDateTime.DayOfWeek] and similar properties.
  List<String> get LongDayNames {
    _EnsureDaysInitialized();
    return _longDayNames!;
  }

  /// Returns a read-only list of the abbreviated names of the days of the week for the default calendar for this culture.
  /// See the usage guide for caveats around the use of these names for other calendars.
  /// Element 0 of the list is null, and the other elements correspond with the index values returned from
  /// [LocalDateTime.DayOfWeek] and similar properties.
  List<String> get ShortDayNames {
    _EnsureDaysInitialized();
    return _shortDayNames!;
  }

  /// Gets the BCL date time format associated with this formatting information.
  ///
  /// This is usually the [DateTimeFormatInfo] from [CultureInfo],
  /// but in some cases they're different: if a DateTimeFormatInfo is provided with no
  /// CultureInfo, that's used for format strings but the invariant culture is used for
  /// text comparisons and culture lookups for non-BCL formats (such as Offset) and for error messages.
  final DateTimeFormatInfo DateTimeFormat;

  /// Gets the time separator.
  String get TimeSeparator => DateTimeFormat.TimeSeparator;

  /// Gets the date separator.
  String get DateSeparator => DateTimeFormat.DateSeparator;

  /// Gets the AM designator.
  String get AMDesignator => DateTimeFormat.AMDesignator;

  /// Gets the PM designator.
  String get PMDesignator => DateTimeFormat.PMDesignator;

  /// Returns the names for the given era in this culture.
  ///
  /// [era]: The era to find the names of.
  ///
  /// Returns a read-only list of names for the given era, or an empty list if
  /// the era is not known in this culture.
  List<String> GetEraNames(Era era) {
    // Dart: null safety checks era.
    return _GetEraDescription(era).AllNames;
  }

  /// Returns the primary name for the given era in this culture.
  ///
  /// [era]: The era to find the primary name of.
  ///
  /// Returns the primary name for the given era, or an empty string if the era name is not known.
  String GetEraPrimaryName(Era era) {
    // Dart: null safety checks era.
    return _GetEraDescription(era).PrimaryName;
  }

  _EraDescription _GetEraDescription(Era era) =>
      _eraDescriptions.putIfAbsent(era, () => _EraDescription.ForEra(era, CultureInfo));

  /// Gets the [NodaFormatInfo] object for the current thread.
  ///
  /// (noda_dart: for [NodaCultureInfo.CurrentCulture], the culture of the host's language; see there.)
  static NodaFormatInfo get CurrentInfo => GetInstance(NodaCultureInfo.CurrentCulture);

  /// Gets the [Offset] "l" pattern.
  String get OffsetPatternLong => CultureInfo.GetPatternResource('OffsetPatternLong')!;

  /// Gets the [Offset] "m" pattern.
  String get OffsetPatternMedium => CultureInfo.GetPatternResource('OffsetPatternMedium')!;

  /// Gets the [Offset] "s" pattern.
  String get OffsetPatternShort => CultureInfo.GetPatternResource('OffsetPatternShort')!;

  /// Gets the [Offset] "L" pattern.
  String get OffsetPatternLongNoPunctuation => CultureInfo.GetPatternResource('OffsetPatternLongNoPunctuation')!;

  /// Gets the [Offset] "M" pattern.
  String get OffsetPatternMediumNoPunctuation => CultureInfo.GetPatternResource('OffsetPatternMediumNoPunctuation')!;

  /// Gets the [Offset] "S" pattern.
  String get OffsetPatternShortNoPunctuation => CultureInfo.GetPatternResource('OffsetPatternShortNoPunctuation')!;

  /// Clears the cache. Only used for test purposes.
  @internal
  static void ClearCache() => _Cache.Clear();

  /// Gets the [NodaFormatInfo] for the given [NodaCultureInfo].
  ///
  /// This method maintains a cache of results for read-only cultures.
  ///
  /// [cultureInfo]: The culture info.
  ///
  /// Returns the [NodaFormatInfo]. Will never be null.
  @internal
  static NodaFormatInfo GetFormatInfo(NodaCultureInfo cultureInfo) {
    // Dart: null safety checks cultureInfo.
    if (identical(cultureInfo, NodaCultureInfo.InvariantCulture)) {
      return InvariantInfo;
    }
    // Never cache (or consult the cache) for non-read-only cultures.
    // We don't initialize eagerly in this case, to preserve previous behavior -
    // and as we expect such instances to be reused relatively rarely.
    if (!cultureInfo.IsReadOnly) {
      return NodaFormatInfo.NewCultureInfoInitializeEagerly(cultureInfo, false);
    }
    return _Cache.GetOrAdd(cultureInfo);
  }

  /// Gets the [NodaFormatInfo] for the given [IFormatProvider]. If the
  /// format provider is null then the format object for the invariant culture is returned (noda_dart: NodaTime uses
  /// the current thread's culture; noda_dart, as noda-js, formats with the invariant culture unless told otherwise).
  /// If it's a CultureInfo, that's used for everything. If it's a DateTimeFormatInfo, that's used for
  /// format strings, day names etc but the invariant culture is used for text comparisons and
  /// resource lookups. Otherwise, [ArgumentError] is thrown.
  ///
  /// [provider]: The [IFormatProvider].
  ///
  /// Throws [ArgumentError]: The format provider cannot be used for Noda Time.
  ///
  /// Returns the [NodaFormatInfo]. Will never be null.
  static NodaFormatInfo GetInstance(IFormatProvider? provider) => switch (provider) {
        null => InvariantInfo,
        NodaCultureInfo cultureInfo => GetFormatInfo(cultureInfo),
        // Note: no caching for this case. It's a corner case anyway... we could add a cache later
        // if users notice a problem.
        DateTimeFormatInfo dateTimeFormatInfo => NodaFormatInfo.NewCultureInfoDateTimeFormatInitializeEagerly(
            NodaCultureInfo.InvariantCulture, dateTimeFormatInfo, false),
        _ => throw ArgumentError('Cannot use provider of type ${provider.runtimeType} in Noda Time', 'provider'),
      };

  /// Returns a [String] that represents this instance.
  @override
  String toString() => 'NodaFormatInfo[${CultureInfo.Name}]';
}

/// The description for an era: the primary name and all possible names.
final class _EraDescription {
  final String PrimaryName;
  final List<String> AllNames;

  _EraDescription._NewPrimaryNameAllNames(String primaryName, List<String> allNames)
      : PrimaryName = primaryName,
        AllNames = allNames;

  static _EraDescription ForEra(Era era, NodaCultureInfo cultureInfo) {
    String? pipeDelimited = cultureInfo.GetPatternResource(era.ResourceIdentifier);
    String primaryName;
    List<String> allNames;
    if (pipeDelimited == null) {
      allNames = <String>[];
      primaryName = '';
    } else {
      // If the BCL has provided an era name other than the one we'd consider to be the primary one, make *that*
      // the primary one for formatting.
      // TODO: Achieve the same result without the string allocations.
      String? eraNameFromCulture = _GetEraNameFromBcl(era, cultureInfo);
      if (eraNameFromCulture != null && !pipeDelimited.startsWith('$eraNameFromCulture|')) {
        pipeDelimited = '$eraNameFromCulture|$pipeDelimited';
      }
      allNames = pipeDelimited.split('|');
      primaryName = allNames[0];
      // Order by length, descending to avoid early out (e.g. parsing BCE as BC and then having a spare E)
      allNames.sort((x, y) => y.length.compareTo(x.length));
    }
    return _EraDescription._NewPrimaryNameAllNames(primaryName, List<String>.unmodifiable(allNames));
  }

  /// Returns the name of the era within a culture according to the BCL, if this is known and we're confident that
  /// it's correct. (The selection here seems small, but it covers most cases.) This isn't ideal, but it's better
  /// than nothing, and fixes an issue where non-English BCL cultures have "gg" in their patterns.
  static String? _GetEraNameFromBcl(Era era, NodaCultureInfo culture) {
    // (noda_dart: the calendar is identified by its .NET type name, as noda-js does.)
    var calendar = culture.DateTimeFormat.Calendar;
    bool getEraFromCalendar = (era == Era.Common && calendar == 'GregorianCalendar') ||
        (era == Era.AnnoPersico && calendar == 'PersianCalendar') ||
        (era == Era.AnnoHegirae && (calendar == 'HijriCalendar' || calendar == 'UmAlQuraCalendar'));
    return getEraFromCalendar ? culture.DateTimeFormat.GetEraName(1) : null;
  }
}
