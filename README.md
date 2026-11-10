# noda-client: NodaTime for TypeScript and Dart

[![Release](https://img.shields.io/github/v/release/jeremy-morren/noda-client)](https://github.com/jeremy-morren/noda-client/releases/latest)

Line-for-line ports of [NodaTime](https://nodatime.org), the date and time library for .NET, with NodaTime's API,
text formats, time zones and calendars, and NodaTime's own tests:

| Port | Folder | Package | Runs on |
|---|---|---|---|
| **noda-js** (TypeScript) | [`ts/`](ts/README.md) | [`noda-js`](https://www.npmjs.com/package/noda-js) on npm | any JavaScript engine (ES2015): browsers, Node, Bun, Deno, React Native (Hermes), embedded engines |
| **noda_dart** (Dart) | [`dart/noda_dart/`](dart/noda_dart/README.md) | [`noda_dart`](https://pub.dev/packages/noda_dart) on pub.dev | everywhere Flutter and Dart run: Android, iOS, Windows, macOS, Linux, the web (dart2js and dart2wasm) |

## Getting started

### TypeScript / JavaScript

[![noda-js](https://img.shields.io/npm/v/noda-js?label=noda-js)](https://www.npmjs.com/package/noda-js)
[![noda-js-zod](https://img.shields.io/npm/v/noda-js-zod?label=noda-js-zod)](https://www.npmjs.com/package/noda-js-zod)
[![noda-js-win-x64](https://img.shields.io/npm/v/noda-js-win-x64?label=noda-js-win-x64)](https://www.npmjs.com/package/noda-js-win-x64)
[![noda-js-win-arm64](https://img.shields.io/npm/v/noda-js-win-arm64?label=noda-js-win-arm64)](https://www.npmjs.com/package/noda-js-win-arm64)

```sh
npm i noda-js
npm i noda-js-zod zod   # optional: zod schemas for NodaTime's JSON formats
```

```ts
import { Instant, LocalDate, LocalDatePattern } from "noda-js";
import { tzdb } from "noda-js/tzdb/bundled";
import { enAU } from "noda-js/cultures";

const date = new LocalDate(2024, 3, 1).PlusDays(30);
LocalDatePattern.Create("d MMMM uuuu", enAU).Format(date);                   // "31 March 2024"
Instant.FromUtc(2024, 3, 31, 12, 0).InZone(tzdb.Get("Australia/Sydney")).toString();
// "2024-03-31T23:00:00 Australia/Sydney (+11)"
```

See also:
- [time zones](ts/docs/Timezones.md) (the system's zones, `TZ`, Windows IDs, the native addon)
- [`noda-js/linq`](ts/docs/linq.md) (comparers for [linq-to-typescript](https://github.com/arogozine/LinqToTypeScript)).

On Windows, npm also installs the native addon for `noda-js/system` (`noda-js-win-x64` or `noda-js-win-arm64`). Without those, `noda-js/system` uses the runtime's FFI, then `Intl`.

### Dart / Flutter

[![noda_dart](https://img.shields.io/pub/v/noda_dart?label=noda_dart)](https://pub.dev/packages/noda_dart)

```sh
dart pub add noda_dart   # or: flutter pub add noda_dart
```

```dart
import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/tzdb_bundled.dart';

void main() {
  final local = Instant.FromUtc(2024, 3, 31, 12, 0).InZone(tzdb['Australia/Sydney']);
  print(local);                                                       // 2024-03-31T23:00:00 Australia/Sydney (+11)
  print(Period.BetweenLocalDate(LocalDate(2024, 1, 31), local.Date)); // P2M
}
```

Both follow NodaTime's main branch, and both are generated, as far as possible, from NodaTime itself by the .NET
tools in [`tools/`](tools/README.md): enums, constants, culture data, calendar tables, the tz database, and every
test case of NodaTime's test suite. See [AGENTS.md](AGENTS.md) for how the repository works.

## LICENSE

Licensed under Apache-2.0, like NodaTime. See [NOTICE.txt](NOTICE.txt) for data licences.
