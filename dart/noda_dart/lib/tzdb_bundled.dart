// noda_dart: new code. The bundled tzdb: NodaTime's DateTimeZoneProviders.Tzdb and TzdbDateTimeZoneSource.Default.
library;

import 'src/DateTimeZoneProviders.dart';
import 'src/IDateTimeZoneProvider.dart';
import 'src/TimeZones/TzdbBundledData.generated.dart' as bundled;
import 'src/TimeZones/TzdbDateTimeZoneSource.dart';

export 'tzdb.dart';

/// The bundled tzdb source: NodaTime's `TzdbDateTimeZoneSource.Default`.
TzdbDateTimeZoneSource get tzdbSource => TzdbDateTimeZoneSource.Default;

/// A provider over the bundled tzdb source: NodaTime's `DateTimeZoneProviders.Tzdb`.
IDateTimeZoneProvider get tzdb => DateTimeZoneProviders.Tzdb;

/// The bundled tz database's version, e.g. "2026f".
const String bundledTzdbVersion = bundled.tzdbVersion;

/// The SHA-256 of the bundled NZD file (hex), to compare with nodatime.org's published files.
const String bundledTzdbSha256 = bundled.sha256;
