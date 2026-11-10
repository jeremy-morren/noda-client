# noda-js

A TypeScript port of [NodaTime](https://nodatime.org): the same types, member names, and text and JSON formats.

```sh
npm i noda-js
```

```ts
import { Instant, LocalDate, LocalDatePattern, Duration } from "noda-js";
import { tzdb } from "noda-js/tzdb/bundled";
import { enAU } from "noda-js/cultures";

const date = new LocalDate(2024, 3, 1).PlusDays(30);
date.DayOfWeek;                                            // IsoDayOfWeek.Sunday
LocalDatePattern.Create("d MMMM uuuu", enAU).Format(date); // "31 March 2024"

const now = Instant.FromUtc(2024, 3, 31, 12, 0);
now.InZone(tzdb.Get("Australia/Sydney")).toString();       // "2024-03-31T23:00:00 Australia/Sydney (+11)"
Duration.FromHours(1.5).TotalMinutes;                      // 90
JSON.stringify(date);                                      // "\"2024-03-31\""
```

## Names

C# names unchanged: properties are getters (`duration.TotalSeconds`), methods are methods (`date.PlusDays(1)`).
JS protocol members keep JS names: `toString()`, `toJSON()` / `static fromJSON()`, `valueOf()` (throws, so `a < b`
fails: use `CompareTo`), `[Symbol.iterator]`. Indexers are `Get(...)`.

## Entry points

| Import | Contents |
|---|---|
| `noda-js` | The core types: `Instant`, `LocalDate`, `ZonedDateTime`, `Period`, patterns, `DateTimeZone`, the ISO, Gregorian, Julian and Coptic calendars, `SystemClock`, ... |
| `noda-js/tzdb/bundled` | `tzdb`: the bundled IANA time zone database (`DateTimeZoneProviders.Tzdb`) |
| `noda-js/tzdb` | `TzdbDateTimeZoneSource`: load an NZD file at run time |
| `noda-js/tzdb/compiler` | `CompileTzdb`, `CompileTzdbToNzd` (and `...Sync`): compile an IANA tzdata release at run time, from a URL, bytes, a `Blob` or a stream |
| `noda-js/system` | `SystemDateTimeZoneProvider`: the host's time zones (`DateTimeZoneProviders.Bcl`): Windows' on Windows, `Intl`'s elsewhere ([docs](https://github.com/jeremy-morren/noda-client/blob/main/ts/docs/Timezones.md)) |
| `noda-js/windows` | Windows time zone IDs ↔ IANA IDs (CLDR) |
| `noda-js/cultures` | Every culture as a named export (`enAU`, `esES`, ...). `NodaCultureInfo.CurrentCulture` picks the host's language among those used. |
| `noda-js/cultures/all` | Registers every culture |
| `noda-js/calendars/hebrew`, `/islamic`, `/persian`, `/umalqura`, `/badi`, `/all` | The other calendar systems, under NodaTime's `CalendarSystem` member names (`HebrewCivil`, `GetIslamicCalendar`, ...) |
| `noda-js/testing` | `FakeClock` and test time zones (`NodaTime.Testing`) |
| `noda-js/linq` | Comparers for [linq-to-typescript](https://github.com/arogozine/LinqToTypeScript) ([docs](https://github.com/jeremy-morren/noda-client/blob/main/ts/docs/linq.md)) |

## Compatibility

- ES2015, no polyfills (Chrome 51, Firefox 54, Safari 10, Edge 15); `noda-js/system`'s `Intl` zones need
  `formatToParts` (Chrome 57, Firefox 51, Safari 11, Edge 18).
- ESM with TypeScript types; side-effect free except `noda-js/cultures/all` and `noda-js/calendars/*`.
- C# `long` results are `number`s (exact up to 2⁵³); `long` arguments also accept a decimal string.
- Differences from NodaTime: [docs/api-differences.md](https://github.com/jeremy-morren/noda-client/blob/main/ts/docs/api-differences.md).

[`noda-js-zod`](https://www.npmjs.com/package/noda-js-zod): zod schemas for NodaTime's JSON formats.

Licensed under Apache-2.0, like NodaTime. See NOTICE.txt for the data licences (IANA tzdb, Unicode CLDR).
