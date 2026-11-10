# Time zones

There's no `DateTimeZoneProviders`. Import the provider you need.

```ts
import { DateTimeZoneCache, Instant } from "noda-js";
import { tzdb, tzdbSource } from "noda-js/tzdb/bundled";            // DateTimeZoneProviders.Tzdb
import { TzdbDateTimeZoneSource } from "noda-js/tzdb";
import { CompileTzdb } from "noda-js/tzdb/compiler";
import { SystemDateTimeZoneProvider, SystemDateTimeZoneSource } from "noda-js/system"; // DateTimeZoneProviders.Bcl

// The bundled IANA tzdb.
const sydney = tzdb.Get("Australia/Sydney");
Instant.FromUtc(2024, 3, 31, 12, 0).InZone(sydney);
tzdb.GetSystemDefault();                          // the host's zone, e.g. Australia/Sydney

// A Windows ID (e.g. from .NET's BclDateTimeZone) as a tzdb zone.
tzdb.Get(tzdbSource.WindowsMapping.PrimaryMapping.get("AUS Eastern Standard Time")!);

// Newer tzdb data: an NZD file, or IANA tzdata compiled at run time.
const fromNzd = new DateTimeZoneCache(TzdbDateTimeZoneSource.FromBytes(nzdBytes));
const compiled = new DateTimeZoneCache(await CompileTzdb("https://data.iana.org/time-zones/tzdata-latest.tar.gz"));

// The host's own zones: Windows' zones on Windows, Intl's elsewhere.
SystemDateTimeZoneProvider.GetSystemDefault();    // e.g. "AUS Eastern Standard Time" on Windows
new SystemDateTimeZoneSource().Backend;           // "addon", "ffi" or "intl"
```

## The system provider

On Windows it reads Windows' time zone data, giving the same results as NodaTime's `BclDateTimeZoneSource` on .NET.
It uses the native addon if installed, then the runtime's FFI (Node 26+ `node:ffi`, Bun, Deno), then `Intl`.
Elsewhere it uses `Intl` (approximate: transitions are found by sampling).

## TZ

Both providers honour `TZ`, Windows included. A Windows or IANA ID gives that zone. Unset or empty gives the host's
zone. Anything else gives UTC.

## Native addon

`noda-js-win-x64` and `noda-js-win-arm64` are optional dependencies of `noda-js`, installed by npm on Windows. Skip them
with `npm install --omit=optional`. Bundlers don't include them.
