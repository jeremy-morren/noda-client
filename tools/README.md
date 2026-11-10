# .NET Tools

Built with the exact .NET SDK (and runtime) in `global.json`.

- `NodaJs.Package`: reproducible release archives (`zip`, `tar-gzip`) for `ts/scripts/build/build-module.ts`.
- `NodaJs.Tools`: generates `*.generated.ts` and `*.generated.dart` for both ports from .NET and NodaTime. Don't edit
  those files; re-run:

```sh
node tools/generate.ts                      # everything
node tools/generate.ts --only scenarios
```

Building `NodaJs.Tools` fetches NodaTime at the ref in `nodatime-ref.txt` into `.nodatime/<ref>/` and
references its projects. ICU is app-local (`IcuVersion`), so culture data is the same on every OS. Unchanged files
aren't rewritten.

Paths below are relative to each port's `src/` (`ts/src/noda-js/`, `dart/noda_dart/lib/src/`) and `test/`
(`ts/test/`, `dart/noda_dart/test/`):

| Command     | Writes              | From |
|-------------|---------------------|------|
| `data`      | enums, `src/NodaConstants`, `src/Text/TextErrorMessages`, `src/Cultures/*` (`cultures.txt`), `src/Globalization/*`, `src/Calendars/*Data`, `src/TimeZones/TzdbBundledData` (and `testdata/tzdb/tzdata<version>.tar.gz`), `test/api/nodatime-api`, `test/golden/**` | Reflection over NodaTime; .NET `CultureInfo`; NodaTime's `TzdbCompiler`; NodaTime formatting values |
| `cldr`      | `src/Bcl/CldrWindowsZones` | CLDR `windowsZones.xml`, parsed by NodaTime's `CldrWindowsZonesParser` |
| `scenarios` | `test/scenarios/**` | Every NUnit test case in `NodaTime.Test` and `NodaTime.TzdbCompiler.Test` |
| `system-zones` | `testdata/system-zones.json` (not committed) | NodaTime's `BclDateTimeZoneSource` on this machine, for both ports' Windows comparison tests (`ts/scripts/test/export-system-zones.ts`) |

## One model, two writers

Each export builds one model and writes it for every port in `Port.All` through `TypescriptWriter` and `DartWriter`
(`Common/`). Test values are encoded once by `ValueEncoder`. Dart forms are in `dart/docs/porting-conventions.md`.

## tzdb

By default the tzdb is compiled by NodaTime's `TzdbCompiler` from the latest IANA release and the CLDR
`windowsZones.xml` NodaTime picks from its `data/cldr` (byte-identical to nodatime.org's NZD for the same inputs), so
new tz data doesn't wait for nodatime.org. `--tzdb latest` takes nodatime.org's file, `--tzdb embedded` the pinned
NodaTime's (offline); `--tzdata` and `--cldr` pick other inputs. The compiled tarball is kept as `testdata/tzdb/tzdata<version>.tar.gz` so both ports' tests can compile it too.

## Test scenarios

`scenarios` enumerates the test assemblies with NUnit's `DefaultTestAssemblyBuilder`, so the cases are exactly what
NUnit runs. Each fixture becomes `test/scenarios/<namespace path>/<Fixture>.generated.*` (the compiler's under
`TzdbCompiler/`), listed in `test/scenarios/index.generated.*`. New upstream tests show as todo until ported. Fixtures
listed in `scenario-exclusions.txt` are emitted without cases.

## Windows time zones

Windows' zone rules have no redistributable source, so nothing exports them: the ports read the registry
(see [Timezones.md](../ts/docs/Timezones.md)).
