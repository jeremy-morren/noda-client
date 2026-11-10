# AGENTS.md

Two **line-for-line ports of [NodaTime](https://github.com/nodatime/nodatime)**, feature-compatible:

| Folder | What | Package |
|---|---|---|
| `ts/` | noda-js: TypeScript, any JS engine (ES2015) | npm `noda-js`, `noda-js-zod`, Windows addons |
| `dart/noda_dart/` | noda_dart: Dart, everywhere Dart and Flutter run | pub `noda_dart` |
| `tools/` | The C# generator both ports are generated from | — |
| `scripts/` | Shared CI and release scripts (TypeScript): `lib/`, `release/`, `changelog/`, `devices/`, `time-zones/`, `ci/` | — |
| `testdata/` | Test data both ports read: binary fixtures (the tzdata release the bundled NZD comes from), and the uncommitted `system-zones.json` export | — |

NodaTime is pinned in `tools/nodatime-ref.txt` (a main commit by default, so new tests are
included; a tag works too). Generated files name its HEAD commit. The weekly `export` workflow moves it to main.

## Principles

1. **As little of our own code as possible.** Port NodaTime line by line, keeping structure, member order and
   comments, so files compare side by side with the C#. Where .NET code is needed, port dotnet/runtime the same way.
   Mark the rest `// noda-js: new code.` / `// noda_dart: new code.`
2. **Generate everything that can be generated** from NodaTime (enums, constants, messages, cultures, calendar
   tables, tzdb, API listing, golden vectors, every NUnit test case) as real code per language
   (`*.generated.ts`, `*.generated.dart`) from one model. **Never edit generated files**: run `node tools/generate.ts`.
3. **Tests come from NodaTime**: each fixture is ported (`test/ported/`) and run over the generated cases; an unported
   test shows as todo/skipped.
4. **Deduplicate**: one generator, one set of scripts, one CI and release pipeline, deduplicate code whenver possible.
5. **Succint**: Short succint descriptive comments, small composable functions. Do not describe the obvious.

## Naming

- NodaTime's names unchanged in both ports, PascalCase members included (`date.PlusDays(1)`), except each language's
  protocol members (TS: `toString`, `toJSON`, `valueOf`; Dart: `toString`, `==`, `hashCode`, `compareTo`, `toJson`).
- Dart file paths as in C# (`lib/src/Text/Patterns/LocalDatePattern.dart`); a member named like its type uses a
  prefixed import (`nt.Offset`).
- Internal constructors: `New` + parameter names (`LocalDate.NewDaysSinceEpoch`) in both ports.
- See `ts/docs/porting-conventions.md`, `dart/docs/porting-conventions.md`.

## Exceptions

- TS: one `NodaError`, whose `Codes` are the .NET exception type and its bases.
- Dart: Dart's errors (`ArgumentError`, `RangeError`, `StateError`, `UnsupportedError`, `FormatException`), with
  NodaTime's types extending them (`SkippedTimeException extends RangeError`).

## System time zones

NodaTime's `BclDateTimeZoneSource` semantics in both ports (reference: `ts/docs/Timezones.md`):

- **Windows**: Windows zones read as .NET's `TimeZoneInfo` reads them (registry, Dynamic DST, MUI names, DST
  adjustment off); IANA IDs mapped by CLDR.
- **Elsewhere**: IANA zones from TZif files and `/etc/localtime`, Android's tzdata, or the web's `Intl`.
- **`TZ` is honoured everywhere, Windows included.** Unset/empty → the host's zone; a Windows or IANA ID → that zone;
  anything else → UTC.
- Tests compare with NodaTime on .NET on the same machine; CI runs them in many configured zones.

## Commands

```sh
npm ci                                                          # once: the scripts' packages
node tools/generate.ts                                          # regenerate both ports
cd ts && npm ci && npm run typecheck && npm test                # TypeScript
cd dart/noda_dart && dart pub get && dart analyze && dart test  # Dart (-p chrome, node, ... for the web)
```

## CI and releases

- `ci.yml`: both ports' tests on every platform feasible; results labelled by platform and architecture.
- `draft-release.yml` (push to main): version `version.txt` major.minor + next patch after the published releases;
  builds every package into a draft release. Publishing it runs `release-npm.yml` (npm, GitHub Packages) and
  `release-dart.yml` (pub.dev), which check the rebuilt assets are byte-identical.
- Changelogs (Keep a Changelog): add user-visible changes under `## [Unreleased]` in `ts/src/noda-js/CHANGELOG.md`
  and `dart/noda_dart/CHANGELOG.md`; releasing turns them into the version's section and opens a PR to main.

## Working here

- Feature branch, commit often; never push to main.
- Scripts are TypeScript (`node <script>.ts --help`), in a directory per purpose (`ts/scripts/`, `dart/scripts/`
  likewise), importing `noda-scripts/ci` and `noda-scripts/gh` (never `../` paths). Paths are repository-relative. No
  PowerShell, bash, `.js` or `.mjs`; workflows only call them (no shell logic in YAML).
- Comments short: only what the code can't say.
- No `.claude/` folder in the repository.
