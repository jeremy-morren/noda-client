# Porting conventions (Dart)

noda_dart is a file-by-file port of NodaTime, sibling of noda-js (`ts/`): same NodaTime commit (`tools/nodatime-ref.txt`), same
features, same generated tests. Aims, in order:

1. **NodaTime's API and names** (`date.PlusDays(1)`, `Instant.MaxValue`), with Dart idioms only where Dart has the
   C# construct (operators, `==`/`hashCode`, `Comparable`, extensions, `Iterable`, records for `out`). Dart's
   protocol members keep Dart names: `toString`, `==`, `hashCode`, `compareTo`, `iterator`, `toJson`.
2. **NodaTime's wire formats**: patterns, `toString()` and JSON.
3. **Little own code**: translate line by line; generate what .NET can tell us (`tools/` → `*.generated.dart`).
4. **Runs everywhere Flutter runs** (plus VM, AOT, Node), depending only on `package:meta`.

Read the C# first, then noda-js's file next to it. Where the languages differ, this document decides.

## Files

| NodaTime | noda_dart (`dart/noda_dart/`) |
|---|---|
| `src/NodaTime/LocalDate.cs` | `lib/src/LocalDate.dart` |
| `src/NodaTime/Text/Patterns/SteppedPatternBuilder.cs` | `lib/src/Text/Patterns/SteppedPatternBuilder.dart` |
| `src/NodaTime.Testing/FakeClock.cs` | `lib/src/Testing/FakeClock.dart` |
| `src/NodaTime.TzdbCompiler/Tzdb/TzdbZoneInfoParser.cs` | `lib/src/TzdbCompiler/Tzdb/TzdbZoneInfoParser.dart` |
| `src/NodaTime.Test/LocalDateTest*.cs` (all partials) | `test/ported/LocalDateTest_test.dart` |
| `src/NodaTime.TzdbCompiler.Test/Tzdb/TokensTest.cs` | `test/ported/TzdbCompiler/Tzdb/TokensTest_test.dart` |
| noda-js's `src/noda-js/System/*` (.NET's `TimeZoneInfo`) | `lib/src/System/*` |
| generated | `*.generated.dart` next to the C#'s place; test cases in `test/scenarios/**`. **Never edit**; run `node tools/generate.ts`. |

- One Dart file per C# type (partials merged; nested types in the outer type's file).
- Keep NodaTime's member order and `#region`s (as `// #region` comments).

Headers:

```dart
// Ported from NodaTime 6e024dde: src/NodaTime/LocalDate.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
```

- Own code: `// noda_dart: new code.` and one line on what it is.
- Ported .NET code: `// noda_dart: port of <what> from dotnet/runtime (<path>).` and
  `// Copyright (c) .NET Foundation and Contributors. Licensed under the MIT license (see NOTICE.txt).`

## Libraries and imports

- Inside `lib/src`, import relatively. Import cycles are fine; top-level and `static final` fields are lazy and
  isolate-safe, so `static readonly` → `static final`, and `Lazy<T>`/double-checked locking → plain lazy fields.
- Public libraries (`lib/*.dart`) mirror noda-js's entry points with `show` lists: `noda_dart.dart`, `tzdb.dart`,
  `tzdb_bundled.dart`, `tzdb_compiler.dart`, `system.dart`, `windows.dart`, `testing.dart`, `cultures.dart`,
  `calendars.dart`. Nothing under `lib/src` is public.

## Names

| C# | Dart |
|---|---|
| Types | Unchanged. |
| Members (any visibility) | The C# name (`PlusDays`, `MaxValue`). Internal → public + `@internal`. Private → `_` prefix (`_GenerateTotalDaysByMonth`, `_nanoOfDay`), unless another file needs it. Parameters and locals unchanged. |
| Protocol members | `ToString()` → `toString()`; `Equals(object)` → `operator ==`; `GetHashCode()` → `hashCode`; `CompareTo` → `compareTo`; `GetEnumerator` → `iterator`; `GetType()` → `runtimeType`; JSON → `toJson`/`fromJson`. |
| Member named like a type (`ZonedDateTime.Offset`) | The member hides the type in the class body, so import the type with prefix `nt` and write `nt.Offset` there. Only where the analyzer needs it. |
| Static and instance member with the same name | The static one gets the suffix `Static` (`Duration.NegateStatic`), unless an operator covers it. |
| Nested types | Top-level `OuterInner`: `OffsetDateTime.Comparer.Local` → `OffsetDateTimeComparer.Local`. |

Clashes with Dart's libraries are kept: NodaTime's `Duration` shadows `dart:core`'s. Code needing both uses
`import 'dart:core' as core;` (with `import 'dart:core' hide Duration;` in `lib/src`).

## Types and members

| C# | Dart |
|---|---|
| `struct` / `class` | `final class` (`abstract class` if unsealed/abstract); `readonly` → `final`. |
| `interface` | `abstract interface class` (or `abstract class` if extended). |
| `enum` | Generated extension type over `int` (`IsoDayOfWeek(0)` exists; `[Flags]` get `\|`, `&`, `~`). `ToString()` → `.Name`; `(int) x` → `x.value`; `(E) n` → `E(n)`. |
| Property | Getter (static: getter or `static final` if C# caches). Setters only on `PeriodBuilder`. |
| Field / `const` | Field (`final` if `readonly`) / `static const` (private: top-level `const _foo`). |
| Indexer | `operator []` (`[]=` for setters). |
| Public constructors | A prefix chain → one constructor with optional positional parameters. Other overloads → named constructors named for all their parameters (`LocalDate.EraYearOfEraMonthDay`). |
| Internal/private constructors | `New` + capitalised C# parameter names (`LocalDate.NewDaysSinceEpoch`, `Duration._NewDaysNanoOfDayNoValidation`); parameterless: `C.New()`. Mechanical, so separate files agree. |
| Method overloads | Prefix chains and C# optional parameters → optional positional parameters. Otherwise the first declared keeps the name; others add their distinguishing parameter types (`MinusZonedDateTime`), reusing noda-js's names. |
| `out` / `ref` | Return a record (`(bool, DateTimeZone?) TryGetZone(String id)`); `ref`: return the new value or pass a small holder. |
| Nullable | As NodaTime annotates. `CheckNotNull` on a non-nullable parameter → `// Dart: null safety checks x.`; tests passing `null` there are skipped ("null safety"). |
| Optional parameters | Optional positional, same defaults. |
| Delegates | Function types; named delegates → `typedef`. |
| Extension methods | Dart `extension` in the ported file. |
| `IEquatable<T>` / `==` | `bool Equals(T other)` + `operator ==(Object other) => other is T && Equals(other)`. |
| `IComparable<T>` / `<` etc. | `implements Comparable<T>` (`compareTo`), `CompareTo(Object?)` only where tested, and `<`, `<=`, `>`, `>=` where C# has them. |
| `IComparer<T>` / `IEqualityComparer<T>` | Interfaces in `lib/src/Utility/Comparers.dart`. |
| Operators | Dart operators where C# has them, plus NodaTime's named methods. With several overloads the operator takes the first; others are methods only (`MinusInstant`). |
| Conversion operators | `From...` / `To...` methods. |
| `IEnumerable<T>` / `yield` | `Iterable<T>` / `sync*`. `IReadOnlyList` → `List.unmodifiable`; `IReadOnlyDictionary` → `Map.unmodifiable`; LINQ → `Iterable` methods. |
| `ToString(pattern, provider)` | `toString()` (default pattern, invariant culture) + `ToStringPattern(String? patternText, [IFormatProvider?])`. |
| `Deconstruct` | A record getter: `final (y, m, d) = date.Deconstruct;`. |
| `lock`, `Interlocked`, `volatile`, `ThreadLocal` | Dropped (`// Dart: isolates don't share memory.`). |
| `IDisposable` | Dropped unless it releases a platform resource (`close()`). |
| `IXmlSerializable`, `[Serializable]`, `TypeConverter`, `HighPerformance` | `// Not ported: <member> (<reason>)`. |
| BCL interop | Dart's `DateTime` (`ToDateTimeUtc()`, `FromDateTimeUtc`; `DateTimeKind` → `isUtc`) and `Duration` for `TimeSpan` (`ToCoreDuration`, `FromCoreDuration`). Microseconds only: round as .NET does (ticks: towards negative infinity) and comment. `Stopwatch` → Dart's. `DateTimeOffset`, `DateOnly`, `TimeOnly`, `TimeProvider`: not ported (see `api-differences/core.md`). |

### JSON

Each value type has `String toJson()` (as `NodaTime.Serialization.SystemTextJson` writes) and
`factory T.fromJson(String json)` (same pattern; throws `UnparsableValueException`). A constructor, so
`json_serializable` and `freezed` need no converter.

## Numbers

NodaTime checks overflow, so `int`/`long` overflow throws `OverflowException` outside `unchecked`.

| C# | Dart |
|---|---|
| `int`, `long`, ... | `int` (64-bit on VM/AOT/wasm, but wraps): where overflow is reachable use `lib/src/Utility/Checked.dart` (`Checked.Add`, `Multiply`, `ToInt32`, ...). `unchecked((int) x)` → `x.toSigned(32)`. |
| Bitwise operators | dart2js truncates to 32 bits, unsigned: beyond 32 bits use arithmetic (`~/`, `%`) with a `// noda_dart:` comment; wrap possibly negative 32-bit results in `.toSigned(32)`. |
| `/`, `%`, `>>>` | `~/`; `a.remainder(b)` (Dart's `%` is Euclidean); `>>>`. |
| dart2js | `int` is exact only to ±2⁵³. Literals beyond that: `Int64.MaxValue`, `Int64.MinValue` or `int.parse`. Such test cases are skipped on dart2js. |
| `BigInteger`, `Int128`, `decimal` | `BigInt`; reproduce `decimal` overflow and rounding where visible. |
| `double` | `double`; `(long) d` → `d.truncate()` (check NaN/infinity first where reachable). |
| `char` | `String` of length 1; arithmetic via `codeUnitAt(0)` / `String.fromCharCode`. |
| `string.Format`, `StringBuilder` | Interpolation (doubles need .NET's format: `lib/src/Utility/StringFormat.dart`); `StringBuffer`. |

## Exceptions

Dart's errors where Dart has the concept; NodaTime's exceptions extend them.

| .NET | Dart |
|---|---|
| `ArgumentException` | `ArgumentError` |
| `ArgumentNullException` | `ArgumentError.notNull(name)` (nullable parameters only) |
| `ArgumentOutOfRangeException` | `RangeError` |
| `InvalidOperationException` | `StateError` |
| `NotSupportedException` / `PlatformNotSupportedException` | `UnsupportedError` |
| `NotImplementedException` | `UnimplementedError` |
| `FormatException` | `FormatException` |
| `KeyNotFoundException` | `ArgumentError` |
| `OverflowException`, `DivideByZeroException` | Ours, `extends ArithmeticException` (`lib/src/Utility/SystemExceptions.dart`) |
| `IndexOutOfRangeException` | `IndexError` |
| `IOException`, `EndOfStreamException` | Ours in `SystemExceptions.dart` (`dart:io` isn't on the web) |
| NodaTime's | Same names: `SkippedTimeException extends RangeError`, `UnparsableValueException extends FormatException`, `InvalidNodaDataException implements Exception`, ... |

Messages are NodaTime's and .NET's. `test/helpers/Assertions.dart` has matchers named for the .NET types
(`ThrowsArgumentOutOfRange` → `RangeError`).

## Doc comments

NodaTime's XML docs become `///`: `<summary>` → first paragraph, `<param name="x">` → `[x]: ...`, `<returns>` →
`Returns ...`, `<exception cref="X">` → `Throws [X] ...`, `<see cref="Foo.Bar"/>` → `[Foo.bar]`, `<c>x</c>` →
`` `x` ``, `<para>` → blank `///`. Implementation comments verbatim.

## Platforms

- Platform code (`lib/src/System/`, clock, local zone) uses conditional imports; never `dart:io`, `dart:ffi` or
  `dart:js_interop` in a file other platforms compile.
- Windows: `dart:ffi`; TZif: `dart:io`; web: `Intl` via `dart:js_interop`.
- pana must keep reporting every platform and `is:wasm-ready`.

## Tests

`tools/` generates every NUnit case of `NodaTime.Test` and `NodaTime.TzdbCompiler.Test` into `test/scenarios/**`. A
ported test gives a body per test method:

```dart
// Ported from NodaTime 6e024dde: src/NodaTime.Test/LocalDateTest.cs (+ partial files)
import '../scenarios/LocalDateTest.generated.dart' as scenarios;
import '../helpers/Scenarios.dart';

void main() {
  port(scenarios.fixture, {
    'EpochProperties': (args) { ... },
    'FromDayOfYear_Valid': (args) { final [int year, int dayOfYear] = args; ... },
  });
}
```

`port()` (`test/helpers/Scenarios.dart`) registers one test per case (NUnit's name), skips methods without a body
("not ported") and cases marked for dart2js, and fails on a body with no test method. Helpers live in
`test/helpers/` with noda-js's file names.
