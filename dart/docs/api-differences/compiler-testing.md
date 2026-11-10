# API differences: tzdb compiler and NodaTime.Testing

`package:noda_dart/tzdb_compiler.dart` (with `FileUtility`) and `package:noda_dart/testing.dart`.

## NodaTime.Testing

| C# | Dart | Why |
|---|---|---|
| `FakeClock(Instant)`, `FakeClock(Instant, Duration)` | `FakeClock(Instant initial, [Duration? autoAdvance])` (null → `Duration.Zero`) | A prefix chain; `Duration.Zero` isn't a constant, so the default is null. |
| `FakeClock.FromUtc(y, m, d)`, `FromUtc(y, m, d, h, mi, s)` | `FakeClock.FromUtc(int year, int monthOfYear, int dayOfMonth, [int hourOfDay = 0, int minuteOfHour = 0, int secondOfMinute = 0])` | One method: the 3-argument overload is midnight. |
| `FakeClock.AdvanceNanoseconds(long)` etc. | `int` parameters | `long` → `int`. |
| `SingleTransitionDateTimeZone(Instant, int, int)` | `SingleTransitionDateTimeZone(Instant transitionPoint, int offsetBeforeHours, int offsetAfterHours)` | First declared keeps the unnamed constructor. |
| `SingleTransitionDateTimeZone(Instant, Offset, Offset)`, `(Instant, Offset, Offset, string id)` | `SingleTransitionDateTimeZone.TransitionPointOffsetBeforeOffsetAfter(Instant, Offset, Offset, [String id = 'Single'])` | Another overload (a prefix chain of two): named for its parameters. |
| `MultiTransitionDateTimeZone.Builder` | `MultiTransitionDateTimeZoneBuilder` | Dart has no nested types. |
| `Builder()`, `Builder(int, int)`, `Builder(int, int, string)` | `MultiTransitionDateTimeZoneBuilder([int firstStandardOffsetHours = 0, int firstSavingOffsetHours = 0, String firstName = 'First'])` | A prefix chain. |
| `Builder(int firstOffsetHours, string firstName)` | `MultiTransitionDateTimeZoneBuilder.FirstOffsetHoursFirstName(int, String)` | Not in the chain: named for its parameters. |
| `Builder.Add(Instant, int)`, `Add(Instant, int, int)`, `Add(Instant, int, int, string)` | `Add(Instant transition, int newStandardOffsetHours, [int newSavingOffsetHours = 0, String? newName])` (null → "Interval from {transition}") | A prefix chain. |
| `MultiTransitionDateTimeZone.Builder : IEnumerable` (`GetEnumerator` throws) | not ported | Only exists for C# collection initializers. |
| `MultiTransitionDateTimeZone.Intervals`, `Transitions` (`ReadOnlyCollection`) | `List` (unmodifiable) | |
| `FakeDateTimeZoneSource.Builder` | `FakeDateTimeZoneSourceBuilder` (`extends Iterable<DateTimeZone>`) | Dart has no nested types; `IEnumerable<DateTimeZone>` → `Iterable`. |
| `FakeDateTimeZoneSource.GetSystemDefaultId()` (looks up `TimeZoneInfo.Local.Id` in `BclIdsToZoneIds`) | looks up `SystemDateTimeZoneSource().GetSystemDefaultId()` | The host's zone ID on every platform (`TimeZoneInfo` is Windows-only here). |
| `DurationConstruction.Days(this double)`, `Days(this int)` (and `Hours`, `Minutes`, `Seconds`, `Milliseconds`, `Ticks`, `Nanoseconds`; `int` and `long` overloads) | `extension DurationConstruction on int` (`5.Days()`) and `extension DurationConstructionDouble on double` (`1.5.Days()`, calling `Duration.FromDaysDouble`, ...) | `int` and `long` are both `int`; one extension per receiver type. |
| `LocalDateConstruction.January(this int day, int year)` ... | `extension LocalDateConstruction on int` (`1.January(2017)`) | |

## Tzdb compiler

| C# | Dart | Why |
|---|---|---|
| The `NodaTime.TzdbCompiler` command line (`Program.Main(string[])`, `CompilerOptions`) | `CompileTzdb`, `CompileTzdbToNzd` (async), `CompileTzdbSync`, `CompileTzdbToNzdSync`, `CompileTzdbOptions` (`WindowsZones`, `Log`) in `package:noda_dart/tzdb_compiler.dart`; internally `Program.Main(FileSource, WindowsZones, log)` returning `({Uint8List Nzd, TzdbDateTimeZoneSource Source})` | A library, as noda-js's; output in memory, always validated. Sources: bytes, `Stream<List<int>>`, http(s) URLs (archive or directory ending `/`), `data:` URIs, local files and directories. Sync functions: bytes or `data:` only. |
| `Program.LoadWindowsZones`, the `-w` directory, `--windows-override`, `CldrWindowsZonesParser` | not ported | CLDR XML parsing; the caller passes a `WindowsZones` (default: the bundled CLDR mapping, `GetCldrWindowsZones()`). |
| `-z` (`GenerateDateTimeZone` from the command line), `-s` (XML schema), `CreateOutputStream`, `Read` | not ported | Command line, files, XML. (`TzdbDatabase.GenerateDateTimeZone` itself is ported.) |
| `Program.MergeWindowsZones` | ported; sorts by Windows ID and territory ordinally | .NET's default `OrderBy` comparer is culture-sensitive; the IDs are ASCII. |
| `TzdbZoneInfoCompiler()`, `TzdbZoneInfoCompiler(TextWriter? log)` | `TzdbZoneInfoCompiler([void Function(String line)? log = print])` | A log function rather than a TextWriter; by default, `print` (C#: the console). |
| `TzdbZoneInfoCompiler.CompileAsync(string path)` | ported (`Future<TzdbDatabase>`), plus `@internal Compile(FileSource)` (noda-js's) | A directory or local file needs dart:io; on the web a path is a URL relative to the page. |
| `TzdbZoneInfoCompiler.ZoneFiles`, `Iso3166TabFile`, `ZoneTabFile`, `Zone1970TabFile` (private) | `@internal` | Input.dart downloads them from directory URLs (as noda-js). |
| `FileSource` private constructor | `@internal FileSource.NewNamesOpenFunctionFullOrigin` | Archive.dart builds sources too. |
| `FileSource.Open(name)` (`Stream`), `FromArchive(Stream, string)` | `Uint8List Open(String)`, `FromArchive(Uint8List, String)` | A stream is the bytes it holds; tar read by noda_dart's own reader (`Tar.dart`). |
| `IoExtensions.ReadLines(this Stream)`, `ReadLines(this TextReader)`, `ReadLines(this FileSource, string)` | `extension IoExtensions on Uint8List`, `IoExtensionsTextReader on String`, `IoExtensionsFileSource on FileSource` | One extension per receiver. `ReadLines(Func<TextReader>)` not ported (only used by the FileSource overload). |
| `TzdbZoneInfoParser.Parse(Stream, TzdbDatabase)`, `Parse(TextReader, TzdbDatabase)` | `Parse(Uint8List, TzdbDatabase)`, `ParseTextReader(String, TzdbDatabase)` | Overloads: the second gets its parameter type. |
| `TzdbZoneInfoParser.ParseLink` → `Tuple<string, string>` | `(String, String)` | Record. |
| `Tokens.TryNextToken(out string)` | `(bool, String) TryNextToken()` | `out` → record. |
| `MissingTokenException(string)`, `(string, string)` | `MissingTokenException(String name, [String? message])` | A prefix chain. |
| `TzdbStreamWriter.Write(..., Stream)` | `Write(..., Stream)` with noda_dart's `Utility/Stream.dart` `Stream` | |
| `TzdbDatabase.ToTzdbDateTimeZoneSource()` | reads the data back with `TzdbDateTimeZoneSource.FromBytes` | noda-js's API for NZD bytes. |
| `TzdbDatabase.LogCounts()` | `LogCounts(void Function(String) log)` | Writes to a log function rather than the console. |
| `FileUtility.LoadFileOrUrlAsync(string)` → `Stream` | `Future<Uint8List>` | The whole file or download, decompressed (gzip by noda_dart's own inflate, `Inflate.dart`, on every platform). |
| `FileUtility.Decompress` (private) | `@internal` | Archive.dart decompresses archives given as bytes. |
| `HttpRequestException` | `HttpRequestException` (`lib/src/TzdbCompiler/Shims.dart`, exported by `tzdb_compiler.dart`) | Dart has no equivalent on every platform. |
| `NotImplementedException` (rules with a TYPE) | `UnimplementedError` | |
