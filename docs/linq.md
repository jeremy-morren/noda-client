# noda-js/linq

The `noda-js/linq` entry point: comparers for noda-js types that plug straight into [linq-to-typescript](https://github.com/arogozine/LinqToTypeScript):

```ts
import { from } from "linq-to-typescript";
import { Duration, LocalDateTime } from "noda-js";
import {
  CreatePeriodComparer,
  DurationComparer,
  InstantEqualityComparer,
  OffsetDateTimeInstantComparer,
} from "noda-js/linq";

from(durations).orderBy(d => d, DurationComparer).toArray();
from(meetings).orderByDescending(m => m.start, OffsetDateTimeInstantComparer).toArray();
from(instants).distinct(InstantEqualityComparer).toArray();
from(periods).orderBy(p => p, CreatePeriodComparer(new LocalDateTime(2024, 1, 1, 0, 0))).toArray();
```

Each comparer is a plain function, `(x, y) => number` (an `IComparer`) or `(x, y) => boolean` (an
`IEqualityComparer`), exactly linq-to-typescript's types, so they also work anywhere else that takes one, e.g.
`array.sort(LocalDateComparer)`.

## Dependencies

noda-js **doesn't depend on linq-to-typescript**: the two function types the comparers need are copied from
linq-to-typescript 12.1.1 (MIT licence, Copyright (c) 2021 Alexandre Rogozine; see NOTICE.txt). They aren't exported
(use linq-to-typescript's own `IComparer` / `IEqualityComparer`, which are the same types).

## Exports

### Natural order

For each type that NodaTime makes `IComparable`: the order of its `CompareTo`.

| Export | Type |
|---|---|
| `AnnualDateComparer` | `IComparer<AnnualDate>` |
| `DurationComparer` | `IComparer<Duration>` |
| `InstantComparer` | `IComparer<Instant>` |
| `LocalDateComparer` | `IComparer<LocalDate>` |
| `LocalDateTimeComparer` | `IComparer<LocalDateTime>` |
| `LocalTimeComparer` | `IComparer<LocalTime>` |
| `OffsetComparer` | `IComparer<Offset>` |
| `YearMonthComparer` | `IComparer<YearMonth>` |

### Equality

For each type that NodaTime makes `IEquatable`: its `Equals`.

| Export | Type |
|---|---|
| `AnnualDateEqualityComparer` | `IEqualityComparer<AnnualDate>` |
| `DateIntervalEqualityComparer` | `IEqualityComparer<DateInterval>` |
| `DurationEqualityComparer` | `IEqualityComparer<Duration>` |
| `InstantEqualityComparer` | `IEqualityComparer<Instant>` |
| `IntervalEqualityComparer` | `IEqualityComparer<Interval>` |
| `LocalDateEqualityComparer` | `IEqualityComparer<LocalDate>` |
| `LocalDateTimeEqualityComparer` | `IEqualityComparer<LocalDateTime>` |
| `LocalTimeEqualityComparer` | `IEqualityComparer<LocalTime>` |
| `OffsetEqualityComparer` | `IEqualityComparer<Offset>` |
| `OffsetDateEqualityComparer` | `IEqualityComparer<OffsetDate>` |
| `OffsetDateTimeEqualityComparer` | `IEqualityComparer<OffsetDateTime>` |
| `OffsetTimeEqualityComparer` | `IEqualityComparer<OffsetTime>` |
| `PeriodEqualityComparer` | `IEqualityComparer<Period>` |
| `YearMonthEqualityComparer` | `IEqualityComparer<YearMonth>` |
| `ZonedDateTimeEqualityComparer` | `IEqualityComparer<ZonedDateTime>` |
| `ZoneIntervalEqualityComparer` | `IEqualityComparer<ZoneInterval>` |

### NodaTime's comparers

`OffsetDateTime`, `ZonedDateTime` and `Period` have no natural order; NodaTime provides comparers instead.

| Export | Type | NodaTime |
|---|---|---|
| `OffsetDateTimeLocalComparer` | `IComparer<OffsetDateTime>` | `OffsetDateTime.Comparer.Local.Compare`: by local date/time, ignoring the offset |
| `OffsetDateTimeInstantComparer` | `IComparer<OffsetDateTime>` | `OffsetDateTime.Comparer.Instant.Compare`: by instant, ignoring the calendar |
| `OffsetDateTimeLocalEqualityComparer` | `IEqualityComparer<OffsetDateTime>` | `OffsetDateTime.Comparer.Local.Equals` |
| `OffsetDateTimeInstantEqualityComparer` | `IEqualityComparer<OffsetDateTime>` | `OffsetDateTime.Comparer.Instant.Equals` |
| `ZonedDateTimeLocalComparer` | `IComparer<ZonedDateTime>` | `ZonedDateTime.Comparer.Local.Compare`: by local date/time, ignoring the zone and offset |
| `ZonedDateTimeInstantComparer` | `IComparer<ZonedDateTime>` | `ZonedDateTime.Comparer.Instant.Compare`: by instant, ignoring the zone and calendar |
| `ZonedDateTimeLocalEqualityComparer` | `IEqualityComparer<ZonedDateTime>` | `ZonedDateTime.Comparer.Local.Equals` |
| `ZonedDateTimeInstantEqualityComparer` | `IEqualityComparer<ZonedDateTime>` | `ZonedDateTime.Comparer.Instant.Equals` |
| `PeriodNormalizingEqualityComparer` | `IEqualityComparer<Period>` | `Period.NormalizingEqualityComparer`: equal once normalized (`PT24H` equals `P1D`) |
| `CreatePeriodComparer(baseDateTime)` | `(baseDateTime: LocalDateTime) => IComparer<Period>` | `Period.CreateComparer(baseDateTime)`: adds both periods to `baseDateTime` and compares the results |

## null and undefined

Each comparer behaves like .NET's `Comparer<T>.Default` / `EqualityComparer<T>.Default`, and accepts `null` and
`undefined` (every `IComparer<T>` above is precisely an `IComparer<T | null | undefined>`):

- `null` and `undefined` sort before any value and compare equal to each other: `DurationComparer(null, d) < 0`,
  `DurationComparer(null, undefined) === 0`.
- An equality comparer is `true` for two of `null`/`undefined`, and `false` for one of them and a value.
- Otherwise the type's own `CompareTo` / `Equals` (or NodaTime's comparer) decides, errors included: comparing
  `LocalDate`, `LocalDateTime` or `YearMonth` values in different calendar systems throws `ArgumentError`, as in
  NodaTime, and so does comparing a value of another type. Equality comparers are `false`, not an error, for a
  value of another type.

`Array.prototype.sort`, which linq-to-typescript's `orderBy` uses, always puts `undefined` last without calling the
comparer. Use `null` for keys that should sort first.
