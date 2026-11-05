# Tests

| Folder / file | What |
|---|---|
| `scenarios/` | **Generated.** Every NodaTime.Test test method and case (`tools/NodaJs.Tools (scenarios)`). `types.ts` is hand-written. |
| `ported/` | Hand-ported NodaTime tests, mirroring `src/NodaTime.Test` (`ported/Text/LocalDatePatternTest.test.ts`). |
| `helpers/` | The scenario harness (`scenarios.ts`), value decoding (`decode.ts`), NUnit-style assertions. |
| `unported.test.ts` | Lists every NodaTime fixture with no ported file yet, as `todo`s. |
| `api/` | NodaTime's public API by reflection (generated) and a test that noda-js matches its shape: properties are getters, methods are methods. Deliberate differences: `api/differences.ts`. |
| `golden/` | **Generated.** NodaTime's own formatting/parsing results per culture, .NET's culture-aware comparisons, and NodaTime.Serialization.SystemTextJson's JSON for one value of each type in the ISO, Julian and Coptic calendars (`json/`, read back by `json.test.ts`). |
| `clock-isolation.test.ts` | Only `SystemClock` may read the real time, so everything else is testable with `FakeClock`. |
| `fixtures/` | Binary test resources, imported with Vite's `?inline` (a `data:` URL) so they load the same way everywhere. |
| `vitest/` | `npm run test:ci`'s JUnit reporter (suites named per project) and coverage provider (v8, Node only). |

## Where tests run

Every test runs on Node and in Chromium (V8), Firefox (SpiderMonkey) and WebKit (JavaScriptCore), headless, via
[Vitest browser mode](https://vitest.dev/guide/browser/) and Playwright: the Vitest projects are `node`, `chromium`,
`firefox` and `webkit` (see `vitest.config.ts`). `test/bundle/`, `clock-isolation.test.ts` and `unported.test.ts` need
Node (esbuild, `node:fs`), so they only run in `node`.

| Command | Runs |
|---|---|
| `npm test` | All four projects. |
| `npm run test:node` | Node only (no browsers needed). |
| `npm run test:browser` | The three browsers. |
| `npx vitest run --project firefox test/ported/LocalDateTest.test.ts` | One file in one project. |
| `npm run test:ci` | All four, with coverage (from `node`) and `test-results/junit.xml`. |

The browsers are Playwright's builds: install them once with `npx playwright install chromium firefox webkit` (on Linux,
add `--with-deps` for their system packages). Tests must not import `node:*` modules unless they're Node-only (add them to
`nodeOnly` in `vitest.config.ts`).

## Porting a NodaTime test class

1. Open the scenario file, e.g. `scenarios/LocalDateTest.generated.ts`. Each test lists its C# `source`
   (`file:line` in `.nodatime/<tag>/`).
2. Create `ported/LocalDateTest.test.ts` and give the body of each test method, translated from the C#:

   ```ts
   import { fixture } from "../scenarios/LocalDateTest.generated.ts";
   import { port } from "../helpers/scenarios.ts";
   import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
   import { LocalDate, ArgumentOutOfRangeError } from "../../src/internal.ts";

   port(fixture, {
     // [TestCase(...)] cases: arguments arrive decoded, in C# parameter order.
     PlusDays_Simple(start: LocalDate, days: number, expected: LocalDate) {
       assertNodaEqual(start.PlusDays(days), expected);
     },
     // [TestCase(..., ExpectedResult = x)]: return the value; the harness compares it.
     DayOfWeek_AroundEpoch(year: number) {
       return new LocalDate(year, 1, 1).DayOfWeek;
     },
     // Plain [Test]: no arguments.
     MinIsoValue() {
       assertThrows(ArgumentOutOfRangeError, () => LocalDate.MinIsoValue.PlusDays(-1));
     },
   });
   ```
3. Run `npx vitest run test/ported/LocalDateTest.test.ts`. Methods you haven't given a body show as
   `todo`; cases with values noda-js can't represent (calendars other than ISO, Gregorian, Julian and Coptic; BCL types) are skipped with the
   reason. A body whose name matches no NodaTime test fails, which catches typos and upstream renames.

When NodaTime adds tests, re-run `tools/generate.ps1 -Only scenarios`: new cases run against existing
bodies automatically, and new methods appear as `todo`.
