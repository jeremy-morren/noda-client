# noda-js

[![CI](https://github.com/jeremy-morren/noda-client/actions/workflows/draft-release.yml/badge.svg?branch=main)](https://github.com/jeremy-morren/noda-client/actions/workflows/draft-release.yml?query=branch%3Amain)
[![Release](https://img.shields.io/github/v/release/jeremy-morren/noda-client)](https://github.com/jeremy-morren/noda-client/releases/latest)
[![noda-js on npm](https://img.shields.io/npm/v/noda-js?label=noda-js)](https://www.npmjs.com/package/noda-js)
[![noda-js-zod on npm](https://img.shields.io/npm/v/noda-js-zod?label=noda-js-zod)](https://www.npmjs.com/package/noda-js-zod)
[![License](https://img.shields.io/github/license/jeremy-morren/noda-client)](../LICENSE.txt)

A TypeScript port of [NodaTime](https://nodatime.org).

## Usage

```sh
npm i noda-js
```

### Construction and arithmetic

```ts
import { Duration, Instant, LocalDate, LocalTime, Period, SystemClock } from "noda-js";

const instant = Instant.FromUtc(2024, 3, 31, 12, 0);   // 2024-03-31T12:00:00Z
const now = SystemClock.Instance.GetCurrentInstant();
const fromDate = Instant.FromJsDate(new Date());       // and instant.ToJsDate()

const date = new LocalDate(2024, 3, 1);
const meeting = date.At(new LocalTime(9, 30));               // a LocalDateTime: 2024-03-01T09:30:00

const ninety = Duration.FromMinutes(90);
ninety.TotalHours;                                           // 1.5
instant.Plus(Duration.FromHours(36));                        // 2024-04-02T00:00:00Z
date.PlusMonths(1).PlusDays(-1);                             // 2024-03-31
Period.Between(new LocalDate(2024, 1, 31), date).toString(); // "P1M1D"
```

### Time zones

```ts
import { tzdb } from "noda-js/tzdb/bundled"; // the IANA time zone database, bundled

const madrid = tzdb.Get("Europe/Madrid");
instant.InZone(madrid);                    // 2024-03-31T14:00:00 Europe/Madrid (+02)
instant.InZone(madrid)
  .WithZone(tzdb.Get("Australia/Sydney")); // 2024-03-31T23:00:00 Australia/Sydney (+11)
madrid.GetUtcOffset(instant);              // +02

// Local date and time → a zoned value. 02:30 on 31 March 2024 doesn't exist in Madrid (the clocks went forward):
const gap = new LocalDate(2024, 3, 31).At(new LocalTime(2, 30));
gap.InZoneLeniently(madrid);                    // 2024-03-31T03:30:00 Europe/Madrid (+02)
gap.InZoneStrictly(madrid);                     // throws SkippedTimeException
meeting.InZoneLeniently(madrid).ToInstant();    // 2024-03-01T08:30:00Z
```

The host's own zones (NodaTime's `DateTimeZoneProviders.Bcl`) are in `noda-js/system`: Windows' zones on Windows,
the host's `Intl` zones elsewhere:

```ts
import { SystemDateTimeZoneProvider } from "noda-js/system";

SystemDateTimeZoneProvider.GetSystemDefault();     // "AUS Eastern Standard Time" on Windows, "Australia/Sydney" elsewhere
tzdb.GetSystemDefault();                           // Australia/Sydney (both honour TZ)
```

More: [docs/Timezones.md](docs/Timezones.md).

### Formatting and parsing

```ts
import { LocalDatePattern, NodaCultureInfo } from "noda-js";
import { esES } from "noda-js/cultures"; // every culture is a named export; bundles keep only the ones you import

date.toString("d MMMM uuuu", null);                                  // "1 March 2024" (null: the invariant culture)
LocalDatePattern.Create("d 'de' MMMM 'de' uuuu", esES).Format(date); // "1 de marzo de 2024"

const result = LocalDatePattern.Iso.Parse("2024-02-30");
result.Success;                                          // false
result.Exception.message;                                // "The day 30 is out of range in month 2 of year 2024. ..."
LocalDatePattern.Iso.Parse("2024-02-29").Value;          // 2024-02-29

// The host's language: import "noda-js/cultures/all" (every culture), or import the cultures you support.
LocalDatePattern.Create("D", NodaCultureInfo.CurrentCulture).Format(date);
```

### Other calendar systems

ISO (the default), Gregorian, Julian and Coptic are in `CalendarSystem`; the others are separate imports:

```ts
import { HebrewCivil } from "noda-js/calendars/hebrew";
import { GetIslamicCalendar } from "noda-js/calendars/islamic"; // also /persian, /umalqura, /badi, or /all
import { IslamicEpoch, IslamicLeapYearPattern } from "noda-js";

new LocalDate(2024, 3, 1).WithCalendar(HebrewCivil);                    // 21 Adar I 5784: year 5784, month 6, day 21
date.WithCalendar(GetIslamicCalendar(IslamicLeapYearPattern.Base16, IslamicEpoch.Civil));
```

### JSON

`toJSON()` and `fromJSON()` use NodaTime.Serialization.SystemTextJson's formats:

```ts
import { CalendarSystem, ZonedDateTime } from "noda-js";

JSON.stringify({ at: instant, on: date, zoned: instant.InZone(madrid) });
// {"at":"2024-03-31T12:00:00Z","on":"2024-03-01","zoned":"2024-03-31T14:00:00+02 Europe/Madrid"}
Instant.fromJSON("2024-03-31T12:00:00Z");
ZonedDateTime.fromJSON("2024-03-31T14:00:00+02 Europe/Madrid", tzdb);

// JSON doesn't record the calendar: values are read in the ISO calendar unless you pass another.
LocalDate.fromJSON("2024-03-01", CalendarSystem.Julian); // 1 March 2024 (Julian), which is 14 March (ISO)
```

[zod](https://zod.dev) schemas with `noda-js-zod`:

```sh
npm i noda-js-zod
```

```ts
import * as z from "zod";
import NodaZ from "noda-js-zod";

const Booking = z.object({
  at: NodaZ.Instant,
  nights: z.array(NodaZ.LocalDate),
  zone: NodaZ.DateTimeZone(tzdb),
});

const booking = Booking.parse(await response.json());
booking.at.InZone(booking.zone);   // a ZonedDateTime
Booking.encode(booking);           // back to the JSON form

// The schemas read ISO values; .WithCalendar(calendar) returns a schema for another calendar (the original is unchanged).
const CopticDate = NodaZ.LocalDate.WithCalendar(CalendarSystem.Coptic);
CopticDate.parse("1740-06-21");    // 1740-06-21 in the Coptic calendar, which is 29 February 2024 (ISO)

Booking.safeParse({ at: 42, nights: ["2024-02-30"], zone: "Europe/Madrid" });
// ✖ Expected an Instant string in the format uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z', but received number → at at
// ✖ The day 30 is out of range in month 2 of year 2024. Value being parsed: '2024-02-30'. → at nights[0]
```

#### Up-to-date time zones

Compile the latest IANA release at run time with `noda-js/tzdb/compiler` (`CompileTzdbSync` is synchronous;
`CompileTzdbToNzd` returns NZD bytes to cache for `TzdbDateTimeZoneSource.FromBytes`):

```ts
import { CompileTzdb } from "noda-js/tzdb/compiler";

// On the server
const source = await CompileTzdb("https://data.iana.org/time-zones/tzdata-latest.tar.gz");

// In a browser (data.iana.org has no CORS):
const [latest] = await (await fetch("https://api.github.com/repos/eggert/tz/tags?per_page=1")).json();
const source = await CompileTzdb(`https://cdn.jsdelivr.net/gh/eggert/tz@${latest.name}/`);

const tzdbLatest = new DateTimeZoneCache(source);
```

## Packages

| Package                                    | What | npm | GitHub Packages |
|--------------------------------------------|-------------|-----|-----------------|
| [`noda-js`](src/noda-js/README.md)         | The port | [noda-js](https://www.npmjs.com/package/noda-js) | [@jeremy-morren/noda-js](https://github.com/jeremy-morren/noda-client/pkgs/npm/noda-js) |
| [`noda-js-zod`](src/noda-js-zod/README.md) | Zod schemas for NodaTime's JSON | [noda-js-zod](https://www.npmjs.com/package/noda-js-zod) | [@jeremy-morren/noda-js-zod](https://github.com/jeremy-morren/noda-client/pkgs/npm/noda-js-zod) |

From GitHub Packages, install the core under its npm name, as noda-js-zod imports `"noda-js"`:
`"noda-js": "npm:@jeremy-morren/noda-js@^0.2.0"`. Both are published with npm provenance.

## Runs anywhere

- ES2015 (Chrome 51, Firefox 54, Safari 10, Edge 15), no polyfills: browsers, Node, Deno, Bun, embedded engines.
- Exact C# `long` values beyond 2⁵³ use native `BigInt` where the engine has it, [long.js](https://github.com/dcodeIO/long.js)
  otherwise; same API and results.
- Host APIs (`Intl`, `TextDecoder`, `atob`, `performance`, `DecompressionStream`) are used when present, with fallbacks.
  Only `noda-js/system` and `NodaCultureInfo.CurrentCulture` need the host (and compiling tzdata from a URL needs
  `fetch`).
- Tested on Node, Chromium, Firefox, WebKit, QuickJS, Hermes 0.13, engines without `BigInt` (Node 8.17, Chromium 66), and
  in apps built with esbuild, Rollup, webpack 5, Vite, Parcel 2 and Bun.

### Without a bundler

Each [release](https://github.com/jeremy-morren/noda-client/releases/latest) has `noda-js-module-<version>.zip` / `.tar.gz`:
one ES module, `noda-js.js`, with the whole package (about 160 KB gzipped):

```html
<script type="module">
  import { Instant, tzdb } from "./noda-js.js";
  console.log(Instant.FromUtc(2024, 7, 1, 12, 0).InZone(tzdb.Get("Europe/Madrid")).toString());
</script>
```

Verify a copy: `gh attestation verify noda-js-module-<version>.zip --repo jeremy-morren/noda-client`.

## More

- Differences from NodaTime: [docs/api-differences.md](docs/api-differences.md)
- Time zones: [docs/Timezones.md](docs/Timezones.md)
- Porting conventions: [docs/porting-conventions.md](docs/porting-conventions.md)
- Tests: [test/README.md](test/README.md)

## License

Licensed under Apache-2.0, like NodaTime. See [NOTICE.txt](../NOTICE.txt) for data licences.
