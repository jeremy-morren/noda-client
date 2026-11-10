# noda-js/linq

Comparers for [linq-to-typescript](https://github.com/arogozine/LinqToTypeScript):

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

Each is a plain function, `(x, y) => number` or `(x, y) => boolean`, so it also works elsewhere:
`array.sort(LocalDateComparer)`. noda-js doesn't depend on linq-to-typescript (the two function types are copied from
12.1.1, MIT; see NOTICE.txt).

## Exports

### Natural order (`CompareTo`)

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

### Equality (`Equals`)

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

| Export | Type | NodaTime |
|---|---|---|
| `OffsetDateTimeLocalComparer` | `IComparer<OffsetDateTime>` | `OffsetDateTime.Comparer.Local.Compare` |
| `OffsetDateTimeInstantComparer` | `IComparer<OffsetDateTime>` | `OffsetDateTime.Comparer.Instant.Compare` |
| `OffsetDateTimeLocalEqualityComparer` | `IEqualityComparer<OffsetDateTime>` | `OffsetDateTime.Comparer.Local.Equals` |
| `OffsetDateTimeInstantEqualityComparer` | `IEqualityComparer<OffsetDateTime>` | `OffsetDateTime.Comparer.Instant.Equals` |
| `ZonedDateTimeLocalComparer` | `IComparer<ZonedDateTime>` | `ZonedDateTime.Comparer.Local.Compare` |
| `ZonedDateTimeInstantComparer` | `IComparer<ZonedDateTime>` | `ZonedDateTime.Comparer.Instant.Compare` |
| `ZonedDateTimeLocalEqualityComparer` | `IEqualityComparer<ZonedDateTime>` | `ZonedDateTime.Comparer.Local.Equals` |
| `ZonedDateTimeInstantEqualityComparer` | `IEqualityComparer<ZonedDateTime>` | `ZonedDateTime.Comparer.Instant.Equals` |
| `PeriodNormalizingEqualityComparer` | `IEqualityComparer<Period>` | `Period.NormalizingEqualityComparer` |
| `CreatePeriodComparer(baseDateTime)` | `(baseDateTime: LocalDateTime) => IComparer<Period>` | `Period.CreateComparer(baseDateTime)` |

## null and undefined

As .NET's `Comparer<T>.Default` / `EqualityComparer<T>.Default`:

- `null` and `undefined` sort first and are equal to each other.
- Otherwise the type's `CompareTo` / `Equals` decides, errors included (different calendars, or another type, throw
  `ArgumentException`). Equality comparers return `false` for another type.

`Array.prototype.sort` (used by `orderBy`) puts `undefined` last without calling the comparer: use `null` to sort first.
