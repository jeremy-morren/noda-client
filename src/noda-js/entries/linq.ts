// noda-js: the `noda-js/linq` entry point. Comparers for noda-js types in linq-to-typescript's shape
// (IComparer: (x, y) => number, IEqualityComparer: (x, y) => boolean), so they plug straight into its methods:
// `from(durations).orderBy(d => d, DurationComparer)`, `.distinct(InstantEqualityComparer)`. noda-js doesn't
// depend on linq-to-typescript (its two function types are copied in Linq/LinqToTypeScript.ts). See docs/linq.md.

export {
  // Natural order (IComparable<T>)
  AnnualDateComparer,
  DurationComparer,
  InstantComparer,
  LocalDateComparer,
  LocalDateTimeComparer,
  LocalTimeComparer,
  OffsetComparer,
  YearMonthComparer,
  // NodaTime's comparers
  CreatePeriodComparer,
  OffsetDateTimeInstantComparer,
  OffsetDateTimeLocalComparer,
  ZonedDateTimeInstantComparer,
  ZonedDateTimeLocalComparer,
} from "../Linq/Comparers.ts";

export {
  // Equals (IEquatable<T>)
  AnnualDateEqualityComparer,
  DateIntervalEqualityComparer,
  DurationEqualityComparer,
  InstantEqualityComparer,
  IntervalEqualityComparer,
  LocalDateEqualityComparer,
  LocalDateTimeEqualityComparer,
  LocalTimeEqualityComparer,
  OffsetDateEqualityComparer,
  OffsetDateTimeEqualityComparer,
  OffsetEqualityComparer,
  OffsetTimeEqualityComparer,
  PeriodEqualityComparer,
  YearMonthEqualityComparer,
  ZonedDateTimeEqualityComparer,
  ZoneIntervalEqualityComparer,
  // NodaTime's equality comparers
  OffsetDateTimeInstantEqualityComparer,
  OffsetDateTimeLocalEqualityComparer,
  PeriodNormalizingEqualityComparer,
  ZonedDateTimeInstantEqualityComparer,
  ZonedDateTimeLocalEqualityComparer,
} from "../Linq/EqualityComparers.ts";
