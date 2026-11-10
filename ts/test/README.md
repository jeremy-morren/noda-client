# Tests

| Folder / file | What |
|---|---|
| `scenarios/` | **Generated**: every NodaTime.Test and NodaTime.TzdbCompiler.Test method and case. `types.ts` is hand-written. |
| `ported/` | Ported NodaTime tests, mirroring `src/NodaTime.Test` (and `src/NodaTime.TzdbCompiler.Test` under `TzdbCompiler/`). |
| `helpers/` | Scenario harness (`scenarios.ts`), value decoding (`decode.ts`), NUnit-style assertions. |
| `unported.test.ts` | NodaTime fixtures with no ported file, as `todo`s. |
| `api/` | noda-js's API shape against NodaTime's (by reflection); differences in `api/differences.ts`. |
| `golden/` | **Generated** .NET results: formatting/parsing per culture, culture-aware comparisons, JSON in every calendar, every year of every calendar. |
| `tzdb-compiler/` | `noda-js/tzdb/compiler` reproduces the bundled NZD byte for byte; the inflate and tar readers. |
| `system/` | `noda-js/system`: unit tests over a fake registry; `environment.test.ts` (real Node processes per `TZ` and backend); `WindowsComparison.test.ts` (against .NET; needs Windows and `testdata/system-zones.json` (repository root) from `npm run test:export-system-zones`, else skipped). |
| `clock-isolation.test.ts` | Only `SystemClock` reads the real time. |
| `@testdata/` | The repository's `testdata/` (shared with noda_dart): binary resources, imported with `?inline`; `tzdb/tzdata<version>.tar.gz` is the release the bundled NZD comes from. |
| `long/` | `LongBigInt` against long.js, and which one noda-js picked. |
| `bundlers/` | The built package bundled by esbuild, Rollup, webpack 5, Vite, Parcel 2 and Bun, run with and without `BigInt`. |
| `vitest/` | `test:ci`'s JUnit reporter and coverage provider. |

## Where tests run

Vitest projects: `node`, `node-longjs` (long.js in place of `BigInt`), and `chromium`, `firefox`, `webkit` (headless,
[browser mode](https://vitest.dev/guide/browser/)). Node-only tests are listed in `nodeOnly` in `vitest.config.ts`.

From the `node` project also:

- `no-host-apis.test.ts`: without `Intl`, `navigator`, `TextDecoder`, `atob`, `Uint8Array.fromBase64`, `performance`.
- `module/quickjs.test.ts`: the single-file module in [QuickJS](https://bellard.org/quickjs/).
- `module/hermes.test.ts`: [Hermes](https://github.com/facebook/hermes) (`npm run test:install-hermes`).
- `module/old-engines.test.ts`: Node 8.17, QuickJS 2019-12-21, Chromium 66 (no `BigInt`; install with
  `npm run test:install-old-engines`; QuickJS and Chromium Linux x64 only).

Engines that aren't installed are skipped locally and fail in CI.

| Command | Runs |
|---|---|
| `npm test` | Every project. |
| `npm run test:node` | `node` and `node-longjs`. |
| `npm run test:browser` | The three browsers. |
| `npx vitest run --project firefox test/ported/LocalDateTest.test.ts` | One file in one project. |
| `npm run test:ci` | Every project, with coverage and `test-results/junit.xml`. |

Install the browsers once: `npx playwright install chromium firefox webkit` (`--with-deps` on Linux). More browsers via
`NODA_TEST_BROWSERS` (comma-separated): `edge`, `safari` (macOS), `ios-safari` (`NODA_TEST_IOS_UDID`),
`android-chrome` (`npm run test:android`).

### CI

`ci.yml` runs one job per platform, each writing a Vitest blob report (`npm run test:blob`):

| Where | Projects |
|---|---|
| Linux, Windows, macOS | `node` (coverage, QuickJS, Hermes, old engines, Bun), `node-longjs`, `chromium`, `firefox`, `webkit` |
| Windows (x64, ARM64) | `node` also builds the native addon and exports .NET's zones for `test/system/` |
| Windows | `edge` |
| macOS | `safari`, `ios-safari` |
| Linux | `android-chrome` |

The `report` job merges them (`npm run test:merge`) into one JUnit and one coverage report. The `checks`
job runs typecheck, build, `check:package`, `check:reproducible` and `build:module`.

## Porting a NodaTime test class

1. Open the scenario file, e.g. `scenarios/LocalDateTest.generated.ts` (each test lists its C# `source`).
2. Create `ported/LocalDateTest.test.ts` with a body per test method, translated from the C#:

   ```ts
   import { fixture } from "../scenarios/LocalDateTest.generated.ts";
   import { port } from "../helpers/scenarios.ts";
   import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
   import { LocalDate } from "../../src/noda-js/internal.ts";

   port(fixture, {
     // [TestCase(...)]: arguments arrive decoded, in C# order.
     PlusDays_Simple(start: LocalDate, days: number, expected: LocalDate) {
       assertNodaEqual(start.PlusDays(days), expected);
     },
     // ExpectedResult = x: return the value.
     DayOfWeek_AroundEpoch(year: number) {
       return new LocalDate(year, 1, 1).DayOfWeek;
     },
     // [Test]: no arguments.
     MinIsoValue() {
       assertThrows("ArgumentOutOfRangeException", () => LocalDate.MinIsoValue.PlusDays(-1));
     },
   });
   ```
3. `npx vitest run test/ported/LocalDateTest.test.ts`. Methods without a body are `todo`; unrepresentable cases are
   skipped with the reason; a body matching no NodaTime test fails.

After NodaTime adds tests, `node tools/generate.ts --only scenarios`: new cases run against existing bodies, new methods
appear as `todo`.
