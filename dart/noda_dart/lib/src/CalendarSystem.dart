// Ported from NodaTime 6e024dde: src/NodaTime/CalendarSystem.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'CalendarOrdinal.generated.dart';
import 'Calendars/BadiYearMonthDayCalculator.dart';
import 'Calendars/CopticYearMonthDayCalculator.dart';
import 'Calendars/Era.dart';
import 'Calendars/EraCalculator.dart';
import 'Calendars/GJEraCalculator.dart';
import 'Calendars/GregorianYearMonthDayCalculator.dart';
import 'Calendars/HebrewMonthNumbering.generated.dart';
import 'Calendars/HebrewYearMonthDayCalculator.dart';
import 'Calendars/IslamicEpoch.generated.dart';
import 'Calendars/IslamicLeapYearPattern.generated.dart';
import 'Calendars/IslamicYearMonthDayCalculator.dart';
import 'Calendars/JulianYearMonthDayCalculator.dart';
import 'Calendars/PersianYearMonthDayCalculator.dart';
import 'Calendars/SingleEraCalculator.dart';
import 'Calendars/UmAlQuraYearMonthDayCalculator.dart';
import 'Calendars/YearMonthDayCalculator.dart' as nt show YearMonthDayCalculator;
import 'IsoDayOfWeek.generated.dart';
import 'Utility/Preconditions.dart';
import 'YearMonthDay.dart';
import 'YearMonthDayCalendar.dart';

// IDs and names are separated out (usually with the ID either being the same as the name,
// or the base ID being the same as a name and then other IDs being formed from it.) The
// differentiation is only present for clarity.
const String _GregorianName = 'Gregorian';
const String _GregorianId = _GregorianName;

const String _IsoName = 'ISO';
const String _IsoId = _IsoName;

const String _CopticName = 'Coptic';
const String _CopticId = _CopticName;

const String _BadiName = 'Badi';
const String _BadiId = _BadiName;

const String _JulianName = 'Julian';
const String _JulianId = _JulianName;

const String _IslamicName = 'Hijri';
const String _IslamicIdBase = _IslamicName;

const String _PersianName = 'Persian';
const String _PersianIdBase = _PersianName;
const String _PersianSimpleId = '$_PersianIdBase Simple';
const String _PersianAstronomicalId = '$_PersianIdBase Algorithmic';
const String _PersianArithmeticId = '$_PersianIdBase Arithmetic';

const String _HebrewName = 'Hebrew';
const String _HebrewIdBase = _HebrewName;
const String _HebrewCivilId = '$_HebrewIdBase Civil';
const String _HebrewScripturalId = '$_HebrewIdBase Scriptural';

const String _UmAlQuraName = 'Um Al Qura';
const String _UmAlQuraId = _UmAlQuraName;

/// A calendar system maps the non-calendar-specific "local time line" to human concepts
/// such as years, months and days.
///
/// Many developers will never need to touch this class, other than to potentially ask a calendar
/// how many days are in a particular year/month and the like. Noda Time defaults to using the ISO-8601
/// calendar anywhere that a calendar system is required but hasn't been explicitly specified.
///
/// If you need to obtain a [CalendarSystem] instance, use one of the static properties or methods in this
/// class, such as the [Iso] property or the [GetHebrewCalendar] method.
///
/// Although this class is currently sealed (as of Noda Time 1.2), in the future this decision may
/// be reversed. In any case, there is no current intention for third-party developers to be able to implement
/// their own calendar systems (for various reasons). If you require a calendar system which is not
/// currently supported, please file a feature request and we'll see what we can do.
///
/// All calendar implementations are immutable and thread-safe. See the thread safety
/// section of the user guide for more information.
final class CalendarSystem {
  // (The IDs and names are top-level private constants above.)

  // Not part of IslamicCalendars as we want to be able to call it without triggering type initialization.
  @internal
  static String GetIslamicId(IslamicLeapYearPattern leapYearPattern, IslamicEpoch epoch) =>
      '$_IslamicIdBase ${epoch.Name}-${leapYearPattern.Name}';

  // While we could implement some of these as auto-props, it probably adds more confusion than convenience.
  static final List<CalendarSystem?> _CalendarByOrdinal = List<CalendarSystem?>.filled(CalendarOrdinal.Size.value, null);

  // C#: the static constructor, which initializes Iso. (Dart's static fields are initialized lazily, on first use.)
  static CalendarSystem _StaticConstructor() {
    var gregorianCalculator = GregorianYearMonthDayCalculator.New();
    var gregorianEraCalculator = GJEraCalculator.NewYmdCalculator(gregorianCalculator);
    return CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorEraCalculator(
        CalendarOrdinal.Iso, _IsoId, _IsoName, gregorianCalculator, gregorianEraCalculator);
  }

  // #region Public factory members for calendars
  /// Fetches a calendar system by its unique identifier. This provides full round-tripping of a calendar
  /// system. This method will always return the same reference for the same ID.
  ///
  /// [id]: The ID of the calendar system. This is case-sensitive.
  ///
  /// Returns the calendar system with the given ID.
  ///
  /// See also [Id].
  ///
  /// Throws [ArgumentError] if no calendar system for the specified ID can be found (C#'s KeyNotFoundException).
  /// Throws [UnsupportedError] if the calendar system with the specified ID is known, but not supported on this
  /// platform.
  static CalendarSystem ForId(String id) {
    // Dart: null safety checks id.
    CalendarSystem Function()? factory = _IdToFactoryMap[id];
    if (factory == null) {
      throw ArgumentError('No calendar system for ID $id exists');
    }
    return factory();
  }

  /// Fetches a calendar system by its ordinal value, constructing it if necessary.
  @internal
  static CalendarSystem ForOrdinal(CalendarOrdinal ordinal) {
    Preconditions.DebugCheckArgument(ordinal.value >= 0 && ordinal.value < CalendarOrdinal.Size.value, 'ordinal',
        'Unknown ordinal value {0}', [ordinal.value]);
    // Avoid an array lookup for the overwhelmingly common case.
    if (ordinal == CalendarOrdinal.Iso) {
      return Iso;
    }
    CalendarSystem? calendar = _CalendarByOrdinal[ordinal.value];
    if (calendar != null) {
      return calendar;
    }
    // Not found it in the array. This can happen if the calendar system was initialized in
    // a different thread, and the write to the array isn't visible in this thread yet.
    // A simple switch will do the right thing. This is separated out (directly below) to allow
    // it to be tested separately. (It may also help this method be inlined...) The return
    // statement below is unlikely to ever be hit by code coverage, as it's handling a very
    // unusual and hard-to-provoke situation.
    // (noda_dart: in Dart, this is usually hit, as the holders below are lazy.)
    return ForOrdinalUncached(ordinal);
  }

  @internal
  @visibleForTesting
  static CalendarSystem ForOrdinalUncached(CalendarOrdinal ordinal) => switch (ordinal) {
        // This entry is really just for completeness. We'd never get called with this.
        CalendarOrdinal.Iso => Iso,
        CalendarOrdinal.Gregorian => Gregorian,
        CalendarOrdinal.Julian => Julian,
        CalendarOrdinal.Coptic => Coptic,
        CalendarOrdinal.Badi => Badi,
        CalendarOrdinal.HebrewCivil => HebrewCivil,
        CalendarOrdinal.HebrewScriptural => HebrewScriptural,
        CalendarOrdinal.PersianSimple => PersianSimple,
        CalendarOrdinal.PersianArithmetic => PersianArithmetic,
        CalendarOrdinal.PersianAstronomical => PersianAstronomical,
        CalendarOrdinal.IslamicAstronomicalBase15 =>
          GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical),
        CalendarOrdinal.IslamicAstronomicalBase16 =>
          GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Astronomical),
        CalendarOrdinal.IslamicAstronomicalIndian =>
          GetIslamicCalendar(IslamicLeapYearPattern.Indian, IslamicEpoch.Astronomical),
        CalendarOrdinal.IslamicAstronomicalHabashAlHasib =>
          GetIslamicCalendar(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Astronomical),
        CalendarOrdinal.IslamicCivilBase15 => GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil),
        CalendarOrdinal.IslamicCivilBase16 => GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil),
        CalendarOrdinal.IslamicCivilIndian => GetIslamicCalendar(IslamicLeapYearPattern.Indian, IslamicEpoch.Civil),
        CalendarOrdinal.IslamicCivilHabashAlHasib =>
          GetIslamicCalendar(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Civil),
        CalendarOrdinal.UmAlQura => UmAlQura,
        _ => throw StateError('Bug in Noda Time: calendar ordinal ${ordinal.Name} missing from switch in CalendarSystem.ForOrdinal.')
      };

  /// Returns the IDs of all calendar systems available within Noda Time. The order of the keys is not guaranteed.
  static Iterable<String> get Ids => _IdToFactoryMap.keys;

  // Note: each factory method must return the same reference on every invocation.
  // If the delegate calls a method, that method must have the same guarantee.
  static final Map<String, CalendarSystem Function()> _IdToFactoryMap = <String, CalendarSystem Function()>{
    // The compiler doesn't know that nothing will execute the delegate before we assign a value to Iso.
    _IsoId: () => Iso,
    _PersianSimpleId: () => PersianSimple,
    _PersianArithmeticId: () => PersianArithmetic,
    _PersianAstronomicalId: () => PersianAstronomical,
    _HebrewCivilId: () => GetHebrewCalendar(HebrewMonthNumbering.Civil),
    _HebrewScripturalId: () => GetHebrewCalendar(HebrewMonthNumbering.Scriptural),
    _GregorianId: () => Gregorian,
    _CopticId: () => Coptic,
    _BadiId: () => Badi,
    _JulianId: () => Julian,
    _UmAlQuraId: () => UmAlQura,
    GetIslamicId(IslamicLeapYearPattern.Indian, IslamicEpoch.Civil): () =>
        GetIslamicCalendar(IslamicLeapYearPattern.Indian, IslamicEpoch.Civil),
    GetIslamicId(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil): () =>
        GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil),
    GetIslamicId(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil): () =>
        GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil),
    GetIslamicId(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Civil): () =>
        GetIslamicCalendar(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Civil),
    GetIslamicId(IslamicLeapYearPattern.Indian, IslamicEpoch.Astronomical): () =>
        GetIslamicCalendar(IslamicLeapYearPattern.Indian, IslamicEpoch.Astronomical),
    GetIslamicId(IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical): () =>
        GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical),
    GetIslamicId(IslamicLeapYearPattern.Base16, IslamicEpoch.Astronomical): () =>
        GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Astronomical),
    GetIslamicId(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Astronomical): () =>
        GetIslamicCalendar(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Astronomical),
  };

  /// Returns a calendar system that follows the rules of the ISO-8601 standard,
  /// which is compatible with Gregorian for all modern dates.
  ///
  /// As of Noda Time 2.0, this calendar system is equivalent to [Gregorian].
  /// The only areas in which the calendars differed were around centuries, and the members
  /// relating to those differences were removed in Noda Time 2.0.
  /// The distinction between Gregorian and ISO has been maintained for the sake of simplicity, compatibility
  /// and consistency.
  static final CalendarSystem Iso = _StaticConstructor();

  /// Returns a Hebrew calendar, as described at https://en.wikipedia.org/wiki/Hebrew_calendar. This is a
  /// purely mathematical calculator, applied proleptically to the period where the real calendar was observational.
  ///
  /// Please note that support for the Hebrew calendar is somewhat experimental,
  /// particularly in terms of calculations involving adding or subtracting years. Additionally, text formatting
  /// and parsing using month names is not currently supported, due to the challenges of handling leap months.
  /// It is hoped that this will be improved in future versions.
  ///
  /// The implementation for this was taken from https://www.cs.tau.ac.il/~nachum/calendar-book/papers/calendar.ps,
  /// which is a public domain algorithm presumably equivalent to that given in the Calendrical Calculations book
  /// by the same authors (Nachum Dershowitz and Edward Reingold).
  ///
  /// [monthNumbering]: The month numbering system to use
  ///
  /// Returns a Hebrew calendar system for the given month numbering.
  static CalendarSystem GetHebrewCalendar(HebrewMonthNumbering monthNumbering) {
    Preconditions.CheckArgumentRange('monthNumbering', monthNumbering.value, 1, 2);
    return _HebrewCalendars.ByMonthNumbering[monthNumbering.value - 1];
  }

  /// Returns the Badíʿ (meaning "wondrous" or "unique") calendar, as described at https://en.wikipedia.org/wiki/Badi_calendar.
  /// This is a purely solar calendar with years starting at the vernal equinox.
  ///
  /// The Badíʿ calendar was developed and defined by the founders of the Bahá'í Faith in the mid to late
  /// 1800's A.D. The first year in the calendar coincides with 1844 A.D. Years are labeled "B.E." for Bahá'í Era.
  ///
  /// A year consists of 19 months, each with 19 days. Each day starts at sunset. Years are grouped into sets
  /// of 19 "Unities" (Váḥid) and 19 Unities make up 1 "All Things" (Kull-i-Shay’).
  ///
  /// A period of days (usually 4 or 5, called Ayyám-i-Há) occurs between the 18th and 19th months. The length of this
  /// period of intercalary days is solely determined by the date of the following vernal equinox. The vernal equinox is
  /// a momentary point in time, so the "date" of the equinox is determined by the date (beginning
  /// at sunset) in effect in Tehran, Iran at the moment of the equinox.
  ///
  /// In this Noda Time implementation, days start at midnight and lookup tables are used to determine vernal equinox dates.
  /// Ayyám-i-Há is internally modelled as extra days added to the 18th month. As a result, a few functions will
  /// not work as expected for Ayyám-i-Há, such as EndOfMonth.
  static CalendarSystem get Badi => _MiscellaneousCalendars.Badi;

  /// Returns an Islamic, or Hijri, calendar system.
  ///
  /// This returns a tabular calendar, rather than one based on lunar observation. This calendar is a
  /// lunar calendar with 12 months, each of 29 or 30 days, resulting in a year of 354 days (or 355 on a leap
  /// year).
  ///
  /// Year 1 in the Islamic calendar began on July 15th or 16th, 622 CE (Julian), thus
  /// Islamic years do not begin at the same time as Julian years. This calendar
  /// is not proleptic, as it does not allow dates before the first Islamic year.
  ///
  /// There are two basic forms of the Islamic calendar, the tabular and the
  /// observed. The observed form cannot easily be used by computers as it
  /// relies on human observation of the new moon. The tabular calendar, implemented here, is an
  /// arithmetic approximation of the observed form that follows relatively simple rules.
  ///
  /// You should choose an epoch based on which external system you wish
  /// to be compatible with. The epoch beginning on July 16th is the more common
  /// one for the tabular calendar, so using [IslamicEpoch.Civil]
  /// would usually be a logical choice. However, Windows uses July 15th, so
  /// if you need to be compatible with other Windows systems, you may wish to use
  /// [IslamicEpoch.Astronomical]. The fact that the Islamic calendar
  /// traditionally starts at dusk, a Julian day traditionally starts at noon,
  /// and all calendar systems in Noda Time start their days at midnight adds
  /// somewhat inevitable confusion to the mix, unfortunately.
  ///
  /// The tabular form of the calendar defines 12 months of alternately
  /// 30 and 29 days. The last month is extended to 30 days in a leap year.
  /// Leap years occur according to a 30 year cycle. There are four recognised
  /// patterns of leap years in the 30 year cycle:
  ///
  /// | Origin | Leap years |
  /// |---|---|
  /// | Kūshyār ibn Labbān | 2, 5, 7, 10, 13, 15, 18, 21, 24, 26, 29 |
  /// | al-Fazārī | 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29 |
  /// | Fātimid (also known as Misri or Bohra) | 2, 5, 8, 10, 13, 16, 19, 21, 24, 27, 29 |
  /// | Habash al-Hasib | 2, 5, 8, 11, 13, 16, 19, 21, 24, 27, 30 |
  ///
  /// The leap year pattern to use is determined from the first parameter to this factory method.
  /// The second parameter determines which epoch is used - the "astronomical" or "Thursday" epoch
  /// (July 15th 622CE) or the "civil" or "Friday" epoch (July 16th 622CE).
  ///
  /// This implementation defines a day as midnight to midnight exactly as per
  /// the ISO calendar. This correct start of day is at sunset on the previous
  /// day, however this cannot readily be modelled and has been ignored.
  ///
  /// [leapYearPattern]: The pattern of years in the 30-year cycle to consider as leap years
  /// [epoch]: The kind of epoch to use (astronomical or civil)
  ///
  /// Returns a suitable Islamic calendar reference; the same reference may be returned by several
  /// calls as the object is immutable and thread-safe.
  static CalendarSystem GetIslamicCalendar(IslamicLeapYearPattern leapYearPattern, IslamicEpoch epoch) {
    Preconditions.CheckArgumentRange('leapYearPattern', leapYearPattern.value, 1, 4);
    Preconditions.CheckArgumentRange('epoch', epoch.value, 1, 2);
    return _IslamicCalendars.ByLeapYearPatternAndEpoch[leapYearPattern.value - 1][epoch.value - 1];
  }

  // #endregion

  // Other fields back read-only automatic properties.
  final EraCalculator _eraCalculator;

  CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorSingleEra(CalendarOrdinal ordinal, String id, String name,
      nt.YearMonthDayCalculator yearMonthDayCalculator, Era singleEra)
      : this._NewOrdinalIdNameYearMonthDayCalculatorEraCalculator(ordinal, id, name, yearMonthDayCalculator,
            SingleEraCalculator.NewEraYmdCalculator(singleEra, yearMonthDayCalculator));

  CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorEraCalculator(CalendarOrdinal ordinal, String id, String name,
      nt.YearMonthDayCalculator yearMonthDayCalculator, EraCalculator eraCalculator)
      : Ordinal = ordinal,
        Id = id,
        Name = name,
        YearMonthDayCalculator = yearMonthDayCalculator,
        MinYear = yearMonthDayCalculator.MinYear,
        MaxYear = yearMonthDayCalculator.MaxYear,
        MinDays = yearMonthDayCalculator.GetStartOfYearInDays(yearMonthDayCalculator.MinYear),
        MaxDays = yearMonthDayCalculator.GetStartOfYearInDays(yearMonthDayCalculator.MaxYear + 1) - 1,
        // We trust the construction code not to mutate the array...
        _eraCalculator = eraCalculator {
    _CalendarByOrdinal[ordinal.value] = this;
  }

  /// Returns the unique identifier for this calendar system. This is provides full round-trip capability
  /// using [ForId] to retrieve the calendar system from the identifier.
  ///
  /// A unique ID for a calendar is required when serializing types which include a [CalendarSystem].
  /// As of 2 Nov 2012 (ISO calendar) there are no ISO or RFC standards for naming a calendar system. As such,
  /// the identifiers provided here are specific to Noda Time, and are not guaranteed to interoperate with any other
  /// date and time API.
  ///
  /// | Calendar ID | Equivalent factory method or property |
  /// |---|---|
  /// | ISO | [CalendarSystem.Iso] |
  /// | Gregorian | [CalendarSystem.Gregorian] |
  /// | Coptic | [CalendarSystem.Coptic] |
  /// | Badi | [CalendarSystem.Badi] |
  /// | Julian | [CalendarSystem.Julian] |
  /// | Hijri Civil-Indian | [CalendarSystem.GetIslamicCalendar](IslamicLeapYearPattern.Indian, IslamicEpoch.Civil) |
  /// | Hijri Civil-Base15 | [CalendarSystem.GetIslamicCalendar](IslamicLeapYearPattern.Base15, IslamicEpoch.Civil) |
  /// | Hijri Civil-Base16 | [CalendarSystem.GetIslamicCalendar](IslamicLeapYearPattern.Base16, IslamicEpoch.Civil) |
  /// | Hijri Civil-HabashAlHasib | [CalendarSystem.GetIslamicCalendar](IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Civil) |
  /// | Hijri Astronomical-Indian | [CalendarSystem.GetIslamicCalendar](IslamicLeapYearPattern.Indian, IslamicEpoch.Astronomical) |
  /// | Hijri Astronomical-Base15 | [CalendarSystem.GetIslamicCalendar](IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical) |
  /// | Hijri Astronomical-Base16 | [CalendarSystem.GetIslamicCalendar](IslamicLeapYearPattern.Base16, IslamicEpoch.Astronomical) |
  /// | Hijri Astronomical-HabashAlHasib | [CalendarSystem.GetIslamicCalendar](IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Astronomical) |
  /// | Persian Simple | [CalendarSystem.PersianSimple] |
  /// | Persian Arithmetic | [CalendarSystem.PersianArithmetic] |
  /// | Persian Algorithmic | [CalendarSystem.PersianAstronomical] (see note) |
  /// | Um Al Qura | [CalendarSystem.UmAlQura]() |
  /// | Hebrew Civil | [CalendarSystem.HebrewCivil] |
  /// | Hebrew Scriptural | [CalendarSystem.HebrewScriptural] |
  ///
  /// The ID "Persian Algorithmic" for the Persian Astronomical calendar is an unfortunate error. The ID has been incorrect
  /// in Noda Time for so long that "fixing" it now would cause compatibility issues between systems storing or
  /// exchanging Noda Time data.
  final String Id;

  /// Returns the name of this calendar system. Each kind of calendar system has a unique name, but this
  /// does not usually provide enough information for round-tripping. (For example, the name of an
  /// Islamic calendar system does not indicate which kind of leap cycle it uses.)
  final String Name;

  /// Gets the minimum valid year (inclusive) within this calendar.
  final int MinYear;

  /// Gets the maximum valid year (inclusive) within this calendar.
  final int MaxYear;

  /// Returns the minimum day number this calendar can handle.
  @internal
  final int MinDays;

  /// Returns the maximum day number (inclusive) this calendar can handle.
  @internal
  final int MaxDays;

  /// Returns the ordinal value of this calendar.
  @internal
  final CalendarOrdinal Ordinal;

  // #region Era-based members

  /// Gets a read-only list of eras used in this calendar system.
  List<Era> get Eras => _eraCalculator.Eras;

  /// Returns the default era to use when a year-of-era is supplied without
  /// an explicit era.
  @internal
  Era get DefaultEra => _eraCalculator.DefaultEra;

  /// Returns the "absolute year" (the one used throughout most of the API, without respect to eras)
  /// from a year-of-era and an era.
  ///
  /// For example, in the Gregorian and Julian calendar systems, the BCE era starts at year 1, which is
  /// equivalent to an "absolute year" of 0 (then BCE year 2 has an absolute year of -1, and so on).  The absolute
  /// year is the year that is used throughout the API; year-of-era is typically used primarily when formatting
  /// and parsing date values to and from text.
  ///
  /// [yearOfEra]: The year within the era.
  /// [era]: The era in which to consider the year
  ///
  /// Returns the absolute year represented by the specified year of era.
  ///
  /// Throws [RangeError] if [yearOfEra] is out of the range of years for the given era.
  /// Throws [ArgumentError] if [era] is not an era used in this calendar.
  int GetAbsoluteYear(int yearOfEra, Era era) => _eraCalculator.GetAbsoluteYear(yearOfEra, era);

  /// Returns the maximum valid year-of-era in the given era.
  ///
  /// Note that depending on the calendar system, it's possible that only
  /// part of the returned year falls within the given era. It is also possible that
  /// the returned value represents the earliest year of the era rather than the latest
  /// year. (See the BC era in the Gregorian calendar, for example.)
  ///
  /// [era]: The era in which to find the greatest year
  ///
  /// Returns the maximum valid year in the given era.
  ///
  /// Throws [ArgumentError] if [era] is not an era used in this calendar.
  int GetMaxYearOfEra(Era era) => _eraCalculator.GetMaxYearOfEra(era);

  /// Returns the minimum valid year-of-era in the given era.
  ///
  /// Note that depending on the calendar system, it's possible that only
  /// part of the returned year falls within the given era. It is also possible that
  /// the returned value represents the latest year of the era rather than the earliest
  /// year. (See the BC era in the Gregorian calendar, for example.)
  ///
  /// [era]: The era in which to find the greatest year
  ///
  /// Returns the minimum valid year in the given era.
  ///
  /// Throws [ArgumentError] if [era] is not an era used in this calendar.
  int GetMinYearOfEra(Era era) => _eraCalculator.GetMinYearOfEra(era);

  // #endregion

  @internal
  final nt.YearMonthDayCalculator YearMonthDayCalculator;

  @internal
  YearMonthDayCalendar GetYearMonthDayCalendarFromDaysSinceEpoch(int daysSinceEpoch) {
    Preconditions.CheckArgumentRange('daysSinceEpoch', daysSinceEpoch, MinDays, MaxDays);
    return YearMonthDayCalculator.GetYearMonthDayDaysSinceEpoch(daysSinceEpoch).WithCalendarOrdinal(Ordinal);
  }

  // #region object overrides

  /// Converts this calendar system to text by simply returning its unique ID.
  ///
  /// Returns the ID of this calendar system.
  @override
  String toString() => Id;

  // #endregion

  /// Returns the number of days since the Unix epoch (1970-01-01 ISO) for the given date.
  @internal
  int GetDaysSinceEpoch(YearMonthDay yearMonthDay) {
    DebugValidateYearMonthDay(yearMonthDay);
    return YearMonthDayCalculator.GetDaysSinceEpoch(yearMonthDay);
  }

  /// Returns the IsoDayOfWeek corresponding to the day of week for the given year, month and day.
  ///
  /// [yearMonthDay]: The year, month and day to use to find the day of the week
  ///
  /// Returns the day of the week as an IsoDayOfWeek
  @internal
  IsoDayOfWeek GetDayOfWeek(YearMonthDay yearMonthDay) {
    DebugValidateYearMonthDay(yearMonthDay);
    int daysSinceEpoch = YearMonthDayCalculator.GetDaysSinceEpoch(yearMonthDay);
    int numericDayOfWeek =
        daysSinceEpoch >= -3 ? 1 + ((daysSinceEpoch + 3).remainder(7)) : 7 + ((daysSinceEpoch + 4).remainder(7));
    return IsoDayOfWeek(numericDayOfWeek);
  }

  /// Returns the number of days in the given year.
  ///
  /// [year]: The year to determine the number of days in
  ///
  /// Throws [RangeError] if the given year is invalid for this calendar.
  ///
  /// Returns the number of days in the given year.
  int GetDaysInYear(int year) {
    Preconditions.CheckArgumentRange('year', year, MinYear, MaxYear);
    return YearMonthDayCalculator.GetDaysInYear(year);
  }

  /// Returns the number of days in the given month within the given year.
  ///
  /// [year]: The year in which to consider the month
  /// [month]: The month to determine the number of days in
  ///
  /// Throws [RangeError] if the given year / month combination
  /// is invalid for this calendar.
  ///
  /// Returns the number of days in the given month and year.
  int GetDaysInMonth(int year, int month) {
    // Simplest way to validate the year and month. Assume it's quick enough to validate the day...
    ValidateYearMonthDay(year, month, 1);
    return YearMonthDayCalculator.GetDaysInMonth(year, month);
  }

  /// Returns whether or not the given year is a leap year in this calendar.
  ///
  /// [year]: The year to consider.
  ///
  /// Throws [RangeError] if the given year is invalid for this calendar.
  /// Note that some implementations may return a value rather than throw this exception. Failure to throw an
  /// exception should not be treated as an indication that the year is valid.
  ///
  /// Returns true if the given year is a leap year; false otherwise.
  bool IsLeapYear(int year) {
    Preconditions.CheckArgumentRange('year', year, MinYear, MaxYear);
    return YearMonthDayCalculator.IsLeapYear(year);
  }

  /// Returns the maximum valid month (inclusive) within this calendar in the given year.
  ///
  /// It is assumed that in all calendars, every month between 1 and this month
  /// number is valid for the given year. This does not necessarily mean that the first month of the year
  /// is 1, however. (See the Hebrew calendar system using the scriptural month numbering system for example.)
  ///
  /// [year]: The year to consider.
  ///
  /// Throws [RangeError] if the given year is invalid for this calendar.
  /// Note that some implementations may return a month rather than throw this exception (for example, if all
  /// years have the same number of months in this calendar system). Failure to throw an exception should not be
  /// treated as an indication that the year is valid.
  ///
  /// Returns the maximum month number within the given year.
  int GetMonthsInYear(int year) {
    Preconditions.CheckArgumentRange('year', year, MinYear, MaxYear);
    return YearMonthDayCalculator.GetMonthsInYear(year);
  }

  @internal
  void ValidateYearMonthDay(int year, int month, int day) {
    YearMonthDayCalculator.ValidateYearMonthDay(year, month, day);
  }

  @internal
  int Compare(YearMonthDay lhs, YearMonthDay rhs) {
    DebugValidateYearMonthDay(lhs);
    DebugValidateYearMonthDay(rhs);
    return YearMonthDayCalculator.Compare(lhs, rhs);
  }

  // #region "Getter" methods which used to be DateTimeField

  @internal
  int GetDayOfYear(YearMonthDay yearMonthDay) {
    DebugValidateYearMonthDay(yearMonthDay);
    return YearMonthDayCalculator.GetDayOfYear(yearMonthDay);
  }

  @internal
  int GetYearOfEra(int absoluteYear) {
    Preconditions.DebugCheckArgumentRange('absoluteYear', absoluteYear, MinYear, MaxYear);
    return _eraCalculator.GetYearOfEra(absoluteYear);
  }

  @internal
  Era GetEra(int absoluteYear) {
    Preconditions.DebugCheckArgumentRange('absoluteYear', absoluteYear, MinYear, MaxYear);
    return _eraCalculator.GetEra(absoluteYear);
  }

  /// In debug configurations only, this method calls [ValidateYearMonthDay]
  /// with the components of the given YearMonthDay, ensuring that it's valid in the
  /// current calendar.
  ///
  /// [yearMonthDay]: The value to validate.
  ///
  /// noda_dart: C#'s `[Conditional("DEBUG")]` is an `assert`.
  @internal
  void DebugValidateYearMonthDay(YearMonthDay yearMonthDay) {
    // Avoid the line even being compiled in a release build...
    assert(() {
      ValidateYearMonthDay(yearMonthDay.Year, yearMonthDay.Month, yearMonthDay.Day);
      return true;
    }());
  }

  // #endregion

  /// Returns a Gregorian calendar system.
  ///
  /// The Gregorian calendar system defines every
  /// fourth year as leap, unless the year is divisible by 100 and not by 400.
  /// This improves upon the Julian calendar leap year rule.
  ///
  /// Although the Gregorian calendar did not exist before 1582 CE, this
  /// calendar system assumes it did, thus it is proleptic. This implementation also
  /// fixes the start of the year at January 1.
  static CalendarSystem get Gregorian => _GregorianJulianCalendars.Gregorian;

  /// Returns a pure proleptic Julian calendar system, which defines every
  /// fourth year as a leap year. This implementation follows the leap year rule
  /// strictly, even for dates before 8 CE, where leap years were actually
  /// irregular.
  ///
  /// Although the Julian calendar did not exist before 45 BCE, this calendar
  /// assumes it did, thus it is proleptic. This implementation also fixes the
  /// start of the year at January 1.
  static CalendarSystem get Julian => _GregorianJulianCalendars.Julian;

  /// Returns a Coptic calendar system, which defines every fourth year as
  /// leap, much like the Julian calendar. The year is broken down into 12 months,
  /// each 30 days in length. An extra period at the end of the year is either 5
  /// or 6 days in length. In this implementation, it is considered a 13th month.
  ///
  /// Year 1 in the Coptic calendar began on August 29, 284 CE (Julian), thus
  /// Coptic years do not begin at the same time as Julian years. This calendar
  /// is not proleptic, as it does not allow dates before the first Coptic year.
  ///
  /// This implementation defines a day as midnight to midnight exactly as per
  /// the ISO calendar. Some references indicate that a Coptic day starts at
  /// sunset on the previous ISO day, but this has not been confirmed and is not
  /// implemented.
  static CalendarSystem get Coptic => _MiscellaneousCalendars.Coptic;

  /// Returns an Islamic calendar system equivalent to the one used by the BCL HijriCalendar.
  ///
  /// This uses the [IslamicLeapYearPattern.Base16] leap year pattern and the
  /// [IslamicEpoch.Astronomical] epoch. This is equivalent to HijriCalendar
  /// when the `HijriCalendar.HijriAdjustment` is 0.
  ///
  /// See also [CalendarSystem.GetIslamicCalendar].
  static CalendarSystem get IslamicBcl => GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Astronomical);

  /// Returns a Persian (also known as Solar Hijri) calendar system implementing the behaviour of the
  /// BCL `PersianCalendar` before .NET 4.6, and the sole Persian calendar in Noda Time 1.3.
  ///
  /// This implementation uses a simple 33-year leap cycle, where years  1, 5, 9, 13, 17, 22, 26, and 30
  /// in each cycle are leap years.
  static CalendarSystem get PersianSimple => _PersianCalendars.Simple;

  /// Returns a Persian (also known as Solar Hijri) calendar system implementing the behaviour
  /// proposed by Ahmad Birashk with nested cycles of years determining which years are leap years.
  ///
  /// This calendar is also known as the algorithmic Solar Hijri calendar.
  static CalendarSystem get PersianArithmetic => _PersianCalendars.Arithmetic;

  /// Returns a Persian (also known as Solar Hijri) calendar system implementing the behaviour of the
  /// BCL `PersianCalendar` from .NET 4.6 onwards (and Windows 10), and the astronomical
  /// system described in Wikipedia and Calendrical Calculations.
  ///
  /// This implementation uses data derived from the .NET 4.6 implementation (with the data built into Noda Time, so there's
  /// no BCL dependency) for simplicity; the actual implementation involves computing the time of noon in Iran, and
  /// is complex.
  static CalendarSystem get PersianAstronomical => _PersianCalendars.Astronomical;

  /// Returns a Hebrew calendar system using the civil month numbering,
  /// equivalent to the one used by the BCL HebrewCalendar.
  ///
  /// See also [CalendarSystem.GetHebrewCalendar].
  static CalendarSystem get HebrewCivil => GetHebrewCalendar(HebrewMonthNumbering.Civil);

  /// Returns a Hebrew calendar system using the scriptural month numbering.
  ///
  /// See also [CalendarSystem.GetHebrewCalendar].
  static CalendarSystem get HebrewScriptural => GetHebrewCalendar(HebrewMonthNumbering.Scriptural);

  /// Returns an Um Al Qura calendar system - an Islamic calendar system primarily used by
  /// Saudi Arabia.
  ///
  /// This is a tabular calendar, relying on pregenerated data.
  static CalendarSystem get UmAlQura => _MiscellaneousCalendars.UmAlQura;
}

// "Holder" classes for lazy initialization of calendar systems
// (noda_dart: top-level, as Dart has no nested types; static fields are lazy.)

abstract final class _PersianCalendars {
  static final CalendarSystem Simple = CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
      CalendarOrdinal.PersianSimple, _PersianSimpleId, _PersianName, PersianYearMonthDayCalculatorSimple.New(), Era.AnnoPersico);
  static final CalendarSystem Arithmetic = CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
      CalendarOrdinal.PersianArithmetic, _PersianArithmeticId, _PersianName, PersianYearMonthDayCalculatorArithmetic.New(), Era.AnnoPersico);
  static final CalendarSystem Astronomical = CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
      CalendarOrdinal.PersianAstronomical, _PersianAstronomicalId, _PersianName, PersianYearMonthDayCalculatorAstronomical.New(), Era.AnnoPersico);

  // Static constructor to enforce laziness.
}

/// Specifically the calendars implemented by IslamicYearMonthDayCalculator, as opposed to all
/// Islam-based calendars (which would include UmAlQura and Persian, for example).
abstract final class _IslamicCalendars {
  // C#: a [4, 2] rectangular array; here a list of lists, indexed [leapYearPattern - 1][epoch - 1].
  static final List<List<CalendarSystem>> ByLeapYearPatternAndEpoch = _StaticConstructor();

  static List<List<CalendarSystem>> _StaticConstructor() {
    var byLeapYearPatternAndEpoch = <List<CalendarSystem>>[];
    for (int i = 1; i <= 4; i++) {
      var row = <CalendarSystem>[];
      for (int j = 1; j <= 2; j++) {
        var leapYearPattern = IslamicLeapYearPattern(i);
        var epoch = IslamicEpoch(j);
        var calculator = IslamicYearMonthDayCalculator.NewLeapYearPatternEpoch(IslamicLeapYearPattern(i), IslamicEpoch(j));
        CalendarOrdinal ordinal = CalendarOrdinal(CalendarOrdinal.IslamicAstronomicalBase15.value + (i - 1) + (j - 1) * 4);
        row.add(CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
            ordinal, CalendarSystem.GetIslamicId(leapYearPattern, epoch), _IslamicName, calculator, Era.AnnoHegirae));
      }
      byLeapYearPatternAndEpoch.add(List<CalendarSystem>.unmodifiable(row));
    }
    return List<List<CalendarSystem>>.unmodifiable(byLeapYearPatternAndEpoch);
  }
}

/// Odds and ends, with an assumption that it's not *that* painful to initialize UmAlQura if you only
/// need Coptic, for example.
abstract final class _MiscellaneousCalendars {
  static final CalendarSystem Coptic = CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
      CalendarOrdinal.Coptic, _CopticId, _CopticName, CopticYearMonthDayCalculator.New(), Era.AnnoMartyrum);
  static final CalendarSystem UmAlQura = CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
      CalendarOrdinal.UmAlQura, _UmAlQuraId, _UmAlQuraName, UmAlQuraYearMonthDayCalculator.New(), Era.AnnoHegirae);
  static final CalendarSystem Badi = CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorSingleEra(
      CalendarOrdinal.Badi, _BadiId, _BadiName, BadiYearMonthDayCalculator.New(), Era.Bahai);

  // Static constructor to enforce laziness. This used to be important to avoid a Heisenbug.
  // I don't believe it's strictly required now, but it does no harm and I don't want to go
  // through the pain I went through before. Besides, very few users will actually want these
  // calendars, so making this fully lazy avoids unnecessary initialization.
}

abstract final class _GregorianJulianCalendars {
  static CalendarSystem get Gregorian => _StaticConstructor.$1;
  static CalendarSystem get Julian => _StaticConstructor.$2;

  // C#: the static constructor, which initializes Gregorian and Julian (run on first use).
  static final (CalendarSystem, CalendarSystem) _StaticConstructor = () {
    var julianCalculator = JulianYearMonthDayCalculator.New();
    var Julian = CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorEraCalculator(
        CalendarOrdinal.Julian, _JulianId, _JulianName, julianCalculator, GJEraCalculator.NewYmdCalculator(julianCalculator));
    var Gregorian = CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorEraCalculator(CalendarOrdinal.Gregorian,
        _GregorianId, _GregorianName, CalendarSystem.Iso.YearMonthDayCalculator, CalendarSystem.Iso._eraCalculator);
    return (Gregorian, Julian);
  }();
}

abstract final class _HebrewCalendars {
  static final List<CalendarSystem> ByMonthNumbering = List<CalendarSystem>.unmodifiable([
    CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorSingleEra(CalendarOrdinal.HebrewCivil, _HebrewCivilId, _HebrewName,
        HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering.Civil), Era.AnnoMundi),
    CalendarSystem._NewOrdinalIdNameYearMonthDayCalculatorSingleEra(CalendarOrdinal.HebrewScriptural, _HebrewScripturalId,
        _HebrewName, HebrewYearMonthDayCalculator.NewMonthNumbering(HebrewMonthNumbering.Scriptural), Era.AnnoMundi)
  ]);

  // Static constructor to enforce laziness.
}
