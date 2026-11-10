# Tests

| Folder / file | What |
|---|---|
| `scenarios/` | **Generated**: every NodaTime.Test and NodaTime.TzdbCompiler.Test case. `types.dart` is hand-written. |
| `ported/` | NodaTime's tests ported line by line, one `_test.dart` per C# fixture, at the C# path. |
| `helpers/` | The harness (`Scenarios.dart`, `Decode.dart`), NUnit's assertions, NodaTime.Test's helpers, the fake Windows registry, fixtures, host services. |
| `tzdb-compiler/` | Our tests of the tzdb compiler, inflate and tar reader. |
| `api/`, `golden/` | Generated data (NodaTime's public API; golden formatting, JSON and calendar vectors) and their tests. |
| `system/` | System time zone tests (fake Windows, real Windows, `TZ` in child processes). |
| `DartInterop_test.dart` | Conversions to and from Dart's `DateTime`, `Duration` and `Stopwatch`. |
| `support/` | Platform glue (see `dart_test.yaml`). |

## Running

```sh
cd dart/noda_dart
dart test test/ported -p vm
dart test test/ported/LocalDateTest_test.dart -p vm -N 'PlusDays'
dart test test/ported -p node -c dart2js
dart test test/ported -p chrome -c dart2wasm
```

Test names are `<fixture> <Method> #<case> <arguments>`; unported methods are skipped as `<fixture> <Method> [<file:line>]`.

## Porting a fixture

Read `dart/docs/porting-conventions.md`, the scenario (`test/scenarios/FooTest.generated.dart`) and noda-js's port
(`ts/test/ported/FooTest.test.ts`). Then:

```dart
// Ported from NodaTime 6e024dde: src/NodaTime.Test/FooTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:noda_dart/src/LocalDate.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../scenarios/FooTest.generated.dart' as scenarios;

final LocalDate SampleDate = LocalDate(2011, 1, 1);

void main() {
  port(scenarios.fixture, {
    'Constructor_Invalid': (args) {
      final [int year, int month, int day] = args;
      Assert.Throws<RangeError>(() => LocalDate(year, month, day));
    },
    'DayOfWeek_AroundEpoch': (args) {          // ExpectedResult: return the value
      final [int year] = args;
      return LocalDate(year, 1, 1).DayOfWeek;
    },
  }, skip: {
    'XmlSerialization': SkipReasons.Xml,
  });
}
```

- One body per C# test method, in the scenario's order; partial files in `// #region FooTest.X.cs` blocks. Keep the
  C#'s comments and statement order.
- Overloaded methods: key by `'Method(int, LocalDate)'` (the scenario's `parameters`).
- Arguments arrive decoded, in C# order. Enums are the generated extension types; `CultureInfo` is `NodaCultureInfo`;
  `Type` is its full name; a fixture's `Data` is a `Map<String, Object?>`.
- Async bodies are awaited.
- C#'s private fields and helpers become top-level, with C# names; `params T[]` is a `List<T>`.
- Fixtures using cultures pass `cultures: scenarioCultures` (`import '../scenarios/cultures.generated.dart'`).
- Test-assembly statics are registered in `main()`: `testStatics['X.Y'] = () => value;`; test zones in `testZones`.
- Pattern fixtures spread `...PatternTestBase.Bodies<T>((fields) => Data(...))` into their bodies.
- Run `dart analyze` and the fixture on the VM and dart2js. Fix lib bugs line by line with the C#.

## Assertions

NUnit's API (`helpers/Assertions.dart`), so assertions stay verbatim; only exception types change (see
`dart/docs/porting-conventions.md`, "Exceptions"):

- `Assert.Throws<T>` requires the exact type; `Assert.Catch<T>` accepts subtypes.
- `Assert.Throws<ArgumentNullException>` is `Assert.ThrowsArgumentNull` (where Dart's types allow a null).
- `Assert.Ignore` skips the case. Format arguments become string interpolation.

## Skipping

Port everything Dart can express. Otherwise add a `skip:` entry, with a `SkipReasons` constant when one fits:

| `SkipReasons.` | For |
|---|---|
| `Xml` | XML serialization |
| `NullSafety` | a `null` Dart's types don't allow |
| `UnaryPlus` | C#'s unary `+` |
| `MinMaxValue` | `TestHelper.AssertMinMaxValue` |
| `DefaultConstructor` | `new T()` / `default(T)` of a struct |
| `DateTimeOffset`, `DateOnlyTimeOnly` | .NET types Dart lacks |
| `CurrentCulture` | setting the current culture |
| `BclFormatting`, `BclCalendar` | .NET's formatting or calendars as the oracle |
| `Reflection` | reflection over NodaTime's assembly |
| `Dart2jsInt` | `if (isDart2js) 'Method': SkipReasons.Dart2jsInt` |

For one unportable line, leave `// Not ported: <what> (<why>).` instead. The harness itself skips methods without a
body, NUnit's ignored/explicit cases, generator exclusions, undecodable arguments (`UnsupportedValue`) and, on
dart2js, cases with integers beyond ±2^53.

## dart2js

An `int` is a JavaScript number, exact to ±2^53: write larger literals as `Int64.MaxValue` or `int.parse('...')`,
and skip bodies that compute with them (`SkipReasons.Dart2jsInt`). Bitwise operators truncate to 32 bits.
