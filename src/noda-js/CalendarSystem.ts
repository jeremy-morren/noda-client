// Ported from NodaTime 3.3.7: src/NodaTime/CalendarSystem.cs
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import {
  CalendarOrdinal,
  CopticYearMonthDayCalculator,
  Era,
  GJEraCalculator,
  GregorianYearMonthDayCalculator,
  IsoDayOfWeek,
  JulianYearMonthDayCalculator,
  Preconditions,
  SingleEraCalculator,
  type EraCalculator,
  type YearMonthDay,
  type YearMonthDayCalculator,
  type YearMonthDayCalendar,
} from "./internal.ts";
import { NewInvalidOperationException, NewKeyNotFoundException, NewNotSupportedException, type ArgumentException, type ArgumentOutOfRangeException, type KeyNotFoundException, type NotSupportedException } from "./internal.ts";

// noda-js: CalendarSystem has the ISO, Gregorian, Julian and Coptic calendar systems. The others (Hebrew, Islamic,
// Persian, Um Al Qura and Badíʿ) are exported by their entry points instead, under the names of the CalendarSystem
// members they replace (e.g. HebrewCivil and GetHebrewCalendar from noda-js/calendars/hebrew; noda-js/calendars/all
// has them all), so that a bundle only contains the calendars an app imports: nothing here refers to them. An entry
// point registers its calendar systems when it's imported (RegisterCalendar), so ForId, Ids and ForOrdinal include them
// from then on.

// IDs and names are separated out (usually with the ID either being the same as the name,
// or the base ID being the same as a name and then other IDs being formed from it.) The
// differentiation is only present for clarity.
const GregorianName = "Gregorian";
const GregorianId = GregorianName;

const IsoName = "ISO";
const IsoId = IsoName;

const CopticName = "Coptic";
const CopticId = CopticName;

// Not ported: BadiName, BadiId (noda-js/calendars/badi)

const JulianName = "Julian";
const JulianId = JulianName;

// Not ported: IslamicName, IslamicIdBase, GetIslamicId (noda-js/calendars/islamic)
// Not ported: PersianName, PersianIdBase, PersianSimpleId, PersianAstronomicalId, PersianArithmeticId (noda-js/calendars/persian)
// Not ported: HebrewName, HebrewIdBase, HebrewCivilId, HebrewScripturalId (noda-js/calendars/hebrew)
// Not ported: UmAlQuraName, UmAlQuraId (noda-js/calendars/umalqura)

// While we could implement some of these as auto-props, it probably adds more confusion than convenience.
const CalendarByOrdinal: (CalendarSystem | undefined)[] = [];

// C#: static constructor initializing Iso; made lazy as module evaluation mustn't depend on other modules.
let iso: CalendarSystem | undefined;

// Note: each factory method must return the same reference on every invocation.
// If the delegate calls a method, that method must have the same guarantee.
let idToFactoryMap: Map<string, () => CalendarSystem> | undefined;

function GetIdToFactoryMap(): Map<string, () => CalendarSystem> {
  return (idToFactoryMap ??= new Map<string, () => CalendarSystem>([
    [IsoId, () => CalendarSystem.Iso],
    [GregorianId, () => CalendarSystem.Gregorian],
    [CopticId, () => CalendarSystem.Coptic],
    [JulianId, () => CalendarSystem.Julian],
  ]));
}

/** The calendar systems registered by the calendar entry points (noda-js: see the top of this file), by ID. */
const RegisteredCalendars = new Map<string, CalendarSystem>();

/**
 * The entry point that exports the calendar system with the given ID, if it's one of NodaTime's other calendar systems
 * (by the IDs' prefixes: "Hebrew ...", "Hijri ...", "Persian ...", "Um Al Qura" and "Badi").
 */
function EntryPointForId(id: string): string | null {
  const families: [prefix: string, entryPoint: string][] = [
    ["Hebrew ", "hebrew"], ["Hijri ", "islamic"], ["Persian ", "persian"], ["Um Al Qura", "umalqura"], ["Badi", "badi"],
  ];
  for (const [prefix, entryPoint] of families) {
    if (id.lastIndexOf(prefix, 0) === 0) {
      return `noda-js/calendars/${entryPoint}`;
    }
  }
  return null;
}

/**
 * A calendar system maps the non-calendar-specific "local time line" to human concepts
 * such as years, months and days.
 *
 * Many developers will never need to touch this class, other than to potentially ask a calendar
 * how many days are in a particular year/month and the like. Noda Time defaults to using the ISO-8601
 * calendar anywhere that a calendar system is required but hasn't been explicitly specified.
 *
 * If you need to obtain a {@link CalendarSystem} instance, use one of the static properties or methods in this
 * class, such as the {@link Iso} property. (noda-js: the Hebrew, Islamic, Persian, Um Al Qura and Badíʿ calendar
 * systems are exported by their entry points, e.g. `GetHebrewCalendar` from noda-js/calendars/hebrew.)
 *
 * Although this class is currently sealed (as of Noda Time 1.2), in the future this decision may
 * be reversed. In any case, there is no current intention for third-party developers to be able to implement
 * their own calendar systems (for various reasons). If you require a calendar system which is not
 * currently supported, please file a feature request and we'll see what we can do.
 *
 * All calendar implementations are immutable and thread-safe. See the thread safety
 * section of the user guide for more information.
 */
export class CalendarSystem {
  // #region Public factory members for calendars
  /**
   * Fetches a calendar system by its unique identifier. This provides full round-tripping of a calendar
   * system. This method will always return the same reference for the same ID.
   * @param id The ID of the calendar system. This is case-sensitive.
   * @returns The calendar system with the given ID.
   * @see {@link Id}
   * @throws {KeyNotFoundException} No calendar system for the specified ID can be found.
   * @throws {NotSupportedException} The calendar system with the specified ID is known, but not supported on this platform.
   * (noda-js: one of NodaTime's other calendar systems, whose entry point hasn't been imported.)
   */
  static ForId(id: string): CalendarSystem {
    Preconditions.CheckNotNull(id, "id");
    const factory = GetIdToFactoryMap().get(id);
    if (factory !== undefined) {
      return factory();
    }
    const registered = RegisteredCalendars.get(id);
    if (registered !== undefined) {
      return registered;
    }
    const entryPoint = EntryPointForId(id);
    if (entryPoint !== null && CalendarSystem.KnownIds.indexOf(id) >= 0) {
      throw NewNotSupportedException(`The ${id} calendar system isn't loaded: import "${entryPoint}" (or "noda-js/calendars/all") to use it.`);
    }
    throw NewKeyNotFoundException(`No calendar system for ID ${id} exists`);
  }

  /**
   * The IDs of NodaTime's other calendar systems (in the calendar entry points), which {@link ForId} reports as not
   * supported until they're registered.
   */
  private static readonly KnownIds: readonly string[] = [
    "Persian Simple", "Persian Arithmetic", "Persian Algorithmic", "Hebrew Civil", "Hebrew Scriptural", "Badi", "Um Al Qura",
    "Hijri Civil-Indian", "Hijri Civil-Base15", "Hijri Civil-Base16", "Hijri Civil-HabashAlHasib",
    "Hijri Astronomical-Indian", "Hijri Astronomical-Base15", "Hijri Astronomical-Base16", "Hijri Astronomical-HabashAlHasib",
  ];

  /**
   * Registers a calendar system created by a calendar entry point (noda-js: see {@link CalendarSystem}), so that
   * {@link ForId}, {@link Ids} and ForOrdinal find it.
   * @internal
   */
  static RegisterCalendar(calendar: CalendarSystem): void {
    RegisteredCalendars.set(calendar.Id, calendar);
  }

  /**
   * Fetches a calendar system by its ordinal value, constructing it if necessary.
   * @internal
   */
  static ForOrdinal(ordinal: CalendarOrdinal): CalendarSystem {
    Preconditions.DebugCheckArgument(ordinal >= 0 && ordinal < CalendarOrdinal.Size, "ordinal",
      "Unknown ordinal value {0}", ordinal);
    // Avoid an array lookup for the overwhelmingly common case.
    if (ordinal === CalendarOrdinal.Iso) {
      return CalendarSystem.Iso;
    }
    const calendar = CalendarByOrdinal[ordinal];
    if (calendar !== undefined) {
      return calendar;
    }
    // Not found it in the array. This can happen if the calendar system was initialized in
    // a different thread, and the write to the array isn't visible in this thread yet.
    // A simple switch will do the right thing. This is separated out (directly below) to allow
    // it to be tested separately. (It may also help this method be inlined...) The return
    // statement below is unlikely to ever be hit by code coverage, as it's handling a very
    // unusual and hard-to-provoke situation.
    return CalendarSystem.ForOrdinalUncached(ordinal);
  }

  /**
   * Returns the IDs of all calendar systems available within Noda Time. The order of the keys is not guaranteed.
   * (noda-js: the ISO, Gregorian, Julian and Coptic calendar systems, and those of the calendar entry points that have
   * been imported.)
   */
  static get Ids(): readonly string[] {
    return [...GetIdToFactoryMap().keys(), ...RegisteredCalendars.keys()];
  }

  /**
   * Returns a calendar system that follows the rules of the ISO-8601 standard,
   * which is compatible with Gregorian for all modern dates.
   *
   * As of Noda Time 2.0, this calendar system is equivalent to Gregorian.
   * The only areas in which the calendars differed were around centuries, and the members
   * relating to those differences were removed in Noda Time 2.0.
   * The distinction between Gregorian and ISO has been maintained for the sake of simplicity, compatibility
   * and consistency.
   */
  static get Iso(): CalendarSystem {
    if (iso === undefined) {
      const gregorianCalculator = GregorianYearMonthDayCalculator.New();
      const gregorianEraCalculator = GJEraCalculator.NewYmdCalculator(gregorianCalculator);
      iso = new CalendarSystem(CalendarOrdinal.Iso, IsoId, IsoName, gregorianCalculator, gregorianEraCalculator);
    }
    return iso;
  }

  // Not ported: GetHebrewCalendar (noda-js/calendars/hebrew)
  // Not ported: Badi (noda-js/calendars/badi)
  // Not ported: GetIslamicCalendar (noda-js/calendars/islamic)

  // #endregion

  // Other fields back read-only automatic properties.
  private readonly _eraCalculator: EraCalculator;

  /**
   * C#: private CalendarSystem(CalendarOrdinal ordinal, string id, string name, YearMonthDayCalculator yearMonthDayCalculator, Era singleEra).
   * (noda-js: internal, for the calendar entry points.)
   * @internal
   */
  static NewOrdinalIdNameYearMonthDayCalculatorSingleEra(ordinal: CalendarOrdinal, id: string, name: string,
    yearMonthDayCalculator: YearMonthDayCalculator, singleEra: Era): CalendarSystem {
    return new CalendarSystem(ordinal, id, name, yearMonthDayCalculator, SingleEraCalculator.NewEraYmdCalculator(singleEra, yearMonthDayCalculator));
  }

  private constructor(ordinal: CalendarOrdinal, id: string, name: string, yearMonthDayCalculator: YearMonthDayCalculator, eraCalculator: EraCalculator) {
    this.Ordinal = ordinal;
    this._id = id;
    this._name = name;
    this.YearMonthDayCalculator = yearMonthDayCalculator;
    this._minYear = yearMonthDayCalculator.MinYear;
    this._maxYear = yearMonthDayCalculator.MaxYear;
    this.MinDays = yearMonthDayCalculator.GetStartOfYearInDays(this.MinYear);
    this.MaxDays = yearMonthDayCalculator.GetStartOfYearInDays(this.MaxYear + 1) - 1;
    // We trust the construction code not to mutate the array...
    this._eraCalculator = eraCalculator;
    CalendarByOrdinal[ordinal] = this;
  }

  private readonly _id: string;

  /**
   * Returns the unique identifier for this calendar system. This is provides full round-trip capability
   * using {@link ForId} to retrieve the calendar system from the identifier.
   *
   * A unique ID for a calendar is required when serializing types which include a {@link CalendarSystem}.
   * As of 2 Nov 2012 (ISO calendar) there are no ISO or RFC standards for naming a calendar system. As such,
   * the identifiers provided here are specific to Noda Time, and are not guaranteed to interoperate with any other
   * date and time API.
   *
   * | Calendar ID | Equivalent factory method or property |
   * |---|---|
   * | ISO | {@link CalendarSystem.Iso} |
   * | Gregorian | {@link CalendarSystem.Gregorian} |
   * | Coptic | {@link CalendarSystem.Coptic} |
   * | Badi | `Badi` (noda-js/calendars/badi) |
   * | Julian | {@link CalendarSystem.Julian} |
   * | Hijri Civil-Indian | `GetIslamicCalendar(IslamicLeapYearPattern.Indian, IslamicEpoch.Civil)` (noda-js/calendars/islamic) |
   * | Hijri Civil-Base15 | `GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil)` (noda-js/calendars/islamic) |
   * | Hijri Civil-Base16 | `GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil)` (noda-js/calendars/islamic) |
   * | Hijri Civil-HabashAlHasib | `GetIslamicCalendar(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Civil)` (noda-js/calendars/islamic) |
   * | Hijri Astronomical-Indian | `GetIslamicCalendar(IslamicLeapYearPattern.Indian, IslamicEpoch.Astronomical)` (noda-js/calendars/islamic) |
   * | Hijri Astronomical-Base15 | `GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Astronomical)` (noda-js/calendars/islamic) |
   * | Hijri Astronomical-Base16 | `GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Astronomical)` (noda-js/calendars/islamic) |
   * | Hijri Astronomical-HabashAlHasib | `GetIslamicCalendar(IslamicLeapYearPattern.HabashAlHasib, IslamicEpoch.Astronomical)` (noda-js/calendars/islamic) |
   * | Persian Simple | `PersianSimple` (noda-js/calendars/persian) |
   * | Persian Arithmetic | `PersianArithmetic` (noda-js/calendars/persian) |
   * | Persian Algorithmic | `PersianAstronomical` (noda-js/calendars/persian) (see note) |
   * | Um Al Qura | `UmAlQura` (noda-js/calendars/umalqura) |
   * | Hebrew Civil | `HebrewCivil` (noda-js/calendars/hebrew) |
   * | Hebrew Scriptural | `HebrewScriptural` (noda-js/calendars/hebrew) |
   *
   * The ID "Persian Algorithmic" for the Persian Astronomical calendar is an unfortunate error. The ID has been incorrect
   * in Noda Time for so long that "fixing" it now would cause compatibility issues between systems storing or
   * exchanging Noda Time data.
   */
  get Id(): string {
    return this._id;
  }

  private readonly _name: string;

  /**
   * Returns the name of this calendar system. Each kind of calendar system has a unique name, but this
   * does not usually provide enough information for round-tripping. (For example, the name of an
   * Islamic calendar system does not indicate which kind of leap cycle it uses.)
   */
  get Name(): string {
    return this._name;
  }

  private readonly _minYear: number;

  /**
   * Gets the minimum valid year (inclusive) within this calendar.
   */
  get MinYear(): number {
    return this._minYear;
  }

  private readonly _maxYear: number;

  /**
   * Gets the maximum valid year (inclusive) within this calendar.
   */
  get MaxYear(): number {
    return this._maxYear;
  }

  /**
   * Returns the minimum day number this calendar can handle.
   * @internal
   */
  readonly MinDays: number;

  /**
   * Returns the maximum day number (inclusive) this calendar can handle.
   * @internal
   */
  readonly MaxDays: number;

  /**
   * Returns the ordinal value of this calendar.
   * @internal
   */
  readonly Ordinal: CalendarOrdinal;

  // #region Era-based members

  /**
   * Gets a read-only list of eras used in this calendar system.
   */
  get Eras(): readonly Era[] {
    return this._eraCalculator.Eras;
  }

  /**
   * Returns the default era to use when a year-of-era is supplied without
   * an explicit era.
   * @internal
   */
  get DefaultEra(): Era {
    return this._eraCalculator.DefaultEra;
  }

  /**
   * Returns the "absolute year" (the one used throughout most of the API, without respect to eras)
   * from a year-of-era and an era.
   *
   * For example, in the Gregorian and Julian calendar systems, the BCE era starts at year 1, which is
   * equivalent to an "absolute year" of 0 (then BCE year 2 has an absolute year of -1, and so on).  The absolute
   * year is the year that is used throughout the API; year-of-era is typically used primarily when formatting
   * and parsing date values to and from text.
   *
   * @param yearOfEra The year within the era.
   * @param era The era in which to consider the year
   * @returns The absolute year represented by the specified year of era.
   * @throws {ArgumentOutOfRangeException} `yearOfEra` is out of the range of years for the given era.
   * @throws {ArgumentException} `era` is not an era used in this calendar.
   */
  GetAbsoluteYear(yearOfEra: number, era: Era): number {
    return this._eraCalculator.GetAbsoluteYear(yearOfEra, era);
  }

  /**
   * Returns the maximum valid year-of-era in the given era.
   *
   * Note that depending on the calendar system, it's possible that only
   * part of the returned year falls within the given era. It is also possible that
   * the returned value represents the earliest year of the era rather than the latest
   * year. (See the BC era in the Gregorian calendar, for example.)
   *
   * @param era The era in which to find the greatest year
   * @returns The maximum valid year in the given era.
   * @throws {ArgumentException} `era` is not an era used in this calendar.
   */
  GetMaxYearOfEra(era: Era): number {
    return this._eraCalculator.GetMaxYearOfEra(era);
  }

  /**
   * Returns the minimum valid year-of-era in the given era.
   *
   * Note that depending on the calendar system, it's possible that only
   * part of the returned year falls within the given era. It is also possible that
   * the returned value represents the latest year of the era rather than the earliest
   * year. (See the BC era in the Gregorian calendar, for example.)
   *
   * @param era The era in which to find the greatest year
   * @returns The minimum valid year in the given era.
   * @throws {ArgumentException} `era` is not an era used in this calendar.
   */
  GetMinYearOfEra(era: Era): number {
    return this._eraCalculator.GetMinYearOfEra(era);
  }

  // #endregion

  /** @internal */
  readonly YearMonthDayCalculator: YearMonthDayCalculator;

  /** @internal */
  GetYearMonthDayCalendarFromDaysSinceEpoch(daysSinceEpoch: number): YearMonthDayCalendar {
    Preconditions.CheckArgumentRange("daysSinceEpoch", daysSinceEpoch, this.MinDays, this.MaxDays);
    return this.YearMonthDayCalculator.GetYearMonthDay(daysSinceEpoch).WithCalendarOrdinal(this.Ordinal);
  }

  // #region object overrides

  /**
   * Converts this calendar system to text by simply returning its unique ID.
   * @returns The ID of this calendar system.
   */
  toString(): string {
    return this.Id;
  }

  // #endregion

  /**
   * Returns the number of days since the Unix epoch (1970-01-01 ISO) for the given date.
   * @internal
   */
  GetDaysSinceEpoch(yearMonthDay: YearMonthDay): number {
    this.DebugValidateYearMonthDay(yearMonthDay);
    return this.YearMonthDayCalculator.GetDaysSinceEpoch(yearMonthDay);
  }

  /**
   * Returns the IsoDayOfWeek corresponding to the day of week for the given year, month and day.
   * @param yearMonthDay The year, month and day to use to find the day of the week
   * @returns The day of the week as an IsoDayOfWeek
   * @internal
   */
  GetDayOfWeek(yearMonthDay: YearMonthDay): IsoDayOfWeek {
    this.DebugValidateYearMonthDay(yearMonthDay);
    const daysSinceEpoch = this.YearMonthDayCalculator.GetDaysSinceEpoch(yearMonthDay);
    const numericDayOfWeek = daysSinceEpoch >= -3 ? 1 + ((daysSinceEpoch + 3) % 7)
      : 7 + ((daysSinceEpoch + 4) % 7);
    return numericDayOfWeek as IsoDayOfWeek;
  }

  /**
   * Returns the number of days in the given year.
   * @param year The year to determine the number of days in
   * @throws {ArgumentOutOfRangeException} The given year is invalid for this calendar.
   * @returns The number of days in the given year.
   */
  GetDaysInYear(year: number): number {
    Preconditions.CheckArgumentRange("year", year, this.MinYear, this.MaxYear);
    return this.YearMonthDayCalculator.GetDaysInYear(year);
  }

  /**
   * Returns the number of days in the given month within the given year.
   * @param year The year in which to consider the month
   * @param month The month to determine the number of days in
   * @throws {ArgumentOutOfRangeException} The given year / month combination
   * is invalid for this calendar.
   * @returns The number of days in the given month and year.
   */
  GetDaysInMonth(year: number, month: number): number {
    // Simplest way to validate the year and month. Assume it's quick enough to validate the day...
    this.ValidateYearMonthDay(year, month, 1);
    return this.YearMonthDayCalculator.GetDaysInMonth(year, month);
  }

  /**
   * Returns whether or not the given year is a leap year in this calendar.
   * @param year The year to consider.
   * @throws {ArgumentOutOfRangeException} The given year is invalid for this calendar.
   * Note that some implementations may return a value rather than throw this exception. Failure to throw an
   * exception should not be treated as an indication that the year is valid.
   * @returns True if the given year is a leap year; false otherwise.
   */
  IsLeapYear(year: number): boolean {
    Preconditions.CheckArgumentRange("year", year, this.MinYear, this.MaxYear);
    return this.YearMonthDayCalculator.IsLeapYear(year);
  }

  /**
   * Returns the maximum valid month (inclusive) within this calendar in the given year.
   *
   * It is assumed that in all calendars, every month between 1 and this month
   * number is valid for the given year. This does not necessarily mean that the first month of the year
   * is 1, however. (See the Hebrew calendar system using the scriptural month numbering system for example.)
   *
   * @param year The year to consider.
   * @throws {ArgumentOutOfRangeException} The given year is invalid for this calendar.
   * Note that some implementations may return a month rather than throw this exception (for example, if all
   * years have the same number of months in this calendar system). Failure to throw an exception should not be
   * treated as an indication that the year is valid.
   * @returns The maximum month number within the given year.
   */
  GetMonthsInYear(year: number): number {
    Preconditions.CheckArgumentRange("year", year, this.MinYear, this.MaxYear);
    return this.YearMonthDayCalculator.GetMonthsInYear(year);
  }

  /** @internal */
  ValidateYearMonthDay(year: number, month: number, day: number): void {
    this.YearMonthDayCalculator.ValidateYearMonthDay(year, month, day);
  }

  /** @internal */
  Compare(lhs: YearMonthDay, rhs: YearMonthDay): number {
    this.DebugValidateYearMonthDay(lhs);
    this.DebugValidateYearMonthDay(rhs);
    return this.YearMonthDayCalculator.Compare(lhs, rhs);
  }

  // #region "Getter" methods which used to be DateTimeField

  /** @internal */
  GetDayOfYear(yearMonthDay: YearMonthDay): number {
    this.DebugValidateYearMonthDay(yearMonthDay);
    return this.YearMonthDayCalculator.GetDayOfYear(yearMonthDay);
  }

  /** @internal */
  GetYearOfEra(absoluteYear: number): number {
    Preconditions.DebugCheckArgumentRange("absoluteYear", absoluteYear, this.MinYear, this.MaxYear);
    return this._eraCalculator.GetYearOfEra(absoluteYear);
  }

  /** @internal */
  GetEra(absoluteYear: number): Era {
    Preconditions.DebugCheckArgumentRange("absoluteYear", absoluteYear, this.MinYear, this.MaxYear);
    return this._eraCalculator.GetEra(absoluteYear);
  }

  /**
   * In debug configurations only, this method calls {@link ValidateYearMonthDay}
   * with the components of the given YearMonthDay, ensuring that it's valid in the
   * current calendar.
   * @param yearMonthDay The value to validate.
   * @internal
   */
  DebugValidateYearMonthDay(yearMonthDay: YearMonthDay): void {
    // Avoid the line even being compiled in a release build...
    // (C#: [Conditional("DEBUG")] with the body inside #if DEBUG; this is a release build.)
    void yearMonthDay;
  }

  // #endregion

  /**
   * Returns a Gregorian calendar system.
   *
   * The Gregorian calendar system defines every
   * fourth year as leap, unless the year is divisible by 100 and not by 400.
   * This improves upon the Julian calendar leap year rule.
   *
   * Although the Gregorian calendar did not exist before 1582 CE, this
   * calendar system assumes it did, thus it is proleptic. This implementation also
   * fixes the start of the year at January 1.
   */
  static get Gregorian(): CalendarSystem {
    return GregorianJulianCalendars.Gregorian;
  }

  /**
   * Returns a pure proleptic Julian calendar system, which defines every
   * fourth year as a leap year. This implementation follows the leap year rule
   * strictly, even for dates before 8 CE, where leap years were actually
   * irregular.
   *
   * Although the Julian calendar did not exist before 45 BCE, this calendar
   * assumes it did, thus it is proleptic. This implementation also fixes the
   * start of the year at January 1.
   *
   * The same reference may be returned by several calls as the object is immutable and thread-safe.
   */
  static get Julian(): CalendarSystem {
    return GregorianJulianCalendars.Julian;
  }

  /**
   * Returns a Coptic calendar system, which defines every fourth year as
   * leap, much like the Julian calendar. The year is broken down into 12 months,
   * each 30 days in length. An extra period at the end of the year is either 5
   * or 6 days in length. In this implementation, it is considered a 13th month.
   *
   * Year 1 in the Coptic calendar began on August 29, 284 CE (Julian), thus
   * Coptic years do not begin at the same time as Julian years. This calendar
   * is not proleptic, as it does not allow dates before the first Coptic year.
   *
   * This implementation defines a day as midnight to midnight exactly as per
   * the ISO calendar. Some references indicate that a Coptic day starts at
   * sunset on the previous ISO day, but this has not been confirmed and is not
   * implemented.
   *
   * The same reference may be returned by several calls as the object is immutable and thread-safe.
   */
  static get Coptic(): CalendarSystem {
    return MiscellaneousCalendars.Coptic;
  }

  // Not ported: IslamicBcl (noda-js/calendars/islamic)
  // Not ported: PersianSimple, PersianArithmetic, PersianAstronomical (noda-js/calendars/persian)
  // Not ported: HebrewCivil, HebrewScriptural (noda-js/calendars/hebrew)
  // Not ported: UmAlQura (noda-js/calendars/umalqura)

  // TODO: Move this after fixing https://github.com/nodatime/nodatime/issues/1269
  /**
   * [VisibleForTesting]
   * @internal
   */
  static ForOrdinalUncached(ordinal: CalendarOrdinal): CalendarSystem {
    switch (ordinal) {
      // This entry is really just for completeness. We'd never get called with this.
      case CalendarOrdinal.Iso: return CalendarSystem.Iso;
      case CalendarOrdinal.Gregorian: return CalendarSystem.Gregorian;
      case CalendarOrdinal.Julian: return CalendarSystem.Julian;
      case CalendarOrdinal.Coptic: return CalendarSystem.Coptic;
      // noda-js: the other calendar systems are created by their entry points, which register them, and constructing
      // a calendar system puts it in CalendarByOrdinal.
      default: {
        for (const calendar of RegisteredCalendars.values()) {
          if (calendar.Ordinal === ordinal) {
            return calendar;
          }
        }
        throw NewInvalidOperationException(`Bug in Noda Time: calendar ordinal ${CalendarOrdinal[ordinal] ?? ordinal} missing from switch in CalendarSystem.ForOrdinal.`);
      }
    }
  }

  // "Holder" classes for lazy initialization of calendar systems
  // Not ported: PersianCalendars, IslamicCalendars, HebrewCalendars, and MiscellaneousCalendars' UmAlQura and Badi
  // (the calendar entry points)

  /** C#: the MiscellaneousCalendars holder's Coptic property initializer. @internal */
  static CreateCoptic(): CalendarSystem {
    return CalendarSystem.NewOrdinalIdNameYearMonthDayCalculatorSingleEra(CalendarOrdinal.Coptic, CopticId, CopticName,
      CopticYearMonthDayCalculator.New(), Era.AnnoMartyrum);
  }

  /** C#: the GregorianJulianCalendars holder's static constructor. @internal */
  static CreateGregorianJulianCalendars(): { readonly Gregorian: CalendarSystem; readonly Julian: CalendarSystem } {
    const julianCalculator = JulianYearMonthDayCalculator.New();
    const julian = new CalendarSystem(CalendarOrdinal.Julian, JulianId, JulianName, julianCalculator, GJEraCalculator.NewYmdCalculator(julianCalculator));
    const iso = CalendarSystem.Iso;
    const gregorian = new CalendarSystem(CalendarOrdinal.Gregorian, GregorianId, GregorianName, iso.YearMonthDayCalculator, iso._eraCalculator);
    return { Gregorian: gregorian, Julian: julian };
  }
}

// C#: private static class GregorianJulianCalendars, initialized on first use.
let gregorianJulianCalendars: { readonly Gregorian: CalendarSystem; readonly Julian: CalendarSystem } | undefined;
// C#: private static class MiscellaneousCalendars ("odds and ends"), initialized on first use.
let coptic: CalendarSystem | undefined;
const MiscellaneousCalendars = {
  get Coptic(): CalendarSystem {
    return (coptic ??= CalendarSystem.CreateCoptic());
  },
};

const GregorianJulianCalendars = {
  get Gregorian(): CalendarSystem {
    return (gregorianJulianCalendars ??= CalendarSystem.CreateGregorianJulianCalendars()).Gregorian;
  },
  get Julian(): CalendarSystem {
    return (gregorianJulianCalendars ??= CalendarSystem.CreateGregorianJulianCalendars()).Julian;
  },
};
