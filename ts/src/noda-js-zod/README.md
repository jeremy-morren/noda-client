# noda-js-zod

[Zod](https://zod.dev) schemas that parse NodaTime's JSON formats (`NodaTime.Serialization.SystemTextJson`) into
[noda-js](https://www.npmjs.com/package/noda-js) values.

```sh
npm i noda-js-zod noda-js zod
```

Requires zod 4.1+: each schema is a [codec](https://zod.dev/codecs): `.parse()` uses the type's `fromJSON()`,
`.encode()` its `toJSON()`.

## Usage

```ts
import NodaZ from "noda-js-zod"; // or: import { NodaZ } from "noda-js-zod";
import { Instant } from "noda-js";

const instant = NodaZ.Instant.parse("2024-01-31T12:00:00Z"); // an Instant
instant.Equals(Instant.FromUtc(2024, 1, 31, 12, 0));         // true

NodaZ.Instant.encode(instant);                   // "2024-01-31T12:00:00Z"
NodaZ.LocalDate.parse("2024-02-29").PlusDays(1); // LocalDate 2024-03-01
NodaZ.Period.parse("P1Y2M").Months;              // 2
```

Invalid input gives zod issues:

```ts
NodaZ.Instant.safeParse(1706702400000).error?.issues;
// [{
//   code: "invalid_type",
//   expected: "string",
//   path: [],
//   message: "Expected an Instant string in the format uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z', but received number"
// }]
```

### Time zones

`ZonedDateTime` and `DateTimeZone` schemas take the provider to look IDs up in:

```ts
import { tzdb } from "noda-js/tzdb/bundled"; // or a provider from noda-js/tzdb, noda-js/system, ...

const ZonedDateTimeSchema = NodaZ.ZonedDateTime(tzdb); // create once, reuse
const meeting = ZonedDateTimeSchema.parse("2024-01-31T12:00:00+01 Europe/Madrid");
meeting.Zone.Id;                       // "Europe/Madrid"
ZonedDateTimeSchema.encode(meeting);   // "2024-01-31T12:00:00+01 Europe/Madrid"

NodaZ.DateTimeZone(tzdb).parse("America/New_York"); // tzdb.Get("America/New_York")
```

Windows IDs (written by .NET's `BclDateTimeZone`) need `SystemDateTimeZoneProvider` (`noda-js/system`) on Windows.
Elsewhere, map them to tzdb IDs with `tzdbSource.WindowsMapping.PrimaryMapping` (`noda-js/tzdb/bundled`).

### Calendars

JSON doesn't record the calendar: schemas read ISO values; `.WithCalendar(calendar)` returns a schema for another
calendar (the original is unchanged):

```ts
import { CalendarSystem } from "noda-js";

const CopticDate = NodaZ.LocalDate.WithCalendar(CalendarSystem.Coptic); // create once, reuse
CopticDate.parse("1740-06-21");                       // 1740-06-21 in the Coptic calendar (29 February 2024)
NodaZ.LocalDate.parse("1740-06-21").Calendar;         // CalendarSystem.Iso: NodaZ.LocalDate is unchanged
NodaZ.ZonedDateTime(tzdb).WithCalendar(CalendarSystem.Julian);
```

## Schemas

Wire formats are NodaTime patterns.

| Schema | Input (JSON) | Wire format |
|---|---|---|
| `NodaZ.Instant` | string | `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z'` (`InstantPattern.ExtendedIso`) |
| `NodaZ.LocalDate` | string | `uuuu'-'MM'-'dd` (`LocalDatePattern.Iso`) |
| `NodaZ.LocalTime` | string | `HH':'mm':'ss;FFFFFFFFF` (`LocalTimePattern.ExtendedIso`) |
| `NodaZ.LocalDateTime` | string | `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF` (`LocalDateTimePattern.ExtendedIso`) |
| `NodaZ.OffsetDateTime` | string | `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<Z+HH:mm>` (`OffsetDateTimePattern.Rfc3339`) |
| `NodaZ.OffsetDate` | string | `uuuu'-'MM'-'ddo<G>` (`OffsetDatePattern.GeneralIso`) |
| `NodaZ.OffsetTime` | string | `HH':'mm':'ss;FFFFFFFFFo<G>` (`OffsetTimePattern.ExtendedIso`) |
| `NodaZ.Offset` | string | `g`: shortest of `+HH:mm:ss`, `+HH:mm`, `+HH` (`OffsetPattern.GeneralInvariant`) |
| `NodaZ.Duration` | string | `-H:mm:ss.FFFFFFFFF`, total hours (`DurationPattern.JsonRoundtrip`) |
| `NodaZ.Period` | string | ISO 8601 plus `s`, `t`, `n` units (`PeriodPattern.Roundtrip`) |
| `NodaZ.YearMonth` | string | `uuuu'-'MM` (`YearMonthPattern.Iso`) |
| `NodaZ.AnnualDate` | string | `MM'-'dd` (`AnnualDatePattern.Iso`) |
| `NodaZ.Interval` | object | `{ start?, end? }`, `Instant` strings; missing means unbounded |
| `NodaZ.DateInterval` | object | `{ start, end }`, `LocalDate` strings (inclusive) |
| `NodaZ.ZonedDateTime(provider)` | string | `uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z` |
| `NodaZ.DateTimeZone(provider)` | string | a zone ID of the provider |

Interval property names match ignoring case; `encode()` writes camelCase. Exported types: `TextSchema<T>`,
`ObjectSchema<J, T>`, `IntervalJson`, `DateIntervalJson`.

## Errors

Bad input is always a zod issue (never a thrown exception), with its `path`:

- **Not a string** (or not an object, for intervals): `invalid_type`, e.g.
  `Expected a LocalDate string in the format uuuu'-'MM'-'dd, but received null`.
- **Unparsable string**: `invalid_format` (`format`: the type, `pattern`: its pattern) with noda-js's parse message.
- **Rejected after parsing** (a `DateInterval` ending before its start): `custom`.

`encode()` of the wrong type: a `custom` issue (`Expected an Instant value, but received string`).

### Nested

```ts
import * as z from "zod";
import NodaZ from "noda-js-zod";
import { tzdb } from "noda-js/tzdb/bundled";

const Booking = z.object({
  at: NodaZ.Instant,
  nights: z.array(NodaZ.LocalDate),
  stay: NodaZ.DateInterval,
  length: NodaZ.Period.optional(),
  zone: NodaZ.DateTimeZone(tzdb),
});
type Booking = z.output<typeof Booking>; // { at: Instant; nights: LocalDate[]; stay: DateInterval; ... }

const booking = Booking.parse(await response.json());
booking.stay.Length; // number of days

JSON.stringify(Booking.encode(booking)); // back to the wire format

const result = Booking.safeParse({ at: "2024-01-31T12:00:00Z", nights: ["2024-02-30"], stay: { start: "2024-02-01" }, zone: "Europe/Madrid" });
console.log(z.prettifyError(result.error!));
// ✖ The day 30 is out of range in month 2 of year 2024. Value being parsed: '2024-02-30'.
//   → at nights[0]
// ✖ Expected a LocalDate string in the format uuuu'-'MM'-'dd, but received undefined
//   → at stay.end
```

## Bundle size

Schemas are created in `/* @__PURE__ */` calls: Rollup (Vite) keeps only those you use; esbuild keeps all (about 3 kB
minified).

## License

Apache-2.0, like noda-js and NodaTime.
