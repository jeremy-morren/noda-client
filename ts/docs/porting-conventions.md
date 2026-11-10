# Porting conventions

noda-js is a file-by-file port of NodaTime (the commit pinned in `tools/nodatime-ref.txt`,
fetched into `.nodatime/<ref>/`). Aims:

1. **NodaTime's API and names** (PascalCase). C# properties are getters, methods are methods. Only members JS calls by
   name keep JS names: `toString`, `toJSON`/`fromJSON`, `valueOf`, `[Symbol.iterator]`, and members of extended
   built-ins (`Error.message`, `Map.get`).
2. **NodaTime's wire formats**: text patterns, `toString()` and JSON.
3. **As little of our own code as possible**: translate line by line, don't redesign; generate whatever .NET can tell
   us (`tools/`).

## Files

| NodaTime | noda-js |
|---|---|
| `src/NodaTime/Foo.cs` | `src/noda-js/Foo.ts` |
| `src/NodaTime/Text/Patterns/Bar.cs` | `src/noda-js/Text/Patterns/Bar.ts` |
| `src/NodaTime.Testing/...` | `src/noda-js/Testing/...` |
| `src/NodaTime.Test/FooTest*.cs` (all partial files) | `test/ported/FooTest.test.ts` |
| anything generated | `*.generated.ts`. **Never edit**; re-run `node tools/generate.ts`. |

One TS file per C# type (partials merged). Keep NodaTime's member order and `#region`s (as `// #region`).

Ported files start with:

```ts
// Ported from NodaTime <ref>: src/NodaTime/LocalDate.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
```

- Own code starts with `// noda-js: new code.`; small additions in ported files are marked `// noda-js: ...`.
- Code ported from .NET (only `src/noda-js/System/`) starts with `// noda-js: port of <what> from dotnet/runtime
  (<path>).` and the .NET Foundation MIT copyright line, and keeps .NET's names and comments.
- XML doc comments become JSDoc (`<param>` → `@param`, `<returns>` → `@returns`, `<exception cref="X">` →
  `@throws {X}`, `<see cref="Foo.Bar"/>` → `{@link Foo.Bar}`). Implementation comments stay verbatim.

## Imports and module cycles

1. **Inside `src/`, import NodaTime types from the barrel `src/noda-js/internal.ts`**, never from each other's files.
   The barrel's order is the safe evaluation order (base classes first). Leaf modules (generated constants,
   `Utility/` helpers) may be imported directly. Separate entry points (`TimeZones/Tzdb...`, `System/`, `Testing/`)
   import from `internal.ts` but aren't in it.
2. **No module-level code may use another module's exports at evaluation time**, except `extends`. C# `static readonly`
   fields of object type become **lazy static getters**:

   ```ts
   // C#: public static Instant MaxValue { get; } = new Instant(...);
   static get MaxValue(): Instant { return (maxValue ??= new Instant(...)); }
   ```

   (`let maxValue: Instant | undefined;` at module level; a plain getter if C# returns a new struct each time.)
   Primitive constants stay `static readonly X = 5;`. This keeps everything tree-shakable: `"sideEffects"` lists only
   the registration modules and the barrel (whose order is an effect; `test/bundlers/` checks it).

Use `import type` for type-only imports, and `.ts` extensions on relative imports (`tsc` rewrites them).

## Types and members

| C# | TypeScript |
|---|---|
| `struct` / `class` | `class`; `readonly` where C# has it. Private/internal fields are TS `private`/plain (not `#private`), so factories can set them. |
| Type names | Unchanged; interfaces keep the `I` prefix. |
| Members (public, internal and private) | **The C# name**: `PlusDays`, `MaxValue`, `BclCompatibleTicks`. Except JS protocol members (`toString`, `toJSON`/`fromJSON`, `valueOf`, `[Symbol.iterator]`) and built-in overrides (`Error.message`/`name`, `Map.get`/`set`/...). Indexers are `Get(key)`/`Set(key, value)`. |
| Enum members | Unchanged (`IsoDayOfWeek.Monday`). Enums are generated. |
| Property | getter, never a method. Settable properties (only `PeriodBuilder`) get getter + setter. |
| Field | camelCase in NodaTime → `_camelCase` (`_nanoOfDay`). Fields standing in for a C# property, or PascalCase in NodaTime, are PascalCase. Module-level caches (`let maxValue`) are camelCase. |
| `const` | `static readonly` with the C# name, or a module-level `const` if private. |
| Public constructor overloads | one `constructor(...args)` dispatching at run time, with TS overload signatures. |
| Internal/private constructors | `/** @internal */ static` factories named **`New` + the C# parameter names, capitalised**: `internal LocalDate(int daysSinceEpoch)` → `LocalDate.NewDaysSinceEpoch(...)`; `private Duration(int days, long nanoOfDay, bool noValidation)` → `Duration.NewDaysNanoOfDayNoValidation(...)`. Mechanical, so separately ported files agree. Built with `Object.create(X.prototype)` or a module-private constructor token. |
| Nested types (`OffsetDateTime.Comparer`) | Top-level `OuterInner` (`OffsetDateTimeComparer`) declared before `Outer`, plus `static readonly Inner = OuterInner;`. |
| `default(T)` | The C# default value (`Duration.Zero`, `LocalDate` 0001-01-01); add `/** @internal */ static get DefaultValue()` if needed. |
| Struct field of a NodaTime struct type | Plain readonly field (values are immutable). |
| Method overloads | One implementation, TS overload signatures, run-time dispatch. Overloads that can't be told apart: the common one keeps the name, the other gets a suffix (listed in `api-differences.md`). |
| `out` / `ref` parameters | Return a tuple `[result, out]` (or an object); `ref`: return the new value or pass `{ value }`. |
| `T?` / nullable reference | `T \| null` (not `undefined`). C# defaults: `param: T = default`. |
| Delegates | Function types; named NodaTime delegates are `type` aliases. |
| Functions | Always PascalCase: extension methods, module-level functions, own helpers (`PadStart`, `Int64.Add`), members of objects standing in for static classes, data-shape properties. camelCase only for JS protocol members, instances (`tzdb`, `enAU`) and locals. |
| Extension methods | Exported functions with the C# name in the ported file; plus an instance member where the target is a noda-js class. |
| `IEquatable<T>.Equals` / `Equals(object)` / `==` | `implements IEquatable<T>` (`Utility/Equality.ts`, internal): `Equals(other: T): boolean; Equals(other: unknown): boolean;` and one implementation that checks `instanceof` first (never throws). |
| `IComparable<T>.CompareTo` / `CompareTo(object)` / `<` ... | `implements IComparable<T>`: `CompareTo(other: T \| null): number; CompareTo(other: unknown): number;`. `null`/`undefined` → `1`; other types → `Preconditions.CheckArgument(other instanceof T, "obj", "Object must be of type NodaTime.T.")`. Static `Compare` only where NodaTime has one. Comparer classes keep `(x, y)` and are `instanceof`-safe. |
| `operator +` `-` `*` `/` | static `Add` / `Subtract` / `Multiply` / `Divide`. |
| unary `-` | static `Negate(x)` (+ instance `Negate()` if NodaTime has one). Unary `+` dropped. |
| Conversion operators | static `From...` / instance `To...`; listed in `api-differences.md`. |
| `GetHashCode`, `Deconstruct` | Omitted. |
| `valueOf` | Throws `TypeError` (`Utility/ValueType.ts`), so `a < b` fails loudly. |
| `ToString()` | `toString()`: the default pattern, **invariant culture**. |
| `ToString(string?, IFormatProvider?)` | `toString(patternText?: string \| null, formatProvider?: IFormatProvider \| null)` |
| XML serialization, `TypeConverter`, BCL interop, `HighPerformance` | Not ported; leave `// Not ported: <member> (<reason>)` where the member was. |

### JSON

Value types get `toJSON()` (what NodaTime.Serialization.SystemTextJson writes) and static `fromJSON(json)` (same
pattern; throws `UnparsableValueException`).

## Numbers

NodaTime is compiled with overflow checking on, so `int`/`long` overflow throws `OverflowException` outside
`unchecked`.

| C# | TypeScript |
|---|---|
| `int`, `short`, `byte` | `number`; `Int32.Checked(x)` where overflow is reachable; `unchecked((int) x)` → `x \| 0`. |
| `int / int`, `long / long` | `Int64.Div(a, b)` / `Math.trunc(a / b)`. |
| `long` below 2⁵³ (nanosecond-of-day, days, ms since epoch) | `number` |
| `long` that can exceed 2⁵³ (ticks, total nanoseconds, `Period` hour…nanosecond fields) | Internally an exact **`Int64Value`** (`Utility/Numbers.ts`): a `number` when safe, else a `Long` (`Utility/Long.ts`: `LongBigInt` with `BigInt`, long.js otherwise). Use only members `LongBigInt` implements (add one with a test in `test/long/`). Compute with the checked `Int64` helpers. **Results**: `number` (nearest double beyond 2⁵³), with an `/** @internal */` exact accessor if needed (`ExactHours`). **Arguments**: `number \| string` via `Int64.FromArgument(value, "name")`; a decimal string is exact. A non-safe-integer `number` takes the C# `double` overload where there is one. |
| `BigInteger`, `Int128`, `decimal` (only `Duration` beyond ±292 years) | `WideInteger` (`Utility/WideInteger.ts`), reproducing `decimal` overflow and rounding. `BigInteger`/`Int128`-only members aren't ported. |
| `double` | `number` |
| `char` | 1-character `string`; arithmetic via `charCodeAt`. |
| `bool` | `boolean` |

**No `BigInt` in `src/`** except `Utility/LongBigInt.ts` (ESLint exempts it). The baseline is **ES2015**: `tsconfig.json`
targets ES2015 with the ES2015 library (plus `Intl` typings), so use the `Utility/` helpers (`PadStart`, `indexOf`,
`Object.keys`) instead of later APIs. Tests use `test/tsconfig.json` (newer lib, Node types); `npm run typecheck`
checks both. Generated test data may use `bigint` literals (`test/helpers/decode.ts` converts them).

## Exceptions

Every error is a `NodaError` (`Utility/NodaError.ts`). `Codes` is the .NET type's name (also `name`), then its base
types', nearest first, without `Exception`: `["SkippedTimeException", "ArgumentOutOfRangeException",
"ArgumentException", "SystemException"]`. `IsNodaError(e, code)` matches derived types, like a C# catch clause.

- **.NET library exceptions** (`ArgumentException`, `FormatException`, `OverflowException`, ...) are types, not classes
  (`Utility/SystemExceptions.ts`), with the .NET members (`ParamName`, `ActualValue`). Create them with the factories:
  `throw new ArgumentOutOfRangeException(nameof(x), x, msg)` → `throw NewArgumentOutOfRangeException("x", x, msg)`.
  `catch (FormatException)` → `IsNodaError(e, "FormatException")`.
- **NodaTime's exceptions** are classes derived from `NodaError` with their own properties
  (`UnparsableValueException.Value`, `SkippedTimeException.Zone`, ...).

Tests check the exact code, like NUnit's `Assert.Throws<T>`: `assertThrows("ArgumentException", action)`,
`expect(action).toThrowNodaError("FormatException")`, `expect(error).toBeNodaError(...)` (`test/setup.ts`).

## .NET library shims

| .NET | Shim |
|---|---|
| `StringBuilder` | `Utility/StringBuilder.ts` |
| `string.Format` / `Invariant($"...")` | `FormatString(fmt, ...args)` (`Utility/StringFormat.ts`) / template literals |
| `int.ToString("D2", ...)` | `FormatHelper` (ported) |
| `CultureInfo`, `DateTimeFormatInfo`, `CompareInfo`, `IFormatProvider` | `Globalization/NodaCultureInfo.ts`; data in `src/noda-js/Cultures/*.generated.ts`. |
| `IReadOnlyList<T>` / `IList<T>` | `readonly T[]` / `T[]` |
| `IDictionary`, `IReadOnlyDictionary`, `ConcurrentDictionary` | `Map` / `ReadonlyMap` |
| `IEnumerable<T>` with `yield` | generators returning `Iterable<T>` |
| `Lazy<T>` | a lazily set field |
| `Debug.Assert`, `Preconditions.Debug*` | No-op calls, as in a release build (ported tests use the `*_NotDebug` variants). |

## Tests

Every NUnit test and case of `NodaTime.Test` and `NodaTime.TzdbCompiler.Test` is generated into
`test/scenarios/**/*.generated.ts`; a ported test file gives a body per test method, run over every case. Methods
without a body show as `todo`. See `test/README.md`.
