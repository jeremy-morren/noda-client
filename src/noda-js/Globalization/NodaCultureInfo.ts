// noda-js: the parts of System.Globalization.CultureInfo, DateTimeFormatInfo and CompareInfo that
// NodaTime reads. The data is generated from .NET by tools/NodaJs.Tools data, into src/noda-js/Cultures/*.generated.ts,
// and member names are .NET's (PascalCase), so ported code reads them as NodaTime reads the .NET objects.

import { invariantCultureData } from "./InvariantCultureData.generated.ts";
import { PatternResources } from "./PatternResources.generated.ts";

/** Culture data as written by tools/NodaJs.Tools (data). */
export interface CultureData {
  readonly Name: string;
  readonly DateTimeFormat: DateTimeFormatData;
  /** NodaTime pattern resources that differ from the neutral ones (src/noda-js/Globalization/PatternResources.generated.ts). */
  readonly PatternResources?: Readonly<Record<string, string>>;
}

/** The members of .NET's DateTimeFormatInfo that NodaTime uses. */
export interface DateTimeFormatData {
  /** The .NET calendar type name, e.g. "GregorianCalendar". */
  readonly Calendar: string;
  readonly AMDesignator: string;
  readonly PMDesignator: string;
  readonly TimeSeparator: string;
  readonly DateSeparator: string;
  readonly ShortDatePattern: string;
  readonly LongDatePattern: string;
  readonly ShortTimePattern: string;
  readonly LongTimePattern: string;
  readonly FullDateTimePattern: string;
  readonly MonthDayPattern: string;
  readonly YearMonthPattern: string;
  readonly SortableDateTimePattern: string;
  readonly UniversalSortableDateTimePattern: string;
  readonly RFC1123Pattern: string;
  /** 13 entries, as in .NET (the last is for a 13th month, and usually empty). */
  readonly MonthNames: readonly string[];
  readonly AbbreviatedMonthNames: readonly string[];
  readonly MonthGenitiveNames: readonly string[];
  readonly AbbreviatedMonthGenitiveNames: readonly string[];
  /** 7 entries, Sunday first, as in .NET. */
  readonly DayNames: readonly string[];
  readonly AbbreviatedDayNames: readonly string[];
  readonly ShortestDayNames: readonly string[];
  /** GetEraName(1..n) of the culture's calendar. */
  readonly EraNames: readonly string[];
  /** GetAbbreviatedEraName(1..n) of the culture's calendar. */
  readonly AbbreviatedEraNames: readonly string[];
  /** System.DayOfWeek value (0 = Sunday). */
  readonly FirstDayOfWeek: number;
  /** System.Globalization.CalendarWeekRule value. */
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
  readonly AMDesignator!: string;
  readonly PMDesignator!: string;
  readonly TimeSeparator!: string;
  readonly DateSeparator!: string;
  readonly ShortDatePattern!: string;
  readonly LongDatePattern!: string;
  readonly ShortTimePattern!: string;
  readonly LongTimePattern!: string;
  readonly FullDateTimePattern!: string;
  readonly MonthDayPattern!: string;
  readonly YearMonthPattern!: string;
  readonly SortableDateTimePattern!: string;
  readonly UniversalSortableDateTimePattern!: string;
  readonly RFC1123Pattern!: string;
  /** @inheritDoc */
  readonly MonthNames!: readonly string[];
  readonly AbbreviatedMonthNames!: readonly string[];
  readonly MonthGenitiveNames!: readonly string[];
  readonly AbbreviatedMonthGenitiveNames!: readonly string[];
  /** @inheritDoc */
  readonly DayNames!: readonly string[];
  readonly AbbreviatedDayNames!: readonly string[];
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
  private _ignoreCaseCollator: Intl.Collator | undefined;
  private _collator: Intl.Collator | undefined;

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
      case CompareOptions.IgnoreCase:
        return Math.sign((this._ignoreCaseCollator ??= new Intl.Collator(this.Locale, { sensitivity: "accent" })).compare(a, b));
      default:
        return Math.sign((this._collator ??= new Intl.Collator(this.Locale, { sensitivity: "variant" })).compare(a, b));
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

  /** Equivalent of CultureInfo.InvariantCulture. */
  static get InvariantCulture(): NodaCultureInfo {
    return (invariantCulture ??= new NodaCultureInfo(invariantCultureData));
  }

  /** Cultures are always read-only in noda-js. */
  get IsReadOnly(): boolean {
    return true;
  }

  /**
   * Equivalent of PatternResources.ResourceManager.GetString(name, culture): NodaTime's own localized
   * resources (offset patterns, era names).
   */
  GetPatternResource(name: string): string | null {
    return this._patternResourceOverrides[name] ?? PatternResources[name] ?? null;
  }

  toString(): string {
    return this.Name;
  }
}

let invariantCulture: NodaCultureInfo | undefined;
