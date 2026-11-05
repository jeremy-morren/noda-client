// noda-js: the parts of System.Globalization.CultureInfo, DateTimeFormatInfo and CompareInfo that
// NodaTime reads. The data is generated from .NET by tools/NodaJs.Tools data, into src/noda-js/Cultures/*.generated.ts,
// and member names are .NET's (PascalCase), so ported code reads them as NodaTime reads the .NET objects.

import { ArgumentError, InvalidOperationError } from "../Utility/SystemExceptions.ts";
import { invariantCultureData } from "./InvariantCultureData.generated.ts";
import { PatternResources } from "./PatternResources.generated.ts";

/** Culture data as written by tools/NodaJs.Tools (data). */
export interface CultureData {
  /** The culture name (CultureInfo.Name), e.g. "es-ES"; "" for the invariant culture. */
  readonly Name: string;
  /** The culture's date and time formatting data (CultureInfo.DateTimeFormat). */
  readonly DateTimeFormat: DateTimeFormatData;
  /** NodaTime pattern resources that differ from the neutral ones (src/noda-js/Globalization/PatternResources.generated.ts). */
  readonly PatternResources?: Readonly<Record<string, string>>;
}

/** The members of .NET's DateTimeFormatInfo that NodaTime uses. */
export interface DateTimeFormatData {
  /** The .NET calendar type name, e.g. "GregorianCalendar". */
  readonly Calendar: string;
  /** The designator for hours before noon, e.g. "AM" (the `tt` pattern specifier). */
  readonly AMDesignator: string;
  /** The designator for hours after noon, e.g. "PM" (the `tt` pattern specifier). */
  readonly PMDesignator: string;
  /** The separator between hours, minutes and seconds (the `:` pattern specifier), e.g. ":". */
  readonly TimeSeparator: string;
  /** The separator between year, month and day (the `/` pattern specifier), e.g. "/". */
  readonly DateSeparator: string;
  /** The short date pattern (standard pattern `d`), e.g. "dd/MM/yyyy". */
  readonly ShortDatePattern: string;
  /** The long date pattern (standard pattern `D`), e.g. "dddd, d MMMM yyyy". */
  readonly LongDatePattern: string;
  /** The short time pattern (standard pattern `t`), e.g. "HH:mm". */
  readonly ShortTimePattern: string;
  /** The long time pattern (standard pattern `T`), e.g. "HH:mm:ss". */
  readonly LongTimePattern: string;
  /** The long date and long time pattern (standard pattern `F`), e.g. "dddd, d MMMM yyyy HH:mm:ss". */
  readonly FullDateTimePattern: string;
  /** The month and day pattern (.NET's `M` format), e.g. "d MMMM". */
  readonly MonthDayPattern: string;
  /** The year and month pattern (.NET's `Y` format), e.g. "MMMM yyyy". */
  readonly YearMonthPattern: string;
  /** The sortable (ISO 8601) date and time pattern (.NET's `s` format): "yyyy'-'MM'-'dd'T'HH':'mm':'ss". */
  readonly SortableDateTimePattern: string;
  /** The universal sortable date and time pattern (.NET's `u` format): "yyyy'-'MM'-'dd HH':'mm':'ss'Z'". */
  readonly UniversalSortableDateTimePattern: string;
  /** The RFC 1123 date and time pattern (.NET's `R` format): "ddd, dd MMM yyyy HH':'mm':'ss 'GMT'". */
  readonly RFC1123Pattern: string;
  /**
   * The full month names (the `MMMM` pattern specifier, standalone), January first: 13 entries, as in .NET (the last is
   * for a 13th month, and usually empty).
   */
  readonly MonthNames: readonly string[];
  /** The abbreviated month names (the `MMM` pattern specifier, standalone): 13 entries, like {@link MonthNames}. */
  readonly AbbreviatedMonthNames: readonly string[];
  /**
   * The full month names in the genitive case, used with a day (`d MMMM`) in languages that inflect them (e.g. Russian,
   * Polish): 13 entries, like {@link MonthNames}. The same as MonthNames where the language doesn't distinguish them.
   */
  readonly MonthGenitiveNames: readonly string[];
  /** The abbreviated month names in the genitive case (`d MMM`): 13 entries, like {@link MonthGenitiveNames}. */
  readonly AbbreviatedMonthGenitiveNames: readonly string[];
  /** The full day names (the `dddd` pattern specifier): 7 entries, Sunday first, as in .NET. */
  readonly DayNames: readonly string[];
  /** The abbreviated day names (the `ddd` pattern specifier): 7 entries, Sunday first. */
  readonly AbbreviatedDayNames: readonly string[];
  /** The shortest day names (e.g. "Su"): 7 entries, Sunday first. */
  readonly ShortestDayNames: readonly string[];
  /** The full era names (the `gg` pattern specifier): GetEraName(1..n) of the culture's calendar. */
  readonly EraNames: readonly string[];
  /** The abbreviated era names: GetAbbreviatedEraName(1..n) of the culture's calendar. */
  readonly AbbreviatedEraNames: readonly string[];
  /** The first day of the week, as a System.DayOfWeek value (0 = Sunday). */
  readonly FirstDayOfWeek: number;
  /**
   * How the first week of the year is chosen, as a System.Globalization.CalendarWeekRule value (0 = FirstDay,
   * 1 = FirstFullWeek, 2 = FirstFourDayWeek).
   */
  readonly CalendarWeekRule: number;
}

/**
 * Equivalent of System.IFormatProvider, as NodaTime uses it: a culture, or a DateTimeFormatInfo
 * on its own.
 */
export type IFormatProvider = NodaCultureInfo | DateTimeFormatInfo;

/** Equivalent of System.Globalization.CompareOptions (the values NodaTime uses). */
export enum CompareOptions {
  None = 0,
  IgnoreCase = 1,
  Ordinal = 0x40000000,
  OrdinalIgnoreCase = 0x10000000,
}

/**
 * Equivalent of System.Globalization.DateTimeFormatInfo: read-only culture formatting data.
 */
export class DateTimeFormatInfo implements DateTimeFormatData {
  /** @inheritDoc */
  readonly Calendar!: string;
  /** @inheritDoc */
  readonly AMDesignator!: string;
  /** @inheritDoc */
  readonly PMDesignator!: string;
  /** @inheritDoc */
  readonly TimeSeparator!: string;
  /** @inheritDoc */
  readonly DateSeparator!: string;
  /** @inheritDoc */
  readonly ShortDatePattern!: string;
  /** @inheritDoc */
  readonly LongDatePattern!: string;
  /** @inheritDoc */
  readonly ShortTimePattern!: string;
  /** @inheritDoc */
  readonly LongTimePattern!: string;
  /** @inheritDoc */
  readonly FullDateTimePattern!: string;
  /** @inheritDoc */
  readonly MonthDayPattern!: string;
  /** @inheritDoc */
  readonly YearMonthPattern!: string;
  /** @inheritDoc */
  readonly SortableDateTimePattern!: string;
  /** @inheritDoc */
  readonly UniversalSortableDateTimePattern!: string;
  /** @inheritDoc */
  readonly RFC1123Pattern!: string;
  /** @inheritDoc */
  readonly MonthNames!: readonly string[];
  /** @inheritDoc */
  readonly AbbreviatedMonthNames!: readonly string[];
  /** @inheritDoc */
  readonly MonthGenitiveNames!: readonly string[];
  /** @inheritDoc */
  readonly AbbreviatedMonthGenitiveNames!: readonly string[];
  /** @inheritDoc */
  readonly DayNames!: readonly string[];
  /** @inheritDoc */
  readonly AbbreviatedDayNames!: readonly string[];
  /** @inheritDoc */
  readonly ShortestDayNames!: readonly string[];
  /** @inheritDoc */
  readonly EraNames!: readonly string[];
  /** @inheritDoc */
  readonly AbbreviatedEraNames!: readonly string[];
  /** @inheritDoc */
  readonly FirstDayOfWeek!: number;
  /** @inheritDoc */
  readonly CalendarWeekRule!: number;

  constructor(data: DateTimeFormatData) {
    Object.assign(this, data);
  }

  /** Equivalent of DateTimeFormatInfo.GetEraName(int). */
  GetEraName(era: number): string {
    return this.EraNames[era - 1] ?? "";
  }

  /** Equivalent of DateTimeFormatInfo.GetAbbreviatedEraName(int). */
  GetAbbreviatedEraName(era: number): string {
    return this.AbbreviatedEraNames[era - 1] ?? "";
  }

  /** The invariant culture's format info. */
  static get InvariantInfo(): DateTimeFormatInfo {
    return NodaCultureInfo.InvariantCulture.DateTimeFormat;
  }
}

/**
 * Equivalent of System.Globalization.CompareInfo, for the culture-sensitive comparisons NodaTime's
 * parsers make. Backed by Intl.Collator; tested against .NET's results by test/golden/compare.
 */
export class CompareInfo {
  // null: the host has no usable Intl.Collator.
  private _ignoreCaseCollator: Intl.Collator | null | undefined;
  private _collator: Intl.Collator | null | undefined;

  constructor(readonly Name: string) {}

  /**
   * Equivalent of CompareInfo.Compare(string1, offset1, length1, string2, offset2, length2, options),
   * and of the shorter Compare(string1, string2, options) overload.
   */
  Compare(string1: string, string2: string, options?: CompareOptions): number;
  Compare(string1: string, offset1: number, length1: number, string2: string, offset2: number, length2: number, options?: CompareOptions): number;
  Compare(...args: unknown[]): number {
    let a: string;
    let b: string;
    let options: CompareOptions;
    if (typeof args[1] === "number") {
      const [s1, o1, l1, s2, o2, l2, opts] = args as [string, number, number, string, number, number, CompareOptions | undefined];
      a = s1.substring(o1, o1 + l1);
      b = s2.substring(o2, o2 + l2);
      options = opts ?? CompareOptions.None;
    } else {
      [a, b] = args as [string, string];
      options = (args[2] as CompareOptions | undefined) ?? CompareOptions.None;
    }
    switch (options) {
      case CompareOptions.Ordinal:
        return a < b ? -1 : a > b ? 1 : 0;
      case CompareOptions.OrdinalIgnoreCase: {
        const ua = a.toUpperCase();
        const ub = b.toUpperCase();
        return ua < ub ? -1 : ua > ub ? 1 : 0;
      }
      case CompareOptions.IgnoreCase: {
        const collator = (this._ignoreCaseCollator ??= CreateCollator(this.Locale, "accent"));
        if (collator !== null) {
          return Math.sign(collator.compare(a, b));
        }
        // Intl not available: case-insensitive ordinal comparison instead of culture-aware.
        const ua = a.toUpperCase();
        const ub = b.toUpperCase();
        return ua < ub ? -1 : ua > ub ? 1 : 0;
      }
      default: {
        const collator = (this._collator ??= CreateCollator(this.Locale, "variant"));
        if (collator !== null) {
          return Math.sign(collator.compare(a, b));
        }
        return a < b ? -1 : a > b ? 1 : 0;
      }
    }
  }

  /** Equivalent of CompareInfo.IsPrefix(source, prefix, options). */
  IsPrefix(source: string, prefix: string, options?: CompareOptions): boolean {
    return prefix.length <= source.length && this.Compare(source, 0, prefix.length, prefix, 0, prefix.length, options) === 0;
  }

  private get Locale(): string {
    return this.Name === "" ? "und" : this.Name;
  }
}

/**
 * Equivalent of System.Globalization.CultureInfo, holding only what NodaTime uses. Cultures are
 * immutable; use {@link NodaCultureInfo.FromData} to create one (e.g. a test culture with modified patterns).
 */
export class NodaCultureInfo {
  /** The culture name, e.g. "fr-FR"; "" for the invariant culture. */
  readonly Name: string;
  readonly DateTimeFormat: DateTimeFormatInfo;
  readonly CompareInfo: CompareInfo;
  private readonly _patternResourceOverrides: Readonly<Record<string, string>>;

  private constructor(data: CultureData) {
    this.Name = data.Name;
    this.DateTimeFormat = new DateTimeFormatInfo(data.DateTimeFormat);
    this.CompareInfo = new CompareInfo(data.Name);
    this._patternResourceOverrides = data.PatternResources ?? {};
  }

  /** Creates a culture from exported (or hand-modified) data. */
  static FromData(data: CultureData): NodaCultureInfo {
    return new NodaCultureInfo(data);
  }

  /**
   * Creates a culture from exported data and registers it for {@link CurrentCulture}: how the culture modules of
   * noda-js/cultures create their cultures.
   * @internal
   */
  static FromDataRegistered(data: CultureData): NodaCultureInfo {
    const culture = new NodaCultureInfo(data);
    NodaCultureInfo.Register(culture);
    return culture;
  }

  /** Equivalent of CultureInfo.InvariantCulture. */
  static get InvariantCulture(): NodaCultureInfo {
    return (invariantCulture ??= new NodaCultureInfo(invariantCultureData));
  }

  /**
   * Makes cultures available to {@link CurrentCulture}. The cultures of noda-js/cultures register themselves when an
   * app uses them, but a bundler drops a culture module the app imports and never otherwise uses: register such
   * cultures here, or `import "noda-js/cultures/all"` to bundle and register every culture. A culture registered
   * under a name already registered replaces it.
   */
  static Register(...cultures: NodaCultureInfo[]): void {
    for (const culture of cultures) {
      if (!(culture instanceof NodaCultureInfo)) {
        throw new ArgumentError("Only NodaCultureInfo values can be registered.", "cultures");
      }
      // The invariant culture isn't a host language's culture.
      if (culture.Name !== "") {
        registeredCultures.set(culture.Name.toLowerCase(), culture);
      }
    }
  }

  /**
   * noda-js: the culture of the host's preferred language (equivalent of CultureInfo.CurrentCulture). Takes the host's
   * languages in order of preference (`navigator.languages` in browsers, `navigator.language`, or else the default
   * locale of `Intl.DateTimeFormat`) and returns the first one that matches a registered culture (see {@link Register}):
   * a culture with the same name ("es-AR"), else one named by the language alone ("es"), else the first registered
   * culture of that language ("es-ES"). Evaluated on each access, so it follows changes to the host's languages.
   * @throws {InvalidOperationError} None of the host's languages matches a registered culture.
   */
  static get CurrentCulture(): NodaCultureInfo {
    const languages = HostLanguages();
    for (const language of languages) {
      const culture = MatchRegisteredCulture(language);
      if (culture !== undefined) {
        return culture;
      }
    }
    const registered: string[] = [];
    registeredCultures.forEach((culture) => registered.push(culture.Name));
    throw new InvalidOperationError(
      `${languages.length === 0 ? "The host reports no languages (no navigator or Intl)" : `None of the host's languages (${languages.join(", ")})`} matches a registered culture ` +
        `(${registered.length === 0 ? "none are registered" : registered.join(", ")}). Import the cultures you support ` +
        `from noda-js/cultures and register them with NodaCultureInfo.Register, or import "noda-js/cultures/all".`,
    );
  }

  /** Cultures are always read-only in noda-js. */
  get IsReadOnly(): boolean {
    return true;
  }

  /**
   * Equivalent of PatternResources.ResourceManager.GetString(name, culture):
   * NodaTime's own localized resources (offset patterns, era names).
   */
  GetPatternResource(name: string): string | null {
    return this._patternResourceOverrides[name] ?? PatternResources[name] ?? null;
  }

  toString(): string {
    return this.Name;
  }
}

let invariantCulture: NodaCultureInfo | undefined;

// noda-js: the cultures registered for NodaCultureInfo.CurrentCulture, by lower-case name, in registration order.
const registeredCultures = new Map<string, NodaCultureInfo>();

/** The host's languages, most preferred first (BCP 47 tags such as "es-AR"). */
function HostLanguages(): readonly string[] {
  if (typeof navigator !== "undefined") {
    if (navigator.languages !== undefined && Array.isArray(navigator.languages) && navigator.languages.length > 0) {
      return navigator.languages;
    }
    if (typeof navigator.language === "string") {
      return [navigator.language];
    }
  }
  // No navigator (e.g. Node before 21): Intl's default locale, if Intl is available.
  try {
    if (typeof Intl !== "undefined" && typeof Intl.DateTimeFormat === "function") {
      const locale = new Intl.DateTimeFormat().resolvedOptions().locale;
      if (typeof locale === "string" && locale !== "") {
        return [locale];
      }
    }
  } catch {
    // No usable Intl: no host languages.
  }
  return [];
}

/** An Intl.Collator for the locale, or null if Intl is not available. */
function CreateCollator(locale: string, sensitivity: "accent" | "variant"): Intl.Collator | null {
  try {
    return typeof Intl !== "undefined" && typeof Intl.Collator === "function" ? new Intl.Collator(locale, { sensitivity }) : null;
  } catch {
    return null;
  }
}

/** The registered culture for a language tag: same name, else the language alone, else that language's first. */
function MatchRegisteredCulture(tag: string): NodaCultureInfo | undefined {
  const name = tag.toLowerCase();
  const exact = registeredCultures.get(name);
  if (exact !== undefined) {
    return exact;
  }
  const language = name.split("-")[0]!;
  const neutral = registeredCultures.get(language);
  if (neutral !== undefined) {
    return neutral;
  }
  let first: NodaCultureInfo | undefined;
  registeredCultures.forEach((culture, key) => {
    if (first === undefined && key.split("-")[0] === language) {
      first = culture;
    }
  });
  return first;
}
