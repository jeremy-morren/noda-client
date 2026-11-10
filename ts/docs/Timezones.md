# Time zones

The time zone types (`DateTimeZone`, `ZoneInterval`, `IDateTimeZoneProvider`, `DateTimeZoneCache`, ...) are in core;
the zones are in separate entry points. There's no `DateTimeZoneProviders`: import a provider.

| Import | Provider | NodaTime |
|---|---|---|
| `noda-js/tzdb/bundled` | `tzdb`, `tzdbSource`: the bundled IANA tzdb | `DateTimeZoneProviders.Tzdb`, `TzdbDateTimeZoneSource.Default` |
| `noda-js/tzdb` | `TzdbDateTimeZoneSource.FromBytes` / `FromBase64`: an NZD file loaded at run time | `TzdbDateTimeZoneSource.FromStream` |
| `noda-js/tzdb/compiler` | `CompileTzdb(source)` etc.: IANA tzdata compiled at run time | NodaTime.TzdbCompiler |
| `noda-js/system` | `SystemDateTimeZoneProvider`, `SystemDateTimeZoneSource`, `SystemDateTimeZone`: the host's zones | `DateTimeZoneProviders.Bcl`, `BclDateTimeZoneSource`, `BclDateTimeZone` |
| `noda-js/windows` | `WindowsIdDateTimeZoneProvider`: a provider that also accepts Windows IDs (CLDR mapping) | (none) |

```ts
import { tzdb } from "noda-js/tzdb/bundled";
import { SystemDateTimeZoneProvider } from "noda-js/system";

tzdb.Get("Australia/Sydney");
tzdb.GetSystemDefault();                         // e.g. Australia/Sydney
SystemDateTimeZoneProvider.GetSystemDefault();   // e.g. "AUS Eastern Standard Time" on Windows
```

Newer tzdb data: see [Up-to-date time zones](../README.md#up-to-date-time-zones).

## The system provider (`noda-js/system`)

`SystemDateTimeZoneSource` is NodaTime's `BclDateTimeZoneSource`; `SystemDateTimeZoneProvider` is a
`DateTimeZoneCache` over it; `SystemDateTimeZone` is `BclDateTimeZone` (`OriginalZone`, `DisplayName`,
`FromTimeZoneInfo`, `ForSystemDefault`).

The backend is chosen on first use, first match wins:

| Backend | When | IDs | Rules |
|---|---|---|---|
| `"addon"` | Windows, native addon package installed | Windows IDs | Windows', as .NET's `TimeZoneInfo` |
| `"ffi"` | Windows under Node 26+ (`node:ffi`), Bun (`bun:ffi`) or Deno (FFI permission granted) | Windows IDs | Windows', as .NET |
| `"intl"`, Windows | Windows without either | Windows IDs, mapped from `Intl`'s IANA zones by CLDR | `Intl` |
| `"intl"`, elsewhere | Browsers, non-Windows hosts | IANA IDs | `Intl` |

`VersionId` names it: `"TimeZoneInfo: Windows (node:ffi)"` (or `bun:ffi`, `Deno FFI`, the addon's package name), or
`"Intl: <tz version>"` (`"Intl: unknown"` where the host doesn't expose it), plus `" (Windows IDs from CLDR windowsZones
<n>)"` on Windows.

Without Windows' data or `Intl.DateTimeFormat` (e.g. embedded JS engines), creating the source throws `InvalidOperationException`.

Host modules are reached by feature detection (`process.getBuiltinModule`, `Deno.dlopen`) not static static imports, 
so `noda-js/system` loads anywhere. Node 26 prints an `ExperimentalWarning` on first use of `node:ffi`.

### On Windows

With FFI or the addon, the results are those of NodaTime's `BclDateTimeZoneSource` on .NET on the same machine:

- `src/noda-js/System/` ports the parts of .NET's `TimeZoneInfo` NodaTime uses: the registry's `Time Zones` keys
  (`TZI`, `Dynamic DST`), MUI display names in the user's UI language, `TimeZoneInfo.Local` (from
  `GetDynamicTimeZoneInformation`, including DST adjustment turned off), `GetSystemTimeZones` and
  `FindSystemTimeZoneById`.
- `SystemDateTimeZone.FromTimeZoneInfo` ports `BclDateTimeZone.FromTimeZoneInfo`.
- `test/system/WindowsComparison.test.ts` checks every zone (names, rules, intervals 1800-2100), the ID order and the
  local zone against an export from .NET (`npm run test:export-system-zones`).

`ForId` also accepts IANA IDs (as `FindSystemTimeZoneById` on .NET 6+): the zone keeps the IANA ID with its Windows zone's 
rules. The mapping is the CLDR copy `noda-js/windows` bundles, which may be newer than .NET's ICU copy; POSIX-style
IDs CLDR dropped (`EST5EDT`) aren't accepted.

The Windows calls are behind `IWindowsTimeZoneApi` (plain JS values). Bun and Deno use the same interface but only Node
is tested.

### Without Windows' data: Intl

`Intl` only gives the offset at an instant, so transitions are found by sampling weekly and binary-searching to the
millisecond (cached per year). Approximations:

- Two transitions less than a week apart that return to the same offset are missed.
- `ZoneInterval.Name` is the English short name ("AEST", "GMT+5:30"); `DisplayName` the English generic name, or the ID.
- `Savings`: within each year, the smallest offset is standard time and up to 2 hours above it is DST (wrong for
  negative DST, e.g. Europe/Dublin).
- Before 1800, the 1800 offset; from 2040, one annual rule (as ICU). `MinOffset`/`MaxOffset` are estimated.
- `OriginalZone` is null.

On Windows without FFI, IDs are the Windows IDs CLDR maps (territory "001") to a zone the host has, with that zone's
`Intl` rules; mapped IANA IDs are accepted too.

## The system default zone

`GetSystemDefault()` (both providers) and `SystemDateTimeZone.ForSystemDefault()` give the host's zone.

### TZ

Both providers honour `TZ` wherever there are environment variables (`process.env`, or `Deno.env` with permission),
Windows included. A leading `:` is ignored.

- **Unset or empty**: the host's zone (`TimeZoneInfo.Local` with FFI/addon, else `Intl`'s default).
- **A zone ID**: that zone, matched ignoring case. On Windows, a Windows ID as is and an IANA ID mapped by CLDR
  (`TZ=America/La_Paz` → "SA Western Standard Time"). Elsewhere, an IANA ID.
- **Anything else** (unknown ID, POSIX TZ string, Windows ID outside Windows): **UTC** (`"UTC"` on Windows, `"Etc/UTC"`
  elsewhere and for tzdb), as Node, Python, glibc and .NET on Unix do.

The tzdb provider maps a Windows ID through its source's `WindowsMapping`, and uses an IANA ID as is.

### When the zone can't be determined

The tzdb provider maps the host's zone as `TzdbDateTimeZoneSource.MapTimeZoneInfoId` does, falling back to
`GuessZoneIdByTransitions` with `Date`'s offsets (so it works without `Intl`). Ties go to the first ID in ordinal
order. A `TZ` zone is never guessed. With nothing to go on, `GetSystemDefaultId()` is null and `GetSystemDefault()`
throws `DateTimeZoneNotFoundException`.

## Windows IDs elsewhere (`noda-js/windows`)

`WindowsIdDateTimeZoneProvider` wraps a provider so it accepts Windows IDs (as written by .NET's `BclDateTimeZone` on
Windows), mapping each to its CLDR primary tzdb zone with tzdb's rules. `GetCldrWindowsZones()` is the mapping.

## Native addon (optional)

| Package | Platform |
|---|---|
| `noda-js-win32-x64` | 64-bit Windows |
| `noda-js-win32-arm64` | Windows on ARM64 |

- `noda-js` lists both as `optionalDependencies`; npm installs the matching one, nothing elsewhere. No 32-bit package.
- Same calls and results as FFI (checked by `scripts/native/compare-native.ts` and `test/system/environment.test.ts`), but no
  experimental FFI: a Node-API 8 module, loaded on Node 20.16+/22.3+, Bun and Deno.
- Order on Windows: addon, then FFI, then `Intl`.
- To skip it: `npm install --omit=optional`. Bundlers don't include it (loaded by package name at run time).
- Source: `native/windows/time-zones.c` (Node-API glue) and `windows-time-zones.c` (the Windows calls). Build:
  `npm run build:native` (Visual Studio's C++ tools and C++ Clang tools: clang-cl, lld-link). The `.node` and its PDB
  (`native/windows/build/Release/time-zones.pdb`, not packed) are reproducible, wherever the repository is checked out.
- C tests of `windows-time-zones.c` (`native/windows/test/`, [greatest](https://github.com/silentbicycle/greatest)
  1.5.0): `npm run test:native` (`-- --coverage` for line coverage).

## Differences from NodaTime

- `Bcl*` types are `System*` (`noda-js/system`). `TimeZoneInfo`'s public members are `Id`, `DisplayName`,
  `StandardName`, `DaylightName`, `SupportsDaylightSavingTime` and `HasIanaId`. Only Windows' data is read (.NET's
  Unix rules aren't ported).
- `VersionId` names the backend.
- `TZ` is honoured on Windows too; an unknown `TZ` is UTC.
- The tzdb provider's system zone comes from `TZ` or `Intl` and `Date`, not `TimeZoneInfo.Local`.
- No `DateTimeZoneProviders`; no `InTzdbSystemDefaultZone` / `InBclSystemDefaultZone`: use
  `InZone(clock, tzdb.GetSystemDefault())`.
