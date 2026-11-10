# noda_dart

A line-for-line Dart port of [NodaTime](https://nodatime.org): the same types, names, text patterns, JSON, calendars
and test suite. Sibling of [noda-js](../../ts/README.md).

Runs everywhere Flutter and Dart run (Android, iOS, Windows, macOS, Linux, web with dart2js and dart2wasm). Depends
only on `package:meta`.

```dart
import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/tzdb_bundled.dart';

void main() {
  final zone = tzdb['Australia/Sydney'];
  final now = SystemClock.Instance.GetCurrentInstant();
  final local = now.InZone(zone);
  print(local);                                   // 2026-11-08T20:15:42 Australia/Sydney (+11)
  print(local.Date.PlusMonths(1));                // 2026-12-08
  print(Period.BetweenLocalDate(LocalDate(2026, 1, 31), local.Date));
}
```

## Names

- NodaTime's names, unchanged (`date.PlusDays(1)`, `Instant.MaxValue`), so NodaTime's docs apply.
- Dart's protocol members keep Dart names: `toString()`, `==`, `hashCode`, `compareTo`, `toJson()`/`fromJson`.
- Differences: [docs/api-differences](../docs/api-differences/).
- `Duration` shadows `dart:core`'s: use `import 'dart:core' as core;` for both. In Flutter, `Offset` clashes with
  `dart:ui`'s: import noda_dart `as nt` or `hide Offset`.

## Libraries

| Import | What |
|---|---|
| `package:noda_dart/noda_dart.dart` | Core types, text patterns, calendars |
| `package:noda_dart/tzdb_bundled.dart` | The bundled IANA tzdb (`DateTimeZoneProviders.Tzdb`) |
| `package:noda_dart/tzdb.dart` | `TzdbDateTimeZoneSource.FromBytes`: an NZD file loaded at run time |
| `package:noda_dart/tzdb_compiler.dart` | Compiles an IANA `tzdata*.tar.gz` at run time |
| `package:noda_dart/system.dart` | The system's time zones (`BclDateTimeZoneSource`): Windows' zones, the OS's tzdb, or the browser's `Intl` |
| `package:noda_dart/cultures.dart` | Culture data for formatting and parsing |
| `package:noda_dart/testing.dart` | NodaTime.Testing: `FakeClock`, fake zones |

## JSON

Value types have `toJson()` (NodaTime.Serialization.SystemTextJson's format) and a `fromJson` constructor, so
`jsonEncode`, `json_serializable` and `freezed` work without converters.

`ZonedDateTime` and `DateTimeZone` also need a provider to read the zone ID:

```dart
final json = jsonEncode(zoned);                              // "2026-11-08T20:15:42+11 Australia/Sydney"
final back = ZonedDateTime.fromJson(jsonDecode(json), tzdb); // throws UnparsableValueException for an unknown ID
final zone = DateTimeZone.fromJson('Europe/London', tzdb);   // DateTimeZoneNotFoundException if unknown
```

With `json_serializable`, pass the provider through `@JsonKey(fromJson: ...)`:

```dart
import 'package:json_annotation/json_annotation.dart';
import 'package:noda_dart/noda_dart.dart';
import 'package:noda_dart/tzdb_bundled.dart';

part 'meeting.g.dart';

ZonedDateTime _zonedFromJson(String json) => ZonedDateTime.fromJson(json, tzdb);
DateTimeZone _zoneFromJson(String json) => DateTimeZone.fromJson(json, tzdb);

@JsonSerializable()
class Meeting {
  Meeting(this.start, this.duration, this.zone);

  @JsonKey(fromJson: _zonedFromJson)
  final ZonedDateTime start;
  final Duration duration;                                   // no converter needed
  @JsonKey(fromJson: _zoneFromJson)
  final DateTimeZone zone;

  factory Meeting.fromJson(Map<String, dynamic> json) => _$MeetingFromJson(json);
  Map<String, dynamic> toJson() => _$MeetingToJson(this);
}
```

The calendar isn't in the JSON: values are read as ISO unless `fromJson` is given one
(`LocalDate.fromJson(json, CalendarSystem.Julian)`).

## Dart's DateTime and Duration

NodaTime's `DateTime`/`TimeSpan` conversions use Dart's `DateTime` and `Duration`:

- `Instant.FromDateTimeUtc` / `ToDateTimeUtc` (`dateTime.ToInstant()`); UTC only, so use `dateTime.toUtc()`.
- `LocalDateTime.FromDateTime` / `ToDateTimeUnspecified` (`dateTime.ToLocalDateTime()`), same on `LocalDate`.
- `Duration.FromCoreDuration` / `ToCoreDuration` (`dartDuration.ToDuration()`), `Offset.FromCoreDuration`,
  `stopwatch.ElapsedDuration()`.
- Precision is microseconds; finer values are truncated.

## The local time zone

`GetSystemDefault()` honours `TZ` on every platform, Windows included (a Windows or IANA ID; anything else is UTC),
else the system's zone. See [AGENTS.md](../../AGENTS.md#system-time-zones-both-ports).

## License

Apache-2.0, like NodaTime. Data licences (IANA tz database, CLDR, ICU): NOTICE.txt.
