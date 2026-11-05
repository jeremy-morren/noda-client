# noda-js

A TypeScript port of [NodaTime](https://nodatime.org).

## Usage

```ts
import { LocalDate, LocalDatePattern } from "noda-js";
import { tzdb } from "noda-js/tzdb/bundled";
import { frFR } from "noda-js/cultures"; // bundles keep only the cultures you import

const date = new LocalDate(2024, 3, 1).PlusDays(30);
date.DayOfWeek;                                            // IsoDayOfWeek.Sunday
LocalDatePattern.Create("d MMMM uuuu", frFR).Format(date); // "31 mars 2024"
date.AtStartOfDayInZone(tzdb.get("Europe/Paris")).toJSON();
```

## Packages

| Package | What it is |
|---|---|
| [`noda-js`](src/noda-js/README.md) | The port itself: every NodaTime type, text patterns, time zones (bundled tzdb or the browser's), cultures, testing helpers |
| [`noda-js-zod`](src/noda-js-zod/README.md) | Zod schemas that parse NodaTime's JSON formats into noda-js values (`NodaZ.Instant`, ...) |

They live in `src/` as npm workspaces, are versioned together, and are published from CI with npm provenance
(see [.github/workflows/release.yml](.github/workflows/release.yml)).

`noda-js` entry points: `noda-js` (core), `noda-js/tzdb` (NZD reader), `noda-js/tzdb/bundled` (bundled tz data),
`noda-js/browser` (zones from `Intl`), `noda-js/windows` (Windows zone IDs via CLDR), `noda-js/cultures` (every
culture as a named export, e.g. `enAU`; tree-shaken, so a bundle only has the cultures it imports; the invariant
culture is always in the core), `noda-js/testing` (`FakeClock` and test zones), `noda-js/linq` (comparers for
[linq-to-typescript](https://github.com/arogozine/LinqToTypeScript), e.g. `DurationComparer`; see
[docs/linq.md](docs/linq.md)).

It runs on ES2015 (Chrome 51, Firefox 54, Safari 10, Edge 15) with no polyfills, and doesn't use `BigInt`
(`noda-js/browser` also needs `Intl.DateTimeFormat.prototype.formatToParts`: Chrome 57, Firefox 51, Safari 11,
Edge 18). `npm run lint` keeps `src/` within that baseline, and the tests run on Node, Chromium, Firefox and WebKit.
C# `long` arguments accept a number or, for exact values beyond 2⁵³, a decimal string.
- How the port is written: [docs/porting-conventions.md](docs/porting-conventions.md)
- Differences from NodaTime: [docs/api-differences.md](docs/api-differences.md)
- Tests: [test/README.md](test/README.md)

## Port

This is a line-by-line port of NodaTime. It aims for:

- **The same API, with the same names**: C# properties are getters (`duration.TotalSeconds`, `date.Year`,
  `Instant.MaxValue`), methods are methods (`date.PlusDays(1)`). Only what JS itself calls by name keeps its JS
  name: `toString()`, `toJSON()`/`fromJSON()`, `valueOf()`, `[Symbol.iterator]`.
- **The same wire formats**: text patterns, `toString()`, and JSON (`toJSON()` / `fromJSON()`) produce
  and accept what NodaTime (and `NodaTime.Serialization.SystemTextJson`) do.
- **As little of our own code as possible**: the source is a file-by-file port of NodaTime
  (`src/noda-js/Foo.ts` ← `src/NodaTime/Foo.cs`), and everything .NET can tell us (enums, constants, error
  messages, culture data, tzdb, the API shape, ~20,000 test cases) is generated from .NET by the tools
  in [`tools/`](tools/README.md).

## License

Licensed under Apache-2.0, like NodaTime. See [NOTICE.txt](NOTICE.txt) for data licences.
